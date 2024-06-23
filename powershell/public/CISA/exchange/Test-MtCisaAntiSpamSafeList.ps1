<#
.SYNOPSIS
    Checks state of anti-spam policies

.DESCRIPTION

    Safe lists SHOULD NOT be enabled.

.EXAMPLE
    Test-MtCisaAntiSpamSafeList

    Returns true if Safe List is disabled in anti-spam policy
#>

Function Test-MtCisaAntiSpamSafeList {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policy = Get-HostedConnectionFilterPolicy

    $resultPolicy = $policy | Where-Object {`
        -not $_.EnableSafeList
    }

    $testResult = ($resultPolicy|Measure-Object).Count -eq 1

    $portalLink = "https://security.microsoft.com/antispam"

    if ($testResult) {
        $testResultMarkdown = "Well done. [Safe List]($portalLink) is disabled in your tenant."
    } else {
        $testResultMarkdown = "[Safe List]($portalLink) is enabled in your tenant."
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}