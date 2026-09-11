function Test-MtCisAttachmentFilter {
    <#
    .SYNOPSIS
    Checks if the default common attachment types filter is enabled

    .DESCRIPTION
    The common attachment types filter should be enabled and cover the CIS default list of blocked file types.
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.1.2, L1)

    .EXAMPLE
    Test-MtCisAttachmentFilter

    Returns true if the common attachment types filter is enabled.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisAttachmentFilter
    #>
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
        # CIS default list of blocked file types (Default Value section of the recommendation)
        $defaultExtensions = @(
            'ani', 'apk', 'app', 'appx', 'arj', 'bat', 'cab', 'cmd', 'com',
            'deb', 'dex', 'dll', 'docm', 'elf', 'exe', 'hta', 'img', 'iso',
            'jar', 'jnlp', 'kext', 'lha', 'lib', 'library', 'lnk', 'lzh',
            'macho', 'msc', 'msi', 'msix', 'msp', 'mst', 'pif', 'ppa',
            'ppam', 'reg', 'rev', 'scf', 'scr', 'sct', 'sys', 'uif', 'vb',
            'vbe', 'vbs', 'vxd', 'wsc', 'wsf', 'wsh', 'xll', 'xz', 'z', 'ace'
        )

        Write-Verbose "Getting Malware Filter Policy..."
        $policies = Get-MtExo -Request MalwareFilterPolicy

        # We grab the default policy
        $policy = $policies | Where-Object { $_.IsDefault -eq $true }

        Write-Verbose "Executing checks"
        $fileFilter = $policy | Where-Object {
            $_.EnableFileFilter -match "True"
        }

        $missingExtensions = $defaultExtensions | Where-Object { $_ -notin $policy.FileTypes }

        $testResult = (($fileFilter | Measure-Object).Count -ge 1) -and (($missingExtensions | Measure-Object).Count -eq 0)

        $portalLink = "https://security.microsoft.com/presetSecurityPolicies"

        if ($testResult) {
            $testResultMarkdown = "Well done. Your tenant's default malware filter policy has the common attachment file filter enabled with the default extensions blocked ($portalLink).`n`n%TestResult%"
        }
        else {
            $testResultMarkdown = "Your tenant's default malware filter policy does not have the common attachment file filter fully enabled ($portalLink).`n`n%TestResult%"
        }

        $resultMd = "| Setting | Result |`n"
        $resultMd += "| --- | --- |`n"

        if ($fileFilter) {
            $enableFilterResult = "✅ Pass"
        }
        else {
            $enableFilterResult = "❌ Fail"
        }
        $resultMd += "| EnableFileFilter | $enableFilterResult |`n"

        if (($missingExtensions | Measure-Object).Count -eq 0) {
            $resultMd += "| Default extensions blocked | ✅ Pass |`n"
        }
        else {
            $resultMd += "| Default extensions blocked | ❌ Fail (missing: $($missingExtensions -join ', ')) |`n"
        }

        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $resultMd

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
