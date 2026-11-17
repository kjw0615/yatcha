@echo off
cd /d "%~dp0"
set "APPDATA=%~dp0tools\userdata"
start "Godot Editor" "%~dp0tools\godot\Godot_v4.6-stable_win64.exe" --editor --path "%~dp0."
