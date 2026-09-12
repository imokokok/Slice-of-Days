@echo off
if defined GODOT_BIN (
  "%GODOT_BIN%" --editor --path "%~dp0."
) else (
  godot --editor --path "%~dp0."
)
if errorlevel 1 pause
