<#
.SYNOPSIS
    Checks state of anti-spam policies

.DESCRIPTION

    IP allow lists SHOULD NOT be created.

.EXAMPLE
    Test-MtCisaAntiSpamAllowList

    Returns true if no allowed IPs in anti-spam policy
#>

Function Test-MtCisaAntiSpamAllowList {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policy = Get-HostedConnectionFilterPolicy

    $resultPolicy = $policy | Where-Object {`
        ($_.IPAllowList|Measure-Object).Count -eq 0
    }

    $testResult = ($resultPolicy|Measure-Object).Count -eq 1

    $portalLink = "https://security.microsoft.com/antispam?tid=344f7861-e82f-495d-8bf3-3898ef4b2ae2"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant does not allow IPs for bypass.`n`n%TestResult%"
        $result = "[✅ Pass]($portalLink)"
    } else {
        $testResultMarkdown = "Your tenant does allow IPs for bypass.`n`n%TestResult%"
        $result = "[❌ Fail]($portalLink)`n`n"
        $policy.IPAllowList | ForEach-Object {`
            $result += "* $_`n"
        }
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}