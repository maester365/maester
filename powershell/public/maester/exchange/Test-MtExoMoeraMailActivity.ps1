<#
.SYNOPSIS
    Checks the sent mail activity for MOERA addresses in the past 7 days.

.DESCRIPTION
    This command retrieves the mail actiivty for the past 7 days, and checks
    for any sent mail from MOERA addresses.

.EXAMPLE
    Test-MtExoMoeraMailActivity

    Returns true if no sent mail activity from MOERA addresses in past 7 days.

.LINK
    https://maester.dev/docs/commands/Test-MtExoMoeraMailActivity
#>
function Test-MtExoMoeraMailActivity {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        Write-Verbose "Checking current report obfuscation"
        $reportSettings = Invoke-MgGraphRequest -Method Get -Uri "v1.0/admin/reportSettings"
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }

    if ($reportSettings.displayConcealedNames -and !((Get-MgContext).Scopes -contains "ReportSettings.ReadWrite.All")) {
        Add-MtTestResultDetail -SkippedBecause LimitedPermissions
        return $null
    } elseif ($reportSettings.displayConcealedNames) {
        try {
            Write-Verbose "Disabling report obfuscation"
            Invoke-MgGraphRequest -Method PATCH -Uri "v1.0/admin/reportSettings" -Body (@{displayConcealedNames = $false}|ConvertTo-Json)
        } catch {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
            return $null
        }
    }
    $file = "$([System.IO.Path]::GetTempPath())maester-EmailActivityUserDetail.csv"

    try {
            Write-Verbose "Downloading report"
            Invoke-MgGraphRequest -Uri "v1.0/reports/getEmailActivityUserDetail(period='D7')" -OutputFilePath $file
        } catch {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
    $results = Import-Csv $file
    $filteredResults = $results|Where-Object {
        $_."User Principal Name" -like "*.onmicrosoft.com" -and `
        $_."Send Count" -gt 0
    }

    $testResult = ($filteredResults|Measure-Object).Count -gt 0
    if (!$testResult){
        $testResultMarkdown = "Well Done. Microsoft Online Exchange Routing Addresses (MOERA) are not in use for sending email in the past 7 days.`n`n"
    } else {
        $testResultMarkdown = "Microsoft Online Exchange Routing Addresses (MOERA) are in use for sending email in the past 7 days.`n`n"
        $testResultMarkdown += "| User Principal Name | Send Count |`n"
        $testResultMarkdown += "| --- | --- |`n"
        foreach ($result in $filteredResults){
            $testResultMarkdown += "| $($result."User Principal Name") | $($result."Send Count") |`n"
        }
    }

    if ($reportSettings.displayConcealedNames) {
        try {
            Write-Verbose "Enabling report obfuscation"
            Invoke-MgGraphRequest -Method PATCH -Uri "v1.0/admin/reportSettings" -Body (@{displayConcealedNames = $true}|ConvertTo-Json)
        } catch {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
            return $null
        }
    }
    Write-Verbose "Removing temp report file"
    Remove-Item $file

    Write-Verbose $testResultMarkdown|ConvertTo-Json -Compress
    Add-MtTestResultDetail -Result $testResultMarkdown

    return !$result
}