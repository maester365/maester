function Invoke-MtGit {
    <#
    .SYNOPSIS
    Runs git in a repository and returns its output as lines.

    .DESCRIPTION
    Runs git -C <Path> <Arguments>. When git fails, it throws with git's error message, unless -AllowFailure is
    set, in which case it returns nothing. Standard error is never mixed into the returned lines.

    .PARAMETER Path
    The repository folder.

    .PARAMETER Arguments
    The git arguments.

    .PARAMETER AllowFailure
    Return nothing instead of throwing when git exits with an error.

    .EXAMPLE
    Invoke-MtGit -Path ./mirror -Arguments 'rev-parse', 'HEAD'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string[]] $Arguments,

        [switch] $AllowFailure
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $lines = & git -C $Path @Arguments 2>&1 | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) { $errors.Add($_.ToString()) } else { [string] $_ }
    }
    if ($LASTEXITCODE -ne 0) {
        if ($AllowFailure) { return }
        throw "git $($Arguments -join ' ') failed in ${Path}: $($errors -join ' ')"
    }
    $lines
}
