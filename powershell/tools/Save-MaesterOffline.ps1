function Save-MaesterOffline {
    <#
    .SYNOPSIS
    Download local copies of Maester and its dependencies for use on systems that cannot access the PowerShell Gallery.

    .DESCRIPTION
    This function downloads the Maester module and its dependencies to a specified directory, allowing for offline
    installation on systems without access to the PowerShell Gallery. Once downloaded the modules can be copied to
    the target system and installed using Install-Module with the -Path parameter.

    .PARAMETER DestinationPath
    The directory to download and save the required PowerShell modules in.

    .EXAMPLE
    Save-MaesterOffline -DestinationPath ~/Downloads/Maester

    .NOTES
    Author: Sam Erde (@SamErde)
    Company: Sentinel Technologies, Inc
    Version: 1.0.1
    Date: 2025-09-10

    #>
    [CmdletBinding()]
    param (
        # Directory to download and save the required PowerShell modules in.
        [Parameter(HelpMessage = 'The path to an existing directory to download and save the required PowerShell modules in.')]
        [ValidateScript( { Test-Path -Path $_ -PathType Container -IsValid } )]
        [string] $DestinationPath = $PWD.Path,

        # Switch to create a ZIP file of the downloaded modules.
        [Parameter(HelpMessage = 'Create a ZIP file of the downloaded modules.')]
        [switch] $CreateZip
    )

    # Ensure the destination path exists, or try to create it, if necessary.
    if (Test-Path -Path $DestinationPath -PathType Container) {
        Write-Verbose "Using existing directory: $DestinationPath"
    } else {
        try {
            New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
            Write-Verbose "Created directory: $DestinationPath"
        } catch {
            Write-Error "Failed to create directory: $DestinationPath. Error: $_"
            return
        }
    }

    # Check if the Microsoft.PowerShell.PSResourceGet module is available and attempt to install it if necessary. If
    # the PSResourceGet module is not available, fall back to using Save-Module.
    $PSResourceGetInstalled = $false
    if ( (Get-Command -Name Save-PSResource -ErrorAction SilentlyContinue) ) {
        $PSResourceGetInstalled = $true
    } else {
        Write-Host "The 'Microsoft.PowerShell.PSResourceGet' module is not available. Attempting to install it from the PowerShell Gallery..."
        try {
            Install-Module -Name 'Microsoft.PowerShell.PSResourceGet' -Scope CurrentUser -Force -ErrorAction Stop
            Import-Module -Name 'Microsoft.PowerShell.PSResourceGet' -Force -ErrorAction Stop
            Write-Host "Successfully installed and imported the 'Microsoft.PowerShell.PSResourceGet' module."
            $PSResourceGetInstalled = $true
        } catch {
            Write-Error "Failed to install or import the 'Microsoft.PowerShell.PSResourceGet' module. Error: $_"
            return
        }
    }

    # List the required module names and versions.
    $RequiredModules = @(
        @{
            Name       = 'Pester'
            Prerelease = $false
            Version    = [version]'5.7.1'
        },
        @{
            Name       = 'Maester'
            Prerelease = $true
            Version    = $null  # Get the latest
        },
        @{
            Name       = 'Az.Accounts'
            Prerelease = $false
            Version    = $null  # Get the latest
        },
        @{
            Name       = 'ExchangeOnlineManagement'
            Prerelease = $false
            Version    = $null  # Get the latest
        },
        @{
            Name       = 'Microsoft.Graph.Authentication'
            Prerelease = $false
            Version    = $null  # Get the latest. Just don't get 2.26.*!
        },
        @{
            Name       = 'MicrosoftTeams'
            Prerelease = $false
            Version    = $null  # Get the latest
        }
    )

    # Track installed modules.
    $InstalledModules = @()

    if ($PSResourceGetInstalled) {
        Write-Verbose "Using 'Save-PSResource' (Microsoft.PowerShell.PSResourceGet) to download modules.`n"
    } else {
        Write-Verbose "Using 'Save-Module' (PowerShellGet) to download modules.`n"
    }

    # Download the required modules into the DestinationPath.
    foreach ($Module in $RequiredModules) {
        $Name = $Module.Name
        $Version = $Module.Version
        $Prerelease = $Module.Prerelease

        try {
            Write-Host "Downloading module: $($("$Name $Version").Trim()) $(if ($Prerelease) {"(prerelease)"})" -ForegroundColor Cyan
            if ($PSResourceGetInstalled) {
                #try {
                if ($Version) {
                    Save-PSResource -Name $Name -Path $DestinationPath -Version $Version -Prerelease:$Prerelease -SkipDependencyCheck
                } else {
                    Write-Verbose "Getting latest version"
                    Save-PSResource -Name $Name -Path $DestinationPath -Prerelease:$Prerelease -SkipDependencyCheck
                }
                $InstalledModules += $Name
                Write-Host "Successfully downloaded module: $Name" -ForegroundColor Green
            } else {
                if ($Version) {
                    Save-Module -Name $Name -Path $DestinationPath -MinimumVersion $Version -AllowPrerelease:$Prerelease
                } else {
                    Save-Module -Name $Name -Path $DestinationPath -AllowPrerelease:$Prerelease
                }
                $InstalledModules += $Name
                Write-Host "Successfully downloaded module: $Name" -ForegroundColor Green
            }
        } catch {
                Write-Error "Failed to download module: $Name. Error: $_"
        }
    }

    # Summary of downloaded modules.
    if ($InstalledModules.Count -gt 0) {
        Write-Host "`nDownloaded modules to $DestinationPath`n"
        $InstalledModules | ForEach-Object -Process { Write-Host "`t$_" } -End { Write-Host "`n" }
    } else {
        Write-Warning 'No modules were downloaded.'
    }

    # Create a ZIP file of the downloaded modules if requested.
    if ($CreateZip.IsPresent -and $InstalledModules.Count -gt 0) {
        $ZipPath = Join-Path -Path $DestinationPath -ChildPath 'MaesterModuleWithDependencies.zip'
        try {
            # Remove old ZIP file if it exists already.
            if (Test-Path -Path $ZipPath) {
                Remove-Item -Path $ZipPath -Force
                Write-Verbose "Removed existing ZIP file: $ZipPath"
            }
            Compress-Archive -Path (Join-Path -Path $DestinationPath -ChildPath '*') -DestinationPath $ZipPath -Force
            Write-Host "Created ZIP file: $ZipPath" -ForegroundColor Green
        } catch {
            Write-Error "Failed to create ZIP file: $ZipPath. Error: $_"
        }
    }
}
