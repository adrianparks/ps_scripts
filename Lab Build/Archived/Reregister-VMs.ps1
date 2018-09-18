$Datastore = "Resource_03"

$Paths = Get-Content vms.txt | Foreach {

  # typical path: ./sql01.oucs-test.ox.ac.uk/sql01.oucs-test.ox.ac.uk.vmx
  $Path = $_.Substring(1)
  $FullPath = "[$Datastore] $Path"
  Write-Host $FullPath

  New-VM -VMFilePath $FullPath -ResourcePool PROD
  
}


