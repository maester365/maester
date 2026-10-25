<#
.SYNOPSIS
    Writes the framework files of the ASD suite from the ISM OSCAL release.

.DESCRIPTION
    The Australian Signals Directorate publishes the Information Security Manual (ISM) as an OSCAL catalog, and
    the Essential Eight Maturity Model as OSCAL baseline profiles of that catalog, one per maturity level:
    https://www.cyber.gov.au/ism/oscal (mirrored at https://github.com/AustralianCyberSecurityCentre/ism-oscal).

    This script reads them and writes the two catalogues of the ASD suite:

      tests/asd/frameworks/ism.json              every numbered ISM control (the ISM principles are not included):
                                                 Id, Guideline, Section, Applicability
      tests/asd/frameworks/essential-eight.json  every control an Essential Eight baseline asks for: Id, Level
                                                 (the lowest maturity level that requires it), Strategy and a
                                                 Related reference to the ISM control of the same ID

    Only identifiers and facts are written, never the text of a control. The version of both frameworks is the
    version of the OSCAL catalog; update it in tests/asd/suite.json as well. The edition of the maturity model the
    profiles implement is not in the OSCAL data: pass it with -MaturityModelEdition when ASD publishes a new one.

    ISM content is (c) Commonwealth of Australia, Australian Signals Directorate, licensed under CC BY 4.0.

    The mitigation strategy of an Essential Eight requirement is not in the OSCAL data. It is derived from the
    section the control sits under, with a few controls placed by their ID (see Get-Strategy), following the
    Essential Eight Maturity Model. Review the result when a release moves a control.

.EXAMPLE
    ./build/asd/Update-AsdFramework.ps1

    Downloads the latest release from the GitHub mirror and rewrites both framework files.

.EXAMPLE
    ./build/asd/Update-AsdFramework.ps1 -SourcePath ./ism-oscal

    Reads ISM_catalog.json and ISM_E8_ML*-baseline_profile.json from a local folder.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Build script output for the console')]
[CmdletBinding()]
param(
    # A folder that holds ISM_catalog.json and the ISM_E8_ML1, ML2 and ML3 baseline profile files. Downloaded when omitted.
    [string] $SourcePath,

    # The branch or tag of the GitHub mirror to download from.
    [string] $Ref = 'main',

    # The folder the framework files are written to.
    [string] $OutputPath = "$PSScriptRoot/../../tests/asd/frameworks",

    # The edition of the Essential Eight Maturity Model that the OSCAL baseline profiles implement.
    [string] $MaturityModelEdition = 'October 2024'
)

$ErrorActionPreference = 'Stop'

$files = @('ISM_catalog.json', 'ISM_E8_ML1-baseline_profile.json', 'ISM_E8_ML2-baseline_profile.json', 'ISM_E8_ML3-baseline_profile.json')
if (-not $SourcePath) {
    $SourcePath = Join-Path ([System.IO.Path]::GetTempPath()) 'ism-oscal'
    $null = New-Item -Path $SourcePath -ItemType Directory -Force
    foreach ($file in $files) {
        $uri = "https://raw.githubusercontent.com/AustralianCyberSecurityCentre/ism-oscal/$Ref/$file"
        Write-Host "Downloading $uri"
        Invoke-WebRequest -Uri $uri -OutFile (Join-Path $SourcePath $file)
    }
}

$catalog = (Get-Content -LiteralPath (Join-Path $SourcePath 'ISM_catalog.json') -Raw | ConvertFrom-Json).catalog
$version = [string]$catalog.metadata.version
Write-Host "ISM OSCAL catalog $version ($($catalog.metadata.'last-modified'))"

# Every ISM control with the headings above it: guideline (top level), chapter and section.
function Get-Control {
    param([object[]] $Groups, [string[]] $Path = @())
    foreach ($group in $Groups) {
        $here = $Path + [string]$group.title
        foreach ($control in @($group.controls)) {
            if ($null -eq $control) { continue }
            [pscustomobject]@{ Path = $here; Control = $control }
        }
        if ($group.PSObject.Properties['groups']) { Get-Control -Groups @($group.groups) -Path $here }
    }
}

