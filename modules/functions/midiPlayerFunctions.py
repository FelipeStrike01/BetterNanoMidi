import threading
import json
import os
import platform
import datetime
import keyboard
import logging

from PySide6.QtWidgets import QFileDialog
from mido import MidiFile
from pynput import keyboard as pynputKeyboard
from modules import configuration

from ui.midiPlayer import MidiPlayerTab
from ui.settings import SettingsTab
from ui import customTheme
from modules.functions import mainFunctions
from modules.midiHandler import useOutput
from ui.qt_compat import CompatVar

logger = logging.getLogger(__name__)
osName = platform.system()

if osName == 'Windows':
    from modules.midiHandler import midiWindows as midiHandler
elif osName == 'Darwin':
    from modules.midiHandler import midiDarwin as midiHandler
elif osName == "Linux":
    from modules.midiHandler import midiLinux as midiHandler

app = mainFunctions.getApp()

switchUseMIDIvar = CompatVar("off")
switchSustainvar = CompatVar("off")
switchNoDoublesvar = CompatVar("off")
switchVelocityvar = CompatVar("off")
switch88Keysvar = CompatVar("off")
currentMidiDuration = 0.0
previewPlayback = False
previewFile = ""
previewGeneration = 0

def isPlaylistPlaybackActive():
    return bool(app and getattr(app, "playlistActive", False))

def shouldLoopCurrentMidi():
    return bool(configuration.configData["midiPlayer"].get("loopSong", False)) and not isPlaylistPlaybackActive()

switchUseMIDIvar.set("on" if configuration.configData.get('midiPlayer', {}).get('useMIDIOutput', False) else "off")
switchSustainvar.set("on" if configuration.configData.get('midiPlayer', {}).get('sustain', False) else "off")
switchNoDoublesvar.set("on" if configuration.configData.get('midiPlayer', {}).get('noDoubles', False) else "off")
switchVelocityvar.set("on" if configuration.configData.get('midiPlayer', {}).get('velocity', False) else "off")
switch88Keysvar.set("on" if configuration.configData.get('midiPlayer', {}).get('88Keys', False) else "off")

def switchUseMIDI():
    logger.info("switchUseMIDI called")
    try:
        configuration.configData["midiPlayer"]['useMIDIOutput'] = switchUseMIDIvar.get() == "on"
        configuration.configData.save()

        mainFunctions.clearConsole()
        mainFunctions.refreshOutputDevices()
        if switchUseMIDIvar.get() == "on":
            threading.Thread(target=mainFunctions.insertConsoleText, args=("-------< WARNING >-------   This will not press keys for you!", True)).start()
        else:
            threading.Thread(target=mainFunctions.insertConsoleText, args=("Macro Mode.", True)).start()
    except Exception as e:
        logger.exception(f"switchUseMIDI error: {e}")

def switchSustain():
    logger.info("switchSustain called")
    try:
        configuration.configData['midiPlayer']['sustain'] = switchSustainvar.get() == "on"
        configuration.configData.save()
    except Exception as e:
        logger.exception(f"switchSustain error: {e}")

def switchNoDoubles():
    logger.info("switchNoDoubles called")
    try:
        configuration.configData['midiPlayer']['noDoubles'] = switchNoDoublesvar.get() == "on"
        configuration.configData.save()
    except Exception as e:
        logger.exception(f"switchNoDoubles error: {e}")

def switchVelocity():
    logger.info("switchVelocity called")
    try:
        configuration.configData['midiPlayer']['velocity'] = switchVelocityvar.get() == "on"
        configuration.configData.save()
    except Exception as e:
        logger.exception(f"switchVelocity error: {e}")

def switch88Keys():
    logger.info("switch88Keys called")
    try:
        configuration.configData['midiPlayer']['88Keys'] = switch88Keysvar.get() == "on"
        configuration.configData.save()
    except Exception as e:
        logger.exception(f"switch88Keys error: {e}")

