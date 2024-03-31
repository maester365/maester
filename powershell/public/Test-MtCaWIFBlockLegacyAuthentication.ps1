<#
.SYNOPSIS
  Checks if the user is blocked from using legacy authentication

.DESCRIPTION
    Checks if the user is blocked from using legacy authentication using the Conditional Access WhatIf Graph API endpoint.

.PARAMETER UserId
    The UserId to test the Conditional Acccess policie with

.EXAMPLE
    Test-MtCaWIFBlockLegacyAuthentication -UserId "e7417ac7-0485-4014-9100-33163bd6211f"
#>
function Test-MtCaWIFBlockLegacyAuthentication {
    [CmdletBinding()]
    [OutputType([object])]
    param (
        # The UserId to test the Conditional Acccess policie with
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory)]
        [string]$UserId
    )

    $policiesResult = Test-MtConditionalAccessWhatIf -UserId "e7417ac7-0485-4014-9100-33163bd6211f" -IncludeApplications "00000002-0000-0ff1-ce00-000000000000" -ClientAppType exchangeActiveSync

    if ( $policiesResult.Count -gt 0 ) {
        $testResult = "Well done. The following conditional access policies are currently blocking legacy authentication.`n`n%TestResult%"
        $Result = $true
    } else {
        $testResult = "No conditional access policy securing security info registration."
        $Result = $false
    }
    Add-MtTestResultDetail -Result $testResult -GraphObjects $policiesResult -GraphObjectType ConditionalAccess
    Write-Verbose "Checking if the user $UserId is blocked from using legacy authentication"
    return $Result
}
