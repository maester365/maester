<#
.SYNOPSIS
    Checks if the common attachment types filter is comprehensive

.DESCRIPTION
    The common attachment types filter should be comprehensive
    CIS Microsoft 365 Foundations Benchmark v5.0.0

.EXAMPLE
    Test-MtCisAttachmentFilterComprehensive

    Returns true if the attachment types match the comprehensive list supplied by CIS

.LINK
    https://maester.dev/docs/commands/Test-MtCisAttachmentFilterComprehensive
#>
function Test-MtCisAttachmentFilterComprehensive {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }

    Write-Verbose 'Executing checks'

    try {
        # Set CIS supplied comprehensive extension list
        $L2Extensions = @(
            '7z', 'a3x', 'ace', 'ade', 'adp', 'ani', 'app', 'appinstaller',
            'applescript', 'application', 'appref-ms', 'appx', 'appxbundle', 'arj',
            'asd', 'asx', 'bas', 'bat', 'bgi', 'bz2', 'cab', 'chm', 'cmd', 'com',
            'cpl', 'crt', 'cs', 'csh', 'daa', 'dbf', 'dcr', 'deb',
            'desktopthemepackfile', 'dex', 'diagcab', 'dif', 'dir', 'dll', 'dmg',
            'doc', 'docm', 'dot', 'dotm', 'elf', 'eml', 'exe', 'fxp', 'gadget', 'gz',
            'hlp', 'hta', 'htc', 'htm', 'htm', 'html', 'html', 'hwpx', 'ics', 'img',
            'inf', 'ins', 'iqy', 'iso', 'isp', 'jar', 'jnlp', 'js', 'jse', 'kext',
            'ksh', 'lha', 'lib', 'library-ms', 'lnk', 'lzh', 'macho', 'mam', 'mda',
            'mdb', 'mde', 'mdt', 'mdw', 'mdz', 'mht', 'mhtml', 'mof', 'msc', 'msi',
            'msix', 'msp', 'msrcincident', 'mst', 'ocx', 'odt', 'ops', 'oxps', 'pcd',
            'pif', 'plg', 'pot', 'potm', 'ppa', 'ppam', 'ppkg', 'pps', 'ppsm', 'ppt',
            'pptm', 'prf', 'prg', 'ps1', 'ps11', 'ps11xml', 'ps1xml', 'ps2',
            'ps2xml', 'psc1', 'psc2', 'pub', 'py', 'pyc', 'pyo', 'pyw', 'pyz',
            'pyzw', 'rar', 'reg', 'rev', 'rtf', 'scf', 'scpt', 'scr', 'sct',
            'searchConnector-ms', 'service', 'settingcontent-ms', 'sh', 'shb', 'shs',
            'shtm', 'shtml', 'sldm', 'slk', 'so', 'spl', 'stm', 'svg', 'swf', 'sys',
            'tar', 'theme', 'themepack', 'timer', 'uif', 'url', 'uue', 'vb', 'vbe',
            'vbs', 'vhd', 'vhdx', 'vxd', 'wbk', 'website', 'wim', 'wiz', 'ws', 'wsc',
            'wsf', 'wsh', 'xla', 'xlam', 'xlc', 'xll', 'xlm', 'xls', 'xlsb', 'xlsm',
            'xlt', 'xltm', 'xlw', 'xml', 'xnk', 'xps', 'xsl', 'xz', 'z'
        )

        # Duplicate the array, so we are left with a list of extensions missing at the end
        $missingExtensionList = $L2Extensions

        Write-Verbose 'Getting Attachment Types Filter...'
        $policies = Get-MtExo -Request MalwareFilterPolicy

        # For each policy, run checks
        foreach ($policyId in $policies.Id) {

            # We grab the policy we are checking
            $policy = $policies | Where-Object { $_.Id -eq $policyId }
            if ($policy.EnableFileFilter -ne 'True') {
                # If the policy isn't enabled, skip
                break
            }

            foreach ($extension in $L2Extensions) {
                $checkResult = $policy | Where-Object { $_.FileTypes -contains $extension }
                if ($checkResult) {
                    #If the check finds extension, remove it from the list as it is covered
                    $missingExtensionList = $missingExtensionList | Where-Object { $_ -ne $extension }
                }
            }

        }

        $testResult = ($missingExtensionList | Measure-Object).Count -eq 0
        if ($testResult) {
            $testResultMarkdown = "Well done. Your tenant covers all CIS recommended file attachment extensions:`n`n%TestResult%"
        } else {
            $testResultMarkdown = "Your tenant does not cover all CIS recommended file attachment extensions:`n`n%TestResult%"
        }

        $resultMd = "| Extension Name | Result |`n"
        $resultMd += "| --- | --- |`n"
        foreach ($item in $missingExtensionList) {
            $itemResult = '❌ Fail'
            $resultMd += "| $($item) | $($itemResult) |`n"
        }

        $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
