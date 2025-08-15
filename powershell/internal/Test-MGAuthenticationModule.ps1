function Test-MGAuthenticationModule {
<#
.SYNOPSIS
    Check which version of the Microsoft.Graph.Authentication module and recommend a different version if necessary.
.DESCRIPTION
    This function checks which version of the Microsoft.Graph.Authentication module is installed and recommends a
    different version be installed and used if necessary.

    This can be necessary because some environments are pinned to version 2.25.0 due to bugs in later releases while
    other environments need (or want) to upgrade to a newer release. At the same time, versions with known issues need
    to be skipped in almost every environment.

    Version    Status
    -----------------
    2.25.0     No known issues.
    2.26.0     Known issues with authentication flows. Do not use.
    2.26.1     Known issues with token acquisition. Do not use.
    2.27.0     Works for most Maester scenarios. Limitations: not yet supported on Azure Automation accounts(?). Known issues with other Microsoft.Graph submodules requires some organizations to block this version.
    2.28.0     Works for most Maester scenarios. Limitations: not yet supported on Azure Automation accounts(?). Known issues with other Microsoft.Graph submodules requires some organizations to block this version.
    2.29.0     Works for most Maester scenarios. Limitations: not yet supported on Azure Automation accounts(?). Known issues with other Microsoft.Graph submodules requires some organizations to block this version.
    2.29.1     Works for most Maester scenarios. Limitations: not yet supported on Azure Automation accounts(?). Known issues with other Microsoft.Graph submodules requires some organizations to block this version.

    Precedence is given to the version installed in the CurrentUser scope. If the module is not installed in the
    CurrentUser scope, the version installed in the AllUsers scope is used.
#>

    [CmdletBinding()]
    param (

    )

    begin {
        $DependencySupport = Get-Content -Path "$PSScriptRoot\..\Dependency-Support.json" | ConvertFrom-Json
    }

    process {
        $ModuleInfo = Get-InstalledModule -Name Microsoft.Graph.Authentication -ListAvailable | Select-Object -First 1
        $ModuleInfo = Get-InstalledPSResource Microsoft.Graph.Authentication -Scope CurrentUser | Sort Version -Descending | Select -First 1
        # The cmdlet from Microsoft.PowerShell.PSResourceGet is much better because you can easily check scopes, but may not be universally installed.

        # Early WIP. Will replace with info from $DependencySupport JSON data.
        $ModuleInfo.Version | ForEach-Object {
            switch ($_) {
                '2.25.0' { Write-Verbose "Microsoft.Graph.Authentication version 2.25.0 is installed and is the recommended version." }
                '2.26.0' { Write-Warning "Microsoft.Graph.Authentication version 2.26.0 is known to have issues with authentication flows. Do not use." }
                '2.26.1' { Write-Warning "Microsoft.Graph.Authentication version 2.26.1 is known to have issues with token acquisition. Do not use." }
                '2.27.0' { Write-Verbose "Microsoft.Graph.Authentication version 2.27.0 works for most scenarios but has some limitations and known issues with other Microsoft.Graph submodules." }
                '2.28.0' { Write-Verbose "Microsoft.Graph.Authentication version 2.28.0 works for most scenarios but has some limitations and known issues with other Microsoft.Graph submodules." }
                '2.29.0' { Write-Verbose "Microsoft.Graph.Authentication version 2.29.0 works for most scenarios but has some limitations and known issues with other Microsoft.Graph submodules." }
                '2.29.1' { Write-Verbose "Microsoft.Graph.Authentication version 2.29.1 works for most scenarios but has some limitations and known issues with other Microsoft.Graph submodules." }
                default { Write-Warning "Unknown or unsupported Microsoft.Graph.Authentication version: $_" }
            }
        }
    }

    end {

    }
}
