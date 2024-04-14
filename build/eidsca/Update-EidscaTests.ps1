<#
 .Synopsis
  Generates Maester tests for the Entra ID Security Config Analyzer defined at https://github.com/Cloud-Architekt/AzureAD-Attack-Defense

  .DESCRIPTION
  * Downloads the latest version from https://raw.githubusercontent.com/Cloud-Architekt/AzureAD-Attack-Defense/AADSCAv4/config/EidscaConfig.json
  * Generates Maester tests for each test defined in the JSON file

  .EXAMPLE
    ./build/EIDSCA/Update-EidscaTests.ps1
#>

param (
    # Folder where generated test file should be written to.
    [string] $TestFilePath = "./tests/EIDSCA/Test-EIDSCA.Generated.Tests.ps1",

    # Folder where docs should be generated
    [string] $DocsPath = "./website/docs/tests/EIDSCA",

    [string] $PowerShellFunctionsPath = "./powershell/public/eidsca",

    # Control name to filter on
    [string] $ControlName = "*",

    # URL to the EIDSCA config file
    [string] $AadSecConfigUrl = 'https://raw.githubusercontent.com/Cloud-Architekt/AzureAD-Attack-Defense/AADSCAv4/config/EidscaConfig.json'
)

Function GetRelativeUri($graphUri) {
    $relativeUri = $graphUri -replace 'https://graph.microsoft.com/v1.0/', ''
    $relativeUri = $relativeUri -replace 'https://graph.microsoft.com/beta/', ''
    return $relativeUri
}

Function GetVersion($graphUri) {
    $apiVersion = 'v1.0'
    if ($graphUri.Contains('beta')) {
        $apiVersion = 'beta'
    }
    return $apiVersion
}

Function GetRecommendedValue($RecommendedValue) {
    return "'$RecommendedValue'"
}

