@echo off
setlocal
if defined GODOT_EXE (
  if exist "%GODOT_EXE%" (
    start "" "%GODOT_EXE%" --path "%~dp0."
    exit /b
  )
)
where godot >nul 2>nul
if not errorlevel 1 (
  godot --path "%~dp0."
  exit /b
)
echo Import project.godot in Godot 4.4 or later and press F5.
echo Or set GODOT_EXE to your Godot executable path.
pause
