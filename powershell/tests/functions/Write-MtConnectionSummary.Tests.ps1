BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force

    # Rebuild the console text from Write-Host records, honouring -NoNewline.
    function Get-HostText ([object[]] $Records) {
        $text = ''
        foreach ($record in $Records) {
            if ($record -isnot [System.Management.Automation.InformationRecord]) { continue }
            $message = $record.MessageData
            $text += "$($message.Message)"
            if (-not $message.NoNewLine) { $text += "`n" }
        }
        $text
    }
}

Describe 'Write-MtConnectionSummary' {
    It 'Prints the services in a fixed order with their status and details' {
        $summary = @(
            [pscustomobject]@{ Service = 'SharePoint Online'; Status = 'Skipped'; Details = '-SharePointClientId was not provided' }
            [pscustomobject]@{ Service = 'Azure'; Status = 'Connected'; Details = 'admin@contoso.com' }
            [pscustomobject]@{ Service = 'Microsoft Graph'; Status = 'Connected'; Details = 'admin@contoso.com' }
        )

        $lines = (Get-HostText (InModuleScope Maester -Parameters @{ Summary = $summary } { param($Summary) Write-MtConnectionSummary -Summary $Summary 6>&1 })) -split "`n"

        $lines | Should -Contain ('{0}  {1}  {2}' -f 'Service'.PadRight(17), 'Status'.PadRight(9), 'Details')
        $rows = $lines | Where-Object { $_ -match '^(Microsoft Graph|Azure|SharePoint Online)\s' }
        $rows[0] | Should -Match '^Microsoft Graph\s+Connected\s+admin@contoso\.com$'
        $rows[1] | Should -Match '^Azure\s+Connected\s+admin@contoso\.com$'
        $rows[2] | Should -Match '^SharePoint Online\s+Skipped\s+-SharePointClientId was not provided$'
        $lines | Should -Contain 'For more details on each connection, run Connect-Maester with -Verbose.'
    }

    It 'Keeps only the first line of a detail and shortens long ones' {
        $longError = "Unable to load shared library 'kernel32.dll' or one of its dependencies. " + ('x' * 200) + "`ndlopen(kernel32.dll.dylib) tried: ..."
        $summary = @([pscustomobject]@{ Service = 'Microsoft Teams'; Status = 'Failed'; Details = $longError })

        $text = Get-HostText (InModuleScope Maester -Parameters @{ Summary = $summary } { param($Summary) Write-MtConnectionSummary -Summary $Summary 6>&1 })
        $row = ($text -split "`n") | Where-Object { $_ -like 'Microsoft Teams*' }

        $row | Should -Match "Failed\s+Unable to load shared library 'kernel32\.dll'"
        $row | Should -Match '\.\.\.$'
        $row | Should -Not -Match 'dlopen'
        ($row -replace '^Microsoft Teams\s+Failed\s+', '').Length | Should -BeLessOrEqual 110
    }

    It 'Prints nothing when no service was attempted' {
        InModuleScope Maester { Write-MtConnectionSummary -Summary @() 6>&1 } | Should -BeNullOrEmpty
    }
}
