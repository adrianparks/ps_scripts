# 
# Name:			Get-ShortlyExpiringAccounts.ps1
# Author:		Adrian Parks
# Created:		17 June 2013
# Purpose:		Get a list of accounts that will shortly expire, and email them out
# Revisions:	1.0	  Initial Version 
#

if (!(Get-Module ActiveDirectory)) {Import-Module ActiveDirectory}
if (!(Get-Module OxCloud_Functions)) {Import-Module OxCloud_Functions}

$MailFrom = "" # enter from address
$LogPath = 'C:\Scripts\ScriptLogs\'

$timer = [System.Diagnostics.Stopwatch]::StartNew()
$timer.reset()
$timer.start()







$MailSubject = "Accounts in the AD soon to expire"
$MailBody = "Dear <recipient>,`r`n
The following accounts in the AD will shortly expire:


Regards,
etc`r`n
"

Send-Email -MailTo $Email -MailFrom $MailFrom -MailSubject $MailSubject -MailBody $MailBody
# Write-Log -LogFile $LogFilePath -Date -Level "INFO" -Message ("$Email`r`n$MailSubject`r`n$MailBody")

$duration = ($timer.elapsed).totalseconds
Write-Host "Script run time $duration seconds"

# __END__
