function Add-MtReportAttachment {
    <#
    .SYNOPSIS
    Embeds an HTML report from another tool in the Maester HTML report, opened with one click.

    .DESCRIPTION
    Call this from a test, an instance source or a pack when the tool it runs writes its own single-file
    HTML report (for example the Microsoft Zero Trust Assessment). The file is read at once, so the tool's
    output folder can be deleted afterwards.

    The HTML report shows a button for each attachment on the overview page, and on the result of the test
    that added it. The button opens the attached report in a new browser tab. The report is stored compressed
    (gzip, then Base64), so a 10 MB report adds about 2 MB to the Maester report.

    Attachments are kept only in the HTML report and the results that Invoke-Maester -PassThru returns. The
    JSON results file lists each attachment's name and size without its content. The HTML report leaves
    attachments out when -RedactUserIdentity is used, because Maester cannot redact another tool's report.

    The attached page runs in the browser with the same access as the Maester report, so only attach reports
    written by tools you trust. Adding a second attachment with the same name from the same test replaces the
    first.

    .EXAMPLE
    Add-MtReportAttachment -Name 'Zero Trust Assessment report' -Path ./zt/ZeroTrustAssessmentReport.html

    Embeds the Zero Trust Assessment report in the Maester report of this run.

    .EXAMPLE
    Add-MtReportAttachment -Name 'Tenant inventory' -Content $html

    Embeds an HTML page built in memory.

    .LINK
    https://maester.dev/docs/commands/Add-MtReportAttachment
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    [OutputType([void])]
    param(
        # The label of the button that opens the attachment, for example 'Zero Trust Assessment report'.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        # Path of a single-file HTML report to embed.
        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        # The HTML to embed, when it is not in a file.
        [Parameter(Mandatory, ParameterSetName = 'Content')]
        [ValidateNotNullOrEmpty()]
        [string] $Content
    )

    if ($PSCmdlet.ParameterSetName -eq 'Path') {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            Write-Warning "Add-MtReportAttachment: $Path was not found, so '$Name' is not attached to the report."
            return
        }
        $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path).ProviderPath)
        $fileName = [System.IO.Path]::GetFileName($Path)
    } else {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Content)
        $fileName = $null
    }

    $buffer = [System.IO.MemoryStream]::new()
    try {
        $gzip = [System.IO.Compression.GZipStream]::new($buffer, [System.IO.Compression.CompressionLevel]::SmallestSize, $true)
        try { $gzip.Write($bytes, 0, $bytes.Length) } finally { $gzip.Dispose() }
        $compressed = [System.Convert]::ToBase64String($buffer.ToArray())
    } finally {
        $buffer.Dispose()
    }

    # The test that added it, so the report can show the button on that test's result too.
    $testId = [Maester.Engine.MtSession]::GetCurrentTest()

    if (-not $__MtSession.ReportAttachments) { $__MtSession.ReportAttachments = [System.Collections.Generic.List[object]]::new() }
    $existing = @($__MtSession.ReportAttachments | Where-Object { $_.Name -eq $Name -and $_.TestId -eq $testId })
    foreach ($item in $existing) { $null = $__MtSession.ReportAttachments.Remove($item) }

    $__MtSession.ReportAttachments.Add([pscustomobject][ordered]@{
            Id          = [guid]::NewGuid().ToString('n')
            Name        = $Name
            TestId      = $testId
            ContentType = 'text/html'
            FileName    = $fileName
            Size        = $bytes.Length
            Encoding    = 'gzip+base64'
            Content     = $compressed
        })
    Write-Verbose ("Attached '{0}' to the report: {1:N1} MB, {2:N1} MB embedded." -f $Name, ($bytes.Length / 1MB), ($compressed.Length / 1MB))
}
