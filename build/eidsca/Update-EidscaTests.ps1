<#
 .Synopsis
  Generates the Maester EIDSCA checks for the Entra ID Security Config Analyzer defined at https://github.com/Cloud-Architekt/AzureAD-Attack-Defense

  .DESCRIPTION
  For each EIDSCA control collected by Maester the generator writes:
  * tests/eidsca/Test.EIDSCA.<ID>.ps1 and .md: the native test (Maester 3.0). Its [MaesterTest] function reads
    the tenant value and returns $true when it meets the recommended value.
  * powershell/internal/generated/eidsca/Test-MtEidsca<ID>.ps1: the internal function that reads the tenant value,
    reports it with Add-MtTestResultDetail and returns it.
  * powershell/internal/generated/eidsca/Test-MtEidscaControl.ps1: the dispatcher (internal since Maester 3.0).

  The generator reads a local copy of the EIDSCA config (build/eidsca/EidscaConfig.json) and a cache of page
  titles (build/eidsca/PageTitles.json), so a run without -Download needs no network and reproduces the committed
  files exactly. CI reruns it and fails on drift (powershell/tests/general/EidscaGenerator.Tests.ps1).
  Severity comes from eidsca-test-metadata.json and Author/Contributor from the authorship seed (design section 11),
  so regeneration keeps them.

  .EXAMPLE
    ./build/eidsca/Update-EidscaTests.ps1

    Regenerates the files from the local copy of the EIDSCA config.

  .EXAMPLE
    ./build/eidsca/Update-EidscaTests.ps1 -Download

    Downloads the latest EIDSCA config, looks up new page titles and regenerates the files.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This command updates multiple EIDSCA tests.')]
param (
    # Folder where the native test files (Test.EIDSCA.<ID>.ps1 and .md) are written.
    [string] $TestPath = "$PSScriptRoot/../../tests/eidsca",

    # Folder where the internal tenant value functions (Test-MtEidsca<ID>.ps1) are written.
    [string] $PowerShellFunctionsPath = "$PSScriptRoot/../../powershell/internal/generated/eidsca",

    # Folder where the dispatcher Test-MtEidscaControl is written.
    [string] $PublicFunctionPath = "$PSScriptRoot/../../powershell/internal/generated/eidsca",

    # Folder with the generator templates.
    [string] $TemplatePath = "$PSScriptRoot/templates",

    # Local copy of the EIDSCA config. -Download refreshes it from -AadSecConfigUrl.
    [string] $ConfigPath = "$PSScriptRoot/EidscaConfig.json",

    # Cache of the web page titles used in the generated Markdown links. -Download adds missing titles.
    [string] $PageTitleCachePath = "$PSScriptRoot/PageTitles.json",

    # Severity of each check (same shape as a Maester config: TestSettings with Id and Severity). Read only.
    [string] $MaesterConfigPath = "$PSScriptRoot/eidsca-test-metadata.json",

    # Authorship seed with the author and contributors of each check (design section 11).
    [string] $AuthorshipPath = "$PSScriptRoot/../../docs/proposals/maester-3.0-evidence/authorship-seed.csv",

    # Author used for a control that has no row in the authorship seed.
    [string] $DefaultAuthor = 'Cloud-Architekt',

    # Control name to filter on
    [string] $ControlName = "*",

    # URL to the EIDSCA config file
    [string] $AadSecConfigUrl = 'https://raw.githubusercontent.com/Cloud-Architekt/AzureAD-Attack-Defense/AADSCAv4/config/EidscaConfig.json',

    # Download the EIDSCA config to -ConfigPath and look up page titles that are not in the cache.
    [switch] $Download
)

$ErrorActionPreference = 'Stop'

function GetRelativeUri($graphUri) {
    $relativeUri = $graphUri -replace 'https://graph.microsoft.com/v1.0/', ''
    $relativeUri = $relativeUri -replace 'https://graph.microsoft.com/beta/', ''
    return $relativeUri
}

function GetVersion($graphUri) {
    $apiVersion = 'v1.0'
    if ($graphUri.Contains('beta')) {
        $apiVersion = 'beta'
    }
    return $apiVersion
}

