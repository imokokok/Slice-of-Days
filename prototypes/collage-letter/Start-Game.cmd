@echo off
if exist "%~dp0runtime\python\python.exe" (
  "%~dp0runtime\python\python.exe" "%~dp0server\launch.py"
) else (
  py -3 "%~dp0server\launch.py"
)
if errorlevel 1 pause
