@echo off
cd /d "%~dp0"
set "APPDATA=%~dp0tools\userdata"
start "Yacht Club" "%~dp0tools\godot\Godot_v4.6-stable_win64.exe" --path "%~dp0."
