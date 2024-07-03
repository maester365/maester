
    <#
    .Synopsis
    Generates Maester tests for EntraOps Privileged EAM at https://github.com/Cloud-Architekt/EntraOps

    .DESCRIPTION
    * Downloads the latest version from https://github.com/Cloud-Architekt/EntraOps/blob/main/Queries/PowerShell/PrivilegedEAM.yaml
    * Generates Maester tests for each test defined in the YAML file

    .EXAMPLE
        ./build/entraops/Update-EntraOpsTests.ps1
    #>

    param (
        # Folder where generated test file should be written to.
        [string] $TestFilePath = "./tests/EntraOps/Test-EntraOps.Generated.Tests.ps1",

        # Folder where docs should be generated
        [string] $DocsPath = "./website/docs/tests/entraops",

        [string] $PowerShellFunctionsPath = "./powershell/public/entraops",

        # URL to the EntraOps config file
        [string] $EntraOpsQueriesDownloadUrl = 'https://github.com/Cloud-Architekt/EntraOps/blob/main/Queries/PowerShell/PrivilegedEAM.yaml'
    )


    Function UpdateTemplate($template, $check, $docName) {
        $output = ''
            $output = $template
            $output = $output -replace '%DocName%', $docName
            $output = $output -replace '%DisplayName%', $check.Name
            $output = $output -replace '%CheckId%', $check.Id
            $output = $output -replace '%Category%', $check.Category
            $output = $output -replace '%Severity%', $check.Severity
            $output = $output -replace '%Description%', $check.Description
            $output = $output -replace '%EvaluateResult%', $check.EvaluateResult
            $output = $output -replace '%PSFunctionName%', $psFunctionName

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

    Function GetEntraOpsPsFunctionName($CheckId) {
        $powerShellFunctionName = "Test-Mt$($CheckId)"
        return $powerShellFunctionName
    }

    # Start by getting the latest EntraOps config
    #$Queries = Invoke-WebRequest -Uri $EntraOpsQueriesDownloadUrl | ConvertFrom-Yaml
    $Checks = Get-Content -Path /Users/thomas/Coding/maester/build/entraops/PrivilegedEAM.yaml | ConvertFrom-Yaml

    # Remove previously generated files
    Get-ChildItem -Path $DocsPath -Filter "*.md" -Exclude "readme.md" | Remove-Item -Force
    Get-ChildItem -Path $PowerShellFunctionsPath -Filter "Test-MtEOPS*" | Remove-Item -Force

    $docsTemplate = GetTemplate $DocsPath
    $psTemplate = GetTemplate $PowerShellFunctionsPath "@template.EntraOpsTests.txt" # Use the .txt extension to avoid running the script
    $psMarkdownTemplate = GetTemplate $PowerShellFunctionsPath "@template.EntraOpsTests.md"

    $sb = [System.Text.StringBuilder]::new()

    #region Microsoft Graph checks
    foreach ($Check in $Checks) {
        Write-Verbose "Generating test for $($Check.Name)"

        $testOutputList = [System.Text.StringBuilder]::new()
        $docName = $Check.Id

            $testTemplate = @'
Describe "%DisplayName%" -Tag "EntraOps", "%Category%", "%CheckId%" {
    It "%CheckId%: %Category% - %DisplayName%. See https://maester.dev/docs/tests/%DocName%" {


    <#
        Compare if query of %DisplayName% is true to the expected result
        %EvaluateResult%
    #>

    if ( %SkipCondition% ) {
        Add-MtTestResultDetail -SkippedBecause %SkippedBecause%
    } else {
        %PSFunctionName% | Should -Be True
    }

}
}
'@

            $testTemplate = $testTemplate.Replace('%SkipCondition%', $Check.SkipCondition)
            if($Check.SkipCondition -eq "(!(Get-AzContext) -and !(Get-Module EntraOps))") {
                $testTemplate = $testTemplate.Replace('%SkippedBecause%', '"EntraOps module has not been loaded and connect to Azure PowerShell is missing. Import module and connect to EntraOps before executing Maester by using the following cmdlets:`nConnect-EntraOps -AuthenticationType `"UserInteractive`" -TenantName `"<YourTenantName>`"`n"')
            } elseif ($Check.SkipCondition -like '(!$EntraOpsPrivilegedEamData*') {
                $testTemplate = $testTemplate.Replace('%SkippedBecause%', '"Classification data of EntraOps missing! Run EntraOps before executing Maester by using the following cmdlets:`n `n Connect-EntraOps -AuthenticationType `"UserInteractive`" -TenantName `"<YourTenantName>`"`n`n $EntraOpsPrivilegedEamData = Get-EntraOpsPrivilegedEAM`nAll checks with data source of EntraOps will be skipped!"')
            }

            $psFunctionName = GetEntraOpsPsFunctionName -CheckId $Check.Id
            $testOutput = UpdateTemplate -template $testTemplate -check $Check -docName $docName
            $testOutput = $testOutput.Replace('%Query%', $Check.Query)
            $psOutput = UpdateTemplate -template $psTemplate -check $Check -docName $docName
            $psOutput = $psOutput.Replace('%Query%', $Check.Query)


            $docsOutput = UpdateTemplate -template $docsTemplate -check $Check -docName $docName -isDoc $true
            $docsOutput = $docsOutput.Replace('%Query%', $Check.Query)
            $psMarkdownOutput = UpdateTemplate -template $psMarkdownTemplate -check $Check -docName $docName -isDoc $true
            $psMarkdownOutput = $psMarkdownOutput.Replace('%Query%', $Check.Query)


            if ($testOutput -ne '') {
                [void]$testOutputList.AppendLine($testOutput)
                CreateFile $DocsPath "$docName.md" $docsOutput
                CreateFile $PowerShellFunctionsPath "$psFunctionName.ps1" $psOutput
                CreateFile $PowerShellFunctionsPath "$psFunctionName.md" $psMarkdownOutput
            } else {
            Write-Warning "$($control.CheckId) - $($control.DisplayName) has no recommended value!"
        }

        if ($testOutputList.Length -ne 0) {
            [void]$sb.AppendLine($testOutputList)
        }
    }
    #endregion

    $output = @'
BeforeDiscovery {
<DiscoveryFromJson>}

'@

    # Replace placeholder with Discovery checks from definition in EntraOps JSON
    #$output = $output.Replace('<DiscoveryFromJson>', ($Discovery | Out-String))

    $output = @'
BeforeDiscovery {
    if(!$EntraOpsPrivilegedEamData) {
        $RbacSystems = ("EntraID", "IdentityGovernance", "DeviceManagement", "ResourceApps")
        if($DefaultFolderClassifiedEam) {
            $EntraOpsPrivilegedEamData = foreach ($RbacSystem in $RbacSystems) {
                if ((Test-Path $DefaultFolderClassifiedEam/$RbacSystem/$RbacSystem.json)) {
                    Get-Content -Path $DefaultFolderClassifiedEam/$RbacSystem/$RbacSystem.json `
                    | ConvertFrom-Json -Depth 10
                }
                else {
                    Write-Warning "No EntraOps data from $($RbacSystem)!"
                }
            }
            New-Variable -Name EntraOpsPrivilegedEamData -Value $EntraOpsPrivilegedEamData -Scope Script -Force
        } else {
           Write-Error `
            'Run EntraOps before executing Maester by using the following cmdlets:
                    Connect-EntraOps -AuthenticationType "UserInteractive" -TenantName "<YourTenantName>"
                    Save-EntraOpsPrivilegedEAMJson -RBACSystems @("EntraID", "ResourceApps", "IdentityGovernance")
            '

         }
    } else {
        Write-Warning "EntraOpsPrivilegedEamData already as variable available!"
    }
}

'@

$output += $sb.ToString()
$output | Out-File $TestFilePath -Encoding utf8
