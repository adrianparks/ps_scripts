# eventmon.ps1
#
# version 1.0 AP 27/5/11
#
# Iterate through server logs (Sophos, TSM and selected Event Logs) and output notable events to
# nominated email account (or console)
#
# Use on Windows 2008 or 2008r2 servers in preference to older Perl script (eventmon.exe)
#
# Usage: eventmon [-noEmail] [-isDC] [-isDNS] [-mailTo address] [-noTSM] [-noLastBootTime] 
# [-noEventLog] [-noWarnings] [-noSophos][-sophosLogFile path\to\logfile]
# [-TSMLogFile path\to\logfile]"
#
# -noEmail        : don't send out a mail
# -isDC           : Computer is a domain controller so also check the DFS Replication
#                   and Directory Service logs
# -isDNS          : Computer is a DNS server so also check the DNS Server logs
# -mailTo         : send mail to <address>
# -noTSM          : don't check the TSM logs
# -noLastBootTime : don't output the last boot time of the server
# -noEventLog     : don't check any Event Logs
# -noWarnings     : ignore warnings, just output errors in Event Logs
# -noSophos       : don't check the Sophos logs
# -sophosLogFile  : path to the sav.log file if changed from default
# -TSMLogFile     : path to the dsmsched.log file if changed from default
#
# 
# Sample command line for install via Task Scheduler:
#
# Program/script : C:\WINDOWS\system32\windowspowershell\v1.0\powershell.exe
# Arguments      : -nologo -command "& {C:\scripts\eventmon.ps1 -isDC -isDNS}"
# Start in       : c:\scripts


param([switch]$help=$false,
      [switch]$noEmail=$false,
      [switch]$isDC=$false,
      [switch]$isDNS=$false,
      [string]$mailTo="someone@ox.ac.uk",
      [switch]$noSophos=$false,
      [switch]$noTSM=$false,
      [switch]$noEventLog=$false,
      [switch]$noWarnings=$false,
      [switch]$noLastBootTime=$false,
      [string]$sophosLogFile="C:\ProgramData\Sophos\Sophos Anti-Virus\logs\sav.txt",
      [string]$TSMLogFile = "c:\program files\tivoli\tsm\baclient\dsmsched.log"
      )

### Initial setup

$scriptVersion = "1.0"

$computername =  (Get-Content env:computername).ToLower()
$fqdn = [System.Net.Dns]::GetHostbyAddress("127.0.0.1").HostName.ToLower()
$dnssuffix = $fqdn.Replace($computername,"").Substring(1)

$global:logfile = ""

$smtpServer = "<enter-smtp-server>"
$mailFrom = $computername + "@" + $dnssuffix
$mailSubject = "Daily logs from $computername"
$mailBody = ""
$computerip = ((ipconfig | findstr [0-9].\.)[0]).Split()[-1]
$timer = [System.Diagnostics.Stopwatch]::StartNew()

$indexfile = @{"System" = "syslog_index.xml"; 
               "Application" = "applog_index.xml"; 
               "Security" = "seclog_index.xml";
               "Directory Service" = "dslog_index.xml";
               "DNS Server" = "dnslog_index.xml";
               "DFS Replication" = "dfslog_index.xml"
               }

### Functions 

function usage 
{ 
 Write-Host "usage $($script:MyInvocation.InvocationName) [-noEmail] [-isDC] [-isDNS] [-mailTo address] [-noTSM] [-noLastBootTime] [-noEventLog] [-noWarnings] [-noSophos][-sophosLogFile path\to\logfile] [-TSMLogFile path\to\logfile]"
 exit
}

####
#### send_email function fires the report off
####

function send_email
{

 $mailmessage = New-Object system.net.mail.mailmessage 
 $mailmessage.from = ($mailFrom) 
 $mailmessage.To.add($mailTo)
 $mailmessage.Subject = $mailSubject
 $mailmessage.Body = $global:logfile
 $mailmessage.IsBodyHTML = $false
 $SMTPClient = New-Object Net.Mail.SmtpClient($smtpServer, 25)  
 # $SMTPClient.Credentials = New-Object System.Net.NetworkCredential("$SMTPAuthUsername", "$SMTPAuthPassword") 
 $SMTPClient.Send($mailmessage)
 Write-Host "Report emailed to administrator"

}

####
#### read_tsmlog function checks the TSM log
####

