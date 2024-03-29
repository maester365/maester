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
$MtGraphCache = @{}
$MtGraphBaseUri = $null
$MtTestResultDetail = @{}

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

# Export public functions and aliases
New-Alias -Name 'Invoke-Maester' -Value 'Invoke-MtMaester' -Force
New-Alias -Name 'Connect-Maester' -Value 'Connect-MtGraph' -Force
New-Alias -Name 'Connect-MtMaester' -Value 'Connect-MtGraph' -Force
New-Alias -Name 'Disconnect-Maester' -Value 'Disconnect-MtGraph' -Force
New-Alias -Name 'Disconnect-MtMaester' -Value 'Disconnect-MtGraph' -Force

Export-ModuleMember -Function 'Invoke-MtMaester' -Alias 'Invoke-Maester'
Export-ModuleMember -Function 'Connect-MtGraph' -Alias 'Connect-Maester'
Export-ModuleMember -Function 'Connect-MtGraph' -Alias 'Connect-MtMaester'
Export-ModuleMember -Function 'Disconnect-MtGraph' -Alias 'Disconnect-Maester'
Export-ModuleMember -Function 'Disconnect-MtGraph' -Alias 'Disconnect-MtMaester'
