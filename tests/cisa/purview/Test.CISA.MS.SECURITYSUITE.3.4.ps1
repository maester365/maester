function Test-MtCisaDlpUserNotification {
    <#
    .SYNOPSIS
    Checks whether full-protection DLP rules notify users.

    .DESCRIPTION
    DLP rules protecting credit card numbers, ITINs, and SSNs SHOULD notify users to help educate them on proper use of sensitive information.

    .EXAMPLE
    Test-MtCisaDlpUserNotification

    Returns true when every non-disabled full-protection rule in an enabled policy notifies at least one user.

    .LINK
    https://maester.dev/docs/tests/CISA.MS.SECURITYSUITE.3.4
    #>
    [MaesterTest(
        Id = 'CISA.MS.SECURITYSUITE.3.4',
        Title = 'User notifications to help educate them on the proper use of sensitive information SHOULD be enabled in the DLP policy.',
        Product = 'purview',
        Feature = 'data-loss-prevention',
        Area = 'data-protection',
        ResourceType = 'Policy',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'None',
        Control = 'cisa-scuba:MS.SECURITYSUITE.3.4',
        Service = 'SecurityCompliance',
        License = 'EXCHANGE_DLP',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $fullProtectionRules = @(Get-MtCisaSensitiveDlpRule | Where-Object { $_.SensitiveTypes.Count -eq 3 })
    $testResult = $fullProtectionRules.Count -gt 0 -and @(
        $fullProtectionRules | Where-Object { @($_.Rule.NotifyUser).Count -eq 0 }
    ).Count -eq 0

    $result = "| Policy | Rule | Users notified | Result |`n"
    $result += "| --- | --- | --- | --- |`n"
    foreach ($entry in $fullProtectionRules | Sort-Object -Property { $_.Policy.Identity }, { $_.Rule.Name }) {
        $users = @($entry.Rule.NotifyUser)
        $status = if ($users.Count -gt 0) { '✅ Pass' } else { '❌ Fail' }
        $userText = if ($users.Count -gt 0) { $users -join ', ' } else { 'None' }
        $result += "| $($entry.Policy.Identity) | $($entry.Rule.Name) | $userText | $status |`n"
    }

    if ($fullProtectionRules.Count -eq 0) {
        $message = "No non-disabled DLP rule in an enabled policy protects all three required sensitive information types.`n`n%TestResult%"
    } elseif ($testResult) {
        $message = "Well done. Every non-disabled full-protection DLP rule in an enabled policy notifies at least one user.`n`n%TestResult%"
    } else {
        $message = "Enable user notifications for every non-disabled DLP rule in an enabled policy that protects all three required sensitive information types.`n`n%TestResult%"
    }

    Add-MtTestResultDetail -Result ($message -replace '%TestResult%', $result)
    return [bool]$testResult
}