function read_tsmlog {

  $global:logfile += "`r`nTSM backup summary:`r`n`r`n"

  if (Test-Path $TSMLogFile) {
  
          Write-Host "Reading TSM log file..."
               
          $tsmlog = (Get-Content $TSMLogFile)
          $count = 0
          $tsmreport = ""

	  $dateYesterday = (Get-Date).AddDays(-1)
	  $dateRegEx = [Regex]'\d{2}\-\d{2}\-\d{4}\s\d{2}\:\d{2}\:\d{2}'

          # Iterate through TSM log until we get to first of today's records

          foreach ($line in $tsmlog) {

             $count++

             if ($line -match $dateRegEx) {
             
               $tsmLogDate = [datetime]::ParseExact($line.Substring(0,19), "dd-MM-yyyy HH:mm:ss", $null)
	       if ($tsmLogDate -ge $DateYesterday) {break}
             
             } 
	     
          }

          $totalLines = $tsmlog.count
          $linesToGet = $totalLines - $count

          # Get all today's records, then include interesting lines in the report
          $tsmlog | Select-Object -last $linesToGet | `
             foreach ($_) {

                if ($_ -match "Incremental backup of") {$tsmreport += "$_`r`n"} 
                if ($_ -match "ANS4037E") {$tsmreport += "$_`r`n"}	# changed during processing
                if ($_ -match "ANS1228E") {$tsmreport += "$_`r`n"} # sending failed
                if ($_ -match "ANS4987E") {$tsmreport += "$_`r`n"} # in use
                if ($_ -match "Total number of bytes transferred") {$tsmreport += "$_`r`n"}
                if ($_ -match "Data transfer time") {$tsmreport += "$_`r`n"}
                                                      
             }
             
          if ($tsmreport -eq "") { $tsmreport = "No TSM events found during last 24 hours`r`n" }

          $global:logfile += $tsmreport
             
  } else {

      Write-Host "Couldn't open TSM log file ( $TSMLogFile )"
      $global:logfile += "Couldn't open TSM log file ( $TSMLogFile )`r`n"

  }

}

####
#### read_sophoslog function checks the sophos log
####


function read_sophoslog {

  $global:logfile += "`r`nSophos backup summary:`r`n`r`n"

  if (Test-Path $sophosLogFile) {

              Write-Host "Reading Sophos log file..."

              $sophoslog = (Get-Content $sophosLogFile)
              $count = 0
              $sophosreport = ""

              $dateYesterday = (Get-Date).AddDays(-1)
              $dateRegEx = [Regex]'\d{8}\s\d{6}'

              # Iterate through Sophos log until we get to first of today's records
          
              foreach ($line in $sophoslog) {

                $count++
                if ($line -match $dateRegEx) {
             
                  $sophosLogDate = [datetime]::ParseExact($line.Substring(0,15), "yyyyMMdd HHmmss", $null)
	          if ($sophosLogDate -ge $DateYesterday) {break}
             
                } 
	     
              }
 
              $totalLines = $sophoslog.count
              $linesToGet = $totalLines - $count + 1
              
              $sophoslog | Select-Object -last $linesToGet | `
                 foreach ($_) {

                    if ($_ -match "suspicious") {$sophosreport += "$_`r`n"}
                    if ($_ -match "virus") {$sophosreport += "$_`r`n"}
                    if ($_ -match "Summary of results for scan") {$sophosreport += "$_`r`n"} 
                    if ($_ -match "Items scanned") {$sophosreport += "$_`r`n"} 
                    if ($_ -match "error") {$sophosreport += "$_`r`n"} 
                    if ($_ -match "Items quarantined") {$sophosreport += "$_`r`n"} 
                    if ($_ -match "Items dealt with") {$sophosreport += "$_`r`n"} 
                    
                 }

              if ($sophosreport -eq "") { $sophosreport = "No Sophos events found during last 24 hours`r`n" }

              $global:logfile += $sophosreport
            
  } else {

      Write-Host "Couldn't open Sophos log file ( $sophosLogFile )"
      $global:logfile += "Couldn't open Sophos log file ( $sophosLogFile )`r`n"
  }

}

####
#### read_eventlog function returns the relevant event logs
####


