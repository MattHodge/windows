@setlocal EnableDelayedExpansion EnableExtensions
@for %%i in (%~dp0\_packer_config*.cmd) do @call "%%~i"
@if defined PACKER_DEBUG (@echo on) else (@echo off)

title Installing PowerShell 5. Please wait...

if not exist a:\install_ps5.ps1 echo ==^> ERROR: File not found: a:\install_ps5.ps1

powershell -File a:\install_ps5.ps1 <NUL
@if errorlevel 1 echo ==^> WARNING: Error %ERRORLEVEL% was returned by: powershell -File a:\install_ps5.ps1
