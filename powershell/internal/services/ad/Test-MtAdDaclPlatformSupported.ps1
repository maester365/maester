function Test-MtAdDaclPlatformSupported {
    <#
    .SYNOPSIS
        Returns whether the current platform supports Active Directory DACL queries.

    .DESCRIPTION
        DACL analysis requires Windows PowerShell or PowerShell 7 on Windows.
        This helper centralises the platform check so tests can mock it.

    .EXAMPLE
        if (-not (Test-MtAdDaclPlatformSupported)) { return $null }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return ($IsWindows -or $PSVersionTable.PSEdition -ne 'Core')
}
