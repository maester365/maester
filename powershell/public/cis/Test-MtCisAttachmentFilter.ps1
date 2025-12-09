<#
.SYNOPSIS
    Checks if the default common attachment types filter is enabled

.DESCRIPTION
    The common attachment types filter should be enabled
    CIS Microsoft 365 Foundations Benchmark v5.0.0

.EXAMPLE
    Test-MtCisAttachmentFilter

    Returns true if the common attachment types filter is enabled.

.LINK
    https://maester.dev/docs/commands/Test-MtCisAttachmentFilter
#>
function Test-MtCisAttachmentFilter {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }
    elseif (!(Test-MtConnection SecurityCompliance)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return $null
    }

    try {
        Write-Verbose "Getting Malware Filter Policy..."
        $policies = Get-MtExo -Request MalwareFilterPolicy

        # We grab the default policy
        $policy = $policies | Where-Object { $_.IsDefault -eq $true }

        Write-Verbose "Executing checks"
        $fileFilter = $policy | Where-Object {
            $_.EnableFileFilter -match "True"
        }

        $testResult = ($fileFilter | Measure-Object).Count -ge 1

        $portalLink = "https://security.microsoft.com/presetSecurityPolicies"

        if ($testResult) {
            $testResultMarkdown = "Well done. Your tenants default malware filter policy has the common attachment file filter enabled ($portalLink).`n`n%TestResult%"
        }
        else {
            $testResultMarkdown = "Your tenants default malware filter policy does not have the common attachment file filter enabled ($portalLink).`n`n%TestResult%"
        }

        $resultMd = "| Policy | Result |`n"
        $resultMd += "| --- | --- |`n"

        if ($testResult) {
            $Result = "✅ Pass"
        }
        else {
            $Result = "❌ Fail"
        }

        $resultMd += "| EnableFileFilter | $Result |`n"

        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $resultMd

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
