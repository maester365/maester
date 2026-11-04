function Test-MtCisSafeLink {
    <#
    .SYNOPSIS
    Checks if safe links for office applications are Enabled

    .DESCRIPTION
    Safe links should be enabled for office applications (Exchange Teams Office 365 Apps)
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.1.1, L2)

    .EXAMPLE
    Test-MtCisSafeLink

    Returns true safe links are enabled

    .LINK
    https://maester.dev/docs/commands/Test-MtCisSafeLink
    #>
    [MaesterTest(
        Id = 'CIS.M365.2.1.1',
        Title = 'Ensure Safe Links for Office Applications is Enabled (Only Checks Priority 0 Policy)',
        Product = 'defender',
        RelatedProduct = 'exchange',
        Feature = 'safe-links',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1566.002', 'T1204.001'),
        Control = ('cis-m365:2.1.1', 'nist-800-53-r5:SI-3'),
        Service = ('ExchangeOnline', 'Graph', 'SecurityCompliance'),
        License = 'ATP_ENTERPRISE',
        Author = 'NZLostboy',
        Contributor = 'Mynster9361'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting Safe Links Policy...'

    $priority0Rules = @(Get-MtExo -Request SafeLinksRule | Where-Object { $_.Priority -eq '0' })
    if ($priority0Rules.Count -ne 1) {
        Add-MtTestResultDetail -Result "Expected one Safe Links rule with priority 0, found $($priority0Rules.Count)."
        return $false
    }

    $priority0Rule = $priority0Rules[0]
    $policies = @(Get-MtExo -Request SafeLinksPolicy | Where-Object { $_.Name -eq $priority0Rule.SafeLinksPolicy })
    if ($policies.Count -ne 1) {
        Add-MtTestResultDetail -Result "The policy associated with priority 0 Safe Links rule '$($priority0Rule.Name)' was not found."
        return $false
    }

    $policy = $policies[0]
    $ruleEnabled = $priority0Rule.State -eq 'Enabled'

    $safeLinkCheckList = @()

    #EnableSafeLinksForEmail
    $safeLinkCheckList += [pscustomobject] @{
        'CheckName' = 'EnableSafeLinksForEmail'
        'Value'     = 'True'
    }

    #EnableSafeLinksForTeams
    $safeLinkCheckList += [pscustomobject] @{
        'CheckName' = 'EnableSafeLinksForTeams'
        'Value'     = 'True'
    }

    #EnableSafeLinksForOffice
    $safeLinkCheckList += [pscustomobject] @{
        'CheckName' = 'EnableSafeLinksForOffice'
        'Value'     = 'True'
    }

    #TrackClicks
    $safeLinkCheckList += [pscustomobject] @{
        'CheckName' = 'TrackClicks'
        'Value'     = 'True'
    }

    #AllowClickThrough
    $safeLinkCheckList += [pscustomobject] @{
        'CheckName' = 'AllowClickThrough'
        'Value'     = 'False'
    }

    #ScanUrls
    $safeLinkCheckList += [pscustomobject] @{
        'CheckName' = 'ScanUrls'
        'Value'     = 'True'
    }

    #EnableForInternalSenders
    $safeLinkCheckList += [pscustomobject] @{
        'CheckName' = 'EnableForInternalSenders'
        'Value'     = 'True'
    }

    #DeliverMessageAfterScan
    $safeLinkCheckList += [pscustomobject] @{
        'CheckName' = 'DeliverMessageAfterScan'
        'Value'     = 'True'
    }

    #DisableUrlRewrite
    $safeLinkCheckList += [pscustomobject] @{
        'CheckName' = 'DisableUrlRewrite'
        'Value'     = 'False'
    }

    Write-Verbose 'Executing checks'
    $failedCheckList = @()
    foreach ($check in $safeLinkCheckList) {
        $checkResult = $policy | Where-Object { $_.($check.CheckName) -notmatch $check.Value }
        if ($checkResult) {
            #If the check fails, add it to the list so we can report on it later
            $failedCheckList += $check.CheckName
        }
    }

    $testResult = ($failedCheckList | Measure-Object).Count -eq 0 -and $ruleEnabled

    $portalLink = 'https://security.microsoft.com/presetSecurityPolicies'

    if ($testResult) {
        $testResultMarkdown = 'Well done. Safe Links policy ' + $policy.Name + " and its enabled priority 0 rule match CIS recommendations ($portalLink).`n`n%TestResult%"
    } else {
        $testResultMarkdown = 'Safe Links policy ' + $policy.Name + " or its priority 0 rule does not match CIS recommendations ($portalLink).`n`n%TestResult%"
    }

    $resultMd = "| Check Name | Current Value | Result |`n"
    $resultMd += "| --- | --- | --- |`n"
    foreach ($item in $safeLinkCheckList) {
        $itemResult = '❌ Fail'
        if ($item.CheckName -notin $failedCheckList) {
            $itemResult = '✅ Pass'
        }
        $resultMd += "| $($item.CheckName) | $($policy.($item.CheckName)) | $($itemResult) |`n"
    }
    $ruleStateResult = if ($ruleEnabled) { '✅ Pass' } else { '❌ Fail' }
    $resultMd += "| Priority 0 rule state | $($priority0Rule.State) | $ruleStateResult |`n"

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
