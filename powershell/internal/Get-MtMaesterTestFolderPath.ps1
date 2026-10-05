function Get-MtMaesterTestFolderPath {
    <#
    .SYNOPSIS
    Returns the folder that holds the built-in Pester test suites and the shipped maester-config.json.

    .DESCRIPTION
    In the built module this is builtin-pester/ next to Maester.psd1. In a source checkout it is the
    repository's tests/ folder. Its Custom subfolder, if any, is not part of the built-in tests.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $moduleBase = $ExecutionContext.SessionState.Module.ModuleBase
    $builtIn = Join-Path -Path $moduleBase -ChildPath 'builtin-pester'
    if (Test-Path -LiteralPath $builtIn -PathType Container) { return $builtIn }

    $sourceTests = Join-Path -Path $moduleBase -ChildPath '../tests'
    if (Test-Path -LiteralPath $sourceTests -PathType Container) {
        return (Resolve-Path -LiteralPath $sourceTests).Path
    }
    return $builtIn
}
