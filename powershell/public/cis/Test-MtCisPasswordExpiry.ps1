<#
.SYNOPSIS
    Checks if passwords are set to expire

.DESCRIPTION
    Passwords should not be set to expire
    CIS Microsoft 365 Foundations Benchmark v5.0.0

.EXAMPLE
    Test-MtCisPasswordExpiry

    Returns true if no passwords are set to expire

.LINK
    https://maester.dev/docs/commands/Test-MtCisPasswordExpiry
#>
function Test-MtCisPasswordExpiry {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        Write-Verbose 'Get domain details the password expiry period'
        $domains = Invoke-MtGraphRequest -RelativeUri 'domains'

        Write-Verbose 'Get domains where passwords are set to expire'
        $result = $domains | Where-Object { ($_.PasswordValidityPeriodInDays -ne '2147483647') -and ($_.authenticationType -eq "Managed") }

        $testResult = ($result | Measure-Object).Count -eq 0

        if ($testResult) {
            $testResultMarkdown = "Well done. Your tenant passwords are not set to expire on all your 'managed' domains:`n`n%TestResult%"
        } else {
            $testResultMarkdown = "Your tenant has 1 or more 'managed' domains which expire passwords:`n`n%TestResult%"
        }

        $resultMd = "| Display Name | Domain |`n"
        $resultMd += "| --- | --- |`n"
        foreach ($item in $domains) {
            $itemResult = '❌ Fail'
            if ($item.id -notin $result.id) {
                $itemResult = '✅ Pass'
            }
            $resultMd += "| $($item.Id) | $($itemResult) |`n"
        }

        $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
