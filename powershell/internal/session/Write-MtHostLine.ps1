function Write-MtHostLine {
    <#
    .SYNOPSIS
    Writes a line straight to the host, while a test runs, without disturbing the console renderer.

    .DESCRIPTION
    Write-Host in a test goes to the information stream, which the engine keeps on the test's result and
    replays when the test has finished. Write-MtTestOutput shows a tool's output while it runs, so it writes to
    the host UI instead, which is not a stream. The compact region of the renderer is erased around the write.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string] $Text
    )

    $renderer = $script:__MtConsoleRenderer
    if ($renderer) { $renderer.Pause() }
    try { $Host.UI.WriteLine($Text) } finally { if ($renderer) { $renderer.Resume() } }
}
