@echo off
if exist "%~dp0runtime\python\python.exe" (
  "%~dp0runtime\python\python.exe" "%~dp0server\launch.py" --demo
) else (
  py -3 "%~dp0server\launch.py" --demo
)
if errorlevel 1 pause
