function Show-MtLogo {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    [OutputType([string])]
    param ()

    $Version = (Import-PowerShellDataFile -Path "$PSScriptRoot/../Maester.psd1").ModuleVersion
    # ASCII Art using style "ANSI Shadow"
    $Logo = @"

    ███╗   ███╗ █████╗ ███████╗███████╗████████╗███████╗██████╗
    ████╗ ████║██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔════╝██╔══██╗
    ██╔████╔██║███████║█████╗  ███████╗   ██║   █████╗  ██████╔╝
    ██║╚██╔╝██║██╔══██║██╔══╝  ╚════██║   ██║   ██╔══╝  ██╔══██╗
    ██║ ╚═╝ ██║██║  ██║███████╗███████║   ██║   ███████╗██║  ██║
    ╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝ v$Version

"@

    Write-Host $Logo -ForegroundColor Green
}
