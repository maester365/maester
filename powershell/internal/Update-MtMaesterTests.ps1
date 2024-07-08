<#

#>
Function Update-MtMaesterTests {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This command updates multiple tests')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'TODO: Implement ShouldProcess')]
    [CmdletBinding()]
    param(
        # The path to install the Maester tests to, defaults to the current directory.
        [Parameter(Mandatory = $true)]
        [string] $Path,

        # Defaults to update, used to show the correct message as 'installed' or 'updated'.
        [Parameter(Mandatory = $false)]
        [switch] $Install
    )

    $MaesterTestsPath = Get-MtMaesterTestFolderPath

    if (-not (Test-Path -Path $MaesterTestsPath)) {
        Write-Error "Maester tests not found at $MaesterTestsPath"
        return
    }

    $targetFolderExists = (Test-Path -Path $Path)

    $installOrUpdate = if ($Install) { "installed" } else { "updated" }
    if ($targetFolderExists) {
        # Check if the folder already exists and prompt user to confirm overwrite.
        $itemsToDelete = Get-ChildItem -Path $Path -Exclude "Custom"

        if ($itemsToDelete.Count -gt 0) {
            $message = "`nThe following items will be deleted when installing the latest Maester tests:`n"
            $itemsToDelete | ForEach-Object { $message += "  $($_.FullName)`n" }
            $message += "Do you want to continue? (y/n): "
            $continue = Get-MtConfirmation $message
            if ($continue) {
                foreach ($item in $itemsToDelete) {
                    if ($item.Attributes -ne "Directory") {
                        Remove-Item -Path $item.FullName -Force
                    } else {
                        Remove-Item -Path $item.FullName -Recurse -Force
                    }
                }
            } else {
                Write-Host "Maester tests not $installOrUpdate." -ForegroundColor Red
                return
            }
        }
    }

    if (-not $targetFolderExists) {
        Write-Verbose "Creating directory $Path"
        New-Item -Path $Path -ItemType Directory | Out-Null
    }

    $MaesterTestsPath = Get-MtMaesterTestFolderPath
    Copy-Item -Path $MaesterTestsPath\* -Destination $Path -Recurse -Force

    $message = "Run `Connect-Maester` to sign in and then run `Invoke-Maester` to start testing."
    if (Get-MgContext) {
        $message = "Run Invoke-Maester to start testing."
    }

    Write-Host "Maester tests $installOrUpdate successfully!`n$message" -ForegroundColor Green
}