def selectFile():
    logger.info("selectFile called")
    if app is not None and hasattr(app, "selectMidiFile"):
        app.selectMidiFile("")
        return
    try:
        MidiPlayerTab.filePathEntry.set("")
        unbindControls()
        stopPlayback()
        MidiPlayerTab.timelineIndicator.configure(text="0:00:00 / 0:00:00")
        MidiPlayerTab.playButton.configure(text="Play")

        filePath, _selected_filter = QFileDialog.getOpenFileName(
            None,
            "Select MIDI file",
            "",
            "MIDI files (*.mid *.midi)",
        )
        logger.debug(f"filePath selected: {filePath}")
        if filePath:
            currentVAL = list(MidiPlayerTab.filePathEntry.cget("values"))
            if filePath not in currentVAL:
                currentVAL.append(filePath)
                MidiPlayerTab.filePathEntry.configure(values=currentVAL)

            MidiPlayerTab.filePathEntry.set(filePath)
            midiFile = MidiFile(filePath, clip=True)

            time = midiFile.length
            setMidiDuration(time)
            timelineText = (
                f"0:00:00 / {str(datetime.timedelta(seconds=int(time)))}"
                if configuration.configData['appUI']['timestamp']
                else f"X:XX:XX / {str(datetime.timedelta(seconds=int(time)))}"
            )
            MidiPlayerTab.timelineIndicator.configure(text=timelineText)

            configuration.configData['midiPlayer']['currentFile'] = filePath

            if 'midiList' not in configuration.configData['midiPlayer']:
                configuration.configData['midiPlayer']['midiList'] = []
            if filePath not in configuration.configData['midiPlayer']['midiList']:
                configuration.configData['midiPlayer']['midiList'].append(filePath)
            configuration.configData.save()

            bindControls()
    except Exception as e:
        logger.exception(f"selectFile error: {e}")

def loadSavedFile():
    global currentMidiDuration
    logger.info("loadSavedFile called")
    try:
        midiList = configuration.configData['midiPlayer'].get('midiList', [])
        currentFile = configuration.configData['midiPlayer'].get('currentFile', '')
        
        midiList = [f for f in midiList if os.path.exists(f)]
        configuration.configData['midiPlayer']['midiList'] = midiList
        
        if currentFile and not os.path.exists(currentFile):
            currentFile = ""
            configuration.configData['midiPlayer']['currentFile'] = ""
        
        configuration.configData.save()
        
        entryValues = list(MidiPlayerTab.filePathEntry.cget("values"))
        
        downloadFolder = os.path.join(configuration.baseDirectory, "Midis")
        if os.path.exists(downloadFolder):
            for filename in os.listdir(downloadFolder):
                if filename.lower().endswith(('.mid', '.midi')):
                    filePath = os.path.join(downloadFolder, filename)
                    if filePath not in entryValues and filePath not in midiList:
                        entryValues.append(filePath)
        
        for p in midiList:
            if p not in entryValues:
                entryValues.append(p)
        
        MidiPlayerTab.filePathEntry.configure(values=entryValues)
        
        if currentFile:
            if currentFile not in entryValues:
                entryValues.append(currentFile)
                MidiPlayerTab.filePathEntry.configure(values=entryValues)
            MidiPlayerTab.filePathEntry.set(currentFile)
            currentMidiDuration = 0.0
            MidiPlayerTab.timelineIndicator.configure(text="Loading MIDI…")
            logger.debug(f"queued currentFile for background loading: {currentFile}")
            return
        
        if midiList:
            firstFile = midiList[0]
            MidiPlayerTab.filePathEntry.set(firstFile)
            configuration.configData['midiPlayer']['currentFile'] = firstFile
            configuration.configData.save()
            currentMidiDuration = 0.0
            MidiPlayerTab.timelineIndicator.configure(text="Loading MIDI…")
            logger.debug(f"queued first saved file for background loading: {firstFile}")
            return
        
        currentMidiDuration = 0.0
        MidiPlayerTab.filePathEntry.set("None")
        MidiPlayerTab.timelineIndicator.configure(text="0:00:00 / 0:00:00")
        logger.debug("no saved files found")
    except Exception as e:
        logger.exception(f"loadSavedFile error: {e}")