$controls = @(Get-Control -Groups @($catalog.groups) | Where-Object { $_.Control.class -eq 'ISM-control' -and $_.Control.id -match '^ism-\d{4}$' })
Write-Host "$($controls.Count) controls"

$strategies = @{
    PA  = 'Patch applications'
    PO  = 'Patch operating systems'
    MFA = 'Multi-factor authentication'
    RAP = 'Restrict administrative privileges'
    AC  = 'Application control'
    MAC = 'Restrict Microsoft Office macros'
    UAH = 'User application hardening'
    RB  = 'Regular backups'
}

function Get-Strategy {
    param([string] $Id, [string[]] $Path, [string] $Statement)
    $section = $Path[-1]
    $chapter = $Path[-2]
    # Event logging, incident reporting and incident response are asked for by the four strategies that log events:
    # multi-factor authentication, restrict administrative privileges, application control and user application hardening.
    if ($Id -in 'ISM-0123', 'ISM-0140', 'ISM-1819', 'ISM-1815', 'ISM-1228', 'ISM-1906', 'ISM-0109', 'ISM-1907') { return 'MFA', 'RAP', 'AC', 'UAH' }
    # Memory integrity sits with the other credential protections of Restrict administrative privileges.
    if ($Id -eq 'ISM-1896') { return 'RAP' }
    switch ($section) {
        'Vulnerability scanning' {
            if ($Id -in 'ISM-1807', 'ISM-1808') { return 'PA', 'PO' }
            if ($Id -in 'ISM-1701', 'ISM-1702', 'ISM-1703', 'ISM-1900') { return 'PO' }
            return 'PA'
        }
        'Mitigating known vulnerabilities' {
            if ($Id -in 'ISM-1694', 'ISM-1695', 'ISM-1877', 'ISM-1696', 'ISM-1697', 'ISM-1879', 'ISM-1902', 'ISM-1903', 'ISM-1904') { return 'PO' }
            return 'PA'
        }
        'Cessation of support' { if ($Id -eq 'ISM-1501') { return 'PO' } else { return 'PA' } }
        'Operating system releases and versions' { return 'PO' }
        'Multi-factor authentication' { return 'MFA' }
        'Application control' { return 'AC' }
        'Office productivity suites' {
            if ($Statement -match 'macro|Trusted Locations|trusted publishers') { return 'MAC' } else { return 'UAH' }
        }
        # Command line process creation logging sits with PowerShell logging under user application hardening.
        { $_ -in 'Portable Document Format applications', 'Web browsers', 'PowerShell', 'Command Shell', 'Hardening operating system configurations' } { return 'UAH' }
        { $_ -in 'Privileged access to systems', 'Suspension of access to systems', 'Separate privileged operating environments', 'Administrative infrastructure', 'Protecting credentials' -or $_ -like 'Setting credentials*' } { return 'RAP' }
    }
    if ($chapter -eq 'Data backup and restoration') { return 'RB' }
    throw "No Essential Eight strategy for $Id under '$($Path -join ' > ')'. Add it to Get-Strategy."
}

# Id -> lowest maturity level that includes the control.
$levelOf = @{}
foreach ($level in 1, 2, 3) {
    $baseline = (Get-Content -LiteralPath (Join-Path $SourcePath "ISM_E8_ML$level-baseline_profile.json") -Raw | ConvertFrom-Json).profile
    foreach ($import in @($baseline.imports)) {
        foreach ($include in @($import.'include-controls')) {
            foreach ($id in @($include.'with-ids')) {
                $key = ([string]$id).ToUpperInvariant()
                if (-not $levelOf.ContainsKey($key)) { $levelOf[$key] = "ML$level" }
            }
        }
    }
}
Write-Host "$($levelOf.Count) Essential Eight requirements"

