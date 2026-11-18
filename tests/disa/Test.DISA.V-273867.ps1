function Test-MtDisaIdleSessionTimeout {
    <#
    .SYNOPSIS
    Checks that the Microsoft 365 idle session timeout signs users out after 15 minutes of inactivity or less.

    .DESCRIPTION
    The DISA Microsoft Intune MDM Service Desktop and Mobile STIG (V-273867) asks that the Intune service initiates a
    session lock after a 15-minute period of inactivity. Its check reads the idle session timeout of the Microsoft
    365 admin center (Org settings > Security & privacy > Idle session timeout) and requires 15 minutes or less.

    That setting is stored as the tenant's activity-based timeout policy. The check passes when the policy sets a
    web session idle timeout of no more than the given number of minutes (15 by default), and fails when there is no
    policy or the timeout is longer.

    CIS.M365.1.3.2 reads the same policy, but in hours, with a minimum of one hour, and it also requires a Conditional
    Access policy for unmanaged devices, which the STIG does not ask for. So this is a test of its own.

    .EXAMPLE
    Test-MtDisaIdleSessionTimeout

    Returns true when the idle session timeout is 15 minutes or less.

    .LINK
    https://maester.dev/docs/tests/DISA.V-273867
    #>
    [MaesterTest(
        Id = 'DISA.V-273867',
        Title = 'Microsoft Intune service must initiate a session lock after a 15-minute period of inactivity.',
        Product = 'microsoft-365',
        RelatedProduct = 'entra',
        Feature = 'organization-settings',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = 'T1550.004',
        Control = 'disa-stig-intune-mdm:V-273867',
        Service = 'Graph',
        Lifecycle = 'Preview',
        Author = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Longest idle session timeout that is allowed, in minutes.
        [ValidateRange(1, 1440)]
        [int] $MaximumIdleTimeoutMinutes = 15
    )

    $timeout = Get-MtActivityBasedTimeout
    $testResult = $null -ne $timeout.Timeout -and $timeout.Timeout -le [timespan]::FromMinutes($MaximumIdleTimeoutMinutes)

    $value = if ($timeout.Timeout) { "$([math]::Round($timeout.Timeout.TotalMinutes)) minutes" } else { 'Not configured' }
    $link = 'https://admin.microsoft.com/#/Settings/SecurityPrivacy/:/Settings/L1/IdleSessionTimeout'
    $table = "| Setting | Value | Required | Result |`n| --- | --- | --- | --- |`n"
    $table += "| [Idle session timeout]($link) | $value | $MaximumIdleTimeoutMinutes minutes or less | $(if ($testResult) { '✅ Pass' } else { '❌ Fail' }) |`n"

    if ($testResult) {
        $testResultMarkdown = "Well done. Users are signed out of Microsoft 365 web apps after $value of inactivity.`n`n$table"
    } elseif ($null -eq $timeout.Timeout) {
        $testResultMarkdown = "No idle session timeout is set. Set it to $MaximumIdleTimeoutMinutes minutes or less in the Microsoft 365 admin center.`n`n$table"
    } else {
        $testResultMarkdown = "The idle session timeout is $value. Set it to $MaximumIdleTimeoutMinutes minutes or less.`n`n$table"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
