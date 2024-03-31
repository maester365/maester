Function Get-MtConfirmation ($message)
{
    $continue = $(Write-Host $message -ForegroundColor Yellow -NoNewline; Read-Host)
    return $continue -eq "Y"
}