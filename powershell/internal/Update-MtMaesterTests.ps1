<#

#>
Function Update-MtMaesterTests {
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

    $installOrUpdate = if ($IsInstall) { "installed" } else { "updated" }
    if ($targetFolderExists) {
        # Check if the folder already exists and prompt user to confirm overwrite.
        $itemsToDelete = Get-ChildItem -Path $Path -Exclude "Custom"

        if ($itemsToDelete.Count -gt 0) {
            $message = "`nThe following items will be deleted when installing the latest Maester tests:`n"
            $itemsToDelete | ForEach-Object { $message += "  $($_.FullName)`n" }
            $message += "Do you want to continue? (Y/n)"
            $continue = Get-MtConfirmation $message
            if ($continue) {
                $itemsToDelete | Remove-Item -Force
            } else {
                Write-Host "Maester tests not $installOrUpdate." -ForegroundColor Red
                exit
            }
        }
    }

    if (-not $targetFolderExists) {
        Write-Verbose "Creating directory $Path"
        New-Item -Path $Path -ItemType Directory | Out-Null
    }

    $MaesterTestsPath = Get-MtMaesterTestFolderPath
    Copy-Item -Path $MaesterTestsPath\* -Destination $Path -Recurse -Force
    Write-Host "Maester tests $installOrUpdate successfully. Run Invoke-Maester to start testing." -ForegroundColor Green

}