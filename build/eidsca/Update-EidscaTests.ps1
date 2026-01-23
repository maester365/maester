<#
 .Synopsis
  Generates Maester tests for the Entra ID Security Config Analyzer defined at https://github.com/Cloud-Architekt/AzureAD-Attack-Defense

  .DESCRIPTION
  * Downloads the latest version from https://raw.githubusercontent.com/Cloud-Architekt/AzureAD-Attack-Defense/AADSCAv4/config/EidscaConfig.json
  * Generates Maester tests for each test defined in the JSON file

  .EXAMPLE
    ./build/eidsca/Update-EidscaTests.ps1
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This command updates multiple EIDSCA tests.')]
param (
    # Folder where generated test file should be written to.
    [string] $TestFilePath = "$PSScriptRoot/../../tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",

    # Folder where docs should be generated
    [string] $DocsPath = "$PSScriptRoot/../../website/docs/tests/eidsca",

    # Folder where control functions should be generated
    [string] $PowerShellFunctionsPath = "$PSScriptRoot/../../powershell/internal/eidsca",

    # Folder where the public function should be generated
    [string] $PublicFunctionPath = "$PSScriptRoot/../../powershell/public/eidsca",

    # Control name to filter on
    [string] $ControlName = "*",

    # URL to the EIDSCA config file
    [string] $AadSecConfigUrl = 'https://raw.githubusercontent.com/Cloud-Architekt/AzureAD-Attack-Defense/AADSCAv4/config/EidscaConfig.json'
)

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

