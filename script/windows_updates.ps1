$wuInstallExe = Join-Path "$($env:windir)\SYSTEM32" 'WUInstallAMD64.exe'

if (!(Test-Path -Path $wuInstallExe))
{
    Invoke-WebRequest -UseBasicParsing -Uri 'https://dl.dropboxusercontent.com/u/727435/Tools/WUInstallAMD64.exe' -OutFile $wuInstallExe
}

$schTaskName = Get-Random
$scriptName = "$($schTaskName).ps1"

[scriptblock]$schTaskScript = {
    Start-Sleep -Seconds 5
    $npipeClient = new-object System.IO.Pipes.NamedPipeClientStream($env:ComputerName, 'task', [System.IO.Pipes.PipeDirection]::Out)
    $npipeclient.connect()
    $pipeWriter = new-object System.IO.StreamWriter($npipeClient)
    $pipeWriter.AutoFlush = $true
    C:\WINDOWS\SYSTEM32\WUInstallAMD64.exe /install /autoaccepteula /silent | foreach-object {} {$pipewriter.writeline($_)} {
        $pipewriter.writeline("SCHEDULED_TASK_DONE: $LastExitCode")
        $pipewriter.dispose()
        $npipeclient.dispose()
    }
}

Write-Output "Creating Script File"
$scriptPath = Join-Path $env:TEMP $scriptName
Set-Content -Path $scriptPath -Value $schTaskScript -Force

Write-Output "Creating Scheduled Task"
Start-Process -FilePath 'schtasks' -ArgumentList "/create /tn $($schTaskName) /ru vagrant /rp vagrant /sc once /st 00:00 /sd 01/01/2005 /f /tr ""powershell -executionpolicy unrestricted -File '$($scriptPath)'""" -Wait -NoNewWindow

Start-Sleep -Seconds 3


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
    Start-Process -FilePath 'schtasks' -ArgumentList "SchTasks /Delete /TN $($schTaskName)"

    $host.setshouldexit($exit_code)
}