function ConvertTo-LanguageNeutralMicrosoftUrl {
    param (
        [AllowEmptyString()]
        [string] $Content
    )

    if ([string]::IsNullOrEmpty($Content)) {
        return $Content
    }

    $languageNeutralDomains = @(
        'developer.microsoft.com'
        'docs.microsoft.com'
        'learn.microsoft.com'
        'support.microsoft.com'
        'www.microsoft.com'
    )
    $domainPattern = ($languageNeutralDomains | ForEach-Object { [regex]::Escape($_) }) -join '|'
    $languageSegmentPattern = '(?i)(https?://(?:' + $domainPattern + '))/[a-z]{2}-[a-z]{2}(?=/|[?#\s)\]}>.,;:''"]|$)'

    return $Content -replace $languageSegmentPattern, '$1'
}

function GetRecommendedValue($RecommendedValue) {
    if ($RecommendedValue -notlike "@('*,*')") {
        $isNumericComparison = $false
        $compareOperators = @(">=", "<=", ">", "<")
        foreach ($compareOperator in $compareOperators) {
            if ($RecommendedValue.StartsWith($compareOperator)) {
                $isNumericComparison = $true
                $RecommendedValue = $RecommendedValue.Substring($compareOperator.Length).Trim()
                break
            }
        }
        # Don't wrap in quotes for numeric comparisons to ensure proper numeric comparison in Pester
        # Pattern matches integers (e.g., 30), decimals with leading zero (e.g., 0.5), and decimals without leading zero (e.g., .5)
        if ($isNumericComparison -and $RecommendedValue -match "^(\d+(\.\d+)?|\.\d+)$") {
            return $RecommendedValue
        }
        return "'$RecommendedValue'"
    } else {
        return $RecommendedValue
    }
}

function GetRecommendedValueMarkdown($RecommendedValueMarkdown) {
    if ($RecommendedValueMarkdown -like "@('*,*')") {
        $RecommendedValueMarkdown = $RecommendedValueMarkdown -replace "@\(", "" -replace "\)", ""
        return "$RecommendedValueMarkdown"
    } elseif ($RecommendedValueMarkdown.StartsWith(">") -or $RecommendedValueMarkdown.StartsWith("<")) {
        $RecommendedValueText = (GetCompareOperator($RecommendedValueMarkdown)).Text
        $RecommendedValueMarkdown = "$RecommendedValueText $RecommendedValue"
        return "$RecommendedValueMarkdown"
    } else {
        return "'$RecommendedValueMarkdown'"
    }
}

function GetCompareOperator($RecommendedValue) {
    if ($RecommendedValue -like "@('*,*')") {
        $compareOperator = [PSCustomObject]@{
            name       = 'in'
            pester     = 'BeIn'
            powershell = 'in'
            text       = 'is one of the following values'
            valuetype  = 'string'
        }
    } elseif ($RecommendedValue.StartsWith(">=")) {
        $compareOperator = [PSCustomObject]@{
            name       = '>='
            pester     = 'BeGreaterOrEqual'
            powershell = 'ge'
            text       = 'is greater than or equal to'
            valuetype  = 'int'
        }
    } elseif ($RecommendedValue.StartsWith("<=")) {
        $compareOperator = [PSCustomObject]@{
            name       = '<='
            pester     = 'BeLessOrEqual'
            powershell = 'le'
            text       = 'is less than or equal to'
            valuetype  = 'int'
        }
    } elseif ($RecommendedValue.StartsWith(">")) {
        $compareOperator = [PSCustomObject]@{
            name       = '>'
            pester     = 'BeGreaterThan'
            powershell = 'gt'
            text       = 'is greater than'
            valuetype  = 'int'
        }
    } elseif ($RecommendedValue.StartsWith("<")) {
        $compareOperator = [PSCustomObject]@{
            name       = '<'
            pester     = 'BeLessThan'
            powershell = 'lt'
            text       = 'is less than'
            valuetype  = 'int'
        }

    } else {
        $compareOperator = [PSCustomObject]@{
            name       = '='
            pester     = 'Be'
            powershell = 'eq'
            text       = 'is'
            valuetype  = 'string'
        }
    }
    return $compareOperator
}

