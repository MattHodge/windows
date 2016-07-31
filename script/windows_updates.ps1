$ErrorActionPreference = "Stop"

Import-Module -Name Boxstarter.Bootstrapper

Write-BoxstarterMessage "Enabling Remote Desktop"
Enable-RemoteDesktop

Write-BoxstarterMessage "Setting PS ExecutionPolicy to Unrestricted"
Update-ExecutionPolicy -Policy Unrestricted

Write-BoxstarterMessage "Installing Windows Updates"
Install-WindowsUpdate -AcceptEula
