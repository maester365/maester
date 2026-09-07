function Test-MtEntraAgentHighRiskGraphPermissions {
    <#
    .SYNOPSIS
    Finds Agent Identities with high-risk Microsoft Graph permissions.
    .DESCRIPTION
    Checks application and delegated Microsoft Graph permissions assigned to Agent Identities.
    Reports permissions that Maester classifies as high risk and that Microsoft does not currently
    list as blocked for Agent Identities.
    .EXAMPLE
    Test-MtEntraAgentHighRiskGraphPermissions

    Returns true when no Agent Identity has a listed high-risk Graph permission.
    .LINK
    https://maester.dev/docs/commands/Test-MtEntraAgentHighRiskGraphPermissions
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseSingularNouns', '', Justification = 'This test checks multiple permissions.'
    )]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        Write-Verbose 'Reading Agent Identity Microsoft Graph permission grants.'
        $PermissionState = Get-MtEntraAgentHighRiskGraphPermissionFinding
        $Findings = @($PermissionState.Findings)

        if ($Findings.Count -eq 0) {
            $Message = if ($PermissionState.AgentCount -eq 0) {
                'Well done. No Agent Identities were found in the tenant.'
            } else {
                'Well done. No Agent Identity has a high-risk Microsoft Graph permission.'
            }
            Add-MtTestResultDetail -Result $Message
            return $true
        }

        $Result = "Found $($Findings.Count) high-risk Microsoft Graph permission grant(s) " +
            "across Agent Identities."
        $Result += "`n`n| Agent object ID | Display name | App ID | Permission | " +
            'Type | Attack path |'
        $Result += "`n| --- | --- | --- | --- | --- | --- |"
        foreach ($Finding in $Findings) {
            $Name = [string]$Finding.DisplayName
            if ([string]::IsNullOrWhiteSpace($Name)) { $Name = '(unnamed)' }
            $Name = [System.Net.WebUtility]::HtmlEncode($Name) -replace '\|', '&#124;'
            $Name = $Name -replace "`r?`n", ' '
            $Permission = [System.Net.WebUtility]::HtmlEncode([string]$Finding.Permission)
            $Result += "`n| $($Finding.AgentId) | $Name | $($Finding.AppId) | " +
                "$Permission | $($Finding.PermissionType) | $($Finding.AttackPath) |"
        }

        Add-MtTestResultDetail -Result $Result -Severity 'High'
        return $false
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