function GetPageTitle($uri) {
    $uri = ConvertTo-LanguageNeutralMicrosoftUrl -Content $uri
    $isValidUri = $null -ne ($uri -as [System.URI]).AbsoluteURI

    $title = ''
    if ($isValidUri) {
        # Titles come from the committed cache so that regeneration is reproducible offline.
        if ($script:PageTitleCache.Contains($uri)) {
            return $script:PageTitleCache[$uri]
        }
        if (-not $script:Download) {
            Write-Warning "No cached page title for $uri. Run with -Download to look it up."
            return $title
        }
        try {
            $result = Invoke-WebRequest -Uri $uri
            if ($result.Content -match "(?s)<title>(?<title>.*?)</title>") {
                $title = $Matches['title'].Trim() -replace '\s+', ' '
            }
        } catch {
            Write-Warning "Could not read the page title of ${uri}: $($_.Exception.Message)"
            return $title
        }
        $script:PageTitleCache[$uri] = $title
    }
    return $title
}

function GetPageMarkdownLink($uri) {
    $output = $uri

    $title = GetPageTitle($uri)
    if ($title -ne '') {
        $title = $title.Replace('|', '-')
        $output = "[$title]($uri)"
    }
    return $output
}

function GetGraphExplorerMarkDownLink($relativeUri, $apiVersion) {
    $graphExplorerUrl = "https://developer.microsoft.com/graph/graph-explorer?request=$relativeUri&method=GET&version=$apiVersion&GraphUrl=https://graph.microsoft.com"
    return "[Open in Graph Explorer]($graphExplorerUrl)"
}

function GetMitreUrl($item) {
    $item = $item.Trim()

    $urlPart = ''
    if ($item -ne '') {
        if ($item.StartsWith('TA')) {
            $urlPart = "tactics" #The json includes the heading, split it and get just the code
            $item = $item.Split(" ")[0]
        } elseif ($item.StartsWith('T')) {
            $urlPart = "techniques"
        } elseif ($item.StartsWith('M')) {
            $urlPart = "mitigations"
        }
    }
    if ($urlPart -eq '') {
        return $null
    }

    $itemUrl = $item.Replace('.', '/') #Sub items
    $url = "https://attack.mitre.org/$urlPart/$itemUrl"
    return $url
}

function GetMitreTitle($item) {
    $url = GetMitreUrl($item)
    if ($null -eq $url) {
        return $item
    }
    $title = GetPageTitle($url)

    $cleanHeading = $title.Split(",")[0] # Remove rest of headings
    $title = "$item - $cleanHeading"

    return $title
}

function GetMitreItems($items) {
    $output = ""
    $isFirst = $true
    foreach ($item in $items) {
        if ($isFirst) {
            $isFirst = $false
        } else {
            $output += [System.Environment]::NewLine
        }
        $title = GetMitreTitle($item)
        $output += "      $title"
    }
    return $output
}

function GetMitreMarkdownLink($item) {
    $url = GetMitreUrl($item)
    if ($null -eq $url) {
        return $item
    }
    $title = GetMitreTitle($item)
    $output = "[$title]($url)"
    return $output
}

function GetMitreMarkdownLinks($items) {
    $output = ""
    $isFirst = $true
    foreach ($item in $items) {
        if ($isFirst) {
            $isFirst = $false
        } else {
            $output += "<br/>"
        }
        $output += GetMitreMarkdownLink($item)
    }
    return $output
}
function GetMitreDiagram($controlItem) {

    if ($controlItem.MitreTactic.Length -le 0) {
        return ''
    }

    $mermaid = @'
## MITRE ATT&CK

```mermaid
mindmap
  root{{MITRE ATT&CK}}
    (Tactic)
%Tactics%
    (Mitigation)
%Mitigations%
    (Technique)
%Techniques%
```
|Tactic|Technique|Mitigation|
|---|---|---|
|%TacticUrls%|%TechniqueUrls%|%MitigationUrls%|

'@
    $tactics = GetMitreItems($controlItem.MitreTactic)
    $techniques = GetMitreItems($controlItem.MitreTechnique)
    $mitigations = GetMitreItems($controlItem.MitreMitigation)

    $tacticsLinks = GetMitreMarkdownLinks($controlItem.MitreTactic)
    $techniquesLinks = GetMitreMarkdownLinks($controlItem.MitreTechnique)
    $mitigationsLinks = GetMitreMarkdownLinks($controlItem.MitreMitigation)

    $mermaid = $mermaid -replace '%Tactics%', $tactics
    $mermaid = $mermaid -replace '%Mitigations%', $mitigations
    $mermaid = $mermaid -replace '%Techniques%', $techniques
    $mermaid = $mermaid -replace '%TacticUrls%', $tacticsLinks
    $mermaid = $mermaid -replace '%MitigationUrls%', $mitigationsLinks
    $mermaid = $mermaid -replace '%TechniqueUrls%', $techniquesLinks
    return $mermaid
}

