function Get-MtConfirmation {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    [CmdletBinding()]
    param ($message)

    $continue = $(Write-Host $message -ForegroundColor Yellow -NoNewline; Read-Host)
    return $continue -eq "Y"
}