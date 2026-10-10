<#
.SYNOPSIS
    Generates the ORCA classes and the ORCA native tests from the upstream ORCA module.

.DESCRIPTION
    Without -Offline, clones or updates https://github.com/cammurray/orca in build/orca/orca and
    regenerates powershell/internal/generated/orca (the ORCA classes, the prerequisite functions and one
    check-ORCA*.ps1 per upstream check), then the native tests.

    With -Offline, only the native tests are regenerated, from the committed
    powershell/internal/generated/orca/check-ORCA*.ps1 files. The drift test in
    powershell/tests/general/OrcaGenerator.Tests.ps1 uses this to prove that the committed tests are
    what the generator produces.

    Each upstream check becomes a Maester 3.0 native test (design sections 3 and 14):
    tests/orca/Test.ORCA.<n>.ps1 with one [MaesterTest] function, and tests/orca/Test.ORCA.<n>.md.
    Maester metadata that ORCA does not carry (severity, author, contributors) is read from
    build/orca/orca-test-metadata.json.

.PARAMETER Offline
    Regenerates only the native tests from the committed check files. Nothing is downloaded.

.PARAMETER OutputPath
    Folder that receives the native tests. Defaults to tests/orca.

.EXAMPLE
    ./build/orca/Update-OrcaTests.ps1

.EXAMPLE
    ./build/orca/Update-OrcaTests.ps1 -Offline -OutputPath ./out
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This command updates multiple ORCA tests.')]
[CmdletBinding()]
param (
    [Parameter()] [switch] $Offline,
    [Parameter()] [string] $OutputPath
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$orcaInternal = Join-Path $repo 'powershell/internal/generated/orca'
if (-not $OutputPath) { $OutputPath = Join-Path $repo 'tests/orca' }
$null = New-Item -Path $OutputPath -ItemType Directory -Force

function Write-OrcaGeneratedContent {
    param (
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string] $Value
    )

    if ($Value -match "`r`n") {
        $newLine = "`r`n"
    } else {
        $newLine = "`n"
    }
    $cleanValue = $Value -replace '(?m)[ \t]+(?=\r?$)', ''
    $cleanValue = $cleanValue -replace '(\r?\n)+$', ''
    [System.IO.File]::WriteAllText($Path, "$cleanValue$newLine", [System.Text.UTF8Encoding]::new($false))
}

