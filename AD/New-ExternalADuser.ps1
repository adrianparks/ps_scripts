# 
# Name:			New-ExternalADUser.ps1
# Author:		Adrian Parks
# Created:		28 May 2013
# Purpose:		Create a temporary user in the AD, or a user without an Oxford account
# Revisions:	1.0	  Initial Version 
#

if (!(Get-Module ActiveDirectory)) {Import-Module ActiveDirectory}

function GenPassword ([int]$pwlength) 
{

   $password = $null
   $nextChar = $null
   
   $count = 0

   while ($count -lt $pwlength) {

      $nextChar = $rnd.next(33,127)
      $password = $password+([char]($nextChar))
      $count++
   }

   return $password

}

function ValidPassword($password)
{

   $minCharClasses = 3
   $complexityCount = 0
 
   # define character classes: lower case, upper case, digits and everything else
   $characterClasses = @("a-z","A-Z","0-9","^0-9a-zA-Z")
  
   # List of characters that are not allowed in a password 
   # The hash is rejected because it's tricky on Macs, see RT 41699
   $rejectChars = "#"
 
   # Check number of character classes in password
   foreach ($class in $characterClasses ) {

      if ($password -cmatch "[$class]") {
         $complexityCount++;
      }
   }
 
   # Reject password if insufficient complexity (i.e. insufficient character classes) or
   # if it contains a reject character such as the hash
      
   if ($complexityCount -lt $minCharClasses -or $password -cmatch "[$rejectChars]") { 
   
      return 0
   
   } else {   

      return 1
 
   }
}

# Start main code

	# Initialise some variables for generating a password later

	# random is not as random as it could be, it turns out, so create one object here and refer to it in the
	# GenPassword function rather than creating a new object in the function each time, which may end up with 
	# the same seed and hence result
	$rnd = new-object System.Random
	$passwordLength=12

	# Gather user details from console input
	$answer = "N"
	while ($answer -eq "N") {

		$givenName = ""
		$sn = ""
		$mail = ""
		$description = ""
		$inputDate = ""

		# Required attributes

		while (!($givenName -match "^[a-z -]+$")) {

		   if ($givenName) {Write-Host "Invalid format - upper/lowercase alphabet, space and hyphen only"}
		   $givenName = Read-Host "Enter first name"
		   if (!($givenName)) {Write-Host "Please enter a first name - this is a mandatory field"}
		 
		}

		while (!($sn -match "^[0-9a-z -]+$")) {

		   if ($sn) {Write-Host "Invalid format - upper/lowercase alphabet, numerals, space and hyphen only"}
		   $sn = Read-Host "Enter surname"
		   if (!($sn)) {Write-Host "Please enter a surname - this is a mandatory field"}
		   
		}

		while (!($description)) {

		   $description = Read-Host "Enter description"
		   if (!($description)) {Write-Host "Please enter a description - this is a mandatory field"}
		 
		}

		while (!($mail -match "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$")) {

		   if ($mail) {Write-Host "Error - likely an invalid email address format"}
		   $mail = Read-Host "Enter email address"
		   # Mail is not a mandatory attribute
		   if (!($mail)) {Break}
		 
		}

		# Optional attributes

		$validDate=0

		while ($validDate -eq 0) {

		   $inputDate = Read-Host "Enter account expiry date (DD/MM/YYYY)"
		   # Expiry date is not a mandatory attribute
		   if (!($inputDate)) {
		      $accountExpires = (Get-Date).AddDays(365)
		      Break
		   }
		   
		   if (!([DateTime]::TryParse($inputDate, [ref]$validDate))) {
		      Write-Host "Error - invalid date format"
		   } else { 
		      # set expiry date to a year from now
		      $validDate = 1
			  $accountExpires = [DateTime]::Parse($inputDate)
		   }
		 
		}


		# AD will expire the account at the beginning of the day so we need to add an extra 24 hours to it
		$accountExpires = $accountExpires.AddDays(1)

		Write-Host "You entered the following:`r`n
		First Name: $givenName
		Surname: $sn
		Description: $description
		Email Address: $mail
		Account Expiry Date: $inputDate`r`n"

		$answer = Read-Host "OK? Y/N"
		while(($answer -ne "Y") -and ($answer -ne "N"))
		{
			$answer = Read-Host "OK? Y/N"
		}
	}

	# get a list of all the external accounts and find the last one
	$accounts = Get-ADUser -LDAPFilter "(&(sAMAccountName>=user0000)(sAMAccountName<=user9999))" | select-object SamAccountName
	$lastUserName = ($accounts | Where {$_.SamAccountName -match "user\d{4}"} | Sort-Object SamAccountName | Select-Object -last 1).SamAccountName
	if (!$lastUserName) {$lastUserName = "user0099"}

	# Predict the next username
	[int]$number=$lastUserName.Substring(4)
	$number++
	$userName = "user" + $number.ToString("0000")

	# Set up some variables
	$userDisplayName = $givenName + " " + $sn
	$userPrincipalName = $userName + "@oucs-test.ox.ac.uk"

	# Generate a password for the account
	 do {
	     $pw = GenPassword $passwordLength
	    } until (ValidPassword $pw)
	
	$securepw = ConvertTo-SecureString $pw -asPlainText -Force

	# Create the account

	New-ADUser  -SamAccountName $userName `
				-AccountPassword $securepw `
				-GivenName $givenName `
				-Surname $sn `
				-Name $userDisplayName `
				-Path 'OU=Users,OU=HoldingArea,OU=University Units,DC=oucs-test,DC=ox,DC=ac,DC=uk' `
				-Description $description `
				-EmailAddress $mail `
				-AccountExpirationDate $accountExpires `
				-UserPrincipalName $userPrincipalName `
				-Enabled $true
		
	# Add the Unix attributes
	# First generate the Unix UID from the Windows RID 
	$objUser = New-Object System.Security.Principal.NTAccount("oucs-test", $userName)
	$strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
	$uidNumber = $strSID.value -replace ".*-(.*)",'$1'

	$loginShell = "/bin/bash"
	$msSFU30Name = $userName
	$msSFU30NISDomain = "oucs-test"
	$gidNumber = 513
	$unixHomeDirectory = "/home/$userName"

	
	$userAccount = Get-ADUser -identity $userName
  	$userAccount | Set-ADuser -Add @{loginShell=$loginShell;msSFU30Name=$msSFU30Name;gidNumber=$gidNumber;`
					msSFU30NISDomain=$msSFU30NISDomain;unixHomeDirectory=$unixHomeDirectory}

	Write-Host "Created account`r`nUsername: $userName`r`nPassword: $pw"
	