Function GetPageTitle($uri) {
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

Function GetPageMarkdownLink($uri) {
    $output = $uri

    $title = GetPageTitle($uri)
    if ($title -ne '') {
        $title = $title.Replace('|', '-')
        $output = "[$title]($uri)"
    }
    return $output
}

Function GetGraphExplorerMarkDownLink($relativeUri, $apiVersion) {
    $graphExplorerUrl = "https://developer.microsoft.com/en-us/graph/graph-explorer?request=$relativeUri&method=GET&version=$apiVersion&GraphUrl=https://graph.microsoft.com"
    return "[Open in Graph Explorer]($graphExplorerUrl)"
}

Function GetMitreUrl($item) {
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

Function GetMitreTitle($item) {
    $url = GetMitreUrl($item)
    if ($null -eq $url) {
        return $item
    }
    $title = GetPageTitle($url)

    $cleanHeading = $title.Split(",")[0] # Remove rest of headings
    $title = "$item - $cleanHeading"

    return $title
}

Function GetMitreItems($items) {
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

Function GetMitreMarkdownLink($item) {
    $url = GetMitreUrl($item)
    if ($null -eq $url) {
        return $item
    }
    $title = GetMitreTitle($item)
    $output = "[$title]($url)"
    return $output
}

Function GetMitreMarkdownLinks($items) {
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
Function GetMitreDiagram($controlItem) {

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

Function GetMarkdownLink($uri, $title, [switch]$lookupTitle) {
    if([string]::IsNullOrEmpty($uri)) { return '' }
    if($lookupTitle) {
        $pageTitle = GetPageTitle($uri)
        if(![string]::IsNullOrEmpty($pageTitle)) {
            $title = $pageTitle
        }
    }
    return "- [$title]($uri)"
}

Function GetPortalDeepLinkMarkdown($portalDeepLink) {
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

Function UpdateTemplate($template, $control, $controlItem, $docName, $isDoc) {
    $relativeUri = GetRelativeUri($control.GraphUri)
    $apiVersion = GetVersion($control.GraphUri)

    $recommendedValue = GetRecommendedValue($controlItem.RecommendedValue)
    $currentValue = $controlItem.CurrentValue

    $psFunctionName = GetEidscaPsFunctionName -controlItem $controlItem
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
    $output = $output -replace '%DocName%', $docName
    $output = $output -replace '%ControlName%', $control.ControlName
    $output = $output -replace '%Description%', $control.Description
    $output = $output -replace '%ControlItemDescription%', $controlItem.Description
    $output = $output -replace '%Severity%', $controlItem.Severity
    $output = $output -replace '%DisplayName%', $controlItem.DisplayName
    $output = $output -replace '%Name%', $controlItem.Name
    $output = $output -replace '%CheckId%', $controlItem.CheckId
    $output = $output -replace '%Recommendation%', $recommendation
    $output = $output -replace '%MitreTactic%', $controlItem.MitreTactic
    $output = $output -replace '%MitreTechnique%', $controlItem.MitreTechnique
    $output = $output -replace '%MitreMitigation%', $controlItem.MitreMitigation
    $output = $output -replace '%PortalDeepLink%', $portalDeepLink
    $output = $output -replace '%DefaultValue%', $controlItem.DefaultValue
    $output = $output -replace '%RelativeUri%', $relativeUri
    $output = $output -replace '%ApiVersion%', $apiVersion
    $output = $output -replace '%RecommendedValue%', $recommendedValue
    $output = $output -replace '%CurrentValue%', $CurrentValue
    $output = $output -replace '%GraphEndPoint%', $control.GraphEndpoint
    $output = $output -replace '%GraphDocsUrl%', $graphDocsUrl
    $output = $output -replace '%GraphExplorerUrl%', $graphExplorerUrl
    $output = $output -replace '%MitreDiagram%', $mitreDiagram
    $output = $output -replace '%PSFunctionName%', $psFunctionName
    $output = $output -replace '%PortalDeepLinkMarkdown%', $portalDeepLinkMarkdown
    $output = $output -replace '%GraphDocsUrlMarkdown%', $graphDocsUrlMarkdown
}

return $output
}

# Returns the contents of a file named @template.txt at the given folder path
Function GetTemplate($folderPath, $templateFileName = "@template.txt") {
    $templateFilePath = Join-Path $folderPath $templateFileName
    return Get-Content $templateFilePath -Raw
}

Function CreateFile($folderPath, $fileName, $content) {
    $filePath = Join-Path $folderPath $fileName
    $content | Out-File $filePath -Encoding utf8
}

Function GetEidscaPsFunctionName($controlItem) {
    $powerShellFunctionName = "Test-Mt$($controlItem.CheckId)"
    $powerShellFunctionName = $powerShellFunctionName.Replace("EIDSCA.", "Eidsca")
    return $powerShellFunctionName
}

# Start by getting the latest EIDSCA config
$aadsc = Invoke-WebRequest -Uri $AadSecConfigUrl | ConvertFrom-Json
$aadsc = ($aadsc | Where-Object {$_.CollectedBy -eq "Maester"}).ControlArea
$Discovery = ($aadsc | where-Object {$_.discovery -ne ""}).Discovery

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

foreach ($control in $aadsc) {
    Write-Verbose "Generating test for $($control.ControlName)"

    $testOutputList = [System.Text.StringBuilder]::new()

    foreach ($controlItem in $control.Controls) {
        # Export check only if RecommendedValue is set
        if (($null -ne $controlItem.RecommendedValue -and $controlItem.RecommendedValue -ne "")) {
            $docName = $controlItem.CheckId

$testTemplate = @'
Describe "%ControlName%" -Tag "EIDSCA", "Security", "All", "%CheckId%" {
    It "%CheckId%: %ControlName% - %DisplayName%. See https://maester.dev/docs/tests/%DocName%" {
        <#
            Check if "https://graph.microsoft.com/%ApiVersion%/%RelativeUri%"
            .%CurrentValue% = %RecommendedValue%
        #>
        %PSFunctionName% | Should -Be %RecommendedValue%
    }
}
'@

            # Add condition to test template if defined in EidscaTest
            if ($controlItem.SkipCondition -ne "") {

                $testTemplate = $testTemplate.Replace( '"%CheckId%"', '"%CheckId%" -Skip:( ' + $controlItem.SkipCondition + ' )')
            }
            $testOutput = UpdateTemplate -template $testTemplate -control $control -controlItem $controlItem -docName $docName
            $docsOutput = UpdateTemplate -template $docsTemplate -control $control -controlItem $controlItem -docName $docName -isDoc $true
            $psOutput = UpdateTemplate -template $psTemplate -control $control -controlItem $controlItem -docName $docName
            $psMarkdownOutput = UpdateTemplate -template $psMarkdownTemplate -control $control -controlItem $controlItem -docName $docName -isDoc $true


            if ($testOutput -ne '') {
                [void]$testOutputList.AppendLine($testOutput)

                CreateFile $DocsPath "$docName.md" $docsOutput
                $psFunctionName = GetEidscaPsFunctionName -controlItem $controlItem
                CreateFile $PowerShellFunctionsPath "$psFunctionName.ps1" $psOutput
                CreateFile $PowerShellFunctionsPath "$psFunctionName.md" $psMarkdownOutput
            }
        } else {
            Write-Warning "$($controlItem.CheckId) - $($controlItem.DisplayName) has no recommended value!"
        }
    }
    if ($testOutputList.Length -ne 0) {
        [void]$sb.AppendLine($testOutputList)
    }
}

$output = @'
BeforeDiscovery {
<DiscoveryFromJson>}

'@

# Replace placeholder with Discovery checks from definition in EIDSCA JSON
$output = $output.Replace('<DiscoveryFromJson>',($Discovery | Out-String))

$output += $sb.ToString()
$output | Out-File $TestFilePath -Encoding utf8