function GetRemediationMarkdown($controlItem) {
    if ([string]::IsNullOrWhiteSpace($controlItem.HowToFix)) {
        return ''
    }
    return "#### Remediation action`n`n$($controlItem.HowToFix)"
}

function GetMarkdownLink($uri, $title, [switch]$lookupTitle) {
    if ([string]::IsNullOrEmpty($uri)) { return '' }
    if ($lookupTitle) {
        $pageTitle = GetPageTitle($uri)
        if (![string]::IsNullOrEmpty($pageTitle)) {
            $title = $pageTitle
        }
    }
    return "- [$title]($uri)"
}

function GetPortalDeepLinkMarkdown($portalDeepLink) {
    $result = $portalDeepLink
    if (![string]::IsNullOrEmpty($portalDeepLink)) {
        $domain = ($portalDeepLink -as [System.URI]).Host
        $result = GetMarkdownLink -uri $portalDeepLink -title "[View in $domain]" # Set default markdown

        if ($portalDeepLink -like "*entra.microsoft.com*" -or $portalDeepLink -like "*Microsoft_AAD_IAM*") {
            $result = GetMarkdownLink -uri $portalDeepLink -title "View in Microsoft Entra admin center"
        } elseif ($portalDeepLink -like "*admin.microsoft.com*") {
            $result = GetMarkdownLink -uri $portalDeepLink -title "Open in Microsoft 365 admin center"
        }
    }
    return $result
}

