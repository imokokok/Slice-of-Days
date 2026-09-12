@echo off
py -3 "%~dp0server\app.py" --host 0.0.0.0 --port 8788
if errorlevel 1 pause
