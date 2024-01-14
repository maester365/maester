<#
 .Synopsis
  Generates Maester tests for the Azure AD Attack Defense Security Config defined at https://github.com/Cloud-Architekt/AzureAD-Attack-Defense

  .DESCRIPTION
  * Downloads the latest version from https://github.com/Cloud-Architekt/AzureAD-Attack-Defense/blob/AADSCAv3/config/AadSecConfig.json
  * Generates Maester tests for each test defined in the JSON file

  .EXAMPLE
    Update-AADSCA -TestFilePath "./tests/AADSCAv3/Test-AADSCAv3.Generated.Tests.ps1"
#>

param (
    # Folder where generated test file should be written to.
    [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $true)]
    [string] $TestFilePath
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
    # if ($RecommendedValue -eq $null) {
    #     return $null
    # }
    # if ($RecommendedValue -eq $true) {
    #     return '$true'
    # }
    # if ($RecommendedValue -eq $false) {
    #     return '$false'
    # }
    return "'$RecommendedValue'"
}

Function GetPropertyName($CurrentValue) {
    $CurrentValue = $CurrentValue.Replace('value.', '')
    return $CurrentValue
}

$aadsc = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Cloud-Architekt/AzureAD-Attack-Defense/AADSCAv3/config/AadSecConfig.json' | ConvertFrom-Json

$template = @'
Describe "AADSC: %ControlName% - %DisplayName%" -Tag "AADSCA", "Security", "All", "%Severity%" {
    It "AADSC-%Name%:" {
        $result = Invoke-MtGraphRequest -RelativeUri "%RelativeUri%" -ApiVersion %ApiVersion%
        $result.%CurrentValue% | Should -Be %RecommendedValue% -Because "%RelativeUri%/%CurrentValue% should be %RecommendedValue% but was $($result.%CurrentValue%)"
    }
}
'@

$sb = [System.Text.StringBuilder]::new()

foreach ($control in $aadsc) {
    Write-Verbose "Generating test for $($control.ControlName)"
    $relativeUri = GetRelativeUri($control.GraphUri)
    $apiVersion = GetVersion($control.GraphUri)

    foreach ($controlItem in $control.Controls) {
        Write-Verbose "   > $($controlItem.Name) - $($controlItem.DisplayName)"
        $recommendedValue = GetRecommendedValue($controlItem.RecommendedValue)
        $currentValue = GetPropertyName($controlItem.CurrentValue)

        $output = $template
        $output = $output -replace '%ControlName%', $control.ControlName
        $output = $output -replace '%Severity%', $controlItem.Severity
        $output = $output -replace '%DisplayName%', $controlItem.DisplayName
        $output = $output -replace '%Name%', $controlItem.Name
        $output = $output -replace '%RelativeUri%', $relativeUri
        $output = $output -replace '%ApiVersion%', $apiVersion
        $output = $output -replace '%RecommendedValue%', $recommendedValue
        $output = $output -replace '%CurrentValue%', $CurrentValue

        if ($CurrentValue -eq '' -or $control.ControlName -eq '') {
            Write-Warning 'Skipping'
        } else {
            [void]$sb.AppendLine($output)
        }

    }
}
$output = $sb.ToString()

$output | Out-File $TestFilePath -Encoding utf8