$ism = foreach ($entry in ($controls | Sort-Object { $_.Control.id })) {
    [ordered]@{
        Id            = $entry.Control.id.ToUpperInvariant()
        Guideline     = $entry.Path[0]
        Section       = $entry.Path[-1]
        Applicability = @($entry.Control.props | Where-Object name -EQ 'applicability' | ForEach-Object value)
    }
}

$essentialEight = foreach ($entry in ($controls | Sort-Object { $_.Control.id })) {
    $id = $entry.Control.id.ToUpperInvariant()
    if (-not $levelOf.ContainsKey($id)) { continue }
    $statement = @($entry.Control.parts | Where-Object name -EQ 'statement' | ForEach-Object prose) -join ' '
    $strategy = @(Get-Strategy -Id $id -Path $entry.Path -Statement $statement | ForEach-Object { $strategies[$_] })
    [ordered]@{
        Id       = $id
        Level    = $levelOf[$id]
        Strategy = if ($strategy.Count -eq 1) { $strategy[0] } else { $strategy }
        Related  = @("ism:$id")
    }
}

function Write-Framework {
    param([System.Collections.Specialized.OrderedDictionary] $Header, [object[]] $Requirements, [string] $Path)
    $head = ($Header | ConvertTo-Json -Depth 3).TrimEnd().TrimEnd('}').TrimEnd()
    $rows = @($Requirements | ForEach-Object { '    ' + (($_ | ConvertTo-Json -Depth 3 -Compress) -replace ',"', ', "' -replace '":', '": ') })
    $content = "$head,`n  `"Requirements`": [`n$($rows -join ",`n")`n  ]`n}`n"
    [System.IO.File]::WriteAllText($Path, $content, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Wrote $Path ($($Requirements.Count) requirements)"
}

$null = New-Item -Path $OutputPath -ItemType Directory -Force
$OutputPath = (Resolve-Path -LiteralPath $OutputPath).Path

Write-Framework -Path (Join-Path $OutputPath 'ism.json') -Requirements $ism -Header ([ordered]@{
        Framework = 'ism'
        Name      = 'ASD Information Security Manual'
        Version   = $version
        Url       = 'https://www.cyber.gov.au/ism'
        License   = 'CC-BY-4.0'
        Note      = "Generated by build/asd/Update-AsdFramework.ps1 from the ISM OSCAL catalog release $version (https://www.cyber.gov.au/ism/oscal); every numbered ISM control, without the ISM principles. Guideline and Section are the headings a control sits under; Applicability lists the classifications it applies to: NC (non-classified), OS (OFFICIAL: Sensitive), P (PROTECTED), S (SECRET), TS (TOP SECRET). ISM content (c) Commonwealth of Australia, Australian Signals Directorate, licensed under CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)."
    })

Write-Framework -Path (Join-Path $OutputPath 'essential-eight.json') -Requirements $essentialEight -Header ([ordered]@{
        Framework = 'essential-eight'
        Name      = 'ASD Essential Eight Maturity Model'
        Version   = $version
        Url       = 'https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/essential-eight-maturity-model-ism-mapping'
        License   = 'CC-BY-4.0'
        Note      = "Generated by build/asd/Update-AsdFramework.ps1 from the Essential Eight Maturity Level baseline profiles of ISM OSCAL release $version (https://www.cyber.gov.au/ism/oscal), which implement the $MaturityModelEdition edition of the Essential Eight Maturity Model and its ISM mapping. Each requirement is the ISM control the maturity model asks for, with the same ID. Level is the lowest maturity level whose baseline includes it (ML1, ML2 or ML3); a higher level may replace a control with a stricter one. Strategy is the mitigation strategy, or the strategies, the requirement belongs to. ISM content (c) Commonwealth of Australia, Australian Signals Directorate, licensed under CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)."
    })
