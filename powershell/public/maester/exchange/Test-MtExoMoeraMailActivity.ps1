function Test-MtExoMoeraMailActivity {
    <#
    .SYNOPSIS
        Checks the sent mail activity for MOERA addresses in the past 7 days.

    .DESCRIPTION
        This command retrieves the mail activity for the past 7 days, and checks
        for any sent mail from MOERA addresses.

    .EXAMPLE
        Test-MtExoMoeraMailActivity

        Returns true if no sent mail activity from MOERA addresses in past 7 days.

    .LINK
        https://maester.dev/docs/commands/Test-MtExoMoeraMailActivity
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    begin {
        if (!(Test-MtConnection Graph)) {
            Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
            return $null
        }

        # Prepare temp file for report download
        $file = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "Maester-EmailActivityUserDetail-$(Get-Date -Format yyMMddHHmmss).csv"

        # Track if we disabled obfuscation to re-enable it later
        $obfuscationWasDisabled = $false
    }

    process {
        try {
            Write-Verbose 'Checking current report obfuscation'
            $reportSettings = Invoke-MgGraphRequest -Method Get -Uri 'v1.0/admin/reportSettings'
        } catch {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
            return $null
        }

        # Check if report obfuscation is enabled (displayConcealedNames) and if we have the necessary permissions to disable it
        # Note: This endpoint requires ReportSettings.ReadWrite.All permission (application permission, not delegated)
        # and the application identity must have appropriate admin roles assigned (Reports Administrator or Security Administrator)
        if ($reportSettings.displayConcealedNames -and ((Get-MgContext).Scopes -contains 'ReportSettings.ReadWrite.All')) {
            try {
                Write-Verbose 'Disabling report obfuscation'
                [void](Invoke-MgGraphRequest -Method PATCH -Uri 'v1.0/admin/reportSettings' -Body (@{displayConcealedNames = $false } | ConvertTo-Json))
                $obfuscationWasDisabled = $true
            } catch {
                Write-Verbose "Failed to disable report obfuscation: $_. Continuing with obfuscated data."
            }
        } elseif ($reportSettings.displayConcealedNames) {
            Write-Verbose 'Report obfuscation is enabled but insufficient permissions to disable it. Continuing without de-obfuscating user details.'
        }

        try {
            Write-Verbose 'Downloading report'
            $previousProgressPreference = $ProgressPreference # save progressPreference
            $ProgressPreference = 'SilentlyContinue'
            Invoke-MgGraphRequest -Uri "v1.0/reports/getEmailActivityUserDetail(period='D7')" -OutputFilePath $file
        } catch {
            # Unable to download report
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
            return $null
        } finally {
            # Always restore progressPreference, even if exception occurs
            $ProgressPreference = $previousProgressPreference
        }
        $results = Import-Csv $file -ErrorVariable ImportCsvError

        if (-not $results) {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError "Failed to import CSV report: $ImportCsvError"
            return $null
        }

        # Filter for MOERA addresses (*.onmicrosoft.com) that have sent mail
        # MOERA addresses are not intended for sending email and should not be used
        $filteredResults = $results | Where-Object {
            $_.'User Principal Name' -like '*.onmicrosoft.com' -and `
                $_.'Send Count' -gt 0
        }

        # Return true (pass) if no results found; false (fail) if any results found.
        [bool]$testResult = ($filteredResults | Measure-Object).Count -eq 0
        if ($testResult) {
            $testResultMarkdown = "Well Done. Microsoft Online Exchange Routing Addresses (MOERA) are not in use for sending email in the past 7 days.`n`n"
        } else {
            $testResultMarkdown = "Microsoft Online Exchange Routing Addresses (MOERA) are in use for sending email in the past 7 days.`n`n"
            $testResultMarkdown += "| User Principal Name | Send Count |`n"
            $testResultMarkdown += "| --- | --- |`n"
            foreach ($result in $filteredResults) {
                $testResultMarkdown += "| $($result.'User Principal Name') | $($result.'Send Count') |`n"
            }
        }

        Write-Verbose $testResultMarkdown
        Add-MtTestResultDetail -Result $testResultMarkdown

        return $testResult
    }

    end {
        # Re-enable report obfuscation if we disabled it
        if ($obfuscationWasDisabled) {
            try {
                Write-Verbose 'Re-enabling report obfuscation'
                [void](Invoke-MgGraphRequest -Method PATCH -Uri 'v1.0/admin/reportSettings' -Body (@{displayConcealedNames = $true } | ConvertTo-Json))
            } catch {
                # If we fail to re-enable obfuscation, log a warning but do not fail the test
                Write-Warning "Failed to re-enable report obfuscation: $_"
            }
        }

        Write-Verbose 'Removing temp report file'
        Remove-Item $file -ErrorAction SilentlyContinue
    }
}
