function Import-MtDependency {
    <#
    .SYNOPSIS
    Reduce the risk of assembly loading conflicts by importing dependent modules in a compatible order.

    .DESCRIPTION
    This function checks the versions of Microsoft.Identity.Client.dll in the dependent modules
    (Microsoft.Graph.Authentication, Az.Accounts, ExchangeOnlineManagement, and MicrosoftTeams)
    and imports them in order of descending version to avoid assembly loading conflicts.

    .EXAMPLE
    Import-MtDependency

    Imports the required modules for Maester in the correct order based on their Microsoft.Identity.Client.dll versions.

    .NOTES

    Status: In Development
    Needed:
        - Add proper handling for non-Windows module installation paths (merge from existing test script)
        - Add logic to determine which paths PowerShell will import modules from if the same module is installed in multiple scopes/locations
        - Test with different versions of the modules to ensure correct loading order
        - Add error handling for module import failures
        - Return $true if all modules are imported successfully, $false otherwise
        - Add additional helpful verbose output
        - Optional: optional real-time host output or a final summary

    #>

    [CmdletBinding()]
    param (
        # List of modules to check for dependency conflicts
        [Parameter()]
        [string[]]$ModuleNames = @(
            'Az.Accounts',
            'ExchangeOnlineManagement',
            'Microsoft.Graph.Authentication',
            'MicrosoftTeams'
        )
    )

    begin {
        Write-Verbose "Starting Import-MtDependency"

        # Platform-specific variables
        $DirectorySeparator = [System.IO.Path]::DirectorySeparatorChar
        $PathSeparator = [System.IO.Path]::PathSeparator

        # Create an ordered dictionary (list) of unique module installation location paths.
        $PSModulePathCollection = [System.Collections.Specialized.OrderedDictionary]::new()
        # Loop through the environment variable targets in order of precedence (Process, User, Machine) to get PSModulePath values.
        foreach ($Target in [System.Enum]::GetValues([System.EnvironmentVariableTarget])) {
            # Split the PSModulePath environment variable into individual paths and add them to the ordered dictionary.
            foreach ($PathEntry in [System.Environment]::GetEnvironmentVariable('PSModulePath', $Target) -split $PathSeparator) {
                if ($PathEntry) {
                    $PathEntry = [System.IO.Path]::GetFullPath($PathEntry)
                } else {
                    # If the path entry is empty, skip it.
                    continue
                }
                # Add the path if it is not already in the collection.
                if (-not $PSModulePathCollection.Contains($PathEntry)) {
                    # Add each fully resolved path entry to the ordered dictionary as a key and create an empty list object in the value.
                    $PSModulePathCollection.Add($PathEntry, [System.Collections.Generic.List[PSObject]]::new() )
                }
            }
        }

    }

    process {


        # Get a list of the installed modules and all of their versions.
        [System.Collections.Generic.List[PSObject]]$Modules = Get-Module $ModuleNames -ListAvailable | Sort-Object -Property Name,Version -Descending

        foreach ($Path in $PSModulePathCollection.GetEnumerator()) {
            $PathName = $Path.Key
            foreach ($Module in $Modules) {
                # Check if the module is installed in this path.
                $ModuleName = $Module.Name
                $ModulePath = $Module.Path
                if ($ModulePath.StartsWith($PathName)) {
                    # Add the module to the ordered dictionary.
                    $PSModulePathCollection[$($PathName)].Add($Module)
                }
            }
        }

        $ModulesByLocation = $Modules | Group-Object {
            # This script block is used by the Group-Object cmdlet to determine the key for each grouping.

            # Get the module's root directory
            $ModulePath = [System.IO.Path]::GetFullPath($_.ModuleBase)

            # Find which PSModulePath entry contains this module
            foreach ($PathEntry in $PSModulePathEntries) {
                $NormalizedPathEntry = [System.IO.Path]::GetFullPath($PathEntry)
                if ($ModulePath.StartsWith($NormalizedPathEntry, [System.StringComparison]::OrdinalIgnoreCase)) {
                    return $NormalizedPathEntry
                }
            }
            # ... fallback logic
        }
        $ModulesByLocation




        # Create a hashtable to store module information
        $ModuleInfo = @{}

        foreach ($ModuleName in $ModuleNames) {
            Write-Verbose "`n`n`t> Searching for $ModuleName in possible module paths...`n" -Verbose

            foreach ($RootPath in $PossibleModulePaths) {
                Write-Verbose "  Checking Path: $RootPath" -Verbose
                $ModulePaths = Get-ChildItem -Path $RootPath -Filter $ModuleName -Recurse -Directory -ErrorAction SilentlyContinue

                foreach ($ModulePath in $ModulePaths) {
                    Write-Verbose "          Found: $($ModulePath.FullName)" -Verbose
                    $Dlls = Get-ChildItem -Path $ModulePath.FullName -Recurse -Filter "Microsoft.Identity.Client.dll" -ErrorAction SilentlyContinue

                    foreach ($Dll in $Dlls) {
                        Write-Verbose "          Found: $($Dll.FullName)" -Verbose
                        $DllVersion = [version]$Dll.VersionInfo.FileVersion
                        $ModuleVersion = [version]($Dll.Directory.FullName).TrimStart($ModulePath.FullName).Split($DirectorySeparator)[0]

                        # Store module, path, and version
                        if (-not $ModuleInfo.ContainsKey($ModuleName)) {
                            $ModuleInfo[$ModuleName] = @()
                        }

                        $ModuleInfo[$ModuleName] += [PSCustomObject]@{
                            ModuleName = $ModuleName
                            Path = $ModulePath.FullName
                            Version = $ModuleVersion
                            DllPath = $Dll.FullName
                            DllVersion = $DllVersion
                        }
                    }
                } # end foreach ($ModulePath in $ModulePaths)
            } # end foreach ($RootPath in $PossibleModulePaths)
        } # end foreach ($ModuleName in $ModuleNames)

        # Get the highest version for each module
        $HighestVersions = @{}
        foreach ($ModuleName in $ModuleNames) {
            if ($ModuleInfo.ContainsKey($ModuleName) -and $ModuleInfo[$ModuleName].Count -gt 0) {
                $HighestVersions[$ModuleName] = $ModuleInfo[$ModuleName] | Sort-Object -Property DllVersion | Select-Object -First 1
            }
        }

        # Sort modules by version (descending)
        $SortedModules = $HighestVersions.Values | Sort-Object -Property DllVersion #-Descending

        # Display the detected modules and their versions
        Write-Verbose "Detected modules with Microsoft.Identity.Client.dll versions:" -Verbose
        foreach ($Module in $SortedModules) {
            Write-Verbose "`n`t      Module: $($Module.ModuleName) ($($Module.Version))`n`t Module Path: $($Module.Path)`n`t DLL Version: $($Module.DllVersion)`n" -Verbose
        }

        # Remove any previously loaded modules and re-import them in the correct order.
        $ModuleNames | Remove-Module -Force -ErrorAction SilentlyContinue

        # Import modules in order of descending Microsoft.Identity.Client.dll version
        foreach ($Module in $SortedModules) {
            try {
                Write-Verbose "Importing module $($Module.ModuleName) from path: $($Module.Path)"
                Import-Module -Name $Module.ModuleName -Force -Verbose:$false
                Write-Verbose "Successfully imported module $($Module.ModuleName)"
            }
            catch {
                Write-Warning "Failed to import module $($Module.ModuleName): $_"
            }
        }

    } # end process

    end {
        # Report final module state
        $LoadedModules = $ModuleNames | ForEach-Object {
            $Loaded = Get-Module -Name $_ -ErrorAction SilentlyContinue
            [PSCustomObject]@{
                ModuleName = $_
                Loaded = ($null -ne $Loaded)
                Version = if ($Loaded) { $Loaded.Version } else { "Not loaded" }
            }
        }

        Write-Verbose "Final module loading state:"
        $LoadedModules | ForEach-Object {
            Write-Verbose "$($_.ModuleName): $($_.Loaded) (Version: $($_.Version))" -Verbose
        }

        Write-Verbose "Import-MtDependency completed"
    }
}