function GetRecommendedValue($RecommendedValue) {
    if($RecommendedValue -notlike "@('*,*')") {
        $isNumericComparison = $false
        $compareOperators = @(">=","<=",">","<")
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
    if($RecommendedValueMarkdown -like "@('*,*')") {
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
    $isValidUri = ($uri -as [System.URI]).AbsoluteURI -ne $null

    $title = ''
    if ($isValidUri) {
        $result = Invoke-WebRequest -Uri $uri
        $output = $uri
        if ($result.Content -match "<title>(?<title>.*)</title>") {
            $title = $Matches['title']
        }
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
    $graphExplorerUrl = "https://developer.microsoft.com/en-us/graph/graph-explorer?request=$relativeUri&method=GET&version=$apiVersion&GraphUrl=https://graph.microsoft.com"
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

function GetMarkdownLink($uri, $title, [switch]$lookupTitle) {
    if([string]::IsNullOrEmpty($uri)) { return '' }
    if($lookupTitle) {
        $pageTitle = GetPageTitle($uri)
        if(![string]::IsNullOrEmpty($pageTitle)) {
            $title = $pageTitle
        }
    }
    return "- [$title]($uri)"
}

function GetPortalDeepLinkMarkdown($portalDeepLink) {
    $result = $portalDeepLink
    if (![string]::IsNullOrEmpty($portalDeepLink)) {
        $domain = ($uri -as [System.URI]).Host
        $result =  GetMarkdownLink -uri $portalDeepLink -title "[View in $domain]" # Set default markdown

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

    $psFunctionName = GetEidscaPsFunctionName -checkId $controlItem.CheckId
    $portalDeepLinkMarkdown = GetPortalDeepLinkMarkdown -portalDeepLink $controlItem.PortalDeepLink
    $graphDocsUrlMarkdown = GetMarkdownLink -uri $control.GraphDocsUrl -title "Graph Docs" -lookupTitle

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
        if($controlItem.Severity -eq 'Informational') {
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
        $output = $output -replace '%CurrentValue%', $CurrentValue
        $output = $output -replace '%GraphEndPoint%', $control.GraphEndpoint
        $output = $output -replace '%GraphDocsUrl%', $graphDocsUrl
        $output = $output -replace '%HowToFix%', $controlItem.howToFix
        $output = $output -replace '%GraphExplorerUrl%', $graphExplorerUrl
        $output = $output -replace '%MitreDiagram%', $mitreDiagram
        $output = $output -replace '%PSFunctionName%', $psFunctionName
        $output = $output -replace '%PortalDeepLinkMarkdown%', $portalDeepLinkMarkdown
        $output = $output -replace '%GraphDocsUrlMarkdown%', $graphDocsUrlMarkdown
    }

    # Add condition to test template if defined in EidscaTest
    if (-not [string]::IsNullOrWhiteSpace($controlItem.SkipCondition) ) {
        $SkipCheck = "if ( $($controlItem.SkipCondition) ) {
            Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason '$($controlItem.SkipReason)'
            return " + '$null' +"`
    }"
        $output = $output -replace '%SkipCheck%', "$($SkipCheck)"

        # Extract variable name from the condition to build syntax for TestCases
        $SkipConditionVariable = ($controlItem.SkipCondition  | Select-String -Pattern '\$([^\s]+)').Matches.Value
        $SkipConditionVariableName = $SkipConditionVariable -replace '[$()]', ''
        $output = $output -replace '%TestCases%', " -TestCases @{ $($SkipConditionVariableName) = $($SkipConditionVariable) }"
    } else {
        $output = $output -replace '%SkipCheck%', ""
        $output = $output -replace '%TestCases%', ""
    }

    return $output
}

# Returns the contents of a file named @template.txt at the given folder path
function GetTemplate($folderPath, $templateFileName = "@template.txt") {
    $templateFilePath = Join-Path $folderPath $templateFileName
    return Get-Content $templateFilePath -Raw
}

function CreateFile($folderPath, $fileName, $content) {
    $filePath = Join-Path $folderPath $fileName
    $content | Out-File $filePath -Encoding utf8
}

function GetEidscaPsFunctionName($checkId) {
    $powerShellFunctionName = "Test-Mt$($checkId)"
    $powerShellFunctionName = $powerShellFunctionName.Replace("EIDSCA.", "Eidsca")
    return $powerShellFunctionName
}

function GeneratePublicFunction($folderPath, $controlIds) {
    $output = GetTemplate -folderPath $folderPath -templateFileName '@Test-MtEidscaControl.txt'
    $output = $output -replace '%ArrayOfControlIds%', "'$($controlIds -replace '^.*\.' -join "','")'"
    $output = $output -replace '%InternalFunctionNameTemplate%', (GetEidscaPsFunctionName -checkId 'EIDSCA.$CheckId')
    CreateFile -folderPath $folderPath -fileName 'Test-MtEidscaControl.ps1' -content $output
}

# Start by getting the latest EIDSCA config
$aadsc = Invoke-WebRequest -Uri $AadSecConfigUrl | ConvertFrom-Json
$aadsc = ($aadsc | Where-Object {$_.CollectedBy -eq "Maester"}).ControlArea
$Discovery = ($aadsc | Where-Object {$_.discovery -ne ""}).Discovery

# Remove previously generated files
Get-ChildItem -Path $DocsPath -Filter "*.md" -Exclude "readme.md" | Remove-Item -Force
Get-ChildItem -Path $PowerShellFunctionsPath -Filter "*" -Exclude "@template*" | Remove-Item -Force

$docsTemplate = GetTemplate $DocsPath
$psTemplate = GetTemplate $PowerShellFunctionsPath "@templateps1.txt" # Use the .txt extension to avoid running the script
$psMarkdownTemplate = GetTemplate $PowerShellFunctionsPath "@template.md"

$sb = [System.Text.StringBuilder]::new()

if ($null -ne $ControlName) {
    $aadsc = $aadsc | Where-Object { $_.ControlName -like $ControlName }
}

$exportedControls = [System.Collections.Generic.List[string]]::new()
foreach ($control in $aadsc) {
    Write-Verbose "Generating test for $($control.ControlName)"

    $testOutputList = [System.Text.StringBuilder]::new()

    foreach ($controlItem in $control.Controls) {
        # Export check only if RecommendedValue is set
        if ($null -eq $controlItem.RecommendedValue -or $controlItem.RecommendedValue -eq '') {
            Write-Warning "$($controlItem.CheckId) - $($controlItem.DisplayName) has no recommended value!"
            continue
        }

        $exportedControls.Add($controlItem.CheckId)
        $docName = $controlItem.CheckId

$testTemplate = @'
Describe "EIDSCA" -Tag "EIDSCA",  "%CheckId%" {
    It "%CheckId%: %ControlName% - %DisplayName%. See https://maester.dev/docs/tests/%DocName%"%TestCases% {
        <#
            Check if "https://graph.microsoft.com/%ApiVersion%/%RelativeUri%"
            .%CurrentValue% -%PwshCompareOperator% %RecommendedValue%
        #>
        Test-MtEidscaControl -CheckId %CheckShortId% | Should -%ShouldOperator% %RecommendedValue%
    }
}
'@

        $testOutput = UpdateTemplate -template $testTemplate -control $control -controlItem $controlItem -docName $docName
        $docsOutput = UpdateTemplate -template $docsTemplate -control $control -controlItem $controlItem -docName $docName -isDoc $true
        $psOutput = UpdateTemplate -template $psTemplate -control $control -controlItem $controlItem -docName $docName

        $psMarkdownOutput = UpdateTemplate -template $psMarkdownTemplate -control $control -controlItem $controlItem -docName $docName -isDoc $true

        if ($testOutput -ne '') {
            [void]$testOutputList.AppendLine($testOutput)

            CreateFile $DocsPath "$docName.md" $docsOutput
            $psFunctionName = GetEidscaPsFunctionName -checkId $controlItem.CheckId
            CreateFile $PowerShellFunctionsPath "$psFunctionName.ps1" $psOutput
            CreateFile $PowerShellFunctionsPath "$psFunctionName.md" $psMarkdownOutput
        }
    }
    if ($testOutputList.Length -ne 0) {
        [void]$sb.AppendLine($testOutputList)
    }
}

# Generate Test-MtEidscaControl
GeneratePublicFunction -folderPath $PublicFunctionPath -controlIds $exportedControls

$output = @'
BeforeAll {
<DiscoveryFromJson>}

'@

# Replace placeholder with Discovery checks from definition in EIDSCA JSON
$output = $output.Replace('<DiscoveryFromJson>',($Discovery | Out-String))

$output += $sb.ToString()
$output | Out-File $TestFilePath -Encoding utf8
