function Open-MtBrowserUrl {
    <#
    .SYNOPSIS
    Opens a URL in the default browser when the current platform supports it.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Uri
    )

    if ([string]::IsNullOrWhiteSpace($Uri)) {
        return $false
    }

    try {
        if ($IsMacOS) {
            & open $Uri | Out-Null
        } elseif ($IsLinux) {
            $xdgOpen = Get-Command -Name xdg-open -ErrorAction SilentlyContinue
            if ($null -eq $xdgOpen) {
                return $false
            }
            & $xdgOpen.Source $Uri | Out-Null
        } else {
            Start-Process -FilePath $Uri | Out-Null
        }
        return $true
    } catch {
        Write-Verbose "Failed to open '$Uri' in the default browser. $($_.Exception.Message)"
        return $false
    }
}
