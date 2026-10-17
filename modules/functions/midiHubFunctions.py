"""Network and list operations for MIDI Hub, independent from the UI toolkit."""

from __future__ import annotations

import hashlib
import json
import os
import queue
import threading
import time
from pathlib import Path
from urllib.parse import quote, urljoin, urlparse

import requests

from modules import configuration
from modules.functions import mainFunctions
from ui.midiHub import MidiHubTab
from ui.midiPlayer import MidiPlayerTab


midiDataUrl = "https://api.nanomidi.net/api/midiData"
bitMidiSearchUrl = "https://bitmidi.com/api/midi/search"
bitMidiBaseUrl = "https://bitmidi.com"
# BitMidi's Cloudflare edge returns 520 for requests' default python-requests UA.
bitMidiRequestHeaders = {"User-Agent": "BetterNanoMidi/1.0"}
pageSize = 10
bitMidiPageSize = 15
hubCacheDirectory = os.path.join(configuration.baseDirectory, "Cache", "MidiHub")
coverCacheDirectory = os.path.join(hubCacheDirectory, "covers")
catalogCachePath = os.path.join(hubCacheDirectory, "catalog.json")
coverPreloadWorkers = 8
bitMidiRetryableStatuses = {500, 502, 503, 504, 520, 521, 522, 523, 524, 525, 526}
currentPage = 1
allMidiData: list[dict] = []
filteredData: list[dict] = []
totalPages = 0
searchQuery = ""
sortValue = "Newest"
_activeSource = "nanomidi"
_bitMidiQuery = ""
_bitMidiResults: list[dict] = []
_bitMidiTotalPages = 1
_bitMidiTotal = 0
_searchGeneration = 0
_catalogGeneration = 0
_requestLock = threading.RLock()
downloadFolder = os.path.join(configuration.baseDirectory, "Midis")
os.makedirs(downloadFolder, exist_ok=True)


def _emitHubState(**values) -> None:
    app = mainFunctions.getApp()
    if app and hasattr(app, "hubStateRequested"):
        app.hubStateRequested.emit(values)


def _coverCacheStem(image_filename: str) -> str:
    digest = hashlib.sha256(image_filename.encode("utf-8")).hexdigest()
    return os.path.join(coverCacheDirectory, digest)


def _cachedCoverPath(image_filename: str) -> str:
    if not image_filename:
        return ""
    stem = _coverCacheStem(image_filename)
    for suffix in (".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp"):
        candidate = stem + suffix
        if os.path.isfile(candidate):
            return candidate
    return ""


def _coverCacheSuffix(image_filename: str, response: requests.Response) -> str:
    content_type = str(response.headers.get("Content-Type", "")).split(";", 1)[0].strip().lower()
    suffix_by_type = {
        "image/png": ".png",
        "image/jpeg": ".jpg",
        "image/webp": ".webp",
        "image/gif": ".gif",
        "image/bmp": ".bmp",
    }
    if content_type in suffix_by_type:
        return suffix_by_type[content_type]
    source_suffix = Path(urlparse(image_filename).path).suffix.lower()
    if source_suffix in {".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp"}:
        return source_suffix
    content = response.content[:16]
    if content.startswith(b"\x89PNG\r\n\x1a\n"):
        return ".png"
    if content.startswith(b"\xff\xd8\xff"):
        return ".jpg"
    if content[:6] in (b"GIF87a", b"GIF89a"):
        return ".gif"
    if content.startswith(b"RIFF") and content[8:12] == b"WEBP":
        return ".webp"
    return ".jpg"


def _normaliseMidi(midi: dict) -> dict:
    filename = str(midi.get("midiFilename") or "")
    image = str(midi.get("imageFilename") or "")
    cached_cover = _cachedCoverPath(image)
    image_url = Path(cached_cover).as_uri() if cached_cover else (
        f"https://api.nanomidi.net/api/v2/images/{quote(image, safe='')}?size=240x240" if image else ""
    )
    return {
        "id": str(midi.get("id", "")),
        "name": str(midi.get("name") or "Untitled MIDI"),
        "artists": str(midi.get("artists") or "Unknown artist"),
        "arranger": str(midi.get("arranger") or ""),
        "uploader": str(midi.get("uploader") or "Unknown uploader"),
        "downloads": int(midi.get("downloads") or 0),
        "plays": 0,
        "views": int(midi.get("views") or 0),
        "midiFilename": filename,
        "imageFilename": image,
        "downloadUrl": f"https://api.nanomidi.net/api/midis/{filename}" if filename else "",
        "imageUrl": image_url,
        "source": "nanomidi",
    }


