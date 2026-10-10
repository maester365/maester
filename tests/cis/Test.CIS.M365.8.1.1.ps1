function Test-MtCisThirdPartyFileSharing {
    <#
    .SYNOPSIS
    Ensure third-party file sharing cloud services in Teams are disabled

    .DESCRIPTION
    Ensure third-party file sharing cloud services in Teams are disabled
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (8.1.1)

    .EXAMPLE
    Test-MtCisThirdPartyFileSharing

    Returns true if all third-party file sharing cloud services in Teams are disabled

    .LINK
    https://maester.dev/docs/commands/Test-MtCisThirdPartyFileSharing
    #>
    [MaesterTest(
        Id = 'CIS.M365.8.1.1',
        Title = 'Ensure external file sharing in Teams is enabled for only approved cloud storage services',
        Severity = 'Medium',
        Category = 'CIS',
        Product = 'Teams',
        Tag = ('CIS E3 Level 2', 'CIS M365 v7.0.0'),
        Service = 'Teams',
        Author = 'HenrikPiecha',
        Contributor = ('merill', 'Mynster9361')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Test-MtCisThirdPartyFileSharing: Checking if third-party file sharing cloud services in Teams are disabled'

    $return = $true
    $thirdPartyCloudServices = Get-CsTeamsClientConfiguration -Identity Global | Select-Object AllowDropbox, AllowBox, AllowGoogleDrive, AllowShareFile, AllowEgnyte

    $passResult = '✅ Pass'
    $failResult = '❌ Fail'

    $result = "| Policy | Value | Status |`n"
    $result += "| --- | --- | --- |`n"

    foreach ($thirdPartyProvider in ($thirdPartyCloudServices.PSObject.Properties)) {
        if ($thirdPartyProvider.Value -eq $false) {
            $result += "| $($thirdPartyProvider.Name) | $($thirdPartyProvider.Value) | $passResult |`n"
        } else {
            $result += "| $($thirdPartyProvider.Name) | $($thirdPartyProvider.Value) | $failResult |`n"
            $return = $false
        }
    }

    if ($return) {
        $testResultMarkdown = "Well done. All third-party cloud services are disabled.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "All or specific third-party cloud services are enabled.`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $return
}
