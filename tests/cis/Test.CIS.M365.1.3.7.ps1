function Test-MtCisThirdPartyStorageServicesRestricted {
    <#
    .SYNOPSIS
        Checks if users are restricted to store and share files in third-party storage services in Microsoft 365 on the web.

    .DESCRIPTION
        Users should be restricted to store and share files in third-party storage services in Microsoft 365 on the web.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (1.3.7, L2)

    .EXAMPLE
        Test-MtCisThirdPartyStorageServicesRestricted

        Returns true if users are restricted to store and share files in third-party storage services in Microsoft 365 on the web.

    .LINK
        https://maester.dev/docs/commands/Test-MtCisThirdPartyStorageServicesRestricted
    #>
    [MaesterTest(
        Id = 'CIS.M365.1.3.7',
        Title = 'Ensure ''third-party storage services'' are restricted in ''Microsoft 365 on the web''',
        Severity = 'Medium',
        Category = 'CIS',
        Tag = ('CIS E3', 'CIS E3 Level 2', 'CIS E5', 'CIS E5 Level 2', 'CIS M365 v7.0.0', 'L2', 'Security'),
        Service = 'Graph',
        Author = 'oed-metzb',
        Contributor = 'Mynster9361'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting settings...'
    $ServicePrincipal = Invoke-MtGraphRequest -RelativeUri "servicePrincipals" -Filter "appId eq 'c1f33bc0-bdb4-4248-ba9b-096807ddb43e'" -DisableCache

    Write-Verbose 'Executing checks'
    if ($ServicePrincipal) {
        if ($ServicePrincipal.accountEnabled) {
            $testResult = $false
        }
        else {
            $testResult = $true
        }
    }
    else {
        $testResult = $false
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant settings comply with CIS recommendations.`n`n%TestResult%"
    }
    else {
        $testResultMarkdown = "Your tenant settings do not comply with CIS recommendations.`n`n%TestResult%"
    }

    $resultMd = "| Setting | Result |`n"
    $resultMd += "| --- | --- |`n"

    if ($testResult) {
        $ThirdPartyStorageResult = '✅ Pass'
    }
    else {
        $ThirdPartyStorageResult = '❌ Fail'
    }

    $resultMd += "| Let users open files stored in third-party storage services in Microsoft 365 on the web | $ThirdPartyStorageResult |`n"

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