def _safeInt(value: object) -> int:
    try:
        return max(0, int(value or 0))
    except (TypeError, ValueError):
        return 0


def _normaliseBitMidi(midi: dict) -> dict:
    identifier = str(midi.get("id") or "")
    raw_download_url = str(midi.get("downloadUrl") or "")
    if not raw_download_url and identifier.isdigit():
        raw_download_url = f"/uploads/{identifier}.mid"
    download_url = urljoin(bitMidiBaseUrl + "/", raw_download_url)
    parsed_url = urlparse(download_url)
    if parsed_url.scheme != "https" or parsed_url.hostname != "bitmidi.com":
        download_url = ""
    filename = os.path.basename(urlparse(download_url).path) if download_url else ""
    return {
        "id": identifier,
        "name": str(midi.get("name") or "Untitled MIDI"),
        "artists": "",
        "arranger": "",
        "uploader": "BitMidi",
        "downloads": 0,
        "plays": _safeInt(midi.get("plays")),
        "views": _safeInt(midi.get("views")),
        "midiFilename": filename,
        "downloadUrl": download_url,
        "imageUrl": "",
        "source": "bitmidi",
        "createdAt": str(midi.get("createdAt") or ""),
    }


def _sorted(data: list[dict]) -> list[dict]:
    if sortValue == "Newest":
        return sorted(data, key=lambda item: int(item.get("id") or 0), reverse=True)
    if sortValue == "Oldest":
        return sorted(data, key=lambda item: int(item.get("id") or 0))
    if sortValue == "Downloads":
        return sorted(data, key=lambda item: int(item.get("downloads") or 0), reverse=True)
    if sortValue == "Views":
        return sorted(data, key=lambda item: int(item.get("views") or 0), reverse=True)
    return list(data)


def _filtered() -> list[dict]:
    query = searchQuery.strip().casefold()
    if not query:
        return list(allMidiData)
    return [
        midi for midi in allMidiData
        if query in str(midi.get("name", "")).casefold()
        or query in str(midi.get("artists", "")).casefold()
        or query in str(midi.get("uploader", "")).casefold()
    ]


