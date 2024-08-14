<#
.SYNOPSIS
    Checks state of anti-spam policies

.DESCRIPTION
    IP allow lists SHOULD NOT be created.

.EXAMPLE
    Test-MtCisaAntiSpamAllowList

    Returns true if no allowed IPs in anti-spam policy

.LINK
    https://maester.dev/docs/commands/Test-MtCisaAntiSpamAllowList
#>
function Test-MtCisaAntiSpamAllowList {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }

    $policy = Get-MtExo -Request HostedConnectionFilterPolicy

    $resultPolicy = $policy | Where-Object {`
        ($_.IPAllowList | Measure-Object).Count -gt 0
    }

    $testResult = ($resultPolicy | Measure-Object).Count -eq 0

    $portalLink = "https://security.microsoft.com/antispam"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant does not have any [Anti-spam IP allow lists]($portalLink)."
    } else {
        $testResultMarkdown = "Your tenant has [Anti-spam IP allow lists]($portalLink).`n`n%TestResult%"
        $resultPolicy | ForEach-Object {
            $result = "* $($_.Name)`n"
            $_.IPAllowList | ForEach-Object {`
                    $result += "  * $_`n"
            }
        }
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}