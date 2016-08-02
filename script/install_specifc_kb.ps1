param (
    $KB,
    $KBFileName,
    $DownloadURI
)

# https://download.microsoft.com/download/D/B/1/DB1F29FC-316D-481E-B435-1654BA185DCF/Windows8.1-KB2919355-x64.msu

# 'http://192.168.2.115:8080/HTTPServer/Windows8.1-KB2919355-x64.msu'

# $KB = 'KB2919355'
# $KBFileName = 'Windows8.1-KB2919355-x64.msu'

$hotFixes = Get-HotFix

if ($hotfixes.HotFixID.Contains($KB))
{
  Write-Output "$($KB) is already installed."
  exit 0
}

$schTaskName = Get-Random
$scriptName = "$($schTaskName).ps1"

[scriptblock]$schTaskScript = {
    param (
        $KB,
        $KBFileName,
        $DownloadURI
    )
    $npipeClient = new-object System.IO.Pipes.NamedPipeClientStream($env:ComputerName, 'task', [System.IO.Pipes.PipeDirection]::Out)
    $npipeclient.connect()
    $pipeWriter = new-object System.IO.StreamWriter($npipeClient)
    $pipeWriter.AutoFlush = $true
    
    $updatePath = Join-Path "$($env:TEMP)" $KBFileName

    if (!(Test-Path -Path $updatePath))
    {
        $pipewriter.writeline("$(get-date -Format s) Downloading update to $($updatePath)")
        Invoke-WebRequest -UseBasicParsing -Uri $DownloadURI -OutFile $updatePath
        $pipewriter.writeline("$(get-date -Format s) Finished Downloading Update")
    }

    $pipewriter.writeline("$(get-date -Format s) Starting update install from $($updatePath)")
    Start-Process -FilePath 'wusa.exe' -ArgumentList "$($updatePath) /quiet /norestart" -Wait -NoNewWindow
    $pipewriter.writeline("$(get-date -Format s) Update installation complete")

    $pipewriter.writeline("SCHEDULED_TASK_DONE: $LastExitCode")
    $pipewriter.dispose()
    $npipeclient.dispose()
}.GetNewClosure()

Write-Output "Creating Script File"
$scriptPath = Join-Path $env:TEMP $scriptName
Set-Content -Path $scriptPath -Value $schTaskScript -Force

Write-Output "Creating Scheduled Task"
Start-Process -FilePath 'schtasks' -ArgumentList "/create /tn $($schTaskName) /ru vagrant /rp vagrant /sc once /st 00:00 /sd 01/01/2005 /f /tr ""powershell -executionpolicy unrestricted -File '$($scriptPath)' $KB $KBFileName $DownloadURI""" -Wait -NoNewWindow

Start-Sleep -Seconds 5

Write-Output "$(get-date -Format s) Running Scheduled Task"
try
{
    $npipeServer = new-object System.IO.Pipes.NamedPipeServerStream('task', [System.IO.Pipes.PipeDirection]::In)
    $pipeReader = new-object System.IO.StreamReader($npipeServer)
    Start-Process -FilePath 'schtasks' -ArgumentList "/run /tn ""$($schTaskName)"""
    $npipeserver.waitforconnection()
    $host.ui.writeline('Connected to the scheduled task.')
    while ($npipeserver.IsConnected)
    {
        $output = $pipereader.ReadLine()
        if ($output -like 'SCHEDULED_TASK_DONE:*')
        {
            $exit_code = ($output -replace 'SCHEDULED_TASK_DONE:').trim()
        }
        else
        {
            $host.ui.WriteLine($output)
        }
    }
}
catch
{
    if ($_.Exception.Message)
    {
        Write-Output $_.Exception.Message
    }

    if ($_.Exception.ItemName)
    {
        Write-Output $_.Exception.ItemName
    }

    if ($_.CategoryInfo.Reason)
    {
        Write-Output $_.CategoryInfo.Reason
    }

    if ($_.CategoryInfo.Category)
    {
        Write-Output $_.CategoryInfo.Category.ToString()
    }

    if ($_.CategoryInfo.Activity)
    {
        Write-Output $_.CategoryInfo.Activity
    }
}
finally
{
    $pipereader.dispose()
    $npipeserver.dispose()

    Write-Output "$(get-date -Format s) Removing Scheduled Task"
    Start-Process -FilePath 'schtasks' -ArgumentList "/Delete /TN $($schTaskName) /F"

    $host.setshouldexit($exit_code)
}