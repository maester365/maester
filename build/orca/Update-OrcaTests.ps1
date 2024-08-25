

# Get local repo path and set working dir
$repo = & git rev-parse --show-toplevel
Set-Location -Path $repo\build\orca

# Get orca remote repo
#$orca = "https://github.com/cammurray/orca.git"
#& git clone $orca

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
    }elseif($function){
        $text = $codeBlock.Extent.Text
    }else{
        $codeBlocks += $codeBlock.Extent.Text
    }

    if($function){
        $function = "# Generated on $(Get-Date) by .\build\orca\Update-OrcaTests.ps1`n`n"
        $function += $text
        $function = $function -replace "Write\-Host","Write-Verbose"
        Set-Content -Path "$repo\powershell\internal\orca\$($prereq.name).ps1" -Value $function -Force
    }
}
Write-Verbose "Found $($codeBlocks.Count)/$($prereqs.Count) code blocks"

$orcaPrereqContent = "# Generated on $(Get-Date) by .\build\orca\Update-OrcaTests.ps1`n`n"
$orcaPrereqContent += $codeBlocks -join "`n`n"
$orcaPrereqContent = $orcaPrereqContent -replace "Write\-Host","Write-Verbose"
Set-Content -Path $repo\powershell\internal\orca\orcaClass.ps1 -Value $orcaPrereqContent -Force
#endregion

#region tests
$testFiles = Get-ChildItem $repo\build\orca\orca\Checks\*.ps1
foreach($file in $testFiles){
    $content = [pscustomobject]@{
        file    = $file.Name
        content = Get-Content $file -Raw
        name    = ""
        pass    = ""
        fail    = ""
        func    = ""
        control = ""
        area    = ""
    }

    $content.content = "# Generated on $(Get-Date) by .\build\orca\Update-OrcaTests.ps1`n`n" + $content.content

    $content.content = $content.content -replace`
        "using module `"..\\ORCA.psm1`"",`
        "using module Maester"

    # Script Files
    Set-Content -Path "$repo\powershell\internal\orca\$($content.file)" -Value $content.content -Force

    $option = [Text.RegularExpressions.RegexOptions]::IgnoreCase
    $name = [regex]::Match($content.content,"this.name.*[\'\`"](?'capture'.*)[\'\`"]",$option)
    $pass = [regex]::Match($content.content,"this.passtext.*[\'\`"](?'capture'.*)[\'\`"]",$option)
    $fail = [regex]::Match($content.content,"this.failtext.*[\'\`"](?'capture'.*)[\'\`"]",$option)
    $control = [regex]::Match($content.content,"this.control.*[\'\`"](?'capture'.*)[\'\`"]",$option)
    $area = [regex]::Match($content.content,"this.area.*[\'\`"](?'capture'.*)[\'\`"]",$option)
    $content.name = $name.Groups['capture'].Value
    $content.pass = $pass.Groups['capture'].Value
    $content.fail = $fail.Groups['capture'].Value
    $content.control = $control.Groups['capture'].Value
    $content.area = $area.Groups['capture'].Value

    $content.func = $content.file.Substring(6,7)

    $testScript = @"
# Generated on $(Get-Date) by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "$($content.file.Substring(6,7))", "EXO", "Security", "All" {
    It "$($content.file.Substring(6,7)): $($content.name)" {

        if(!(Test-MtConnection ExchangeOnline)){
            Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
            `$result = `$null
        }elseif(!(Test-MtConnection SecurityCompliance)){
            Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
            `$result = `$null
        }else{
            `$Collection = Get-ORCACollection
            `$obj = New-Object -TypeName $($content.func)
            `$obj.Run(`$Collection)
            `$result = (`$obj.Completed -and `$obj.Result -eq "Pass")

            `$resultMarkdown = "$($content.area + " - " + $content.name + " - " + $content.control)``n``n"
            if(`$result){
                `$resultMarkdown += "Well done. $($content.pass)"
            }else{
                `$resultMarkdown += "Your tenant did not pass. $($content.fail)"
            }

            Add-MtTestResultDetail -Result `$resultMarkdown
        }

        if(`$null -ne `$result) {
            `$result | Should -Be `$true -Because "$($content.pass)"
        }
    }
}
"@

    # Test Files
    Set-Content -Path "$repo\tests\orca\check-$($content.func).Tests.ps1" -Value $testScript -Force
    #$testContents += $content
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
#endregion