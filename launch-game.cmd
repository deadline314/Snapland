@echo off
cd /d "%~dp0"
where godot >nul 2>nul
if errorlevel 1 (
  echo Godot 4.7.2 is required. Install the official Windows build and add it to PATH.
  pause
  exit /b 1
)
godot --path "%~dp0"
