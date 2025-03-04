[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This command updates multiple ORCA tests.')]
param ()

# Get local repo path and set working dir
$repo = & git rev-parse --show-toplevel
$cwd = Get-Location
Set-Location -Path $repo\build\orca

# Get orca remote repo
$orca = "https://github.com/cammurray/orca.git"
if (Test-Path ".\orca") {
    & git pull --depth 1 $orca
} else {
    & git clone --depth 1 $orca
}

#region prereqs
$prereqs = @(
    @{type = "class";    name = "ORCACheck"},
    @{type = "class";    name = "ORCACheckConfig"},
    @{type = "class";    name = "ORCACheckConfigResult"},
    @{type = "class";    name = "PolicyInfo"},
    @{type = "enum";     name = "CheckType"},
    @{type = "enum";     name = "ORCACHI"},
    @{type = "enum";     name = "ORCAConfigLevel"},
    @{type = "enum";     name = "ORCAResult"},
    @{type = "enum";     name = "ORCAService"},
    @{type = "enum";     name = "PolicyType"},
    @{type = "enum";     name = "PresetPolicyLevel"},
    @{type = "function"; name = "Add-IsPresetValue"},
    @{type = "function"; name = "Get-ORCACollection"},
    @{type = "function"; name = "Get-PolicyStateInt"},
    @{type = "function"; name = "Get-PolicyStates"},
    @{type = "function"; name = "Get-AnyPolicyState"}
)

$module = Get-Content .\orca\orca.psm1 -Raw
$parse = [System.Management.Automation.Language.Parser]::ParseInput($module,[ref]$null,[ref]$null)

$codeBlocks = @()
foreach($prereq in $prereqs){
    $enum = $class = $function = $false

    switch($prereq.type){
        "enum" {$enum = $true}
        "class" {$class = $true}
        "function" {$function = $true}
    }

    if($enum -or $class){
        $codeBlock = $parse.Find({
            $args|Where-Object{`
                $_.IsClass -eq $class -and `
                $_.IsEnum -eq $enum -and `
                $_.Name -eq $prereq.Name
            }
        },$true)
    }elseif($function){
        $codeBlock = $parse.FindAll({
            $args|Where-Object{`
                $_.Name -eq $prereq.Name -and`
                $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] -and`
                $_.Parent -isnot [System.Management.Automation.Language.FunctionMemberAst]
            }
        },$true)
    }

    if($codeBlock.Name -eq "Get-ORCACollection"){
        $regex = "Get\-(?'Request'HostedConnectionFilterPolicy|HostedContentFilterPolicy|HostedContentFilterRule|HostedOutboundSpamFilterPolicy|HostedOutboundSpamFilterRule|ATPProtectionPolicyRule|ATPBuiltInProtectionRule|ProtectionAlert|EOPProtectionPolicyRule|QuarantinePolicy|AntiphishPolicy|AntiPhishRule|MalwareFilterPolicy|MalwareFilterRule|TransportRule|SafeAttachmentPolicy|SafeAttachmentRule|SafeLinksPolicy|SafeLinksRule|AtpPolicyForO365|AcceptedDomain|DkimSigningConfig|InboundConnector|ExternalInOutlook|ArcConfig)\r"
        $regexMatches = [regex]::Matches($codeBlock.Extent.Text,$regex)

        $text = $codeBlock.Extent.Text
        $regexMatches|ForEach-Object{
            $text = $text -replace`
                "$($_.Value.Trim())\r","Get-MtExo -Request $($_.Groups['Request'].Value)"
        }
    }elseif($codeBlock.Name -eq "Add-IsPresetValue"){
        $text = $codeBlock.Extent.Text
        $text = $text -replace "-Value .IsPreset","-Value `$IsPreset -Force"
    }elseif($function){
        $text = $codeBlock.Extent.Text
    }else{
        $codeBlocks += $codeBlock.Extent.Text
    }

    if($function){
        $function = "# Generated on $(Get-Date) by .\build\orca\Update-OrcaTests.ps1`n`n"
        $function += "[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]`n"
        $function += "[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]`n"
        $function += "param()`n`n"
        $function += $text
        $function = $function -replace "Write\-Host","Write-Verbose"
        Set-Content -Path "$repo\powershell\internal\orca\$($prereq.name).ps1" -Value $function -Force
    }
}
Write-Verbose "Found $($codeBlocks.Count)/$($prereqs.Count) code blocks"

$orcaClassContent = "# Generated on $(Get-Date) by .\build\orca\Update-OrcaTests.ps1`n`n"
$orcaClassContent += "[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]`n"
$orcaClassContent += "[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingEmptyCatchBlock', '')]`n"
$orcaClassContent += "[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSPossibleIncorrectComparisonWithNull', '')]`n"
$orcaClassContent += "[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]`n"
$orcaClassContent += "[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '')]`n"
$orcaClassContent += "param()`n`n"
$orcaClassContent += $codeBlocks -join "`n`n"
$orcaClassContent = $orcaClassContent -replace "Write\-Host","Write-Verbose"
Set-Content -Path $repo\powershell\internal\orca\orcaClass.psm1 -Value $orcaClassContent -Force

$orcaPrereqContent = "# Generated on $(Get-Date) by .\build\orca\Update-OrcaTests.ps1`n`n"
$orcaPrereqContent += "using module `".\orcaClass.psm1`"`n`n"
$orcaPrereqContent += "[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]`n"
$orcaPrereqContent += "[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingEmptyCatchBlock', '')]`n"
$orcaPrereqContent += "[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSPossibleIncorrectComparisonWithNull', '')]`n"
$orcaPrereqContent += "[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]`n"
$orcaPrereqContent += "[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '')]`n"
$orcaPrereqContent += "param()`n"
$orcaPrereqContent = $orcaPrereqContent -replace "Write\-Host","Write-Verbose"
#endregion

#region tests
$exports = @()
$testFiles = Get-ChildItem $repo\build\orca\orca\Checks\*.ps1
foreach($file in $testFiles){
    $content = [pscustomobject]@{
        file        = $file.Name
        content     = Get-Content $file -Raw
        name        = ""
        pass        = ""
        fail        = ""
        func        = ""
        control     = ""
        area        = ""
        description = ""
        links       = ""
    }

    $content.content = $content.content -replace`
        "using module `"..\\ORCA.psm1`"",`
        ""

    $content.content = "$orcaPrereqContent`n`n" + $content.content

    # Script Files
    Set-Content -Path "$repo\powershell\internal\orca\$($content.file)" -Value $content.content -Force

    $option = [Text.RegularExpressions.RegexOptions]::IgnoreCase
    $name = [regex]::Match($content.content, "this\.name=([\'\`"])(?'capture'.*)\1", $option)
    $pass = [regex]::Match($content.content, "this\.passText=([\'\`"])(?'capture'.*)\1", $option)
    $fail = [regex]::Match($content.content, "this\.failrecommendation=([\'\`"])(?'capture'.*)\1", $option)
    $control = [regex]::Match($content.content, "this\.control=([\'\`"])(?'capture'.*)\1", $option)
    $area = [regex]::Match($content.content, "this\.area=([\'\`"])(?'capture'.*)\1", $option)
    $func = [regex]::Match($content.file, "check-(?'capture'.*).ps1", $option) # Capture between check and .ps1
    $content.name = $name.Groups['capture'].Value
    $content.pass = $pass.Groups['capture'].Value
    $content.fail = $fail.Groups['capture'].Value + ($fail.Groups['capture'].Value -notmatch '\.$' ? '.' : '')
    $content.control = $control.Groups['capture'].Value
    $content.area = $area.Groups['capture'].Value
    $content.func = $func.Groups['capture'].Value

    $testScript = @"
