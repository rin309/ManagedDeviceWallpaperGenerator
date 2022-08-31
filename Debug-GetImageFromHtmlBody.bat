@echo off

:Loop
cls
Title ManagedDeviceWallpaperGenerator
PowerShell -ExecutionPolicy ByPass -NoExit -Command "pushd '%~dp0'; Import-Module -Name ((Get-Location).Path); Write-Host \""[How to use]`n`n\""; Get-ImageFromHtmlBody; Exit"

goto Loop