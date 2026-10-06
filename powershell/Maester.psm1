<#
.DISCLAIMER
	THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF
	ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO
	THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
	PARTICULAR PURPOSE.

	Copyright (c) Microsoft Corporation. All rights reserved.
#>

## Initialize Module Configuration
#Requires -Modules Microsoft.Graph.Authentication

## Initialize Module Variables
## Update Clear-ModuleVariable function in internal/Clear-ModuleVariable.ps1 if you add new variables here
$__MtSession = @{
	GraphCache             = @{}
	GraphBaseUri           = $null
	TestResultDetail       = @{}
	NativeTestInfo         = @{}                 # Native tests of the current run: ID -> function name and Markdown
	NativeReturnValue      = @{}                 # Native tests of the current run: ID -> what the test returned
	Connections            = @()
	DnsCache               = @()
	ExoCache               = @{}
	OrcaCache              = @{}
	AIAgentInfo            = $null       # Get-MtAIAgentInfo cache: @{ Agents; Error }, Error is why no agent data is available
	AzureDevOpsConnectionCache = $null
	DataverseApiBase       = $null       # Resolved Dataverse OData API base URL (e.g. https://org123.api.crm.dynamics.com/api/data/v9.2)
	DataverseResourceUrl   = $null   # Dataverse resource URL for token acquisition (e.g. https://org123.crm.dynamics.com)
	DataverseEnvironmentId = $null # Environment identifier for display (e.g. org123.crm.dynamics.com)
	SpoCache               = @{}                 # Cache for SharePoint Online tenant settings retrieved via PnP
	GitHubCache            = @{}                 # Per-session REST response cache; cleared each Invoke-Maester run
	ADCache                = @{}                 # Active Directory data cache
	ADConnection           = $null               # Active Directory connection state
	ADCredential           = $null               # Active Directory credential retained only for the connected session
	ADCollectionTime       = $null               # Timestamp of last AD data collection
	IncludeAffectedObjects  = $false              # Set by Invoke-Maester -IncludeAffectedObjects; gates per-test object capture
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

# Source checkout: the built-in native tests (tests/**/Test.*.ps1) are module source and are defined
# in module scope. The build concatenates them into Maester.psm1 instead.
$builtInTestRoot = Join-Path $PSScriptRoot '../tests'
if (Test-Path -LiteralPath $builtInTestRoot) {
	$builtInTestRoot = (Resolve-Path -LiteralPath $builtInTestRoot).Path
	$customTestFolder = (Join-Path $builtInTestRoot 'Custom') + [System.IO.Path]::DirectorySeparatorChar
	foreach ($testFile in @(Get-ChildItem -Path $builtInTestRoot -Recurse -File -Filter 'Test.*.ps1' -ErrorAction SilentlyContinue)) {
		if ($testFile.FullName.StartsWith($customTestFolder, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
		try {
			. $testFile.FullName
		} catch {
			$importErrors += "Failed to import built-in test '$($testFile.FullName)': $($_.Exception.Message)"
			Write-Warning $importErrors[-1]
		}
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