# Generated on $(Get-Date) by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "$($content.func)", "EXO", "Security", "All" {
    It "$($content.func): $($content.name)" {
        `$result = Test-$($content.func)

        if(`$null -ne `$result) {
            `$result | Should -Be `$true -Because "$($content.pass)"
        }
    }
}
"@

    # Test Files
    Set-Content -Path "$repo\tests\orca\Test-$($content.func).Tests.ps1" -Value $testScript -Force
    #$testContents += $content

    $funcScript = @"
<#
.SYNOPSIS
    $($content.pass)

.DESCRIPTION
    Generated on $(Get-Date) by .\build\orca\Update-OrcaTests.ps1

.EXAMPLE
    Test-$($content.func)

    Returns true or false

.LINK
    https://maester.dev/docs/commands/Test-$($content.func)
#>
function Test-$($content.func){
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Test-$($content.func)"
    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return = `$null
    }elseif(!(Test-MtConnection SecurityCompliance)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return = `$null
    }

    if((`$__MtSession.OrcaCache.Keys|Measure-Object).Count -eq 0){
        Write-Verbose "OrcaCache not set, Get-ORCACollection"
        `$__MtSession.OrcaCache = Get-ORCACollection -SCC:`$true
    }
    `$Collection = `$__MtSession.OrcaCache
    `$obj = New-Object -TypeName $($content.func)
    try { # Handle "SkipInReport" which has a continue statement that makes this function exit unexpectedly
        `$obj.Run(`$Collection)
    } catch {
        throw
    } finally {
        if(`$obj.SkipInReport) {
            Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'The statement "SkipInReport" was specified by ORCA.'
        }
    }

    if(`$obj.CheckFailed) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason `$obj.CheckFailureReason
        return `$null
    }elseif(-not `$obj.Completed) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'Possibly missing license for specific feature.'
        return `$null
    }

    `$testResult = (`$obj.ResultStandard -eq "Pass" -or `$obj.ResultStandard -eq "Informational")

    `$resultMarkdown = "$($content.area + " - " + $content.name + " - " + $content.control)``n``n"
    if(`$testResult){
        `$resultMarkdown += "Well done. $($content.pass)``n``n%ResultDetail%"
    }else{
        `$resultMarkdown += "The configured settings are not set as recommended.``n``n%ResultDetail%"
    }

    `$passResult = "``u{2705} Pass"
    `$failResult = "``u{274C} Fail"
    `$skipResult = "``u{1F5C4} Skip"
    if (`$obj.ExpandResults) {
        `$resultDetail += "``n``n`$(If (-not [string]::IsNullOrEmpty(`$obj.Config[0].Object)) {"|`$(`$obj.ObjectType)"})`$(If (-not [string]::IsNullOrEmpty(`$obj.Config[0].ConfigItem)) {"|`$(`$obj.ItemName)"})`$(If (-not [string]::IsNullOrEmpty(`$obj.Config[0].ConfigData)) {"|`$(`$obj.DataType)"})|Result|``n"
        `$resultDetail += "`$(If (-not [string]::IsNullOrEmpty(`$obj.Config[0].Object)) {"|-"})`$(If (-not [string]::IsNullOrEmpty(`$obj.Config[0].ConfigItem)) {"|-"})`$(If (-not [string]::IsNullOrEmpty(`$obj.Config[0].ConfigData)) {"|-"})|-|``n"
        ForEach (`$result in `$obj.Config) {
            If (`$result.ResultStandard -eq "Pass") {
                `$objResult = `$passResult
            } ElseIf(`$result.ResultStandard -eq "Informational") {
                `$objResult = `$skipResult
            } Else {
                `$objResult = `$failResult
            }
            `$resultDetail += "`$(If (-not [string]::IsNullOrEmpty(`$result.Object)) {"|`$(`$result.Object)"})`$(If (-not [string]::IsNullOrEmpty(`$result.ConfigItem)) {"|`$(`$result.ConfigItem)"})`$(If (-not [string]::IsNullOrEmpty(`$result.ConfigData)) {"|`$(`$result.ConfigData)"})|`$objResult|``n"
        }
    }

    `$resultMarkdown = `$resultMarkdown -replace "%ResultDetail%", `$resultDetail

    Add-MtTestResultDetail -Result `$resultMarkdown

    return `$testResult
}
"@

    # Test Files
    Set-Content -Path "$repo\powershell\public\orca\Test-$($content.func).ps1" -Value $funcScript -Force
    $exports += "Test-$($content.func)"

    $description = [regex]::Match($content.content, "this\.Importance=([\'\`"])(?'capture'.*)\1", $option) # Capture between first identified apostrophe or qoute and it's last
    $content.description = $description.Groups['capture'].Value -replace '<[^>]+>','' # Remove HTML tags
    $links = [regex]::Match($content.content, "this.Links.*@{(?'capture'[^}]*)}", $option)
    $content.links = $links.Groups['capture'].Value | ConvertFrom-StringData

    $md = @"
$($content.description)

#### Remediation action
$($content.fail)

#### Related Links

"@

    $md += $($content.links.Keys|ForEach-Object{
        "`n* [$($_.Substring(1,$_.Length-2))]($(($content.links["$_"]).Substring(1,($content.links["$_"]).Length-2)))"
    })
    # MD Files
    Set-Content -Path "$repo\powershell\public\orca\Test-$($content.func).md" -Value $md -Force
}
@"
ScriptsToProcess = @(
    '.\internal\orca\orcaClass.ps1',
    $(
        $index = 1
        while($index -le $testFiles.Count){
            "    '.\internal\orca\$(($testFiles[$index]).Name)', '.\internal\orca\$(($testFiles[$index+1]).Name)', '.\internal\orca\$(($testFiles[$index+2]).Name)', `n"
            $index = $index+3
        }
    )
)

"@
@"
FunctionsToExport = @(
    $(
        $index = 1
        while($index -le $exports.Count){
            "    '$(($exports[$index]))', '$(($exports[$index+1]))', '$(($exports[$index+2]))', `n"
            $index = $index+3
        }
    )
)
"@
#endregion

Set-Location -Path $cwd
