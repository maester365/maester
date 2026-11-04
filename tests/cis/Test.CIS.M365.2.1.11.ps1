function Test-MtCisAttachmentFilterComprehensive {
    <#
    .SYNOPSIS
    Checks if the common attachment types filter is comprehensive

    .DESCRIPTION
    The common attachment types filter should be comprehensive
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.1.11, L2)

    .EXAMPLE
    Test-MtCisAttachmentFilterComprehensive

    Returns true if the attachment types match the comprehensive list supplied by CIS

    .LINK
    https://maester.dev/docs/commands/Test-MtCisAttachmentFilterComprehensive
    #>
    [MaesterTest(
        Id = 'CIS.M365.2.1.11',
        Title = 'Ensure comprehensive attachment filtering is applied',
        Product = 'defender',
        RelatedProduct = 'exchange',
        Feature = 'anti-malware',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1566.001', 'T1204.002'),
        Control = ('cis-m365:2.1.11', 'nist-800-53-r5:SI-3'),
        Service = 'ExchangeOnline',
        Author = 'NZLostboy',
        Contributor = 'Mynster9361'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Executing checks'

    # Set CIS supplied comprehensive extension list
    $L2Extensions = @(
        '7z', 'a3x', 'ace', 'ade', 'adp', 'ani', 'apk', 'app', 'appinstaller',
        'applescript', 'application', 'appref-ms', 'appx', 'appxbundle', 'arj',
        'asd', 'asx', 'bas', 'bat', 'bgi', 'bz2', 'cab', 'chm', 'cmd', 'com',
        'cpl', 'crt', 'cs', 'csh', 'daa', 'dbf', 'dcr', 'deb',
        'desktopthemepackfile', 'dex', 'diagcab', 'dif', 'dir', 'dll', 'dmg',
        'doc', 'docm', 'dot', 'dotm', 'elf', 'eml', 'exe', 'fxp', 'gadget', 'gz',
        'hlp', 'hta', 'htc', 'htm', 'html', 'hwpx', 'ics', 'img',
        'inf', 'ins', 'iqy', 'iso', 'isp', 'jar', 'jnlp', 'js', 'jse', 'kext',
        'ksh', 'lha', 'lib', 'library', 'library-ms', 'lnk', 'lzh', 'macho', 'mam', 'mda',
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

    Write-Verbose 'Getting malware filter policies and rules...'
    $policies = @(Get-MtExo -Request MalwareFilterPolicy)
    $rules = @(Get-MtExo -Request MalwareFilterRule)
    $comprehensivePolicies = @($policies | Where-Object { @($_.FileTypes).Count -gt 120 })
    if ($comprehensivePolicies.Count -eq 0) {
        Add-MtTestResultDetail -Result 'No malware filter policy with more than 120 file types was returned; compliance could not be established.'
        return $false
    }

    $policyReports = foreach ($policy in $comprehensivePolicies) {
        $fileTypes = @($policy.FileTypes)
        $missingExtensions = @($L2Extensions | Where-Object { $_ -notin $fileTypes })
        $coverage = [double]($L2Extensions.Count - $missingExtensions.Count) / $L2Extensions.Count
        $policyIdentifiers = @($policy.Id, $policy.Name, $policy.Identity) |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
        $associatedRules = @(
            $rules | Where-Object {
                -not [string]::IsNullOrWhiteSpace([string]$_.MalwareFilterPolicy) -and
                $_.MalwareFilterPolicy -in $policyIdentifiers
            }
        )
        $ruleReports = foreach ($rule in $associatedRules) {
            [pscustomobject]@{
                Name = $rule.Name
                State = $rule.State
                Pass = $rule.State -eq 'Enabled'
            }
        }

        $enabledRules = @($ruleReports | Where-Object { $_.Pass })
        $policyName = if ($policy.Identity) { $policy.Identity } else { $policy.Name }
        $ruleSummary = if ($ruleReports.Count -eq 0) {
            'No associated rule'
        } else {
            @($ruleReports | ForEach-Object { "$($_.Name): $($_.State)" }) -join '; '
        }
        [pscustomobject]@{
            Policy = $policyName
            ExtensionCount = $fileTypes.Count
            MissingExtensions = $missingExtensions
            Coverage = $coverage
            RuleSummary = $ruleSummary
            Pass = $policy.EnableFileFilter -eq $true -and $coverage -ge 0.9 -and $enabledRules.Count -gt 0
        }
    }

    $testResult = @($policyReports | Where-Object { $_.Pass }).Count -gt 0
    if ($testResult) {
        $testResultMarkdown = "Well done. A comprehensive attachment policy and its enabled rule meet CIS recommendations:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "No comprehensive attachment policy and enabled rule meet CIS recommendations:`n`n%TestResult%"
    }

    $resultMd = "| Policy | Extensions | Coverage | Missing extensions | Associated rule and scope | Result |`n"
    $resultMd += "| --- | ---: | ---: | --- | --- | --- |`n"
    foreach ($report in $policyReports) {
        $missing = if ($report.MissingExtensions.Count -eq 0) { 'None' } else { $report.MissingExtensions -join ', ' }
        $itemResult = if ($report.Pass) { '✅ Pass' } else { '❌ Fail' }
        $coverageText = '{0:P1}' -f $report.Coverage
        $resultMd += "| $($report.Policy) | $($report.ExtensionCount) | $coverageText | $missing | $($report.RuleSummary) | $itemResult |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