def switchMidiEvent(event=None):
    global currentMidiDuration
    logger.info("switchMidiEvent called")
    try:
        midiFile = MidiPlayerTab.filePathEntry.get()
        configuration.configData['midiPlayer']['currentFile'] = midiFile
        configuration.configData.save()

        midiFileData = MidiFile(midiFile, clip=True)
        totalTime = midiFileData.length
        setMidiDuration(totalTime)
        timelineText = f"0:00:00 / {str(datetime.timedelta(seconds=int(totalTime)))}" if configuration.configData['appUI']['timestamp'] else f"X:XX:XX / {str(datetime.timedelta(seconds=int(totalTime)))}"
        MidiPlayerTab.timelineIndicator.configure(text=timelineText)
        bindControls()
        logger.debug(f"switched midi file to: {midiFile}")
    except Exception as e:
        logger.exception(f"switchMidiEvent error: {e}")

def setMidiDuration(duration):
    global currentMidiDuration
    try:
        currentMidiDuration = max(0.0, float(duration))
    except (TypeError, ValueError):
        currentMidiDuration = 0.0

def bindControls():
    try:
        playKey = configuration.configData["hotkeys"].get("play", "F1").upper()
        pauseKey = configuration.configData["hotkeys"].get("pause", "F2").upper()
        stopKey = configuration.configData["hotkeys"].get("stop", "F3").upper()
        speedUpKey = configuration.configData["hotkeys"].get("speedup", "F4").upper()
        slowDownKey = configuration.configData["hotkeys"].get("slowdown", "F5").upper()

        if osName == "Windows":
            unbindControls()
            midiHandler.keyboardHandlers.append(keyboard.on_press_key(playKey.lower(), lambda e: startPlayback()))
            midiHandler.keyboardHandlers.append(keyboard.on_press_key(pauseKey.lower(), lambda e: pausePlayback()))
            midiHandler.keyboardHandlers.append(keyboard.on_press_key(stopKey.lower(), lambda e: stopPlayback()))
            midiHandler.keyboardHandlers.append(keyboard.on_press_key(speedUpKey.lower(), lambda e: decreaseSpeed()))
            midiHandler.keyboardHandlers.append(keyboard.on_press_key(slowDownKey.lower(), lambda e: increaseSpeed()))
        else:
            from modules.functions import mainFunctions
            mainFunctions.activeHotkeys.clear()
            mainFunctions.activeHotkeys.update({
                playKey: startPlayback,
                pauseKey: pausePlayback,
                stopKey: stopPlayback,
                speedUpKey: decreaseSpeed,
                slowDownKey: increaseSpeed
            })
            mainFunctions.startGlobalListener()
    except Exception as e:
        logger.exception(f"bindControls error: {e}")

def unbindControls():
    try:
        if osName == "Windows":
            for h in list(midiHandler.keyboardHandlers):
                try:
                    keyboard.unhook(h)
                except Exception:
                    pass
            midiHandler.keyboardHandlers.clear()
        else:
            from modules.functions import mainFunctions
            mainFunctions.activeHotkeys.clear()
    except Exception as e:
        logger.exception(f"unbindControls error: {e}")

def playButton():
    logger.info("playButton called")
    try:
        if not app.isRunning:
            startPlayback()
        else:
            pausePlayback()
    except Exception as e:
        logger.exception(f"playButton error: {e}")

