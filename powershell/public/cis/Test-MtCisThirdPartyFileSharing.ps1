<#
.SYNOPSIS
    Ensure third-party file sharing cloud services in Teams are disabled

.DESCRIPTION
    Ensure third-party file sharing cloud services in Teams are disabled
    CIS Microsoft 365 Foundations Benchmark v5.0.0

.EXAMPLE
    Test-MtCisThirdPartyFileSharing

    Returns true if all third-party file sharing cloud services in Teams are disabled

.LINK
    https://maester.dev/docs/commands/Test-MtCisThirdPartyFileSharing
#>
function Test-MtCisThirdPartyFileSharing {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not (Test-MtConnection Teams)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedTeams
        return $null
    }

    Write-Verbose 'Test-MtCisThirdPartyFileSharing: Checking if third-party file sharing cloud services in Teams are disabled'

    try {
        $return = $true
        $thirdPartyCloudServices = Get-CsTeamsClientConfiguration | Select-Object AllowDropbox, AllowBox, AllowGoogleDrive, AllowShareFile, AllowEgnyte

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
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
