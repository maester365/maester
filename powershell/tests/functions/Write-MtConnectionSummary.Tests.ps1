BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force

    # Rebuild the console lines from Write-Host records, joining -NoNewline segments.
    function Get-SummaryText {
        param([object[]] $Connection)
        $records = InModuleScope Maester -Parameters @{ Connection = $Connection } {
            param($Connection)
            Write-MtConnectionSummary -Connection $Connection
        } 6>&1
        $text = ''
        foreach ($record in $records) {
            $text += [string]$record.MessageData.Message
            if (-not $record.MessageData.NoNewLine) { $text += "`n" }
        }
        $text
    }
}

Describe 'Write-MtConnectionSummary' {
    It 'Lists services in a fixed order with Microsoft Graph first and display names' {
        $text = Get-SummaryText -Connection @(
            [PSCustomObject]@{ Service = 'SharePointOnline'; Status = 'Skipped'; Details = '-SharePointClientId was not provided' }
            [PSCustomObject]@{ Service = 'SecurityCompliance'; Status = 'Connected'; Details = 'admin@contoso.com' }
            [PSCustomObject]@{ Service = 'Graph'; Status = 'Connected'; Details = 'admin@contoso.com' }
        )

        $lines = $text -split "`n" | Where-Object { $_ -match '\S' }
        $lines[0] | Should -Match '^Service\s+Status\s+Details$'
        $lines[2] | Should -Match '^Microsoft Graph\s+Connected\s+admin@contoso\.com$'
        $lines[3] | Should -Match '^Security & Compliance\s+Connected\s+admin@contoso\.com$'
        $lines[4] | Should -Match '^SharePoint Online\s+Skipped\s+-SharePointClientId was not provided$'
    }

    It 'Shows the -Verbose hint only when a service did not connect' {
        $connected = Get-SummaryText -Connection @([PSCustomObject]@{ Service = 'Graph'; Status = 'Connected'; Details = 'admin@contoso.com' })
        $skipped = Get-SummaryText -Connection @([PSCustomObject]@{ Service = 'Dataverse'; Status = 'Skipped'; Details = 'No environment found' })

        $connected | Should -Not -Match '-Verbose'
        $skipped | Should -Match 'run Connect-Maester again with -Verbose'
    }

    It 'Keeps each row on one line and shortens long details' {
        $text = Get-SummaryText -Connection @(
            [PSCustomObject]@{ Service = 'ExchangeOnline'; Status = 'Failed'; Details = "First line`nSecond line " + ('x' * 200) }
        )

        $row = $text -split "`n" | Where-Object { $_ -match '^Exchange Online' }
        $row | Should -HaveCount 1
        $row | Should -Match 'Failed\s+First line Second line x+\.\.\.$'
        $row.Length | Should -BeLessOrEqual ('Exchange Online  '.Length + 'Failed  '.Length + 100)
    }

    It 'Writes nothing when no service was attempted' {
        Get-SummaryText -Connection @() | Should -BeNullOrEmpty
    }
}