def startPlayback():
    global previewPlayback, previewFile
    logger.info("startPlayback called")
    try:
        if previewPlayback:
            stopPlayback(cancelPlaylist=False)
        midiFile = MidiPlayerTab.filePathEntry.get()
        logger.debug(f"startPlayback midiFile: {midiFile}")
        if not os.path.exists(midiFile):
            logger.warning("MIDI File does not exist.")
            threading.Thread(target=mainFunctions.insertConsoleText, args=("MIDI File does not exist.", True)).start()
            return

        if app and not app.isRunning and hasattr(app, "prepareMidiPlaylistPlayback"):
            app.prepareMidiPlaylistPlayback(midiFile)

        useMIDI = configuration.configData["midiPlayer"]['useMIDIOutput']

        if useMIDI:
            outputDevice = MidiPlayerTab.outputDeviceDropdown.get()
            logger.debug(f"outputDevice selected: {outputDevice}")
            if not outputDevice:
                threading.Thread(target=mainFunctions.insertConsoleText, args=("No MIDI output device selected.", True)).start()
                return

            app.isRunning = True
            MidiPlayerTab.playButton.configure(
                text="Playing",
                fg_color=customTheme.activeThemeData["Theme"]["MidiPlayer"]["PlayingColor"],
                hover_color=customTheme.activeThemeData["Theme"]["MidiPlayer"]["PlayingColorHover"]
            )
            MidiPlayerTab.stopButton.configure(state="normal", fg_color=customTheme.activeThemeData["Theme"]["MidiPlayer"]["StopColor"])

            def updateTimeline(text):
                MidiPlayerTab.timelineIndicator.after(0, lambda: MidiPlayerTab.timelineIndicator.configure(text=text))

            useOutput.startPlayback(
                midiFile,
                outputDevice,
                updateCallback=updateTimeline,
                totalSeconds=currentMidiDuration,
            )
            app.setPlaybackPresence("playing", midiFile, "midi")
            logger.debug("useOutput.startPlayback called")

        elif app and not app.isRunning:
            app.isRunning = True
            MidiPlayerTab.playButton.configure(
                text="Playing",
                fg_color=customTheme.activeThemeData["Theme"]["MidiPlayer"]["PlayingColor"],
                hover_color=customTheme.activeThemeData["Theme"]["MidiPlayer"]["PlayingColorHover"]
            )
            MidiPlayerTab.stopButton.configure(state="normal", fg_color=customTheme.activeThemeData["Theme"]["MidiPlayer"]["StopColor"])

            def updateTimeline(text):
                MidiPlayerTab.timelineIndicator.after(0, lambda: MidiPlayerTab.timelineIndicator.configure(text=text))

            midiHandler.startPlayback(
                midiFile,
                updateCallback=updateTimeline,
                totalSeconds=currentMidiDuration,
            )
            app.setPlaybackPresence("playing", midiFile, "midi")
            logger.debug("midiHandler.startPlayback called")
    except Exception as e:
        logger.exception(f"startPlayback error: {e}")

def startPreviewPlayback(midiFile, outputDevice, totalSeconds, displayName="MIDI preview", generation=0):
    global previewPlayback, previewFile, previewGeneration
    if app and app.isRunning:
        raise RuntimeError("Stop the current playback before previewing another MIDI.")

    previewPlayback = True
    previewFile = str(displayName or "MIDI preview")
    previewGeneration = int(generation)
    app.isRunning = True
    MidiPlayerTab.playButton.configure(
        text="Playing",
        fg_color=customTheme.activeThemeData["Theme"]["MidiPlayer"]["PlayingColor"],
        hover_color=customTheme.activeThemeData["Theme"]["MidiPlayer"]["PlayingColorHover"]
    )
    MidiPlayerTab.stopButton.configure(
        state="normal",
        fg_color=customTheme.activeThemeData["Theme"]["MidiPlayer"]["StopColor"]
    )
    app.setPlaybackPresence("playing", previewFile, "midi")

    try:
        started = useOutput.startPlayback(
            midiFile,
            outputDevice,
            totalSeconds=totalSeconds,
            preview=True,
        )
        if not started:
            raise RuntimeError("The MIDI output is already in use.")
    except Exception:
        previewPlayback = False
        previewFile = ""
        previewGeneration = 0
        app.isRunning = False
        bindControls()
        app.setPlaybackPresence("stopped", "", "midi")
        raise
    return True

