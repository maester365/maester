function Test-MtCisPasswordExpiry {
    <#
    .SYNOPSIS
    Checks if passwords are set to expire

    .DESCRIPTION
    Passwords should not be set to expire
    CIS Microsoft 365 Foundations Benchmark v6.0.1

    .EXAMPLE
    Test-MtCisPasswordExpiry

    Returns true if no passwords are set to expire

    .LINK
    https://maester.dev/docs/commands/Test-MtCisPasswordExpiry
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        Write-Verbose 'Get domain details for the password expiry period'
        $domains = Invoke-MtGraphRequest -RelativeUri 'domains'

        Write-Verbose 'Get verified and managed domains where passwords are set to expire'

        $noPasswordExpiryPeriodInDays = [int]::MaxValue

        $excludedDomains = @()
        $applicableDomains = @()
        foreach ($domain in $domains) {
            # Password policy checks apply only to managed and verified domains.
            if (($domain.authenticationType -ne "Managed") -or ($domain.isVerified -ne $true)) {
                $excludedDomains += $domain
                continue
            }

            $applicableDomains += $domain
        }

        $result = $applicableDomains | Where-Object {
            $passwordValidityPeriodInDays = 0
            $domainPasswordValidityPeriodInDays = $_.PasswordValidityPeriodInDays
            # If null or a boolean, the password expiry period is not set, and passwords do not expire.
            # Return false to indicate this domain does not fail the test.
            if (($null -eq $domainPasswordValidityPeriodInDays) -or ($domainPasswordValidityPeriodInDays -is [bool])) {
                return $false
            }
            if (-not [int]::TryParse($domainPasswordValidityPeriodInDays.ToString(), [ref]$passwordValidityPeriodInDays)) {
                return $false
            }
            # If valid integer, check if equal to the value that indicates no password expiry (MaxValue).
            return $passwordValidityPeriodInDays -ne $noPasswordExpiryPeriodInDays
        }

        $testResult = ($result | Measure-Object).Count -eq 0

        if ($testResult) {
            $testResultMarkdown = "Well done. Your tenant passwords are not set to expire on all your 'managed' domains:`n`n%TestResult%"
        } else {
            $testResultMarkdown = "Your tenant has 1 or more 'managed' domains which expire passwords:`n`n%TestResult%"
        }

        $resultMd = "| Domain | Result |`n"
        $resultMd += "| --- | --- |`n"
        foreach ($item in $domains) {
            $itemResult = '❌ Fail'
            if ($item.id -in $excludedDomains.id) {
                $itemResult = '⏭️ Skip'
            } elseif ($item.id -notin $result.id) {
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
