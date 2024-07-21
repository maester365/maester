function Get-MtMaesterTestFolderPath {
    return Join-Path -Path $PSScriptRoot -ChildPath "../maester-tests"
}