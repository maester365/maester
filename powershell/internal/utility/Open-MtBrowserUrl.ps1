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

    $parsedUri = $null
    if (-not [System.Uri]::TryCreate($Uri, [System.UriKind]::Absolute, [ref]$parsedUri)) {
        return $false
    }

    if ($parsedUri.Scheme -ne 'https' -and $parsedUri.Scheme -ne 'http') {
        return $false
    }

    $launchUri = $parsedUri.AbsoluteUri

    try {
        if ($IsMacOS) {
            & open $launchUri | Out-Null
        } elseif ($IsLinux) {
            $xdgOpen = Get-Command -Name xdg-open -ErrorAction SilentlyContinue
            if ($null -eq $xdgOpen) {
                return $false
            }
            & $xdgOpen.Source $launchUri | Out-Null
        } else {
            Start-Process -FilePath $launchUri | Out-Null
        }
        return $true
    } catch {
        Write-Verbose "Failed to open '$Uri' in the default browser. $($_.Exception.Message)"
        return $false
    }
}
