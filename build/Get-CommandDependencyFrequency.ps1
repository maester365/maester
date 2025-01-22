function Get-CommandDependencyFrequency {
    <#
    .SYNOPSIS
    Get command dependencies in the public PowerShell scripts.

    .DESCRIPTION
    This function reads all the public PowerShell scripts and counts the number of times each command is used in them.
    It returns a list of all used commands, the number of times they are used, the module the command is from, and the
    files each command is used in.

    .EXAMPLE
    Get-CommandDependencyFrequency

    Gets all command dependencies in the public PowerShell scripts with their usage and source module.

    .EXAMPLE
    Get-CommandDependencyFrequency -ExcludeBuiltIn

    Gets all command dependencies in the public PowerShell scripts with their usage and source module, excluding built-in PowerShell commands.

    .EXAMPLE
    Get-CommandDependencyFrequency -ExcludeUnknown

    Gets all command dependencies in the public PowerShell scripts with their usage and source module, excluding unknown commands and private functions.

    .EXAMPLE
    Get-CommandDependencyFrequency -ExcludeBuiltIn -ExcludeUnknown

    Gets all command dependencies in the public PowerShell scripts with their usage and source module, excluding built-in PowerShell commands, unknown commands, and private functions.
    #>

    [CmdletBinding()]
    param (

        # Parameter help description
        [Parameter(Position = 0, HelpMessage = 'The path to the PowerShell scripts you want to analyze.')]
        [ValidateScript({ Test-Path -Path $_ -PathType Container })]
        [string]
        $Path = (Join-Path -Path (Split-Path $PSScriptRoot -Parent) -ChildPath 'powershell/public'),

        # Exclude built-in PowerShell commands
        [Parameter(HelpMessage = 'Exclude commands from built-in PowerShell modules in the results.')]
        [switch]
        $ExcludeBuiltIn,

        # Exclude unknown commands
        [Parameter(HelpMessage = 'Exclude commands from unknown PowerShell modules in the results.')]
        [switch]
        $ExcludeUnknown,

        # Exclude Maester functions
        [Parameter(HelpMessage = 'Exclude Maester functions in the results.')]
        [switch]
        $ExcludeMaesterFunctions
    )

    # region FilterResults
    $FilterConditions = '( $_ )'
    if ($ExcludeBuiltIn.IsPresent) {
        $FilterConditions += ' -and ( $_.Module -notin @("Pester", "PowerShellGet") -and $_.Module -notlike "Microsoft.PowerShell*" -and $_.Module -notlike "DnsClient*")'
    }
    if ($ExcludeUnknown.IsPresent) {
        $FilterConditions += ' -and -not ( [string]::IsNullOrEmpty($_.Module) )'
    }
    if ($ExcludeMaesterFunctions.IsPresent) {
        $FilterConditions += ' -and ( $_.Module -notlike "Maester*" )'
    }
    $Filter = [scriptblock]::Create($FilterConditions)
    #endregion FilterResults

    #region GetInternalFunctions
    $InternalFunctionsPath = (Join-Path -Path (Split-Path $PSScriptRoot -Parent) -ChildPath 'powershell/internal')
    [string[]]$InternalFunctions = Get-ChildItem -Path $InternalFunctionsPath -File *.ps1 |
        Select-Object -ExpandProperty BaseName
    #endregion GetInternalFunctions

    #region GetCommandDependencies
    $FileDependencies = New-Object -TypeName System.Collections.Generic.List[PSCustomObject]
    $Files = Get-ChildItem -Path $Path -File *.ps1 -Recurse
    foreach ($file in $Files) {
        $Content = Get-Content $file -Raw
        $Parse = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$null)
        $Commands = $parse.FindAll({
                $args | Where-Object { $_ -is [System.Management.Automation.Language.CommandAst] }
            }, $true) | ForEach-Object {
                ($_.CommandElements | Select-Object -First 1).Value
        } | Group-Object | Sort-Object @{Expression = { $_.Count }; Descending = $true }, Name

        # Add each command detail to $FileDependencies
        foreach ($command in $Commands) {
            $FileDependencies.Add( [PSCustomObject]@{
                    Command = $command.Name
                    Count   = $command.Count
                    File    = $file
                } )
        }
    }
    #endregion GetCommandDependencies

    # Create a reference hash table of all available commands on the system and their source module.
    # Account for CommandType precedence when multiple commands have the same name to get the one that would be used.
    $CommandList = [hashtable]@{}
    $CommandTypePrecedence = @{
        'Function' = 1
        'Alias'    = 2
        'Cmdlet'   = 3
    }
    $GroupedCommands = Get-Command | Group-Object -Property Name
    foreach ($group in $GroupedCommands) {
        $lowestPrecedenceCommand = $group.Group | Sort-Object { $CommandTypePrecedence["$($_.CommandType)"] } | Select-Object -First 1
        $CommandList[$group.Name] = $lowestPrecedenceCommand.Source
    }

    # Loop through $FileDependencies. Create a list of custom objects that contain the command name, the number of times it appears, and the files it appears in.
    $DependencyList = New-Object System.Collections.Generic.List[PSCustomObject]
    foreach ($item in $FileDependencies) {
        # Check if $DependencyList already contains an object with the same command name.
        if ($DependencyList.command -contains $item.command) {
            # If it is already in the list, increment the count and add the file to the files array.
            $ListItem = $DependencyList | Where-Object { $_.command -eq $item.command }
            $ListItem.count = $ListItem.count + $item.count
            $ListItem.files += $item.file
        } else {
            # Create a new item in the list.
            $Module = $CommandList[$item.command]
            if ( [string]::IsNullOrEmpty($Module) -and $InternalFunctions -contains $item.command ) {
                $Module = 'Maester (Internal Function)'
            }

            $DependencyList.Add( [PSCustomObject]@{
                    Command = $item.command
                    Module  = $Module
                    Count   = $item.count
                    Files   = @($item.file)
                } )
        }
    }

    # Sort and output the results.
    $DependencyList = $DependencyList | Sort-Object -Property Module, Count, Name
    $DependencyList | Where-Object -FilterScript $Filter
}
