<#

#>
function Update-MtMaesterTests {
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
    if (-not (Test-Path -Path $MaesterTestsPath -PathType Container)) {
        Write-Error "Maester tests not found at $MaesterTestsPath"
        return
    }

    $MaesterTests = (Get-ChildItem -Path $MaesterTestsPath -Exclude 'Custom').Name

    $targetFolderExists = (Test-Path -Path $Path -PathType Container)
    if (-not $targetFolderExists) {
        Write-Verbose "Creating directory $([System.IO.Path]::GetFullPath($Path))"
        try {
            New-Item -Path $Path -ItemType Directory | Out-Null
        } catch {
            Write-Error "Unable to create directory $([System.IO.Path]::GetFullPath($Path))"
            Write-Verbose $_
            return
        }
    }

    $installOrUpdate = if ($Install) { "installed" } else { "updated" }

    if ($targetFolderExists) {
        # Check if the folder already exists and prompt user to confirm overwrite.
        $itemsToDelete = Get-ChildItem -Path $Path | Where-Object {$_.Name -in $($MaesterTests)}

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

    try {
        Write-Verbose "Copying Maester tests from $MaesterTestsPath/* to $Path"
        Copy-Item -Path $MaesterTestsPath/* -Destination $Path -Recurse -Force
    } catch {
        Write-Error "Unable to copy the Maester tests to $Path."
        Write-Verbose $_
        return
    }

    $message = "Run `Connect-Maester` to sign in and then run `Invoke-Maester` to start testing."
    #if (Get-MgContext) { #ToAdjust: Issue with -SkipGraphConnect
    if (Test-MtConnection Graph) {
        $message = "Run Invoke-Maester to start testing."
    }

    Write-Host "Maester tests $installOrUpdate successfully!`n$message" -ForegroundColor Green
}
