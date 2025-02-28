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
}
New-Variable -Name __MtSession -Value $__MtSession -Scope Script -Force

# Import private and public scripts and expose the public ones
$privateScripts = @(Get-ChildItem -Path "$PSScriptRoot\internal" -Recurse -Filter "*.ps1")
$publicScripts = @(Get-ChildItem -Path "$PSScriptRoot\public" -Recurse -Filter "*.ps1")

foreach ($script in ($privateScripts + $publicScripts)) {
	try {
		. $script.FullName
	} catch {
		Write-Error -Message ("Failed to import function {0}: {1}" -f $script, $_)
	}
}