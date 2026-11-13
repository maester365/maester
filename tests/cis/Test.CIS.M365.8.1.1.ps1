function Test-MtCisThirdPartyFileSharing {
    <#
    .SYNOPSIS
    Ensure external file sharing in Teams is enabled for only approved cloud storage services

    .DESCRIPTION
    Checks that the third-party cloud storage services in the Global Teams client configuration are turned off,
    except those the organization has approved.
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (8.1.1)

    .EXAMPLE
    Test-MtCisThirdPartyFileSharing

    Returns true if every third-party cloud storage service in Teams is turned off

    .EXAMPLE
    Test-MtCisThirdPartyFileSharing -ApprovedProviders Box

    Returns true if every third-party cloud storage service in Teams except Box is turned off

    .LINK
    https://maester.dev/docs/commands/Test-MtCisThirdPartyFileSharing
    #>
    [MaesterTest(
        Id = 'CIS.M365.8.1.1',
        Title = 'Ensure external file sharing in Teams is enabled for only approved cloud storage services',
        Product = 'teams',
        Feature = 'file-sharing',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1567.002',
        Control = ('cis-m365:8.1.1', 'nist-800-53-r5:AC-20', 'nist-800-53-r5:CM-7'),
        Service = 'Teams',
        Author = 'HenrikPiecha',
        Contributor = ('merill', 'Mynster9361')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Cloud storage services the organization has approved for file sharing in Teams, which may stay turned on.
        [ValidateSet('Dropbox', 'Box', 'GoogleDrive', 'ShareFile', 'Egnyte')]
        [string[]] $ApprovedProviders
    )

    Write-Verbose 'Test-MtCisThirdPartyFileSharing: Checking that only approved third-party cloud storage services are turned on in Teams'

    $clientConfig = Get-CsTeamsClientConfiguration -Identity Global
    if ($null -eq $clientConfig) {
        Add-MtTestResultDetail -Result 'The Global Teams client configuration was not returned, so the third-party cloud storage settings could not be confirmed.'
        return $false
    }

    $passResult = '✅ Pass'
    $failResult = '❌ Fail'

    $result = "| Setting | Value | Approved | Status |`n"
    $result += "| --- | --- | --- | --- |`n"

    $return = $true
    foreach ($provider in 'Dropbox', 'Box', 'GoogleDrive', 'ShareFile', 'Egnyte') {
        $setting = "Allow$provider"
        $value = $clientConfig.$setting
        $approved = $provider -in $ApprovedProviders
        if ($value -eq $false -or ($approved -and $value -eq $true)) {
            $result += "| $setting | $value | $(if ($approved) { 'Yes' } else { 'No' }) | $passResult |`n"
        } else {
            $result += "| $setting | $(if ($null -eq $value) { 'Not found' } else { $value }) | $(if ($approved) { 'Yes' } else { 'No' }) | $failResult |`n"
            $return = $false
        }
    }

    if ($return) {
        $testResultMarkdown = "Well done. The five checked third-party storage settings in the Global Teams client configuration are disabled or enabled only for approved providers.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "One or more of the five checked third-party storage settings are missing or enabled without approval. Turn them off, or add approved providers to the ApprovedProviders parameter.`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $return
}