function read_eventlog ($log) {

 $eventdetails = @{}
 $eventcount = @{}
 
 $seed_depth = 100
 $index = (Get-EventLog -LogName $log -newest 1).index

 $global:logfile += "`r`n$log Event Log summary:`r`n"

 Write-Host "Reading $log event log..."
  
 # See if we have an index file to use containing the last event log entry processed on the last run
 # if not, report that we will use a default of $seed_depth entries
 
 if (Test-Path $indexfile[$log]){
 
    $lastindex = Import-Clixml $indexfile[$log]
    Write-Host "Found index file" $indexfile[$log] "- last entry index $lastindex"
    
 } else {
 
    $global:logfile +=  "`r`nNo index file found - using default of searching last $seed_depth entries`r`n"
 }

 # if we have the number of the last event log entry, calculate number of events to retrieve
 # if not, use $seed_depth to do initial seeding
 
 if ($lastindex) { $n = $index - $lastindex } else { $n = $seed_depth }
 
 # if the number of events is less than 0 then something is up with the index file, so don't use it
 
 if ($n -lt 0){
   $global:logfile += "`r`nLog index changed since last run. The log may have been cleared. Re-seeding index and searching last $seed_depth entries.`r`n"
   $n = $seed_depth
 }
 
 if ($n -eq 0){
     $global:logfile += "`r`nNo new entries in $log log since last run of this script...`r`n"
 }
  else
 {

     # get the log entries
     # note that Get-WinEvent does not work reliably on anything prior to Windows 2008 R2, so ditched in favour of older Get-EventLog command
     
     if ($noWarnings) {
     
       $Events = Get-EventLog -LogName $log -Newest $n | where {$_.EntryType -match "Error"}
     
     } else {
     
       $Events = Get-EventLog -LogName $log -Newest $n | where {$_.EntryType -match "Error" -or $_.EntryType -match "Warning"}
     
     }  
     
     # $hits contains the number of events we've found
     $hits = $Events.count
         
     if (!$hits) {
     
        $global:logfile += "`r`nNo notable entries in $log log since last run of this script...`r`n"
     
     } else {
     
         foreach ($event in $Events) {
                   
            $Message = $event.Message.replace("`r`n"," ") # get rid of all the carriage returns in the message
            $EntryType = $event.Entrytype
            $EventID = $event.EventID
            $Source = $event.Source
            
            # if ($EventText.length -ge 500) {$EventText = $EventText.substring(0,499)}
            if ($EventID -eq 5774) {continue}	# ignore the dynamic DNS errors
            if (($EventID -eq 4098) -and ($Source -eq "AdsmClientService")) {continue}	# ignore TSM messages
            if (($EventID -eq 4099) -and ($Source -eq "AdsmClientService")) {continue}	# ignore TSM messages
            
            $eventkey = "$EntryType,$EventID,$Source,$Message"
            $eventdetails[$eventkey] = $event.TimeGenerated
            $eventcount[$eventkey]++
          
         }
        
                  
         foreach ($event in $eventdetails.Keys) {
         
            $date = ($eventdetails[$event]).ToLongDateString() + " " + ($eventdetails[$event]).ToLongTimeString()
                        
            $global:logfile += "`r`n"
            $global:logfile += "$event"
            
            if ($eventcount[$event] -gt 1) {
            
                $global:logfile += "`r`nFirst occurred on $date, then "
                $global:logfile += $eventcount[$event]-1
                $global:logfile += " subsequent instance(s) of this error`r`n"
            
            } else {
            
                $global:logfile += " Timestamp $date`r`n"
            
            }
         
         }
       
     }
     
  }
 
 $index | export-clixml $indexfile[$log]

}

####
#### get_lastboot function gets the last boot time
####

function get_lastboot {

$wmi=Get-WmiObject -class Win32_OperatingSystem
$lastBootTime=$wmi.ConvertToDateTime($wmi.Lastbootuptime)

$global:logfile += "`r`nSystem was last rebooted on " + $lastBootTime.ToLongDateString() + " " + $lastBootTime.ToLongTimeString() + "`r`n"
}

### Program starts 

if ($help) {usage}

$timer.reset()
$timer.start()

if (!$noTSM) {read_tsmlog}
if (!$noSophos) {read_sophoslog}
if (!$noEventLog) {read_eventlog("System")}
if (!$noEventLog) {read_eventlog("Application")}

if ((!$noEventLog) -and ($isDC)) {read_eventlog("Directory Service")}
if ((!$noEventLog) -and ($isDC)) {read_eventlog("DFS Replication")}
if ((!$noEventLog) -and ($isDNS)) {read_eventlog("DNS Server")}

if (!$noLastBootTime) {get_lastboot}

if (!$noEmail) { send_email } else { Write-Host $global:logfile }

$duration = ($timer.elapsed).totalseconds
Write-Host "Script run time $duration seconds"
