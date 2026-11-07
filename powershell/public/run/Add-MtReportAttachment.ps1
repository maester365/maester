function Add-MtReportAttachment {
    <#
    .SYNOPSIS
    Embeds an HTML report from another tool, or data for a built-in report view, in the Maester HTML report.

    .DESCRIPTION
    Call this from a test, an instance source or a pack when the tool it runs writes its own single-file
    HTML report (for example the Microsoft Zero Trust Assessment). The file is read at once, so the tool's
    output folder can be deleted afterwards.

    The HTML report shows a button for each HTML attachment on the overview page, and on the result of the test
    that added it. The button shows the attached report inside the Maester report, beside its navigation, with an option to open it in a new browser tab. The report is stored compressed
    (gzip, then Base64), so a 10 MB report adds about 2 MB to the Maester report.

    With -ContentType application/json the attachment is data that a built-in view of the report reads, found by
    its Name (for example 'zero-trust-workshop', the Zero Trust plan of the Zero Trust Assessment pack). A JSON
    attachment is not shown as a button. It is stored compressed in the same way.

    Attachments are kept only in the HTML report and the results that Invoke-Maester -PassThru returns. The
    JSON results file lists each attachment's name and size without its content. When -RedactUserIdentity is
    used, the HTML report redacts JSON attachments the way it redacts the results, and leaves HTML attachments
    out, because Maester cannot redact another tool's report.

    The attached page runs in a sandboxed frame, with its scripts in an origin of their own, so it cannot read or
    change the Maester report or its data. Adding a second attachment with the same name from the same test
    replaces the first.

    .EXAMPLE
    Add-MtReportAttachment -Name 'Zero Trust Assessment' -Path ./zt/ZeroTrustAssessmentReport.html

    Embeds the Zero Trust Assessment report in the Maester report of this run.

    .EXAMPLE
    Add-MtReportAttachment -Name 'Tenant inventory' -Content $html

    Embeds an HTML page built in memory.

    .EXAMPLE
    Add-MtReportAttachment -Name 'zero-trust-workshop' -Content $json -ContentType 'application/json'

    Adds data for the report's Zero Trust plan view.

    .LINK
    https://maester.dev/docs/commands/Add-MtReportAttachment
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    [OutputType([void])]
    param(
        # The label of the button that opens the attachment, for example 'Zero Trust Assessment'. For a JSON
        # attachment, the name the report view reads it by, for example 'zero-trust-workshop'.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        # Path of a single-file HTML report to embed.
        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        # The HTML or JSON to embed, when it is not in a file.
        [Parameter(Mandatory, ParameterSetName = 'Content')]
        [ValidateNotNullOrEmpty()]
        [string] $Content,

        # text/html (the default) for a report the user opens from a button; application/json for data that a
        # built-in view of the report reads.
        [Parameter()]
        [ValidateSet('text/html', 'application/json')]
        [string] $ContentType = 'text/html'
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
            ContentType = $ContentType
            FileName    = $fileName
            Size        = $bytes.Length
            Encoding    = 'gzip+base64'
            Content     = $compressed
        })
    Write-Verbose ("Attached '{0}' to the report: {1:N1} MB, {2:N1} MB embedded." -f $Name, ($bytes.Length / 1MB), ($compressed.Length / 1MB))
}