def stopPlayback(natural=False, cancelPlaylist=None):
    global previewPlayback, previewFile, previewGeneration
    logger.info("stopPlayback called")
    try:
        wasPreview = previewPlayback
        endedPreviewGeneration = previewGeneration
        if cancelPlaylist is None:
            cancelPlaylist = not natural and not wasPreview
        if cancelPlaylist and app and hasattr(app, "cancelMidiPlaylist"):
            app.cancelMidiPlaylist()

        if not app.isRunning:
            return

        useMIDI = wasPreview or configuration.configData["midiPlayer"]["useMIDIOutput"]

        if useMIDI:
            useOutput.stopPlayback()
            logger.debug("useOutput.stopPlayback called")
        else:
            midiHandler.stopPlayback()
            logger.debug("midiHandler.stopPlayback called")

        app.isRunning = False
        bindControls()
        MidiPlayerTab.stopButton.configure(
            state="disabled",
            fg_color=customTheme.activeThemeData["Theme"]["MidiPlayer"]["StopColorDisabled"]
        )
        MidiPlayerTab.playButton.configure(
            text="Play",
            fg_color=customTheme.activeThemeData["Theme"]["MidiPlayer"]["PlayColor"],
            hover_color=customTheme.activeThemeData["Theme"]["MidiPlayer"]["PlayColorHover"]
        )

        totalTime = currentMidiDuration
        if totalTime > 0:
            timelineText = (
                f"0:00:00 / {str(datetime.timedelta(seconds=int(totalTime)))}"
                if configuration.configData['appUI']['timestamp']
                else f"X:XX:XX / {str(datetime.timedelta(seconds=int(totalTime)))}"
            )
            MidiPlayerTab.timelineIndicator.configure(text=timelineText)
        app.setPlaybackPresence("stopped", "", "midi")
        previewPlayback = False
        previewFile = ""
        previewGeneration = 0
        if wasPreview and hasattr(app, "hubPreviewPlaybackEnded"):
            app.hubPreviewPlaybackEnded.emit(endedPreviewGeneration)
        if natural and not wasPreview and hasattr(app, "midiPlaylistPlaybackFinished"):
            app.midiPlaylistPlaybackFinished.emit()
        logger.debug("stopPlayback completed")
    except Exception as e:
        logger.exception(f"stopPlayback error: {e}")

def pausePlayback():
    logger.info("pausePlayback called")
    try:
        if not app.isRunning:
            return

        useMIDI = previewPlayback or configuration.configData["midiPlayer"]["useMIDIOutput"]
        paused = False

        if useMIDI:
            useOutput.pausePlayback()
            paused = useOutput.paused
            logger.debug(f"useOutput.paused: {paused}")
        else:
            midiHandler.pausePlayback()
            paused = midiHandler.paused
            logger.debug(f"midiHandler.paused: {paused}")

        if paused:
            MidiPlayerTab.playButton.configure(
                text="Paused",
                fg_color=customTheme.activeThemeData["Theme"]["MidiPlayer"]["PausedColor"],
                hover_color=customTheme.activeThemeData["Theme"]["MidiPlayer"]["PausedColorHover"]
            )
        else:
            MidiPlayerTab.playButton.configure(
                text="Playing",
                fg_color=customTheme.activeThemeData["Theme"]["MidiPlayer"]["PlayingColor"],
                hover_color=customTheme.activeThemeData["Theme"]["MidiPlayer"]["PlayingColorHover"]
            )
        midiFile = previewFile if previewPlayback else MidiPlayerTab.filePathEntry.get()
        app.setPlaybackPresence("paused" if paused else "playing", midiFile, "midi")
        logger.debug("pausePlayback state updated")
    except Exception as e:
        logger.exception(f"pausePlayback error: {e}")