#region upstream
if (-not $Offline) {
    $orca = 'https://github.com/cammurray/orca.git'
    $clone = Join-Path $PSScriptRoot 'orca'
    if (Test-Path $clone) {
        & git -C $clone pull --depth 1 $orca
    } else {
        & git clone --depth 1 $orca $clone
    }

    $prereqs = @(
        @{type = 'class'; name = 'ORCACheck' },
        @{type = 'class'; name = 'ORCACheckConfig' },
        @{type = 'class'; name = 'ORCACheckConfigResult' },
        @{type = 'class'; name = 'PolicyInfo' },
        @{type = 'enum'; name = 'CheckType' },
        @{type = 'enum'; name = 'ORCACHI' },
        @{type = 'enum'; name = 'ORCAConfigLevel' },
        @{type = 'enum'; name = 'ORCAResult' },
        @{type = 'enum'; name = 'ORCAService' },
        @{type = 'enum'; name = 'PolicyType' },
        @{type = 'enum'; name = 'PresetPolicyLevel' },
        @{type = 'function'; name = 'Add-IsPresetValue' },
        @{type = 'function'; name = 'Get-ORCACollection' },
        @{type = 'function'; name = 'Get-PolicyStateInt' },
        @{type = 'function'; name = 'Get-PolicyStates' },
        @{type = 'function'; name = 'Get-AnyPolicyState' }
    )

    $module = Get-Content (Join-Path $clone 'orca.psm1') -Raw
    $parse = [System.Management.Automation.Language.Parser]::ParseInput($module, [ref]$null, [ref]$null)

    $codeBlocks = @()
    foreach ($prereq in $prereqs) {
        $enum = $class = $function = $false

        switch ($prereq.type) {
            'enum' { $enum = $true }
            'class' { $class = $true }
            'function' { $function = $true }
        }

        if ($enum -or $class) {
            $codeBlock = $parse.Find({
                    $args | Where-Object {
                        $_.IsClass -eq $class -and
                        $_.IsEnum -eq $enum -and
                        $_.Name -eq $prereq.Name
                    }
                }, $true)
        } elseif ($function) {
            $codeBlock = $parse.FindAll({
                    $args | Where-Object {
                        $_.Name -eq $prereq.Name -and
                        $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                        $_.Parent -isnot [System.Management.Automation.Language.FunctionMemberAst]
                    }
                }, $true)
        }

        if ($codeBlock.Name -eq 'Get-ORCACollection') {
            $regex = "Get\-(?'Request'HostedConnectionFilterPolicy|HostedContentFilterPolicy|HostedContentFilterRule|HostedOutboundSpamFilterPolicy|HostedOutboundSpamFilterRule|ATPProtectionPolicyRule|ATPBuiltInProtectionRule|ProtectionAlert|EOPProtectionPolicyRule|QuarantinePolicy|AntiphishPolicy|AntiPhishRule|MalwareFilterPolicy|MalwareFilterRule|TransportRule|SafeAttachmentPolicy|SafeAttachmentRule|SafeLinksPolicy|SafeLinksRule|AtpPolicyForO365|AcceptedDomain|DkimSigningConfig|InboundConnector|ExternalInOutlook|ArcConfig)\r"
            $regexMatches = [regex]::Matches($codeBlock.Extent.Text, $regex)

            $text = $codeBlock.Extent.Text
            $regexMatches | ForEach-Object {
                $text = $text -replace `
                    "$($_.Value.Trim())\r", "Get-MtExo -Request $($_.Groups['Request'].Value)"
            }
        } elseif ($codeBlock.Name -eq 'Add-IsPresetValue') {
            $text = $codeBlock.Extent.Text
            $text = $text -replace '-Value .IsPreset', "-Value `$IsPreset -Force"
        } elseif ($function) {
            $text = $codeBlock.Extent.Text
        } else {
            $codeBlocks += $codeBlock.Extent.Text
        }

        if ($function) {
            $function = "# Generated by .\build\orca\Update-OrcaTests.ps1`n`n"
            $function += "[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]`n"
            $function += "[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]`n"
            $function += "param()`n`n"
            $function += $text
            $function = $function -replace 'Write\-Host', 'Write-Verbose'
            Write-OrcaGeneratedContent -Path (Join-Path $orcaInternal "$($prereq.name).ps1") -Value $function
        }
    }
    Write-Verbose "Found $($codeBlocks.Count)/$($prereqs.Count) code blocks"

    $orcaClassContent = "# Generated by .\build\orca\Update-OrcaTests.ps1`n`n"
    $orcaClassContent += "[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]`n"
    $orcaClassContent += "[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingEmptyCatchBlock', '')]`n"
    $orcaClassContent += "[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSPossibleIncorrectComparisonWithNull', '')]`n"
    $orcaClassContent += "[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]`n"
    $orcaClassContent += "[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '')]`n"
    $orcaClassContent += "param()`n`n"
    $orcaClassContent += $codeBlocks -join "`n`n"
    $orcaClassContent = $orcaClassContent -replace 'Write\-Host', 'Write-Verbose'
    Write-OrcaGeneratedContent -Path (Join-Path $orcaInternal 'orcaClass.psm1') -Value $orcaClassContent

    $orcaPrereqContent = "# Generated by .\build\orca\Update-OrcaTests.ps1`n`n"
    $orcaPrereqContent += "using module `".\orcaClass.psm1`"`n`n"
    $orcaPrereqContent += "[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]`n"
    $orcaPrereqContent += "[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingEmptyCatchBlock', '')]`n"
    $orcaPrereqContent += "[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSPossibleIncorrectComparisonWithNull', '')]`n"
    $orcaPrereqContent += "[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]`n"
    $orcaPrereqContent += "[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '')]`n"
    $orcaPrereqContent += "param()`n"

    # One check-ORCA*.ps1 per upstream check: the upstream class with the module import replaced.
    Get-ChildItem -Path $orcaInternal -Filter 'check-ORCA*.ps1' | Remove-Item
    foreach ($file in (Get-ChildItem (Join-Path $clone 'Checks') -Filter '*.ps1')) {
        $checkContent = (Get-Content $file -Raw) -replace "using module `"..\\ORCA.psm1`"", ''
        Write-OrcaGeneratedContent -Path (Join-Path $orcaInternal $file.Name) -Value "$orcaPrereqContent`n`n$checkContent"
    }
}
#endregion

#region native tests
$metadataPath = Join-Path $PSScriptRoot 'orca-test-metadata.json'
$metadata = (Get-Content $metadataPath -Raw | ConvertFrom-Json -AsHashtable).Tests

# Collection entries that Get-ORCACollection only fills when Security & Compliance is connected. A check
# that reads one of them needs that service.
$collectionAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $orcaInternal 'Get-ORCACollection.ps1'), [ref]$null, [ref]$null)
$sccKeys = @(
    $collectionAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.IfStatementAst] -and $n.Clauses[0].Item1.Extent.Text -match '\$SCC\b' }, $true) |
        ForEach-Object { [regex]::Matches($_.Clauses[0].Item2.Extent.Text, '\$Collection\[["''](?<key>\w+)["'']\]\s*=') } |
        ForEach-Object { $_.Groups['key'].Value } |
        Sort-Object -Unique
)

function Format-OrcaString { param([string] $Value) "'" + $Value.Replace("'", "''") + "'" }

function Format-OrcaList {
    param([string[]] $Values)
    if ($Values.Count -eq 1) { return Format-OrcaString $Values[0] }
    '(' + (($Values | ForEach-Object { Format-OrcaString $_ }) -join ', ') + ')'
}

$option = [Text.RegularExpressions.RegexOptions]::IgnoreCase
function Get-OrcaCheckValue {
    param([string] $Content, [string] $Property)
    [regex]::Match($Content, "this\.$Property=([\'\`"])(?'capture'.*)\1", $option).Groups['capture'].Value
}

$checkFiles = @(Get-ChildItem -Path $orcaInternal -Filter 'check-ORCA*.ps1' | Sort-Object Name)
$checks = foreach ($file in $checkFiles) {
    $content = Get-Content $file -Raw
    [pscustomobject]@{
        File     = $file.Name
        Content  = $content
        Func     = [regex]::Match($file.Name, "check-(?'capture'.*).ps1", $option).Groups['capture'].Value
        Name     = Get-OrcaCheckValue $content 'name'
        Pass     = Get-OrcaCheckValue $content 'passText'
        Area     = Get-OrcaCheckValue $content 'area'
        Fail     = Get-OrcaCheckValue $content 'failrecommendation'
        Services = [regex]::Match($content, 'this\.Services\s*=\s*\[ORCAService\]::(?<s>\w+)', $option).Groups['s'].Value
    }
}

$written = [System.Collections.Generic.List[string]]::new()
foreach ($check in $checks) {
    $func = $check.Func

    # Title: the pass text, made unique among the variants of a check (ORCA108 and ORCA108_1).
    if ($func -match '_') {
        $siblings = @($checks | Where-Object { $_.File -ne $check.File -and $_.File -like "check-$($func.Split('_')[0])*" })
        switch ($false) {
            ($check.Pass -in $siblings.Pass) { $title = $check.Pass; break }
            ($check.Area -in $siblings.Where({ $_.Pass -eq $check.Pass }).Area) { $title = "$($check.Pass) in $($check.Area)"; break }
            ($check.Name -in $siblings.Name) { $title = $check.Name; break }
            default { $title = $check.Pass; break }
        }
    } else {
        $title = $check.Pass
    }
    if ($title -notmatch '\.$') { $title = "$title." }
    $fail = $check.Fail
    if ($fail -notmatch '\.$') { $fail += '.' }

    # Maester ID: ORCA108_1 -> ORCA.108.1; ORCA120_phish/_malware/_spam -> ORCA.120.1/2/3.
    $testId = ($func -replace 'ORCA', 'ORCA.') -replace '_', '.'
    $mapping = @{
        'ORCA.120.phish'   = 'ORCA.120.1'
        'ORCA.120.malware' = 'ORCA.120.2'
        'ORCA.120.spam'    = 'ORCA.120.3'
    }
    if ($mapping.ContainsKey($testId)) { $testId = $mapping[$testId] }
    if ($testId -notmatch '^ORCA\.\d{1,3}(\.\d+)?$') {
        throw "Test ID '$testId' is not in the Maester format (ORCA.nnn or ORCA.nnn.n). Add a mapping for it in Update-OrcaTests.ps1."
    }

    # Attribute values. Category and Tag reproduce the 2.x Describe 'ORCA' -Tag 'ORCA', '<Id>', 'EXO'
    # (the ORCA suite tag comes from tests/orca/suite.json).
    $meta = $metadata[$testId]
    if (-not $meta) {
        Write-Warning "$testId has no entry in orca-test-metadata.json; using Severity Medium and Author merill. Add an entry and regenerate."
        $meta = @{ Severity = 'Medium'; Author = @('merill') }
    }
    $services = @('ExchangeOnline')
    $readsScc = @($sccKeys | Where-Object { $check.Content -match "\[[`"']$_[`"']\]|ContainsKey\([`"']$_[`"']\)" })
    if ($readsScc.Count -gt 0) { $services += 'SecurityCompliance' }

    $attribute = [System.Collections.Generic.List[string]]::new()
    $attribute.Add("Id = $(Format-OrcaString $testId)")
    $attribute.Add("Title = $(Format-OrcaString $title)")
    $attribute.Add("Severity = $(Format-OrcaString $meta.Severity)")
    $attribute.Add("Category = 'ORCA'")
    $attribute.Add("Product = 'Defender'")
    $attribute.Add("Tag = 'EXO'")
    $attribute.Add("Service = $(Format-OrcaList $services)")
    # Defender for Office 365 Plan 1 or 2. ORCA detects MDO itself and reports 'not completed' without it.
    if ($check.Services -eq 'MDO') { $attribute.Add("License = 'ATP_ENTERPRISE'") }
    $attribute.Add("Author = $(Format-OrcaList @($meta.Author))")
    if ($meta.Contributor) { $attribute.Add("Contributor = $(Format-OrcaList @($meta.Contributor))") }
    $attributeText = ($attribute | ForEach-Object { "        $_" }) -join ",`n"

    $testScript = @"
# Generated by ./build/orca/Update-OrcaTests.ps1 from powershell/internal/generated/orca/$($check.File). Do not edit.

function Test-$func {
    <#
    .SYNOPSIS
    $title

    .DESCRIPTION
    Runs the ORCA check $func (https://github.com/cammurray/orca) against the Exchange Online configuration.

    .LINK
    https://maester.dev/docs/tests/$testId
    #>
    [MaesterTest(
$attributeText
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    `$Collection = Get-MtOrcaCollection
    `$obj = New-Object -TypeName $func
    try { # Handle "SkipInReport" which has a continue statement that makes this function exit unexpectedly
        `$obj.Run(`$Collection)
    } catch {
        Write-OrcaError -TestId "$func" -ErrorRecord `$_ -AdditionalContext "Running $func test"
        throw
    } finally {
        if (`$obj.SkipInReport) {
            Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'The statement "SkipInReport" was specified by ORCA.'
        }
    }

    if (`$obj.CheckFailed) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason `$obj.CheckFailureReason
        return `$null
    } elseif (-not `$obj.Completed) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'Possibly missing license for specific feature.'
        return `$null
    }

    `$testResult = (`$obj.ResultStandard -eq "Pass" -or `$obj.ResultStandard -eq "Informational")

    if (`$testResult) {
        `$resultMarkdown = "Well done! $($title.Replace('`', '``').Replace('"', '`"').Replace('$', '`$'))``n``n%ResultDetail%"
    } else {
        `$resultMarkdown = "The configured settings are not set as recommended.``n``n%ResultDetail%"
    }

    # Return early if we don't need to expand the results
    if (-not `$obj.ExpandResults) {
        Add-MtTestResultDetail -Result `$resultMarkdown.TrimEnd("%ResultDetail%")
        return `$testResult
    }

    `$passResult = "``u{2705} Pass"
    `$failResult = "``u{274C} Fail"
    `$skipResult = "``u{1F5C4} Skip"
    `$showObject = "" + `$obj.CheckType -eq "ObjectPropertyValue"

    `$resultDetail = "``n``n"
    if (`$showObject) { `$resultDetail += "|`$(`$obj.ObjectType)" }
    `$resultDetail += "|`$(`$obj.ItemName)|`$(`$obj.DataType)|Result|``n"

    if (`$showObject) { `$resultDetail += "|-" }
    `$resultDetail += "|-|-|-|``n"

    foreach (`$result in `$obj.Config) {
        if (`$result.ResultStandard -eq "Pass") {
            `$objResult = `$passResult
        } elseif (`$result.ResultStandard -eq "Informational") {
            `$objResult = `$skipResult
        } else {
            `$objResult = `$failResult
        }
        if (`$showObject) { `$resultDetail += "|`$(`$result.Object)" }
        `$resultDetail += "|`$(`$result.ConfigItem)|`$(`$result.ConfigData)|`$objResult|``n"
    }
    `$resultMarkdown = `$resultMarkdown -replace "%ResultDetail%", `$resultDetail

    Add-MtTestResultDetail -Result `$resultMarkdown

    return `$testResult
}
"@
    $ps1Path = Join-Path $OutputPath "Test.$testId.ps1"
    Write-OrcaGeneratedContent -Path $ps1Path -Value $testScript
    $written.Add($ps1Path)

    # Markdown: the ORCA importance text, the fail recommendation and the ORCA links.
    $description = (Get-OrcaCheckValue $check.Content 'Importance') -replace '<[^>]+>', ''
    $links = [regex]::Match($check.Content, "this.Links.*@{(?'capture'[^}]*)}", $option).Groups['capture'].Value | ConvertFrom-StringData
    $linkLines = $links.Keys | Sort-Object | ForEach-Object {
        "* [$($_.Substring(1, $_.Length - 2))]($(($links[$_]).Substring(1, ($links[$_]).Length - 2)))"
    }
    $md = "$description`n`n#### Remediation action`n`n$fail`n`n#### Related Links`n`n$($linkLines -join "`n")`n`n<!--- Results --->`n%TestResult%"
    $mdPath = Join-Path $OutputPath "Test.$testId.md"
    Write-OrcaGeneratedContent -Path $mdPath -Value $md
    $written.Add($mdPath)
}

# Remove native tests whose upstream check is gone.
Get-ChildItem -Path $OutputPath -File | Where-Object { $_.Name -like 'Test.ORCA.*' -and $_.FullName -notin $written } | Remove-Item
Write-Verbose "Wrote $($written.Count / 2) ORCA native tests to $OutputPath"
#endregion
