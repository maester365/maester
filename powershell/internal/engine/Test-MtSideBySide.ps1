function Write-MtOlderVersionWarning {
    <#
    .SYNOPSIS
    Warns once per session when a Maester version older than 3.0 is installed next to this one.

    .DESCRIPTION
    Update-Module keeps Maester 2.x installed. A call to a 2.x check function from outside the module
    makes PowerShell auto-load the 2.x module, and from then on the session runs 2.x code (design
    section 12). The warning gives the exact uninstall command.
    #>
    [CmdletBinding()]
    param()

    if ($script:__MtOlderVersionChecked) { return }
    $script:__MtOlderVersionChecked = $true
    $current = $ExecutionContext.SessionState.Module.Version
    if ($current.Major -lt 3) { return }
    $older = @(Get-Module -Name Maester -ListAvailable -ErrorAction SilentlyContinue | Where-Object { $_.Version.Major -lt 3 })
    if ($older.Count -gt 0) {
        $versions = ($older.Version | Sort-Object -Unique) -join ', '
        Write-Warning ("Maester $versions is also installed. If a script calls one of its functions, PowerShell loads that version " +
            "and the session stops using Maester $current. Remove it with: Uninstall-Module Maester -MaximumVersion 2.99.99 -AllVersions")
    }
}

function Remove-MtForeignModule {
    <#
    .SYNOPSIS
    Removes a second Maester module instance that was loaded during a run, and warns.

    .DESCRIPTION
    A test that calls a function this version no longer exports can make PowerShell auto-load another
    installed Maester. Removing it restores command resolution to this module for the rest of the run.
    Returns $true when a foreign instance was found.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Restores the session to the running module.')]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $self = $ExecutionContext.SessionState.Module
    $foreign = @(Get-Module -Name Maester | Where-Object { $_.ModuleBase -ne $self.ModuleBase -or $_.Version -ne $self.Version })
    if ($foreign.Count -eq 0) { return $false }
    Write-Warning ("Maester $(($foreign.Version | Sort-Object -Unique) -join ', ') was loaded during the run, probably because a test called one of its " +
        "functions directly. It was removed so the run continues on Maester $($self.Version). Use Invoke-MtTest -Id to run a built-in test from a custom test.")
    $foreign | Remove-Module -Force -ErrorAction SilentlyContinue
    $true
}
