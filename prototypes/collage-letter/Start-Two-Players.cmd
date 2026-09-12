@echo off
py -3 "%~dp0server\launch.py" --demo
if errorlevel 1 pause
