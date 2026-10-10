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

    # Called for every result row: the answer does not change for a loaded module, so it is resolved once.
    if ($script:__MtTestFolderPath) { return $script:__MtTestFolderPath }

    $moduleBase = $ExecutionContext.SessionState.Module.ModuleBase
    $builtIn = Join-Path -Path $moduleBase -ChildPath 'builtin-pester'
    $sourceTests = Join-Path -Path $moduleBase -ChildPath '../tests'
    $script:__MtTestFolderPath = if (Test-Path -LiteralPath $builtIn -PathType Container) {
        $builtIn
    } elseif (Test-Path -LiteralPath $sourceTests -PathType Container) {
        (Resolve-Path -LiteralPath $sourceTests).Path
    } else {
        $builtIn
    }
    $script:__MtTestFolderPath
}
