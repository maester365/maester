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

    $portalLink = "https://security.microsoft.com/antispam?tid=344f7861-e82f-495d-8bf3-3898ef4b2ae2"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant does not allow Safe List.`n`n%TestResult%"
        $result = "[✅ Pass]($portalLink)"
    } else {
        $testResultMarkdown = "Your tenant does allow Safe List.`n`n%TestResult%"
        $result = "[❌ Fail]($portalLink)"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}