# Script to change startup type of services listed at
# https://wiki.oucs.ox.ac.uk/nsms/SecurityConfigurationWizardServices
#
# ALG	Application Layer Gateway Service
# CertPropSvc	Certificate Propagation
# TrkWks	Distributed Link Tracking Client
# fdPHost	Function Discovery Provider Host
# FDResPub	Function Discovery Resource Publica...
# FCRegSvc	Microsoft Fibre Channel Platform Re...
# MMCSS	Multimedia Class Scheduler
# napagent	Network Access Protection Agent
# WPDBusEnum	Portable Device Enumerator Service
# Spooler	Print Spooler
# RasAuto	Remote Access Auto Connection Manager
# RasMan	Remote Access Connection Manager
# RemoteRegistry	Remote Registry
# SCardSvr	Smart Card
# SCPolicySvc	Smart Card Removal Policy
# SNMPTRAP	SNMP Trap
# TapiSrv	Telephony
# AudioSrv	Windows Audio
# AudioEndpointBu...	Windows Audio Endpoint Builder
# WcsPlugInService	Windows Color System
# WinRM	Windows Remote Management (WS-Manag...
# W32Time	Windows Time
# WinHttpAutoProx...	WinHTTP Web Proxy Auto-Discovery Se...
# dot3svc	Wired AutoConfig


$ServicesToDisable = @("ALG",
	"CertPropSvc",
	"fdPHost",
	"FDResPub",
	"FCRegSvc",
	"MMCSS",
	"napagent",
	"WPDBusEnum",
	"RasAuto",
	"RasMan",
	"SCardSvr",
	"SCPolicySvc",
	"SNMPTRAP",
	"TapiSrv",
	"AudioSrv",
	"AudioEndpointBuilder",
	"WcsPlugInService",
	"WinRM",
	"WinHttpAutoProxySvc",
	"dot3svc")

$ServicesToSetToManual = @("TrkWks",
	"Spooler",
	"RemoteRegistry")

$ServicesToSetToAutomatic = @("W32Time")

Foreach ($svc in $ServicesToDisable) {  Set-Service -Name $svc -StartupType Disabled  }
Foreach ($svc in $ServicesToSetToManual) {  Set-Service -Name $svc -StartupType Manual}
Foreach ($svc in $ServicesToSetToAutomatic) {  Set-Service -Name $svc -StartupType Automatic  }
