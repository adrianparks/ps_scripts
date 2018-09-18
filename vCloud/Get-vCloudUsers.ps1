$Orgs = Get-Org
Write-Host "Got all the orgs"

Foreach ($Org in $Orgs) {
    $FullName = $Org.FullName
    Write-Host "$Org - $FullName"
    $Users = Get-CIUser -Org $Org
    Foreach ($User in $Users) {
        $Name = $User.Name
        $Role = $User.ExtensionData.Role.Name
        $Email = $User.Email
        If ($Role -eq "Organization Administrator") {
            Write-Host "$Name,$Email"
        }
    }
}