function UpdateTemplate($template, $control, $controlItem, $docName, $isDoc) {
    $relativeUri = GetRelativeUri($control.GraphUri)
    $apiVersion = GetVersion($control.GraphUri)

    $recommendedValue = GetRecommendedValue($controlItem.RecommendedValue)
    $RecommendedValueMarkdown = GetRecommendedValueMarkdown($controlItem.RecommendedValue)
    $compareOperator = GetCompareOperator($controlItem.RecommendedValue)
    $currentValue = $controlItem.CurrentValue

    # Extract just the property path (before any pipeline) for use in docs/comments
    $currentValueProperty = ($currentValue -split '\|')[0].Trim()

    $psFunctionName = GetEidscaPsFunctionName -checkId $controlItem.CheckId
    $portalDeepLinkMarkdown = GetPortalDeepLinkMarkdown -portalDeepLink $controlItem.PortalDeepLink
    $graphDocsUrlMarkdown = GetMarkdownLink -uri $control.GraphDocsUrl -title "Graph Docs" -lookupTitle
    $remediationAction = GetRemediationMarkdown -controlItem $controlItem

    $output = ''
    if ($currentValue -eq '' -or $control.ControlName -eq '') {
        Write-Warning 'Skipping'
    } else {
        $graphExplorerUrl = GetGraphExplorerMarkDownLink -relativeUri $relativeUri -apiVersion $apiVersion

        if ($isDoc) {
            # Only do this for docs
            $graphDocsUrl = GetPageMarkdownLink($control.GraphDocsUrl)
            $recommendation = GetPageMarkdownLink($controlItem.Recommendation)
            $mitreDiagram = GetMitreDiagram -controlItem $controlItem
        }

        $output = $template

        # Replace string with int if DefaultValue is a number and expecting an int as configuration value
        if ($controlItem.DefaultValue -match "^[\d\.]+$") {
            $output = $output -replace 'string', 'int'
        }

        # Map severity to Maester values
        if ($controlItem.Severity -eq 'Informational') {
            $controlItem.Severity = 'Info'
        }

        $output = $output -replace '%DocName%', $docName
        $output = $output -replace '%ControlName%', $control.ControlName
        $output = $output -replace '%Description%', $control.Description
        $output = $output -replace '%ControlItemDescription%', $controlItem.Description
        $output = $output -replace '%Severity%', $controlItem.Severity
        $output = $output -replace '%DisplayName%', $controlItem.DisplayName
        $output = $output -replace '%Name%', $controlItem.Name
        $output = $output -replace '%CheckId%', $controlItem.CheckId
        $output = $output -replace '%CheckShortId%', ($controlItem.CheckId -replace '^EIDSCA\.')
        $output = $output -replace '%Recommendation%', $recommendation
        $output = $output -replace '%MitreTactic%', $controlItem.MitreTactic
        $output = $output -replace '%MitreTechnique%', $controlItem.MitreTechnique
        $output = $output -replace '%MitreMitigation%', $controlItem.MitreMitigation
        $output = $output -replace '%PortalDeepLink%', $portalDeepLink
        $output = $output -replace '%DefaultValue%', $controlItem.DefaultValue
        $output = $output -replace '%RelativeUri%', $relativeUri
        $output = $output -replace '%ApiVersion%', $apiVersion
        $output = $output -replace '%ShouldOperator%', $compareOperator.pester.Replace("'", "")
        $output = $output -replace '%CompareOperatorText%', $compareOperator.Text
        $output = $output -replace '%CompareOperator%', $compareOperator.Name
        $output = $output -replace '%PwshCompareOperator%', $compareOperator.powershell.Replace("'", "")
        $output = $output -replace '%ValueType%', $compareOperator.valuetype
        $output = $output -replace '%RecommendedValue%', $recommendedValue
        $output = $output -replace '%RecommendedValueMarkdown%', $recommendedValueMarkdown
        $output = $output -replace '%CurrentValueProperty%', $currentValueProperty
        $output = $output -replace '%CurrentValue%', $CurrentValue
        $output = $output -replace '%GraphEndPoint%', $control.GraphEndpoint
        $output = $output -replace '%GraphDocsUrl%', $graphDocsUrl
        $output = $output.Replace('%RemediationAction%', $remediationAction)
        $output = $output -replace '%GraphExplorerUrl%', $graphExplorerUrl
        $output = $output -replace '%MitreDiagram%', $mitreDiagram
        $output = $output -replace '%PSFunctionName%', $psFunctionName
        $output = $output -replace '%PortalDeepLinkMarkdown%', $portalDeepLinkMarkdown
        $output = $output -replace '%GraphDocsUrlMarkdown%', $graphDocsUrlMarkdown
    }

    return ConvertTo-LanguageNeutralMicrosoftUrl -Content $output
}

# Returns the value type the tenant value function casts the value to.
function GetValueType($controlItem) {
    if ($controlItem.DefaultValue -match "^[\d\.]+$") {
        return 'int'
    }
    return (GetCompareOperator($controlItem.RecommendedValue)).valuetype
}

# Skip conditions in the EIDSCA config that are licence guards. The engine gates them with License.
$script:LicenseSkipConditions = @{
    "`$EntraIDPlan -eq 'Free'" = 'AAD_PREMIUM'
}