def setSpeed(speed):
    logger.info(f"setSpeed called with speed: {speed}")
    try:
        useMIDI = configuration.configData["midiPlayer"]["useMIDIOutput"]

        if useMIDI:
            useOutput.playbackSpeed = max(0.01, min(5.0, speed / 100.0))
            app.playbackSpeed = round(useOutput.playbackSpeed * 100)
        else:
            midiHandler.playbackSpeed = max(0.01, min(5.0, speed / 100.0))
            app.playbackSpeed = round(midiHandler.playbackSpeed * 100)

        MidiPlayerTab.speedSlider.set(app.playbackSpeed)
        MidiPlayerTab.speedValueEntry.delete(0, "end")
        MidiPlayerTab.speedValueEntry.insert(0, str(app.playbackSpeed))
        logger.debug(f"playbackSpeed set to: {app.playbackSpeed}")
    except Exception as e:
        logger.exception(f"setSpeed error: {e}")

def decreaseSpeed():
    logger.info("decreaseSpeed called")
    try:
        useMIDI = configuration.configData["midiPlayer"]["useMIDIOutput"]
        app.focus_set()

        if useMIDI:
            useOutput.changeSpeed(-(configuration.configData["midiPlayer"]["decreaseSize"] / 100))
            app.playbackSpeed = round(useOutput.playbackSpeed * 100)
        else:
            midiHandler.changeSpeed(-(configuration.configData["midiPlayer"]["decreaseSize"] / 100))
            app.playbackSpeed = round(midiHandler.playbackSpeed * 100)

        MidiPlayerTab.speedSlider.set(app.playbackSpeed)
        MidiPlayerTab.speedValueEntry.delete(0, "end")
        MidiPlayerTab.speedValueEntry.insert(0, str(app.playbackSpeed))
        logger.debug(f"decreased playbackSpeed to: {app.playbackSpeed}")
    except Exception as e:
        logger.exception(f"decreaseSpeed error: {e}")

PITCH_OFFSETS = {
    "Lowest":  -24,
    "Low":     -12,
    "Middle":    0,
    "High":     12,
    "Highest":  24,
}

KEY_OFFSETS = {
    "C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5,
    "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11,
}

def changePitch(value):
    logger.info(f"changePitch called: {value}")
    try:
        configuration.configData["midiPlayer"]["pitchOffset"] = PITCH_OFFSETS.get(value, 0)
        configuration.configData.save()
    except Exception as e:
        logger.exception(f"changePitch error: {e}")

def changeTranspose(value):
    logger.info(f"changeTranspose called: {value}")
    try:
        configuration.configData["midiPlayer"]["transposeOffset"] = KEY_OFFSETS.get(value, 0)
        configuration.configData.save()
    except Exception as e:
        logger.exception(f"changeTranspose error: {e}")

def increaseSpeed():
    logger.info("increaseSpeed called")
    try:
        useMIDI = configuration.configData["midiPlayer"]["useMIDIOutput"]
        app.focus_set()

        if useMIDI:
            useOutput.changeSpeed(configuration.configData["midiPlayer"]["decreaseSize"] / 100)
            app.playbackSpeed = round(useOutput.playbackSpeed * 100)
        else:
            midiHandler.changeSpeed(configuration.configData["midiPlayer"]["decreaseSize"] / 100)
            app.playbackSpeed = round(midiHandler.playbackSpeed * 100)

        MidiPlayerTab.speedSlider.set(app.playbackSpeed)
        MidiPlayerTab.speedValueEntry.delete(0, "end")
        MidiPlayerTab.speedValueEntry.insert(0, str(app.playbackSpeed))
        logger.debug(f"increased playbackSpeed to: {app.playbackSpeed}")
    except Exception as e:
        logger.exception(f"increaseSpeed error: {e}")
