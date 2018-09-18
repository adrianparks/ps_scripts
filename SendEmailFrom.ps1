################################################################################
##### Script Information #######################################################
################################################################################
#Name:			SendEmailFrom.ps1
#Author:		Adrian Parks
#Created:		20 April 2018
#Purpose:		Send email 
#Revisions:		1.0	  Initial Version 
#				
# Send email purporting to be from the $MailFrom address, now it no
# longer seems to be possible to do this in HEAT or via RT

$MailFrom = ""

$MailTo1 = ""
$MailTo2 = ""
$MailTo3 = ""

$MailSubject = "<subject-goes-here>"
$MailBody = 'Dear recipient
Here is your email
'
$SmtpServer = "<enter-smtp-server-here>"
	  
$MailMessage = New-Object Net.Mail.MailMessage
$Smtp = New-Object Net.Mail.SmtpClient($SmtpServer)

$MailMessage.From = $MailFrom
$MailMessage.ReplyTo = $MailFrom
$MailMessage.To.Add($MailTo1)
#$MailMessage.To.Add($MailTo2)
#$MailMessage.To.Add($MailTo3)
$MailMessage.Subject = $MailSubject
$MailMessage.IsBodyHTML = $false
$MailMessage.Body = $MailBody

$Smtp.Send($MailMessage)