# Turns the SkipCondition of a control into the code at the top of the native test.
# - A licence guard becomes a License token (no code).
# - Any other condition is a fact only the test can see: the test reads the discovery variables it uses
#   (from the Discovery lines of the EIDSCA config) and skips with the custom reason.
# - A call to another control's function, (Test-MtEidsca<ID>), is replaced by a direct read of that control's
#   tenant value, so no test calls another test and the other control's result detail is not reported
#   (design section 13).
function GetSkipCheck($controlItem, $discoveryLines, $controlLookup) {
    $result = [pscustomobject]@{ Code = ''; License = @() }
    $condition = "$($controlItem.SkipCondition)".Trim()
    if ([string]::IsNullOrWhiteSpace($condition)) {
        return $result
    }
    if ($script:LicenseSkipConditions.ContainsKey($condition)) {
        $result.License = @($script:LicenseSkipConditions[$condition])
        return $result
    }
    if ($condition -match '\$EntraIDPlan') {
        throw "$($controlItem.CheckId): the licence condition '$condition' has no License mapping in `$LicenseSkipConditions."
    }

    $lines = [System.Collections.Generic.List[string]]::new()

    $calls = [regex]::Matches($condition, '\(Test-MtEidsca(?<id>[A-Za-z0-9]+)\)')
    foreach ($call in $calls) {
        $otherId = "EIDSCA.$($call.Groups['id'].Value)"
        if (-not $controlLookup.ContainsKey($otherId)) {
            throw "$($controlItem.CheckId): the skip condition calls $otherId, which is not an EIDSCA control."
        }
        $other = $controlLookup[$otherId]
        $variableName = "eidsca$($call.Groups['id'].Value)Value"
        $lines.Add("    # Tenant value of $otherId, read directly so that this test does not call another test.")
        $lines.Add("    `$eidsca$($call.Groups['id'].Value)Result = Invoke-MtGraphRequest -RelativeUri `"$(GetRelativeUri($other.Control.GraphUri))`" -ApiVersion $(GetVersion($other.Control.GraphUri))")
        $lines.Add("    [$(GetValueType $other.Item)]`$$variableName = `$eidsca$($call.Groups['id'].Value)Result.$($other.Item.CurrentValue)")
        $condition = $condition.Replace($call.Value, "`$$variableName")
    }

    $variables = [regex]::Matches("$($controlItem.SkipCondition)", '\$(?<name>[A-Za-z_][A-Za-z0-9_]*)') |
        ForEach-Object { $_.Groups['name'].Value } |
        Where-Object { $_ -notin 'null', 'true', 'false' } |
        Select-Object -Unique
    $discoveryCode = foreach ($variable in $variables) {
        $line = $discoveryLines | Where-Object { $_ -match "^\s*\`$$([regex]::Escape($variable))\s*=" } | Select-Object -First 1
        if (-not $line) {
            throw "$($controlItem.CheckId): the skip condition uses `$$variable, which no Discovery line in the EIDSCA config sets."
        }
        "    $($line.Trim())"
    }
    $lines.InsertRange(0, [string[]]@($discoveryCode))

    $reason = "$($controlItem.SkipReason)".Replace("'", "''")
    $lines.Add("    if ( $condition ) {")
    $lines.Add("        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason '$reason'")
    $lines.Add('        return $null')
    $lines.Add('    }')
    $result.Code = "`n" + ($lines -join "`n") + "`n"
    return $result
}

function FormatAttributeString([string] $Value) { "'" + $Value.Replace("'", "''") + "'" }

function FormatAttributeList([string[]] $Values) {
    if ($Values.Count -eq 1) { return FormatAttributeString $Values[0] }
    '(' + (($Values | ForEach-Object { FormatAttributeString $_ }) -join ', ') + ')'
}

# The [MaesterTest(...)] attribute of a native test (design section 4). Category and tags reproduce what
# Pester selected on in 2.x: the Describe 'EIDSCA' block and its tags (the suite tag and the ID).
function GetMaesterTestAttribute($meta) {
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("        Id = $(FormatAttributeString $meta.Id)")
    $lines.Add("        Title = $(FormatAttributeString $meta.Title)")
    if ($meta.Severity) { $lines.Add("        Severity = $(FormatAttributeString $meta.Severity)") }
    $lines.Add("        Category = $(FormatAttributeString $meta.Category)")
    $lines.Add("        Service = $(FormatAttributeList $meta.Service)")
    if ($meta.License.Count -gt 0) { $lines.Add("        License = $(FormatAttributeList $meta.License)") }
    if ($meta.Author.Count -gt 0) { $lines.Add("        Author = $(FormatAttributeList $meta.Author)") }
    if ($meta.Contributor.Count -gt 0) { $lines.Add("        Contributor = $(FormatAttributeList $meta.Contributor)") }
    "    [MaesterTest(`n" + ($lines -join ",`n") + "`n    )]"
}

# Name of the [MaesterTest] function. Test-MtEidsca<ID> keeps its 2.x name and return value (the tenant value).
function GetEidscaNativeFunctionName($checkId) {
    return "Test-MtCheck$($checkId.Replace('EIDSCA.', 'Eidsca'))"
}

# Returns the contents of a template file in the template folder
function GetTemplate($folderPath, $templateFileName) {
    $templateFilePath = Join-Path $folderPath $templateFileName
    return Get-Content $templateFilePath -Raw
}

function RemoveTrailingWhitespace($content) {
    # (?m)$ matches only before LF, so allow a CR in between for CRLF templates (Windows checkouts).
    return $content -replace '(?m)[ \t]+(?=\r?$)', ''
}

function CreateFile($folderPath, $fileName, $content) {
    $filePath = Join-Path $folderPath $fileName
    if ($content -match "`r`n") {
        $newLine = "`r`n"
    } else {
        $newLine = "`n"
    }
    $content = RemoveTrailingWhitespace $content
    $content = $content -replace '(\r?\n)+$', ''
    [System.IO.File]::WriteAllText($filePath, "$content$newLine", [System.Text.UTF8Encoding]::new($false))
}

function GetEidscaPsFunctionName($checkId) {
    $powerShellFunctionName = "Test-Mt$($checkId)"
    $powerShellFunctionName = $powerShellFunctionName.Replace("EIDSCA.", "Eidsca")
    return $powerShellFunctionName
}


function GeneratePublicFunction($folderPath, $controlIds) {
    $output = GetTemplate -folderPath $TemplatePath -templateFileName 'Test-MtEidscaControl.ps1.txt'
    $output = $output -replace '%ArrayOfControlIds%', "'$($controlIds -replace '^.*\.' -join "','")'"
    $output = $output -replace '%InternalFunctionNameTemplate%', (GetEidscaPsFunctionName -checkId 'EIDSCA.$CheckId')
    CreateFile -folderPath $folderPath -fileName 'Test-MtEidscaControl.ps1' -content $output
}

# Read the EIDSCA config: the local copy, refreshed from the upstream repository with -Download.
if ($Download) {
    $configContent = (Invoke-WebRequest -Uri $AadSecConfigUrl).Content
    if ($configContent -is [byte[]]) { $configContent = [System.Text.Encoding]::UTF8.GetString($configContent) }
    [System.IO.File]::WriteAllText($ConfigPath, $configContent, [System.Text.UTF8Encoding]::new($false))
}
$aadsc = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$aadsc = ($aadsc | Where-Object { $_.CollectedBy -eq "Maester" }).ControlArea
$Discovery = @(($aadsc | Where-Object { $_.discovery -ne "" }).Discovery | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

# Page titles for the Markdown links.
$script:PageTitleCache = [ordered]@{}
if (Test-Path -LiteralPath $PageTitleCachePath) {
    foreach ($property in (Get-Content -LiteralPath $PageTitleCachePath -Raw | ConvertFrom-Json).PSObject.Properties) {
        $script:PageTitleCache[$property.Name] = [string]$property.Value
    }
}

# Severity (eidsca-test-metadata.json) and authorship (design section 11), so regeneration keeps them.
$severityById = @{}
if (Test-Path -LiteralPath $MaesterConfigPath) {
    foreach ($row in (Get-Content -LiteralPath $MaesterConfigPath -Raw | ConvertFrom-Json).TestSettings) {
        if ($row.Id -and $row.Severity) { $severityById[[string]$row.Id] = [string]$row.Severity }
    }
}
$authorshipById = @{}
if (Test-Path -LiteralPath $AuthorshipPath) {
    foreach ($row in (Import-Csv -LiteralPath $AuthorshipPath)) { $authorshipById[$row.test_id] = $row }
}

# All controls by ID, so a skip condition can read another control's value.
$controlLookup = @{}
foreach ($control in $aadsc) {
    foreach ($controlItem in $control.Controls) {
        $controlLookup[$controlItem.CheckId] = [pscustomobject]@{ Control = $control; Item = $controlItem }
    }
}

# Remove previously generated files
Get-ChildItem -Path $PowerShellFunctionsPath -Filter 'Test-MtEidsca*' -File -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem -Path $TestPath -Filter 'Test.EIDSCA.*' -File -ErrorAction SilentlyContinue | Remove-Item -Force
# The 2.x Pester file is replaced by the native tests.
Get-ChildItem -Path $TestPath -Filter 'Test-EIDSCA.Generated.Tests.ps1' -File -ErrorAction SilentlyContinue | Remove-Item -Force

$psTemplate = GetTemplate $TemplatePath 'Test-MtEidsca.ps1.txt' # Use the .txt extension to avoid running the script
$nativeTemplate = GetTemplate $TemplatePath 'Test.EIDSCA.ps1.txt'
$markdownTemplate = GetTemplate $TemplatePath 'Test.EIDSCA.md.txt'

if ($null -ne $ControlName) {
    $aadsc = $aadsc | Where-Object { $_.ControlName -like $ControlName }
}

$exportedControls = [System.Collections.Generic.List[string]]::new()
foreach ($control in $aadsc) {
    Write-Verbose "Generating test for $($control.ControlName)"

    foreach ($controlItem in $control.Controls) {
        # Export check only if RecommendedValue is set
        if ($null -eq $controlItem.RecommendedValue -or $controlItem.RecommendedValue -eq '') {
            Write-Warning "$($controlItem.CheckId) - $($controlItem.DisplayName) has no recommended value!"
            continue
        }

        $docName = $controlItem.CheckId
        $psOutput = UpdateTemplate -template $psTemplate -control $control -controlItem $controlItem -docName $docName
        if ($psOutput -eq '') { continue }
        $exportedControls.Add($controlItem.CheckId)

        $markdownOutput = UpdateTemplate -template $markdownTemplate -control $control -controlItem $controlItem -docName $docName -isDoc $true
        $nativeOutput = UpdateTemplate -template $nativeTemplate -control $control -controlItem $controlItem -docName $docName

        # The native test: attribute, skip check and the comparison the 2.x Pester It made.
        $skipCheck = GetSkipCheck -controlItem $controlItem -discoveryLines $Discovery -controlLookup $controlLookup
        $severity = $severityById[$controlItem.CheckId]
        if (-not $severity) { $severity = $controlItem.Severity }
        $authorship = $authorshipById[$controlItem.CheckId]
        $authors = @(if ($authorship -and $authorship.author) { $authorship.author -split ';' } else { $DefaultAuthor }) | Where-Object { $_ }
        $contributors = @(if ($authorship) { $authorship.contributors_recommended -split ';' }) | Where-Object { $_ -and $_ -notin $authors }
        $attribute = GetMaesterTestAttribute @{
            Id                = $controlItem.CheckId
            Title             = "$($control.ControlName) - $($controlItem.DisplayName)."
            Severity          = $severity
            Category          = 'EIDSCA'
            Service           = @('Graph')
            License = @($skipCheck.License)
            Author            = $authors
            Contributor       = $contributors
        }
        $nativeOutput = $nativeOutput.Replace('%NativeFunctionName%', (GetEidscaNativeFunctionName -checkId $controlItem.CheckId))
        $nativeOutput = $nativeOutput.Replace('%MaesterTestAttribute%', $attribute)
        $nativeOutput = $nativeOutput.Replace('%SkipCheck%', $skipCheck.Code)
        $nativeOutput = ConvertTo-LanguageNeutralMicrosoftUrl -Content $nativeOutput

        $psFunctionName = GetEidscaPsFunctionName -checkId $controlItem.CheckId
        CreateFile -folderPath $PowerShellFunctionsPath -fileName "$psFunctionName.ps1" -content $psOutput
        CreateFile -folderPath $TestPath -fileName "Test.$($controlItem.CheckId).ps1" -content $nativeOutput
        CreateFile -folderPath $TestPath -fileName "Test.$($controlItem.CheckId).md" -content $markdownOutput
    }
}

# Generate Test-MtEidscaControl
GeneratePublicFunction -folderPath $PublicFunctionPath -controlIds $exportedControls

# Keep the page title cache sorted so that its diff stays small.
if ($Download) {
    $sortedCache = [ordered]@{}
    foreach ($key in ($script:PageTitleCache.Keys | Sort-Object)) { $sortedCache[$key] = $script:PageTitleCache[$key] }
    [System.IO.File]::WriteAllText($PageTitleCachePath, (($sortedCache | ConvertTo-Json) -replace '\r\n', "`n") + "`n", [System.Text.UTF8Encoding]::new($false))
}