def _publishPage() -> None:
    global totalPages, filteredData, currentPage
    with _requestLock:
        filteredData = _sorted(_filtered())
        totalPages = max(1, (len(filteredData) + pageSize - 1) // pageSize)
        currentPage = min(max(1, currentPage), totalPages)
        start = (currentPage - 1) * pageSize
        items = [_normaliseMidi(item) for item in filteredData[start:start + pageSize]]
        page = currentPage
        total = totalPages
        count = len(filteredData)
    _emitHubState(
        results=items,
        page=page,
        totalPages=total,
        resultCount=count,
        loading=False,
        error="",
        notice="",
        source="nanomidi",
    )


def _publishBitMidiPage(notice: str = "BitMidi results") -> None:
    global currentPage
    with _requestLock:
        rows = list(_bitMidiResults)
        if sortValue == "Views":
            rows.sort(key=lambda item: _safeInt(item.get("views")), reverse=True)
        elif sortValue == "Downloads":
            rows.sort(key=lambda item: _safeInt(item.get("plays")), reverse=True)
        elif sortValue in {"Newest", "Oldest"}:
            rows.sort(
                key=lambda item: str(item.get("createdAt") or ""),
                reverse=sortValue == "Newest",
            )
        page = min(max(1, currentPage), max(1, _bitMidiTotalPages))
        currentPage = page
        count = _bitMidiTotal
        total = max(1, _bitMidiTotalPages)
    _emitHubState(
        results=rows,
        page=page,
        totalPages=total,
        resultCount=count,
        loading=False,
        error="",
        notice=notice,
        source="bitmidi",
    )


def _bitMidiFailureMessage(error: Exception) -> str:
    response = getattr(error, "response", None)
    status = getattr(response, "status_code", None)
    if status == 520:
        return (
            "BitMidi is returning HTTP 520 from its upstream server. "
            "The catalog is temporarily unavailable; try again shortly."
        )
    if status is not None:
        return f"BitMidi is temporarily unavailable (HTTP {status}). Please try again shortly."
    if isinstance(error, requests.Timeout):
        return "BitMidi took too long to respond. Please try the search again."
    if isinstance(error, requests.ConnectionError):
        return "Could not connect to BitMidi. Check your connection and try again."
    if isinstance(error, ValueError):
        return "BitMidi returned an unexpected search response. Please try again later."
    return f"BitMidi search failed ({error.__class__.__name__}). Please try again later."


def _startBitMidiSearch(query: str, page: int, generation: int | None = None) -> None:
    global _activeSource, _bitMidiQuery, _searchGeneration, currentPage
    with _requestLock:
        if generation is None:
            _searchGeneration += 1
            generation = _searchGeneration
        _activeSource = "bitmidi"
        _bitMidiQuery = query
        currentPage = max(1, int(page))
        requested_page = currentPage
    _emitHubState(
        results=[],
        page=requested_page,
        totalPages=1,
        resultCount=0,
        loading=True,
        error="",
        notice="No local matches. Searching BitMidi; this may take longer.",
        source="bitmidi",
    )

    def worker() -> None:
        global _bitMidiResults, _bitMidiTotalPages, _bitMidiTotal
        try:
            params = {"q": query, "page": requested_page - 1, "pageSize": bitMidiPageSize}
            for attempt in range(2):
                try:
                    response = requests.get(
                        bitMidiSearchUrl,
                        params=params,
                        headers=bitMidiRequestHeaders,
                        timeout=(6, 30),
                    )
                except (requests.Timeout, requests.ConnectionError):
                    if attempt == 1:
                        raise
                    time.sleep(0.8)
                    continue

                if attempt == 0 and response.status_code in bitMidiRetryableStatuses:
                    time.sleep(0.8)
                    continue
                response.raise_for_status()
                break

            payload = response.json()
            result = payload.get("result") if isinstance(payload, dict) else None
            if not isinstance(result, dict) or not isinstance(result.get("results"), list):
                raise ValueError("Unexpected BitMidi search response.")

            items = [
                _normaliseBitMidi(item)
                for item in result["results"]
                if isinstance(item, dict)
            ]
            total_count = _safeInt(result.get("total"))
            reported_pages = _safeInt(result.get("pageTotal"))
            pages = max(
                1,
                reported_pages,
                (total_count + bitMidiPageSize - 1) // bitMidiPageSize,
            )
            with _requestLock:
                if generation != _searchGeneration or _activeSource != "bitmidi":
                    return
                _bitMidiResults = items
                _bitMidiTotalPages = pages
                _bitMidiTotal = total_count if total_count else len(items)
                currentPage = requested_page
                no_results = not items
            _publishBitMidiPage(
                "No matches found in the BitMidi catalog." if no_results else "BitMidi results"
            )
        except Exception as exc:
            with _requestLock:
                if generation != _searchGeneration or _activeSource != "bitmidi":
                    return
                _bitMidiResults = []
                _bitMidiTotalPages = 1
                _bitMidiTotal = 0
            _emitHubState(
                results=[],
                page=1,
                totalPages=1,
                resultCount=0,
                loading=False,
                error=_bitMidiFailureMessage(exc),
                notice="",
                source="bitmidi",
            )

    threading.Thread(target=worker, name="bitmidi-search", daemon=True).start()


def searchBar(_event=None) -> None:
    filteredMidiData()


def sortComboCommand(value: str) -> None:
    global sortValue, currentPage
    sortValue = str(value or "Newest")
    currentPage = 1
    if _activeSource == "bitmidi":
        _publishBitMidiPage()
    else:
        _publishPage()


def loadMidiData() -> None:
    """Fetch the catalog off the UI thread and publish the first page."""
    global allMidiData, currentPage, _activeSource, _searchGeneration, _catalogGeneration
    with _requestLock:
        _catalogGeneration += 1
        catalog_generation = _catalogGeneration
        _searchGeneration += 1
        search_generation = _searchGeneration
        _activeSource = "nanomidi"
        currentPage = 1
    _emitHubState(loading=True, error="", notice="", results=[], source="nanomidi")

    def worker() -> None:
        global allMidiData, currentPage
        try:
            response = requests.get(midiDataUrl, timeout=12)
            response.raise_for_status()
            payload = response.json()
            if not isinstance(payload, list):
                raise ValueError("The MIDI catalog response was not a list.")
            with _requestLock:
                if catalog_generation != _catalogGeneration:
                    return
                allMidiData = list(reversed(payload))
                currentPage = 1
                local_matches = _filtered()
                still_current = search_generation == _searchGeneration
            if searchQuery.strip() and not local_matches:
                _startBitMidiSearch(searchQuery, 1, search_generation if still_current else None)
            else:
                _publishPage()
        except Exception as exc:
            with _requestLock:
                if catalog_generation != _catalogGeneration:
                    return
            _emitHubState(
                results=[],
                page=1,
                totalPages=1,
                resultCount=0,
                loading=False,
                notice="",
                error=(
                    "Couldn't reach nanomidi.net. Check your connection and try again. "
                    f"({exc.__class__.__name__})"
                ),
                source="nanomidi",
            )

    threading.Thread(target=worker, name="midi-hub-load", daemon=True).start()


def _saveCatalogCache(payload: list[dict]) -> None:
    os.makedirs(hubCacheDirectory, exist_ok=True)
    temporary = catalogCachePath + ".tmp"
    with open(temporary, "w", encoding="utf-8") as cache_file:
        json.dump(payload, cache_file, ensure_ascii=False, separators=(",", ":"))
    os.replace(temporary, catalogCachePath)


def _loadCatalogCache() -> list[dict] | None:
    try:
        with open(catalogCachePath, "r", encoding="utf-8") as cache_file:
            payload = json.load(cache_file)
        if isinstance(payload, list) and all(isinstance(item, dict) for item in payload):
            return payload
    except (OSError, json.JSONDecodeError):
        pass
    return None


def _downloadCover(image_filename: str) -> bool:
    if not image_filename or _cachedCoverPath(image_filename):
        return False
    image_url = f"https://api.nanomidi.net/api/v2/images/{quote(image_filename, safe='')}?size=240x240"
    try:
        response = requests.get(image_url, timeout=(2.5, 5))
        response.raise_for_status()
        content_type = str(response.headers.get("Content-Type", "")).lower()
        data = response.content
        signature = data[:16]
        looks_like_image = (
            content_type.startswith("image/")
            or signature.startswith(b"\x89PNG\r\n\x1a\n")
            or signature.startswith(b"\xff\xd8\xff")
            or signature[:6] in (b"GIF87a", b"GIF89a")
            or (signature.startswith(b"RIFF") and signature[8:12] == b"WEBP")
            or signature.startswith(b"BM")
        )
        if not looks_like_image or not data:
            return False
        os.makedirs(coverCacheDirectory, exist_ok=True)
        cache_path = _coverCacheStem(image_filename) + _coverCacheSuffix(image_filename, response)
        temporary = cache_path + ".tmp"
        with open(temporary, "wb") as cover_file:
            cover_file.write(data)
        os.replace(temporary, cache_path)
        return True
    except (OSError, requests.RequestException):
        return False


def preloadMidiHubForStartup() -> None:
    """Warm the MIDI Hub catalog and cover cache without blocking the UI thread."""
    global _activeSource, _catalogGeneration, currentPage
    with _requestLock:
        _catalogGeneration += 1
        generation = _catalogGeneration
        _activeSource = "nanomidi"
        currentPage = 1
    _emitHubState(
        startupProgress=0,
        startupStatus="Fetching the MIDI Hub catalog…",
        startupReady=False,
        loading=True,
        error="",
        notice="",
    )

    def worker() -> None:
        global allMidiData, currentPage
        cached_catalog = _loadCatalogCache()
        catalog: list[dict] | None = cached_catalog
        offline = False

        if catalog is not None:
            with _requestLock:
                if generation != _catalogGeneration:
                    return
                allMidiData = list(reversed(catalog))
                currentPage = 1
            _publishPage()
            cached_images = list(dict.fromkeys(
                str(item.get("imageFilename") or "").strip()
                for item in reversed(catalog)
                if str(item.get("imageFilename") or "").strip()
            ))
            cached_covers = sum(1 for name in cached_images if _cachedCoverPath(name))
            cache_complete = cached_covers == len(cached_images)
            _emitHubState(
                startupProgress=(100 if cache_complete else int(cached_covers * 100 / max(1, len(cached_images)))),
                startupStatus=("MIDI Hub cache ready" if cache_complete else f"Preparing cached MIDI Hub · {cached_covers}/{len(cached_images)} covers"),
                startupReady=cache_complete,
            )

        try:
            response = requests.get(midiDataUrl, timeout=(3, 9))
            response.raise_for_status()
            payload = response.json()
            if not isinstance(payload, list) or not all(isinstance(item, dict) for item in payload):
                raise ValueError("The MIDI catalog response was not a list of entries.")
            catalog = payload
            try:
                _saveCatalogCache(payload)
            except OSError:
                pass
        except Exception:
            offline = catalog is not None

        if catalog is None:
            with _requestLock:
                is_current = generation == _catalogGeneration
            if is_current:
                _emitHubState(
                    results=[],
                    page=1,
                    totalPages=1,
                    resultCount=0,
                    loading=False,
                    error="Couldn't reach nanomidi.net. Check your connection and try again.",
                    notice="",
                    source="nanomidi",
                    startupProgress=100,
                    startupStatus="MIDI Hub unavailable · opening offline",
                    startupReady=True,
                )
            return

        with _requestLock:
            if generation != _catalogGeneration:
                return
            allMidiData = list(reversed(catalog))
            currentPage = 1
        _publishPage()

        image_names = list(dict.fromkeys(
            str(item.get("imageFilename") or "").strip()
            for item in reversed(catalog)
            if str(item.get("imageFilename") or "").strip()
        ))
        total = len(image_names)
        cached_count = sum(1 for name in image_names if _cachedCoverPath(name))
        initial_progress = 100 if total == 0 else int(cached_count * 100 / total)
        missing_names = [name for name in image_names if not _cachedCoverPath(name)]
        status_prefix = "Using cached MIDI Hub data" if offline else "Loading MIDI Hub covers"
        _emitHubState(
            startupProgress=initial_progress,
            startupStatus=("MIDI Hub ready" if initial_progress == 100 else f"{status_prefix} · {cached_count}/{total}"),
            startupReady=not missing_names,
        )

        if not missing_names:
            with _requestLock:
                is_current = generation == _catalogGeneration
            if is_current:
                # Re-publish with local file URLs for already cached covers.
                _publishPage()
            _emitHubState(
                startupProgress=100,
                startupStatus=("MIDI Hub ready" if not offline else "MIDI Hub ready · using cached catalog"),
                startupReady=True,
                loading=False,
            )
            return

        cover_queue: queue.Queue[str] = queue.Queue()
        for image_name in missing_names:
            cover_queue.put(image_name)
        progress_lock = threading.Lock()
        progress_state = {"completed": cached_count}
        _emitHubState(startupReady=False)

        def cover_worker() -> None:
            while True:
                try:
                    image_name = cover_queue.get_nowait()
                except queue.Empty:
                    return
                _downloadCover(image_name)
                with progress_lock:
                    progress_state["completed"] += 1
                    processed = progress_state["completed"]
                    finished = processed >= total
                if processed % 5 == 0 or finished:
                    _emitHubState(
                        startupProgress=int(processed * 100 / max(1, total)),
                        startupStatus=f"{status_prefix} · {processed}/{total}",
                    )
                cover_queue.task_done()
                if finished:
                    with _requestLock:
                        is_current = generation == _catalogGeneration
                    if is_current:
                        # Re-publish with local file URLs for covers warmed by this run.
                        _publishPage()
                    ready_covers = sum(1 for name in image_names if _cachedCoverPath(name))
                    final_status = (
                        f"MIDI Hub ready · {ready_covers}/{total} covers"
                        if ready_covers < total
                        else ("MIDI Hub ready" if not offline else "MIDI Hub ready · using cached catalog")
                    )
                    _emitHubState(
                        startupProgress=100,
                        startupStatus=final_status,
                        startupReady=True,
                        loading=False,
                    )

        for index in range(min(coverPreloadWorkers, len(missing_names))):
            threading.Thread(
                target=cover_worker,
                name=f"hub-cover-preload-{index + 1}",
                daemon=True,
            ).start()

    threading.Thread(target=worker, name="midi-hub-startup-preload", daemon=True).start()


def fetchImage(midi: dict) -> str:
    return _normaliseMidi(midi).get("imageUrl", "")


def fetchPublicImage(midi: dict) -> str:
    image_filename = str(midi.get("imageFilename") or "").strip()
    if not image_filename:
        return ""
    return f"https://api.nanomidi.net/api/v2/images/{quote(image_filename, safe='')}?size=240x240"


def sortMidiData(selectedValue: str) -> None:
    sortComboCommand(selectedValue)


def showPage(page: int) -> None:
    global currentPage
    if _activeSource == "bitmidi":
        _startBitMidiSearch(_bitMidiQuery, max(1, int(page)))
        return
    currentPage = max(1, int(page))
    _publishPage()


def downloadMidi(url: str) -> None:
    """Download one selected MIDI, add it to the saved player list, and open it."""
    def worker() -> None:
        try:
            response = requests.get(str(url), headers=bitMidiRequestHeaders, timeout=30)
            response.raise_for_status()
            filename = os.path.basename(urlparse(str(url)).path)
            if not filename.lower().endswith((".mid", ".midi")):
                raise ValueError("The catalog did not provide a MIDI filename.")
            filepath = os.path.join(downloadFolder, filename)
            temporary = filepath + ".download"
            with open(temporary, "wb") as midi_file:
                midi_file.write(response.content)
            os.replace(temporary, filepath)

            midi_settings = configuration.configData["midiPlayer"]
            midi_settings["currentFile"] = filepath
            midi_list = list(midi_settings.get("midiList", []))
            if filepath not in midi_list:
                midi_list.append(filepath)
            midi_settings["midiList"] = midi_list
            configuration.configData.save()

            _emitHubState(downloads={str(url): "complete"})
            app = mainFunctions.getApp()
            if app:
                app.downloadedMidiRequested.emit(filepath)
            mainFunctions.log(f"Downloaded MIDI File: {filepath}")
        except Exception as exc:
            _emitHubState(downloads={str(url): "error"})
            mainFunctions.showMessage("Download failed", f"Couldn't download this MIDI file. {exc}", "error")

    threading.Thread(target=worker, name="midi-hub-download", daemon=True).start()


def prevPage() -> None:
    showPage(currentPage - 1)


def nextPage() -> None:
    showPage(currentPage + 1)


def filteredMidiData(query: str | None = None) -> None:
    global searchQuery, currentPage, _searchGeneration, _activeSource, _bitMidiResults, _bitMidiTotal
    if query is None:
        query = MidiHubTab.searchEntry.get()
    with _requestLock:
        searchQuery = str(query or "")
        currentPage = 1
        _searchGeneration += 1
        generation = _searchGeneration
        _activeSource = "nanomidi"
        _bitMidiResults = []
        _bitMidiTotal = 0
        local_matches = _filtered()
    if searchQuery.strip() and not local_matches:
        _startBitMidiSearch(searchQuery, 1, generation)
    else:
        _publishPage()


def clearList() -> None:
    _emitHubState(results=[], loading=True, error="")
