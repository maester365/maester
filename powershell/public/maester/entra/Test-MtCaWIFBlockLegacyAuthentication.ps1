<#
.SYNOPSIS
  Checks if the user is blocked from using legacy authentication

.DESCRIPTION
    Checks if the user is blocked from using legacy authentication using the Conditional Access WhatIf Graph API endpoint.

.PARAMETER UserId
    The UserId to test the Conditional Access policies with

.EXAMPLE
    Test-MtCaWIFBlockLegacyAuthentication -UserId "e7417ac7-0485-4014-9100-33163bd6211f"

.LINK
    https://maester.dev/docs/commands/Test-MtCaWIFBlockLegacyAuthentication
#>
function Test-MtCaWIFBlockLegacyAuthentication {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        # The UserId to test the Conditional Access policies with
        [Parameter(Mandatory)]
        [string]$UserId
    )

    if ( ( Get-MtLicenseInformation EntraID ) -eq "Free" ) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
        return $null
    }

    try {
        $policiesResult = Test-MtConditionalAccessWhatIf -UserId $UserId -IncludeApplications "00000002-0000-0ff1-ce00-000000000000" -ClientAppType exchangeActiveSync
        if ( $null -ne $policiesResult ) {
            $testResult = "Well done. The following conditional access policies are currently blocking legacy authentication.`n`n%TestResult%"
            $Result = $true
        } else {
            $testResult = "No conditional access policy found that blocks legacy authentication."
            $Result = $false
        }

        Add-MtTestResultDetail -Result $testResult -GraphObjects $policiesResult -GraphObjectType ConditionalAccess
        Write-Verbose "Checking if the user $UserId is blocked from using legacy authentication"
        return $Result
    } catch {
        Add-MtTestResultDetail -Error $_ -GraphObjectType ConditionalAccess
        Write-Verbose "An error occurred while checking if the user $UserId is blocked from using legacy authentication"
        return $false
    }
}
