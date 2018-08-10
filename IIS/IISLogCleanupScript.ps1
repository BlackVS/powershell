Set-Executionpolicy RemoteSigned
$days=60 #You can change the number of days here 
 
# Modify the drive and paths as needed
$ExchangeInstallRoot = "C"
$IISLogPath="inetpub\logs\LogFiles\"
$ExchangeLoggingPath="Program Files\Microsoft\Exchange Server\V15\Logging\"
$ETLLoggingPath="Program Files\Microsoft\Exchange Server\V15\Bin\Search\Ceres\Diagnostics\ETLTraces\"
$ETLLoggingPath2="Program Files\Microsoft\Exchange Server\V15\Bin\Search\Ceres\Diagnostics\Logs"


$Now = Get-Date
$LastWrite = $Now.AddDays(-$days)

Write-Host "Removing IIS and Exchange logs; keeping last" $days "days i.e. older " $LastWrite
 
Function CleanLogfiles($TargetFolder)
{
	$TargetServerFolder = "$ExchangeInstallRoot`:\$TargetFolder"
	Write-Host $TargetServerFolder
	if (Test-Path $TargetServerFolder) {
		Write-Host "Check folder: " $TargetServerFolder
        	$Files = Get-ChildItem $TargetServerFolder -Include *.log,*.blg,*.etl,*.txt -Recurse | Where {$_.LastWriteTime -le "$LastWrite"} 
	        foreach ($File in $Files) {
                Write-Host "Deleting file $File" -ForegroundColor "white"; 
                Remove-Item $File -ErrorAction SilentlyContinue | out-null
			#Write-Host $File
		}
    }
	Else {
		Write-Host "The folder $TargetServerFolder doesn't exist! Check the folder path!" -ForegroundColor "red"
	}
}
 
CleanLogfiles($IISLogPath)
CleanLogfiles($ExchangeLoggingPath)
CleanLogfiles($ETLLoggingPath)
CleanLogfiles($ETLLoggingPath2)
