##################################################################################################################
##### Module Information #########################################################################################
##################################################################################################################
#Name:			OxCloud_Functions
#Author:		Adrian Parks
#Created:		11 January 2013
#Purpose:		Functions for use with Oxford private cloud infrastructure scripts
#Revisions:		1.0	  Initial Version 
#				
#Notes:			Module needs to be installed in your Powershell installation's modules path, under
# 				a directory named the same as the function - i.e. \WindowsPowerShell\Modules\OxCloud_Functions\
#				before it can be sourced. Probably this directory is
#				%userprofile%\Documents\WindowsPowerShell\Modules but you can check this by running 
#				echo $env:PSModulePath in a PS session
#
#				Call the module in a script by use of Import-Module OxCloud_Functions

function Write-Log {
	<#
	.SYNOPSIS
		Write entries to both the host and the console.
	.DESCRIPTION
		Writes entries to the host (Write-Host) and a defined log file (Write-Output) simultaneously .
	.PARAMETER Logfile
		The full path of the log file to which entries should be written.
	.PARAMETER Date
		Switch to define if a date entry should be included when writing entries.
	.PARAMETER Level
		Define the logging level entry that should be added when writing entries.
	.PARAMETER Message
		Supply a string of the desired entry to be written.
	.PARAMETER Colour
		Define the colour to be added used when writing the entry.
	.PARAMETER CreateLogFile
	    Create the log file if it does not already exist
	.PARAMETER NoAppend
	    Overwrite the existing log file instead of appending to it
	
	.EXAMPLE
		PS C:\> Write-Log -LogFile "MyPath" -CreateLogFile -Date -Level "INFO" -Message "MyText"
	#>
	[CmdletBinding()]	
	param(
		[parameter(Mandatory=$true,
			HelpMessage="Supply a full path to the file where log entries will be written",
			ValueFromPipeline=$false)]
		[String]
		$LogFile
		,
		[parameter(Mandatory=$false,
			HelpMessage="Switch parameter to define if a new log file should be created using the defined LogFile parameter.",
			ValueFromPipeline=$false)]
		[Switch]
		$CreateLogFile
		,
		[parameter(Mandatory=$false,
			HelpMessage="Switch parameter to define if date should be specified.",
			ValueFromPipeline=$false)]
		[Switch]
		$Date
		,
		[parameter(Mandatory=$false,
			HelpMessage="Define logging level tag to be assigned to entry such as INFO, WARN, ERROR etc...",
			ValueFromPipeline=$false)]
		[ValidateSet("INFO","WARN","ERROR")]
		[String]
		$Level
		,
		[parameter(Mandatory=$false,
			HelpMessage="Supply the string to be written.",
			ValueFromPipeline=$false)]
		[String]
		$Message
		,
		[parameter(Mandatory=$false,
			HelpMessage="Supply a colour to be used when writing the string to the host.  By default ERROR and WARN will be flagged in Yellow and Red respectively.",
			ValueFromPipeline=$false)]
		[ValidateSet("Yellow","Red", "Green", "Blue","Black")]
		[String]
		$Colour
		,
		[parameter(Mandatory=$false,
			HelpMessage="Switch parameter to define if the entries will overwrite all existing entries instread of the default append.",
			ValueFromPipeline=$false)]
		[Switch]
		$NoAppend
	)
	Process{
		# Confirm if log file and directory already exists and create if appropriate
		if (!(Test-Path -Path $LogFile) -and $CreateLogFile){
			$LogFilePathArr = ($LogFile.split("\"))
			$FolderPath = $LogFilePathArr[0]
			for ($i=1;$i -lt ($LogFilePathArr.Length -1);$i++){
				$FolderPath = $FolderPath + "\" + $LogFilePathArr[$i]
			}
			if (!(Test-Path -Path $FolderPath)){
				New-Item -Path $FolderPath -ItemType Directory
			}
			New-Item -Path $LogFile -ItemType File
		}
				
		# Define date format to use
		$DateStamp = Get-Date -UFormat "[%D %T]"
		
		# Define text colour to use based on defined logging level
		if ($Level){
			if ($Level -eq "WARN"){
				$TextColour = "Yellow"
			}elseif($Level -eq "ERROR"){
				$TextColour = "Red"
			}
		}
		
		# Define text colour to use bassed on optional colour parameter - will override previous colour determination
		if($Colour){
			$TextColour = $Colour
		}
		
		# Write Output to host 
		if ($Message){
			Write-Host $DateStamp $Level $Message -ErrorAction SilentlyContinue
		}
				
		# Write Output to defined log file
		if ($Message){
			if ($NoAppend){
				$DateStamp + " " + $Level + " " + $Message > $LogFile
			}else{
				$DateStamp + " " + $Level + " " + $Message >> $LogFile
			}
		}
	}
	End{}
}

function Send-Email {
	<#
	.SYNOPSIS
		Send email
	.DESCRIPTION
		Send email
	.PARAMETER MailTo
		Email Recipient
	.PARAMETER MailFrom
		Email Sender
	.PARAMETER MailSubject
		Subject of email
	.PARAMETER MailBody
		Main body of email

	.EXAMPLE
		PS C:\> Send-Email -MailTo $target -MailFrom $source -Subject $subject -MailBody $body
	#>
	[CmdletBinding()]
	param(
		[parameter(Mandatory=$true,
			HelpMessage="Provide the recipient email address",
			ValueFromPipeline=$false)]
		[String]
		$MailTo
		,
		[parameter(Mandatory=$true,
			HelpMessage="Provide the sender email address",
			ValueFromPipeline=$false)]
		[String]
		$MailFrom
		,
		[parameter(Mandatory=$true,
			HelpMessage="Supply the subject.",
			ValueFromPipeline=$false)]
		[String]
		$MailSubject
		,
		[parameter(Mandatory=$true,
			HelpMessage="Provide the main body of the email.",
			ValueFromPipeline=$false)]
		[String]
		$MailBody
	)
	Process {

		$SmtpServer = "" # add this
	  
		$MailMessage = New-Object Net.Mail.MailMessage
		$Smtp = New-Object Net.Mail.SmtpClient($SmtpServer)

		$MailMessage.From = $MailFrom
		$MailMessage.ReplyTo = $MailFrom
		$MailMessage.To.Add($MailTo)
		$MailMessage.Subject = $MailSubject
		$MailMessage.IsBodyHTML = $false
		$MailMessage.Body = $MailBody

		$Smtp.Send($MailMessage)
	}
	End{}
}


