@echo off
setlocal
set "APPDATA=%~dp0runtime\data"
start "CWTCH" "%~dp0runtime\Godot_v4.6.2-stable_win64.exe" --path "%~dp0." --log-file "%~dp0play.log"
