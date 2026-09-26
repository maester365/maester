function Test-MtCisaAuditLog {
    <#
    .SYNOPSIS
    Checks state of purview

    .DESCRIPTION
    Microsoft Purview Audit (Standard) logging SHALL be enabled.

    .EXAMPLE
    Test-MtCisaAuditLog

    Returns true if audit log enabled

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaAuditLog
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }elseif(!(Test-MtConnection SecurityCompliance)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return $null
    }

    # Use the session module name from the Exchange Online connection to call the correct
    # Get-AdminAuditLogConfig, not the Security & Compliance version which always returns False.
    $exoModuleName = Get-ConnectionInformation |
        Where-Object { $_.IsEopSession -ne $true -and $_.State -eq 'Connected' } |
        Select-Object -ExpandProperty ModuleName -First 1
    if (-not $exoModuleName) {
        throw 'Could not determine Exchange Online session module name.'
    }
    $config = & "$exoModuleName\Get-AdminAuditLogConfig"

    $testResult = $config.UnifiedAuditLogIngestionEnabled

    $portalLink = "https://purview.microsoft.com/audit/auditsearch"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has [unified audit log enabled]($portalLink)."
    } else {
        $testResultMarkdown = "Your tenant does not have [unified audit log enabled]($portalLink)."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
