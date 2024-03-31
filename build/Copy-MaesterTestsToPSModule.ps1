<#
.SYNOPSIS
    Copies the Maester tests from ./tests to ./powershell/maester-tests folder to be included in the module.

.DESCRIPTION
    This allows the module to be self-contained and not require the tests to be downloaded separately.

    When developing locally if you wish to use the Install-MaesterTests or Update-MaesterTests functions you will need to run this
    script to copy the tests to the correct location.
#>

param(
    # Force to delete target folder if it exists without confirmation.
    [Parameter(Mandatory = $false)]
    [switch] $Force
)
$sourcePath = Join-Path $PSScriptRoot -ChildPath "..\tests"
$destinationPath = Get-MtMaesterTestFolderPath

if (-not (Test-Path -Path $sourcePath)) {
    Write-Error "The source path $sourcePath does not exist."
    return
}

if (Test-Path -Path $destinationPath) {
    Write-Host "Deleting existing destination folder $destinationPath"
    Remove-Item -Path $destinationPath -Recurse -Force:$Force
}

Write-Host "Creating destination folder $destinationPath"
New-Item -Path $destinationPath -ItemType Directory


Write-Host "Copying Maester tests from $sourcePath to $destinationPath"
Copy-Item -Path $sourcePath\* -Destination $destinationPath -Recurse -Force:$Force

Write-Host "Maester tests copied successfully." -ForegroundColor Green