function Test-MtCisUsersCannotCreateM365Groups {
    <#
    .SYNOPSIS
        Checks that users cannot create Microsoft 365 groups.

    .DESCRIPTION
        Checks the Group.Unified directory setting and passes when it exists and group creation by users is turned off, so that Microsoft 365 groups, and the Teams and SharePoint sites behind them, are created in a controlled way.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.1.3.4, L2)

    .EXAMPLE
        Test-MtCisUsersCannotCreateM365Groups

        Returns true if users cannot create Microsoft 365 groups.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.1.3.4
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.1.3.4',
        Title = 'Ensure that ''Users can create Microsoft 365 groups in Azure portals, API or PowerShell'' is set to ''No''',
        Product = 'entra',
        RelatedProduct = 'teams',
        Feature = 'groups',
        Area = 'access-control',
        ResourceType = 'Tenant',
        Severity = 'Low',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = 'None',
        Control = ('cis-m365:5.1.3.4', 'nist-800-53-r5:AC-6'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting the group settings...'
    $groupSettings = Invoke-MtGraphRequest -RelativeUri 'groupSettings'
    $unified = @($groupSettings) | Where-Object { $_.templateId -eq '62375ab9-6b52-47ed-826b-58e47e0e304b' } | Select-Object -First 1
    $creation = @($unified.values) | Where-Object { $_.name -eq 'EnableGroupCreation' } | Select-Object -First 1
    $value = "$($creation.value)"
    $testResult = $null -ne $unified -and $value -eq 'False'

    $passText = 'Users cannot create Microsoft 365 groups.'
    $failText = if ($null -eq $unified) { 'The Group.Unified setting does not exist, so users can create Microsoft 365 groups.' } else { 'Users can create Microsoft 365 groups.' }

    $checks = @([pscustomobject]@{ Setting = 'EnableGroupCreation'; Value = $(if ($value) { $value } else { 'Not found' }); Pass = $testResult })
    $resultMd = "| Setting | Value | Result |`n"
    $resultMd += "| --- | --- | --- |`n"
    foreach ($check in $checks) {
        $resultMd += "| $($check.Setting) | $($check.Value) | $(if ($check.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
