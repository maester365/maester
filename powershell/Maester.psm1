<#
.DISCLAIMER
	THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF
	ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO
	THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
	PARTICULAR PURPOSE.

	Copyright (c) Microsoft Corporation. All rights reserved.
#>

## Initialize Module Configuration
#Requires -Modules Pester, Microsoft.Graph.Authentication

## Initialize Module Variables
## Update Clear-ModuleVariable function in internal/Clear-ModuleVariable.ps1 if you add new variables here
$__MtSession = @{
	GraphCache = @{}
	GraphBaseUri = $null
	TestResultDetail = @{}
	Connections = @()
	DnsCache = @()
	ExoCache = @{}
	OrcaCache = @{}
	AIAgentInfo = $null
	DataverseApiBase = $null       # Resolved Dataverse OData API base URL (e.g. https://org123.api.crm.dynamics.com/api/data/v9.2)
	DataverseResourceUrl = $null   # Dataverse resource URL for token acquisition (e.g. https://org123.crm.dynamics.com)
	DataverseEnvironmentId = $null # Environment identifier for display (e.g. org123.crm.dynamics.com)
	ADCache = @{}                  # Active Directory data cache
	ADConnection = $null           # Active Directory connection state
	ADCollectionTime = $null       # Timestamp of last AD data collection
}
New-Variable -Name __MtSession -Value $__MtSession -Scope Script -Force

# Import private and public scripts and expose the public ones
$privateScripts = @(Get-ChildItem -Path "$PSScriptRoot\internal" -Recurse -Filter "*.ps1" -ErrorAction SilentlyContinue)
$publicScripts = @(Get-ChildItem -Path "$PSScriptRoot\public" -Recurse -Filter "*.ps1" -ErrorAction SilentlyContinue)

$importErrors = @()
foreach ($script in ($privateScripts + $publicScripts)) {
	if (-not (Test-Path $script.FullName)) {
		$importErrors += "Script file not found: $($script.FullName)"
		continue
	}

	try {
		. $script.FullName
	} catch {
		$errorMessage = "Failed to import function from '$($script.FullName)': $($_.Exception.Message)"
		$importErrors += $errorMessage
		Write-Warning $errorMessage
	}
}

# Report import errors if any occurred
if ($importErrors.Count -gt 0) {
	Write-Warning "Module loaded with $($importErrors.Count) import error(s). Some functionality may be unavailable."
}

# Safely import module manifest
try {
	$ModuleInfo = Import-PowerShellDataFile -Path "$PsScriptRoot/Maester.psd1" -ErrorAction Stop
} catch {
	Write-Warning "Failed to load module manifest: $($_.Exception.Message)"
	$ModuleInfo = $null
}