$ErrorActionPreference = 'Stop'
$schTaskName = Get-Random
$scriptName = "$($schTaskName).ps1"
$schTaskScript = "start-sleep -seconds 5;
`$npipeClient = new-object System.IO.Pipes.NamedPipeClientStream(
`$env:ComputerName, 'task', [System.IO.Pipes.PipeDirection]::Out);
`$npipeclient.connect();
`$pipeWriter = new-object System.IO.StreamWriter(`$npipeClient);
`$pipeWriter.AutoFlush = `$true;
Import-Module -Name Boxstarter.Bootstrapper
Install-WindowsUpdate -AcceptEula | foreach-object {} {`$pipewriter.writeline(`$_)} {
    `$pipewriter.writeline(`"SCHEDULED_TASK_DONE: `$LastExitCode`");
    `$pipewriter.dispose();
    `$npipeclient.dispose()
}"

Write-Output "Creating Script File"
Set-Content -Path "C:\Windows\Temp\$($scriptName)" -Value $schTaskScript -Force

Write-Output "Creating Scheduled Task"
Start-Process -FilePath 'schtasks' -ArgumentList "/create /tn $($schTaskName) /ru vagrant /rp vagrant /sc once /st 00:00 /sd 01/01/2005 /f /tr ""powershell -executionpolicy unrestricted -File 'C:\Windows\Temp\$($scriptName)'""" -Wait -NoNewWindow

Start-Sleep -Seconds 3

Write-Output "Running Scheduled Task"
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
finally
{
    $pipereader.dispose()
    $npipeserver.dispose()

    Write-Output "Removing Scheduled Task"
    Start-Process -FilePath 'schtasks' -ArgumentList "SchTasks /Delete /TN $($schTaskName)"

    $host.setshouldexit($exit_code)
}
