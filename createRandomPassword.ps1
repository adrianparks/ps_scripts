function GenPassword ([int]$pwlength) 
{

 #  Generate a password conforming to AD complexity rules (i.e. three character classes)
 
 $password = $null
 $rnd = new-object random 
 $complexChar = @{"Numeric" = "0"; "UpperCase" = "0"; "LowerCase" = "0" ; "Other" = "0"}
 $count=1
 $complexityCount = 0

 while ($count -le $pwlength) {

   $nextChar = $rnd.next(33,127)

   if (($nextChar -ge 48) -and ($nextChar -le 57)) { $complexChar["Numeric"] = 1 }
      elseif (($nextChar -ge 65) -and ($nextChar -le 90)) { $complexChar["UpperCase"] = 1 }
      elseif (($nextChar -ge 97) -and ($nextChar -le 122)) { $complexChar["LowerCase"] = 1 }
      else { $complexChar["Other"] = 1 }

   $password = $password+([char]($nextChar))
      
   if ($count -eq $pwlength) {
       
      # Add up the complexity count, one point for each character class used
      foreach ($type in @($complexChar.keys)) { $complexityCount = $complexityCount + $complexChar[$type] }
 
      # Discard password and start again if insufficient complexity - i.e. less than three character classes
      
      if ($complexityCount -lt 3) { 
      
        # Write-Host ("Password was $password which has only $complexityCount character classes, going again")
        $password = $null
        $complexityCount = 0
        foreach ($type in @($complexChar.keys)) { $complexChar[$type] = 0 }
        $count = 0
      }
   
   }
   
   $count++

 }

 return $password

}


$passwordlength=15

$pw = GenPassword($passwordlength)

Write-Host "$pw"