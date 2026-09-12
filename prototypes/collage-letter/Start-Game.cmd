@echo off
py -3 "%~dp0server\launch.py"
if errorlevel 1 pause
