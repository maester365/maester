<#
.SYNOPSIS
    Ensure third-party file sharing cloud services in Teams are disabled

.DESCRIPTION
    Ensure third-party file sharing cloud services in Teams are disabled

.EXAMPLE
    Test-MtCisThirdPartyFileSharing

    Returns true if all third-party file sharing cloud services in Teams are disabled

.LINK
    https://maester.dev/docs/commands/
#>
function Test-MtCisThirdPartyFileSharing {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    if (-not (Test-MtConnection Teams)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedTeams
        return $null
    }

    $return = $true
    try {
        $thirdPartyCloudServices = Get-CsTeamsClientConfiguration | Select-Object AllowDropbox, AllowBox, AllowGoogleDrive, AllowShareFile, AllowEgnyte
        
        $passResult = "✅ Pass"
        $failResult = "❌ Fail"

        $result = "| Policy | Value | Status |`n"
        $result += "| --- | --- | --- |`n"
    
        ForEach ($thirdPartyProvider in ($thirdPartyCloudServices.PSObject.Properties)) {
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
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
        Add-MtTestResultDetail -Result $testResultMarkdown
    } catch {
        $return = $false
        Write-Error $_.Exception.Message
    }
    return $return
}