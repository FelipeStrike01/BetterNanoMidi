@echo off
setlocal
pushd "%~dp0\.."

if not exist "venv-win\Scripts\python.exe" (
    python -m venv venv-win || goto failure
)
call venv-win\Scripts\activate.bat || goto failure

python -m pip install --upgrade pip pyinstaller || goto failure
python -m pip install -r requirements.txt || goto failure
python scripts\compile_shaders.py || goto failure
python -m PyInstaller --noconfirm build-portable\BetterNanoMidi.spec || goto failure

if defined USERPROFILE if exist "%USERPROFILE%\Downloads" (
    powershell -NoProfile -Command "$p = Get-Process -Name 'Better NanoMid' -ErrorAction SilentlyContinue; if ($p) { $p | Stop-Process -Force }"
    copy /Y "dist\Better NanoMid.exe" "%USERPROFILE%\Downloads\Better NanoMid.exe" >nul || goto failure
)

echo Build complete: dist\Better NanoMid.exe
if defined USERPROFILE if exist "%USERPROFILE%\Downloads\Better NanoMid.exe" echo Copied to: %USERPROFILE%\Downloads\Better NanoMid.exe
popd
exit /b 0

:failure
set "BUILD_EXIT=%ERRORLEVEL%"
popd
exit /b %BUILD_EXIT%
