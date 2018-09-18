#Name:			Create-vCloudReport.ps1
#Author:		Adrian Parks
#Created:		01 May 2018
#Purpose:		Create a vCheck-like report for the Hosted VMs in the vCloud
#Revisions:		1.0	  Initial Version 
#				
# Extract various data from the vCloud Hosted VMs and then present this in a 
# report that looks quite a look like Alan Renouf's vCheck
#
# Brings in the module ReportHTML from the PowerShell repositories if not
# already loaded
#
# You will need to have vcreds.xml created, using something like:
#
# New-VICredentialStoreItem -Host <vcloud-fqdn> -User cs_readonly -Password "Passw0rd1" -File C:\Temp\vcreds.xml
#
# TODO: Write the logs out to a log file rather than using Write-Host

if (!(Get-Module | where {$_.Name -match "ReportHTML"})) {

	Write-Host "Installing external dependencies"
	Install-PackageProvider -Name NuGet -Scope CurrentUser -MinimumVersion 2.8.5.201 -Force
	Install-Module -Name ReportHTML -Scope CurrentUser -Force
	# this is a bit of a hack to ensure the module is loaded
	Get-HTMLContentClose | Out-Null
	
}

$Host = "" # vCD endpoint FQDN
$vDC = "" # enter vDC name
$Org = "" # enter Org

$creds = Get-VICredentialStoreItem -Host $Host -File C:\Temp\vcreds.xml
Connect-CIServer $Host -Org $Org -User $creds.User -Password $creds.Password

$OrgVdc = Get-OrgVdc | Where {$_.Name -eq $vDC}

Write-Host "Getting a list of VMs and vApps..."
$HostedVMs = Get-CIVM | Where {$_.OrgVdc.Name -eq $OrgVdc.Name}
$vApps = Get-CIVApp

# $HostedVMs = Search-Cloud -querytype Vm -Property Name,ContainerName,Vdc | Where {$OrgVdc.ID -contains $_.Vdc}

Write-Host "Analysing list..."
$ITSVMs = $HostedVMs | Where {$_.Name -match "domain0.ox.ac.uk" `
					-Or $_.Name -match "domain1.ox.ac.uk" `
					-Or $_.Name -match "domain2.ox.ac.uk" `
					-Or $_.Name -match "domain3.ox.ac.uk" }
					
$CustomerVMs = $HostedVMs | Where {$_.Name -notmatch "domain0.ox.ac.uk" `
					-And $_.Name -notmatch "domain1.ox.ac.uk" `
					-And $_.Name -notmatch "domain2.ox.ac.uk" `
					-And $_.Name -notmatch "domain3.ox.ac.uk" }
					
