@echo off
if exist "%~dp0runtime\python\python.exe" (
  "%~dp0runtime\python\python.exe" "%~dp0server\app.py" --host 0.0.0.0 --port 8788
) else (
  py -3 "%~dp0server\app.py" --host 0.0.0.0 --port 8788
)
if errorlevel 1 pause
