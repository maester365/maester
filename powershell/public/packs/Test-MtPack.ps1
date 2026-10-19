function Test-MtPack {
    <#
    .SYNOPSIS
    Checks a Maester Pack folder the way Install-MtPack does, without installing it or running any of its code.

    .DESCRIPTION
    Use it while writing a pack, and in the pack's own CI. It reads maester-pack.json, every file and every
    test, and reports what would stop the pack from being installed (Errors), what an installer is told
    (Warnings and Findings), the risk the install prompt shows, the test IDs and the digest that the lock
    file would record. IsValid is $false when there is an error.

    .PARAMETER Path
    The pack folder, the one that holds maester-pack.json. The current folder by default.

    .PARAMETER Official
    Check it as a pack from the maester365 organisation, which may use the names reserved for Maester.

    .EXAMPLE
    Test-MtPack ./my-pack

    Shows whether the pack can be installed, and why not.

    .EXAMPLE
    if (-not (Test-MtPack).IsValid) { exit 1 }

    In a pack repository's CI.

    .LINK
    https://maester.dev/docs/commands/Test-MtPack
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [string] $Path = '.',

        [Parameter()]
        [switch] $Official
    )

    $full = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $content = Test-MtPackContent -Path $full -Official:$Official
    [pscustomobject][ordered]@{
        Id       = if ($content.Manifest) { $content.Manifest.Id } else { $null }
        Version  = if ($content.Manifest) { $content.Manifest.Version } else { $null }
        IsValid  = @($content.Errors).Count -eq 0
        Risk     = $content.Risk
        Errors   = @($content.Errors)
        Warnings = @($content.Warnings)
        Findings = @($content.Findings)
        TestIds  = [string[]]@($content.TestIds)
        Digest   = $content.Digest
        Path     = $full
    }
}