$WindowsVMs = $HostedVMs | Where {$_.GuestOSFullName -match "Microsoft" }
$LinuxVMs = $HostedVMs | Where {$_.GuestOSFullName -match "Linux" `
					  -Or $_.GuestOSFullName -match "CentOS"}
					  

# create a hash table of customer distribution
$CustomerDistribution = @{}
$CustomerDistribution.Add("IT Services",$ITSVMs.Count)
$CustomerDistribution.Add("External Customers",$CustomerVMs.Count)

# rename the column headers
$CustomerDistribution = $CustomerDistribution.keys | `
	Select @{l='Customers';e={$_}},@{l='NumberOfVMs';e={$CustomerDistribution.$_}}
					
# create a hash table of Windows vs Linux distribution			
$WinvLinVMs = @{}
$WinvLinVMs.Add("Windows",$WindowsVMs.Count)
$WinvLinVMs.Add("Linux",$LinuxVMs.Count)	

# rename the column headers
$WinvLinVMs = $WinvLinVMs.keys | `
	Select @{l='Operating System';e={$_}},@{l='NumberOfVMs';e={$WinvLinVMs.$_}}		
					
# More detailed breakdown of operating system distribution
$OSdistrib = ($HostedVMs | group GuestOSFullName | select name,count | sort count -Descending )

# Get spread of VMs over time
Write-Host "Importing historical VM numbers..."
$VMTotalsCSV = import-csv C:\temp\vms.csv -header Date,NumberOfVMs

$VMsByDate = @()

# This summarises the number of VMs by month
# Basically we select the maximum number of VMs we have in January
# Might be better to do it with the average, as we also occasionally decommission VMs

foreach ($Record in $VMTotalsCSV) {
	$VM = "" | Select Date, NumberOfVMs, Year, Month, MonthName
	$VM.Date = Get-Date($Record.Date)
	$VM.Month = ($VM.Date).Month
	$VM.NumberOfVMs = $Record.NumberOfVMs
	$VM.MonthName = (Get-Culture).DateTimeFormat.GetAbbreviatedMonthName($VM.Month)
	$VM.Year =  $VM.Date.Year
	$VMsByDate += $VM
}

$List = ($VMsByDate | Group-Object -Property MonthName, Year)

# Build the final array containing the aggregated VM totals for each month
$VMTotals = @()
Foreach ($Record in $List) {
 $VM = "" | Select MonthYear, NoOfVMs
 $VM.NoOfVMs = (($Record.Group.NumberOfVMs | Measure-Object -Maximum | Select Maximum)).Maximum
 $VM.MonthYear = $Record.Name -Replace ','
 $VMTotals += $VM
} 

# Get up-to-date list of VMs and their contact email addresses
Write-Host "Getting contact details for each VM"
$VMContacts = @()
$Count = 0
$HostedVMs | %{

	$Count+=1
	$VMName = $_.Name
	$vAppName = $_.Vapp.Name

	Write-Host "Processing VM $VMName, total count = $Count"
	
	$vApp = $vApps | where {$_.Name -eq $vAppName}
	if (!$vApp) {
		$vApp = Get-CIVAppTemplate | where {$_.Name -eq $vAppName}
	}

	if (!$vApp) {
			Write-Host "Couldn't find an associated vApp for VM $VMName "
		#	Write-Log -LogFile $LogFilePath -Date -Level "WARN" -Message ("Couldn't find an associated vApp for VM '" + $VMName + "'")	
		} else {
		
			$VM = "" | Select Name, Owner, Email
			$VM.Name = $_.Name
			$VM.Owner = $vApp.Owner.Name
			$VM.Email = $vApp.Owner.Email
			
			$VMContacts += $VM
		}

}

$FormattedVMs = ($VMContacts | Sort-Object -Property Name | Format-Table -Autosize -Property Name, Owner, Email )


Write-Host "Processing complete, setting up report"

#$HostedVMs
#$VMContacts
#$ITSVMs 
#$CustomerVMs
#$LinuxVMs
#$WindowsVMs

#set up the report

$rpt = @()
$rpt += Get-HTMLOpenPage -TitleText "vCloud Report - Hosted VMs" -hidelogos


# summary section

$rpt += Get-HtmlContentOpen -HeaderText "Summary Information"
$rpt += Get-HtmlContenttext -Heading "Total Hosted VMs" -Detail ( $HostedVMs.Count) 
# $rpt += Get-HtmlContenttext -Heading "VM Power State" -Detail ("Running " + ($HostedVMs | ? {$_.Status -eq 'PoweredOn'} | measure ).count + " / Powered Down " + ($HostedVMs | ? {$_.Status -eq 'PoweredOff'} | measure ).count)
$rpt += Get-HtmlContenttext -Heading "VMs Powered On" -Detail (( $HostedVMs | ? {$_.Status -eq 'PoweredOn'} | measure ).count)
$rpt += Get-HtmlContenttext -Heading "VMs Powered Off" -Detail (( $HostedVMs | ? {$_.Status -eq 'PoweredOff'} | measure ).count)

$rpt += Get-HtmlContentClose

# adding the VM details section

$rpt+= Get-HtmlContentOpen -HeaderText "VM Details" -IsHidden
$rpt+= Get-HtmlContentTable $VMContacts
$rpt+= Get-HtmlContentClose 

# adding the VM os section.  Note the -IsHidden switch

$rpt += Get-HtmlContentOpen -HeaderText "VM OS Summary" -IsHidden
$rpt += Get-HtmlContenttable $WinvLinVMs -Fixed
$rpt += Get-HtmlContenttext
$rpt += Get-HtmlContenttable $Osdistrib -Fixed
$rpt += Get-HtmlContentClose

#

$rpt += Get-HtmlContentOpen -HeaderText "Customer Distribution" -IsHidden
$rpt += Get-HtmlContenttable $CustomerDistribution -Fixed
$rpt += Get-HtmlContentClose


# Set up a bar chart

$ChartObject = Get-HTMLBarChartObject
$ChartObject.Title = "Number of VMs by date"
$ChartData = $VMtotals
$ChartObject.Size.Width = 900
$ChartObject.DataDefinition.DataNameColumnName = 'MonthYear'
$ChartObject.DataDefinition.DataValueColumnName = 'NoOfVMs'
$ChartObject.DataDefinition.AxisXTitle = "Date"
$ChartObject.DataDefinition.AxisYTitle = "Number of VMs"

# Add the bar chart from previous section to the report
$rpt += Get-HTMLContentOpen -HeaderText "Number of VMs by date"
$rpt += Get-HTMLBarChart -ChartObject $ChartObject -DataSet $ChartData
$rpt += Get-HTMLContentClose


# Set up a pie chart for operating system distribution

$PieObject1 = Get-HTMLPieChartObject
$PieObject1.Title = "Windows vs Linux Distribution"
$PieObject1.Size.Height =250
$PieObject1.Size.width =250
$PieObject1.ChartStyle.ChartType = 'pie'
$PieObject1.ChartStyle.ColorSchemeName = 'Random'
$PieObject1.DataDefinition.DataNameColumnName ='Operating System'
$PieObject1.DataDefinition.DataValueColumnName = 'NumberOfVMs'

# Add the pie chart from previous section to the report
$rpt += Get-HTMLContentOpen -HeaderText "VM Operating System Distribution"
$rpt += Get-HTMLPieChart -ChartObject $PieObject1 -DataSet $WinvLinVMs
$rpt += Get-HTMLContentClose

# Set up a pie chart for operating system distribution

$PieObject2 = Get-HTMLPieChartObject
$PieObject2.Title = "Detailed Operating System Distribution"
$PieObject2.Size.Height =500
$PieObject2.Size.width =500
$PieObject2.ChartStyle.ChartType = 'doughnut'
$PieObject2.ChartStyle.ColorSchemeName = 'Random'
$PieObject2.DataDefinition.DataNameColumnName ='Name'
$PieObject2.DataDefinition.DataValueColumnName = 'Count'

# Add the pie chart from previous section to the report
$rpt += Get-HTMLContentOpen -HeaderText "VM Operating System Distribution"
$rpt += Get-HTMLPieChart -ChartObject $PieObject2 -DataSet $OSdistrib
$rpt += Get-HTMLContentClose


# close the report

$rpt += Get-HTMLClosePage   


# save the report to a file

$rpt | set-content -path "c:\temp\vCloudReport.html"  
Invoke-Item "c:\temp\vCloudReport.html"








