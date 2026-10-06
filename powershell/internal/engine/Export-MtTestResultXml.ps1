function Export-MtTestResultXml {
    <#
    .SYNOPSIS
    Writes the results of a run as an NUnit 2.5 or JUnit 4 XML file (design section 8, appendix A.2).

    .DESCRIPTION
    One file covers native and Pester rows. The test-case name is <Block>.<Name>, as Pester writes it, so
    CI test history stays continuous. Outcomes keep CI pipelines failing on what they fail on today:
    Passed is success, Failed is failure, an Error the engine raised without running the test is a
    failure, an Error from the test is ignored (failure with ErrorsAsFailures), Skipped is ignored,
    Investigate follows the returned value, and NotRun rows are omitted.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $MaesterResults,
        [Parameter(Mandatory)] [string] $Path,
        [Parameter()] [ValidateSet('NUnitXml', 'NUnit2.5', 'JUnitXml')] [string] $Format = 'NUnitXml',
        [Parameter()] [switch] $ErrorsAsFailures
    )

    $engineErrorCodes = 'InvalidMetadata', 'InvalidConfiguration', 'InvalidInstanceId', 'DuplicateId', 'LoadFailed',
    'InstanceSourceFailed', 'RequiresNewerMaester', 'ForeignModuleLoaded', 'PesterNotAvailable'

    $cases = foreach ($row in @($MaesterResults.Tests)) {
        if ($row.Result -eq 'NotRun') { continue }
        $outcome = switch ($row.Result) {
            'Passed' { 'Success' }
            'Failed' { 'Failure' }
            'Error' { if ($row.ReasonCode -in $engineErrorCodes -or $ErrorsAsFailures) { 'Failure' } else { 'Ignored' } }
            'Investigate' {
                $returned = if ($__MtSession.NativeReturnValue -and $row.Id -and $__MtSession.NativeReturnValue.ContainsKey($row.Id)) { $__MtSession.NativeReturnValue[$row.Id] } else { $null }
                switch ($returned) { 'True' { 'Success' } 'False' { 'Failure' } default { 'Ignored' } }
            }
            default { 'Ignored' }
        }
        $message = if ($row.ReasonDetail) { [string]$row.ReasonDetail }
        elseif ($row.ResultDetail -and $row.ResultDetail.SkippedReason) { [string]$row.ResultDetail.SkippedReason }
        elseif ($row.Result -eq 'Failed') { 'The test failed.' } else { $null }
        $seconds = 0.0
        try { $seconds = [timespan]::Parse([string]$row.Duration, [System.Globalization.CultureInfo]::InvariantCulture).TotalSeconds } catch { $seconds = 0.0 }
        [pscustomobject]@{
            Block = ConvertTo-MtXmlSafeString $row.Block; Name = ConvertTo-MtXmlSafeString "$($row.Block).$($row.Name)"
            Outcome = $outcome; Message = ConvertTo-MtXmlSafeString $message; Seconds = $seconds; Result = $row.Result
        }
    }
    $cases = @($cases)

    # XmlWriter resolves a relative path against the process folder, not the PowerShell location.
    $Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $settings = [System.Xml.XmlWriterSettings]::new()
    $settings.Indent = $true
    $settings.Encoding = [System.Text.UTF8Encoding]::new($false)
    $directory = Split-Path -Path $Path -Parent
    if ($directory) { $null = New-Item -Path $directory -ItemType Directory -Force }
    $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    try {
        $writer.WriteStartDocument()
        $total = $cases.Count
        $failures = @($cases | Where-Object Outcome -EQ 'Failure').Count
        $ignored = @($cases | Where-Object Outcome -EQ 'Ignored').Count
        $time = ($cases | Measure-Object -Property Seconds -Sum).Sum
        if ($null -eq $time) { $time = 0 }
        $groups = @($cases | Group-Object Block)

        if ($Format -eq 'JUnitXml') {
            $writer.WriteStartElement('testsuites')
            $writer.WriteAttributeString('name', 'Maester')
            $writer.WriteAttributeString('tests', [string]$total)
            $writer.WriteAttributeString('failures', [string]$failures)
            $writer.WriteAttributeString('skipped', [string]$ignored)
            $writer.WriteAttributeString('time', $time.ToString('0.000', $culture))
            foreach ($group in $groups) {
                $writer.WriteStartElement('testsuite')
                $writer.WriteAttributeString('name', $group.Name)
                $writer.WriteAttributeString('tests', [string]$group.Count)
                $writer.WriteAttributeString('failures', [string]@($group.Group | Where-Object Outcome -EQ 'Failure').Count)
                $writer.WriteAttributeString('skipped', [string]@($group.Group | Where-Object Outcome -EQ 'Ignored').Count)
                foreach ($case in $group.Group) {
                    $writer.WriteStartElement('testcase')
                    $writer.WriteAttributeString('name', $case.Name)
                    $writer.WriteAttributeString('classname', $case.Block)
                    $writer.WriteAttributeString('time', $case.Seconds.ToString('0.000', $culture))
                    if ($case.Outcome -eq 'Failure') {
                        $writer.WriteStartElement('failure')
                        $writer.WriteAttributeString('message', [string]$case.Message)
                        $writer.WriteEndElement()
                    } elseif ($case.Outcome -eq 'Ignored') {
                        $writer.WriteStartElement('skipped')
                        if ($case.Message) { $writer.WriteAttributeString('message', [string]$case.Message) }
                        $writer.WriteEndElement()
                    }
                    $writer.WriteEndElement()
                }
                $writer.WriteEndElement()
            }
            $writer.WriteEndElement()
        } else {
            $executedAt = try { [datetime]$MaesterResults.ExecutedAt } catch { Get-Date }
            $writer.WriteStartElement('test-results')
            $writer.WriteAttributeString('xmlns', 'xsi', $null, 'http://www.w3.org/2001/XMLSchema-instance')
            $writer.WriteAttributeString('xsi', 'noNamespaceSchemaLocation', 'http://www.w3.org/2001/XMLSchema-instance', 'nunit_schema_2.5.xsd')
            $writer.WriteAttributeString('name', 'Maester')
            $writer.WriteAttributeString('total', [string]$total)
            $writer.WriteAttributeString('errors', '0')
            $writer.WriteAttributeString('failures', [string]$failures)
            $writer.WriteAttributeString('not-run', '0')
            $writer.WriteAttributeString('inconclusive', '0')
            $writer.WriteAttributeString('ignored', [string]$ignored)
            $writer.WriteAttributeString('skipped', '0')
            $writer.WriteAttributeString('invalid', '0')
            $writer.WriteAttributeString('date', $executedAt.ToString('yyyy-MM-dd', $culture))
            $writer.WriteAttributeString('time', $executedAt.ToString('HH:mm:ss', $culture))
            $writer.WriteStartElement('environment')
            $writer.WriteAttributeString('platform', [string]$MaesterResults.PowerShellInfo.Platform)
            $writer.WriteAttributeString('nunit-version', '2.5.8.0')
            $writer.WriteAttributeString('os-version', [string]$MaesterResults.SystemInfo.OSDescription)
            $writer.WriteAttributeString('machine-name', [string]$MaesterResults.SystemInfo.MachineName)
            $writer.WriteAttributeString('user', [string]$MaesterResults.SystemInfo.UserName)
            $writer.WriteAttributeString('user-domain', [string]$MaesterResults.SystemInfo.UserDomain)
            $writer.WriteAttributeString('cwd', (Get-Location).Path)
            $writer.WriteAttributeString('clr-version', [System.Environment]::Version.ToString())
            $writer.WriteEndElement()
            $writer.WriteStartElement('culture-info')
            $writer.WriteAttributeString('current-culture', [System.Globalization.CultureInfo]::CurrentCulture.Name)
            $writer.WriteAttributeString('current-uiculture', [System.Globalization.CultureInfo]::CurrentUICulture.Name)
            $writer.WriteEndElement()

            $writer.WriteStartElement('test-suite')
            $writer.WriteAttributeString('type', 'TestFixture')
            $writer.WriteAttributeString('name', 'Maester')
            $writer.WriteAttributeString('executed', 'True')
            $writer.WriteAttributeString('result', $(if ($failures -gt 0) { 'Failure' } else { 'Success' }))
            $writer.WriteAttributeString('success', $(if ($failures -gt 0) { 'False' } else { 'True' }))
            $writer.WriteAttributeString('time', $time.ToString('0.000', $culture))
            $writer.WriteAttributeString('asserts', '0')
            $writer.WriteStartElement('results')
            foreach ($group in $groups) {
                $groupFailed = [bool]($group.Group | Where-Object Outcome -EQ 'Failure')
                $writer.WriteStartElement('test-suite')
                $writer.WriteAttributeString('type', 'TestFixture')
                $writer.WriteAttributeString('name', $group.Name)
                $writer.WriteAttributeString('executed', 'True')
                $writer.WriteAttributeString('result', $(if ($groupFailed) { 'Failure' } else { 'Success' }))
                $writer.WriteAttributeString('success', $(if ($groupFailed) { 'False' } else { 'True' }))
                $writer.WriteAttributeString('time', (($group.Group | Measure-Object Seconds -Sum).Sum).ToString('0.000', $culture))
                $writer.WriteAttributeString('asserts', '0')
                $writer.WriteStartElement('results')
                foreach ($case in $group.Group) {
                    $writer.WriteStartElement('test-case')
                    $writer.WriteAttributeString('name', $case.Name)
                    $writer.WriteAttributeString('description', $case.Name)
                    $writer.WriteAttributeString('time', $case.Seconds.ToString('0.000', $culture))
                    $writer.WriteAttributeString('asserts', '0')
                    switch ($case.Outcome) {
                        'Success' {
                            $writer.WriteAttributeString('success', 'True'); $writer.WriteAttributeString('result', 'Success'); $writer.WriteAttributeString('executed', 'True')
                        }
                        'Failure' {
                            $writer.WriteAttributeString('success', 'False'); $writer.WriteAttributeString('result', 'Failure'); $writer.WriteAttributeString('executed', 'True')
                            $writer.WriteStartElement('failure'); $writer.WriteElementString('message', [string]$case.Message); $writer.WriteEndElement()
                        }
                        default {
                            $writer.WriteAttributeString('result', 'Ignored'); $writer.WriteAttributeString('executed', 'False')
                            $writer.WriteStartElement('reason'); $writer.WriteElementString('message', [string]$case.Message); $writer.WriteEndElement()
                        }
                    }
                    $writer.WriteEndElement()
                }
                $writer.WriteEndElement()
                $writer.WriteEndElement()
            }
            $writer.WriteEndElement()
            $writer.WriteEndElement()
            $writer.WriteEndElement()
        }
        $writer.WriteEndDocument()
    } finally {
        $writer.Dispose()
    }
}

function ConvertTo-MtXmlSafeString {
    <#
    .SYNOPSIS
    Removes characters XML 1.0 cannot hold (control characters, lone surrogates) from text written to the XML file.

    .DESCRIPTION
    Test names and messages can carry tenant data or error text. XmlWriter throws on a character such as
    U+0001, which would stop every report of the run from being written.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0)] [AllowNull()] [object] $Value
    )
    if ($null -eq $Value) { return '' }
    $text = [string]$Value
    $builder = [System.Text.StringBuilder]::new($text.Length)
    for ($i = 0; $i -lt $text.Length; $i++) {
        $c = $text[$i]
        if ([char]::IsHighSurrogate($c) -and $i + 1 -lt $text.Length -and [char]::IsLowSurrogate($text[$i + 1])) {
            $null = $builder.Append($c).Append($text[$i + 1]); $i++; continue
        }
        if ([System.Xml.XmlConvert]::IsXmlChar($c)) { $null = $builder.Append($c) }
    }
    $builder.ToString()
}
