function Test-MtCisSafeAttachmentsAtpPolicy {
    <#
    .SYNOPSIS
    Checks if Safe Attachments for SharePoint, OneDrive, and Microsoft Teams are enabled

    .DESCRIPTION
    Safe Attachments for SharePoint, OneDrive, and Microsoft Teams should be enabled
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.1.5, L2)

    The control also requires Safe Documents, which needs the SAFEDOCS service plan (Microsoft 365 A5, E5 or G5,
    or Microsoft Defender Suite) and is not part of Defender for Office 365 Plan 1 or Plan 2. When Maester can read
    the tenant's licences, it skips the check on a tenant without that plan; when it cannot, the check runs.
    ORCA.158 checks the SharePoint, OneDrive and Teams setting on any Defender for Office 365 tenant.

    .EXAMPLE
    Test-MtCisSafeAttachmentsAtpPolicy

    Enabled for SharePoint, OneDrive, and Microsoft Teams

    .LINK
    https://maester.dev/docs/commands/Test-MtCisSafeAttachmentsAtpPolicy
    #>
    [MaesterTest(
        Id = 'CIS.M365.2.1.5',
        Title = 'Ensure Safe Attachments for SharePoint, OneDrive, and Microsoft Teams is Enabled',
        Product = 'defender',
        RelatedProduct = ('sharepoint', 'teams'),
        Feature = 'safe-attachments',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1080', 'T1204.002'),
        Control = ('cis-m365:2.1.5', 'nist-800-53-r5:SI-3'),
        Service = ('ExchangeOnline', 'Graph'),
        License = 'SAFEDOCS',
        Author = 'NZLostboy'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting 365 Atp Policy...'
    $policies = @(Get-MtExo -Request AtpPolicyForO365)
    if ($policies.Count -ne 1) {
        Add-MtTestResultDetail -Result "Expected one ATP policy for Office 365, found $($policies.Count)."
        return $false
    }
    $policy = $policies[0]

    $atpPolicyCheckList = @()

    #EnableATPForSPOTeamsODB should be True
    $atpPolicyCheckList += [pscustomobject] @{
        'CheckName' = 'EnableATPForSPOTeamsODB'
        'Value'     = 'True'
    }

    #EnableSafeDocs should be True
    $atpPolicyCheckList += [pscustomobject] @{
        'CheckName' = 'EnableSafeDocs'
        'Value'     = 'True'
    }

    #AllowSafeDocsOpen should be False
    $atpPolicyCheckList += [pscustomobject] @{
        'CheckName' = 'AllowSafeDocsOpen'
        'Value'     = 'False'
    }

    Write-Verbose 'Executing checks'
    $failedCheckList = @()
    foreach ($check in $atpPolicyCheckList) {
        $checkResult = $policy | Where-Object { $_.($check.CheckName) -notmatch $check.Value }
        if ($checkResult) {
            #If the check fails, add it to the list so we can report on it later
            $failedCheckList += $check.CheckName
        }
    }

    $testResult = ($failedCheckList | Measure-Object).Count -eq 0

    $portalLink = 'https://security.microsoft.com/safeattachmentv2'

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has Safe Attachments for SharePoint, OneDrive, and Microsoft Teams enabled ($portalLink).`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have Safe Attachments for SharePoint, OneDrive, and Microsoft Teams enabled ($portalLink).`n`n%TestResult%"
    }

    $resultMd = "| Check Name | Result |`n"
    $resultMd += "| --- | --- |`n"
    foreach ($item in $atpPolicyCheckList) {
        $itemResult = '❌ Fail'
        if ($item.CheckName -notin $failedCheckList) {
            $itemResult = '✅ Pass'
        }
        $resultMd += "| $($item.CheckName) | $($itemResult) |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
