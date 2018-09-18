# addADusers.ps1
#
# version 1.0 AP 1/4/11
# version 1.1 AP 17/6/11
# version 2.0 AP 13/11/11
# 
# Add users to the Active Directory, including Unix attributes for MMP integration 
#
# Takes a CSV file as input, for example:
# 
# Adrian,Parks,adrianp
# Jermain,Defoe,spur1234
#
# Output consists of the input records and the generated password, in CSV format
# Output can be piped to a CSV file using "addADusers.ps1 | out-file userlist.csv"
#
#
# Usage: addADusers [-unitOU <base OU>][-userfile path\to\logfile]
#
# -unitOU         : Base OU of users, directly under the University Units OU (e.g. SSEE)
# -userfile       : path to the input CSV file (e.g. c:\temp\users.csv)


param([switch]$help=$false,
      [string]$unitOU="HoldingArea",
      [string]$userfile="users.csv"
     )

import-module -name ActiveDirectory


function Usage 
{ 
 Write-Host "usage $($script:MyInvocation.InvocationName) [-unitOU <base OU>][-userfile path\to\logfile]
-unitOU         : Base OU of users, directly under the University Units OU (e.g. SSEE or HoldingArea)
-userfile       : path to the input CSV file (e.g. c:\temp\users.csv)
e.g. $($script:MyInvocation.InvocationName) -unitOU SSEE -userfile c:\temp\users.csv"
 exit
}


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

function CheckIsNewUser($userName)
{

   $upnToCheck = $userName + "@oucs-test.ox.ac.uk"
   
   if (Get-ADuser -Filter {userPrincipalName -eq $upnToCheck}) { 
      return 0
   } else { 
      return 1
   }

}

function WriteAccountToAD($givenName,$sn,$userName,$pw)
{

   $userDisplayName = $givenName + " " + $sn
  	
   if ($userName -match "/") { $sAMAccountName = $userName.Replace("/","-") }
   else { $sAMAccountName = $userName }

   $newUser = $ou.Create("user","cn=" + $userDisplayName)
   $newUser.put("sn", $sn)
   $newUser.put("DisplayName", $userDisplayName)
   $newUser.put("givenName", $givenName)
   $newUser.put("sAMAccountName",$sAMAccountName)
   $newUser.put("userPrincipalName",$userName + "@oucs-test.ox.ac.uk")
   $newUser.SetInfo()
   $newUser.SetPassword($pw)
   $newUser.put("userAccountControl", 512)
   $newUser.put("altSecurityIdentities","Kerberos:" + $userName + "@OX.AC.UK")
   $newUser.SetInfo()

   # Generate the Unix UID from the Windows RID 

   $objUser = New-Object System.Security.Principal.NTAccount("oucs-test", $sAMAccountName)
   $strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
   $uid = $strSID.value -replace ".*-(.*)",'$1'
	
   # Add all the SFU attributes to the user account
	
   $newUser.put("loginShell","/bin/bash")
   $newUser.put("msSFU30Name",$sAMAccountName)
   $newUser.put("msSFU30NISDomain","oucs-test")
   $newUser.put("gidNumber",$gid)
   $newUser.put("uidNumber",$uid)
   $newUser.put("unixHomeDirectory","/home/$sAMAccountName")
   $newUser.put("unixUserPassword",$pw)
	
   $newUser.SetInfo()
	
}

  
## Main code starts here  

# List of users that could not be written to the AD
$failedUsers = $null

# random is not as random as it could be, it turns out, so create one object here and refer to it in the
# GenPassword function rather than creating a new object in the function each time, which may end up with 
# the same seed and hence result
$rnd = new-object random 

# OU in which to create new users
$ou = [ADSI]"LDAP://OU=Users,OU=$unitOU,OU=University Units,DC=oucs-test,DC=ox,DC=ac,DC=uk" 

# group ID of the NIS domain-enabled group (usually Domain Users)
$gid = 513

# length of password to generate, minimum three characters or script will never complete
# but then if you are generating passwords of less than three chars that's probably just as well
$passwordLength = 10

if ($help) {Usage}

$timenow = get-date -DisplayHint time

Write-Output ("Starting at $timenow....`r`n")

# First remove any empty lines from the text file

(Get-Content $userfile | where {$_ -ne ""}) | Set-Content $userfile 

# Get each user from the CSV one at a time
foreach ($user in import-csv $userfile -Header "First","Last","Login")
{

   # Trim leading and trailing whitespace from CSV input
   $givenName = ($user.First).Trim()
   $sn = ($user.Last).Trim()
   $userName = ($user.Login).Trim()

   do {
  
     $pw = GenPassword $passwordLength
        
   } until (ValidPassword $pw)
   
   if (CheckIsNewUser $userName) { 
   
      Write-Output ("$givenName,$sn,$userName,$pw")
      WriteAccountToAD $givenName $sn $userName $pw
   
   } else { 
   
      # user account already exists (probably Marko is running this script) so add it to the list of failed updates
      $failedUsers = $failedUsers + "`r`n$userName"      
         
   }
   
} 

if ($failedUsers) {Write-Output ("`r`nFollowing users were not created, as they already exist in the AD: $failedUsers")}

$timenow = get-date -DisplayHint time
Write-Output ("`r`nCompleted at $timenow...")

