BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force

    # The reverse of how Add-MtReportAttachment stores the content.
    function ConvertFrom-MtTestAttachment([string] $Content) {
        $stream = [System.IO.MemoryStream]::new([System.Convert]::FromBase64String($Content))
        $gzip = [System.IO.Compression.GZipStream]::new($stream, [System.IO.Compression.CompressionMode]::Decompress)
        $reader = [System.IO.StreamReader]::new($gzip, [System.Text.Encoding]::UTF8)
        try { $reader.ReadToEnd() } finally { $reader.Dispose() }
    }
}

Describe 'Add-MtReportAttachment' {
    BeforeEach {
        InModuleScope Maester { $__MtSession.ReportAttachments = $null }
    }

    It 'Stores HTML content compressed, with its name and size' {
        $html = '<!doctype html><html><body>' + ('Zero Trust ' * 1000) + '</body></html>'

        Add-MtReportAttachment -Name 'Zero Trust Assessment report' -Content $html

        $attachment = InModuleScope Maester { @($__MtSession.ReportAttachments) }
        $attachment.Count | Should -Be 1
        $attachment[0].Name | Should -BeExactly 'Zero Trust Assessment report'
        $attachment[0].Id | Should -Match '^[0-9a-f]{32}$'
        $attachment[0].ContentType | Should -Be 'text/html'
        $attachment[0].Encoding | Should -Be 'gzip+base64'
        $attachment[0].Size | Should -Be ([System.Text.Encoding]::UTF8.GetByteCount($html))
        $attachment[0].Content.Length | Should -BeLessThan $html.Length
        ConvertFrom-MtTestAttachment $attachment[0].Content | Should -BeExactly $html
    }

    It 'Reads a file, keeping its file name' {
        $path = Join-Path $TestDrive 'ZeroTrustAssessmentReport.html'
        Set-Content -LiteralPath $path -Value '<html>report</html>' -NoNewline -Encoding utf8NoBOM

        Add-MtReportAttachment -Name 'Report' -Path $path

        $attachment = InModuleScope Maester { @($__MtSession.ReportAttachments)[0] }
        $attachment.FileName | Should -Be 'ZeroTrustAssessmentReport.html'
        ConvertFrom-MtTestAttachment $attachment.Content | Should -BeExactly '<html>report</html>'
    }

    It 'Warns and adds nothing when the file does not exist' {
        Add-MtReportAttachment -Name 'Report' -Path (Join-Path $TestDrive 'missing.html') -WarningVariable warnings -WarningAction SilentlyContinue

        $warnings | Should -HaveCount 1
        InModuleScope Maester { $__MtSession.ReportAttachments } | Should -BeNullOrEmpty
    }

    It 'Replaces an attachment of the same name and keeps the others' {
        Add-MtReportAttachment -Name 'Report' -Content '<html>first</html>'
        Add-MtReportAttachment -Name 'Other' -Content '<html>other</html>'
        Add-MtReportAttachment -Name 'Report' -Content '<html>second</html>'

        $attachments = InModuleScope Maester { @($__MtSession.ReportAttachments) }
        $attachments.Name | Should -Be @('Other', 'Report')
        ConvertFrom-MtTestAttachment ($attachments | Where-Object Name -EQ 'Report').Content | Should -BeExactly '<html>second</html>'
    }

    It 'Records the native test that added it' {
        $previous = [Maester.Engine.MtSession]::EnterTest('MP.ZTA')
        try {
            Add-MtReportAttachment -Name 'Report' -Content '<html></html>'
        } finally {
            [Maester.Engine.MtSession]::ExitTest($previous)
        }

        InModuleScope Maester { @($__MtSession.ReportAttachments)[0].TestId } | Should -Be 'MP.ZTA'
    }

    It 'Is cleared at the start of each run' {
        Add-MtReportAttachment -Name 'Report' -Content '<html></html>'

        InModuleScope Maester { Clear-ModuleVariable; $__MtSession.ReportAttachments } | Should -BeNullOrEmpty
    }
}
