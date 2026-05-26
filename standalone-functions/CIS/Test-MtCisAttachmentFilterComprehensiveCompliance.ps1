function Test-MtCisAttachmentFilterComprehensiveCompliance {
    <#
    .SYNOPSIS
    Checks if the common attachment types filter is comprehensive

    .DESCRIPTION
    The common attachment types filter should be comprehensive
    CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisAttachmentFilterComprehensiveCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    try {
        $exoSession = Get-PSSession | Where-Object { $_.ConfigurationName -eq 'Microsoft.Exchange' -and $_.State -eq 'Opened' }
        if ($null -eq $exoSession) {
            Write-Verbose "Not connected to Exchange Online"
            return $null
        }
    } catch {
        Write-Verbose "Exchange Online connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation

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
            'hlp', 'hta', 'htc', 'htm', 'html', 'hwpx', 'ics', 'img',
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
            'xlt', 'xltm', 'xlw', 'xnk', 'xps', 'xsl', 'xz', 'z'
        )

        # Duplicate the array, so we are left with a list of extensions missing at the end
        $missingExtensionList = $L2Extensions

        Write-Verbose 'Getting Attachment Types Filter...'
        $policies = Get-MalwareFilterPolicy

        # For each policy, run checks
        foreach ($policyId in $policies.Id) {

            # We grab the policy we are checking
            $policy = $policies | Where-Object { $_.Id -eq $policyId }
            if ($policy.EnableFileFilter -ne 'True') {
                # If the policy isn't enabled, skip
                continue
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
        return $testResult
    } catch {
        return $null
    }

}
