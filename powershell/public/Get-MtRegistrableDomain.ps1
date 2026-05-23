function Get-MtRegistrableDomain {
    <#
    .SYNOPSIS
        Get the registrable domain for a given domain name.

    .DESCRIPTION
        This function retrieves the registrable domain for a given domain name based on the public suffix list.
        Uses a cached version of the public suffix list for performance reasons.
        Public suffix list is sourced from https://publicsuffix.org/ and stored in the Maester powershell assets repository.

    .PARAMETER DomainName
        The domain name for which to retrieve the registrable domain.

    .EXAMPLE
        Get-MtRegistrableDomain -DomainName "sub.example.co.uk"
        Returns "example.co.uk".

    .EXAMPLE
        Get-MtRegistrableDomain -DomainName "example.co.uk"
        Returns "example.co.uk".

    .EXAMPLE
        Get-MtRegistrableDomain -DomainName "sub.example.com"
        Returns "example.com".

    .EXAMPLE
        Get-MtRegistrableDomain -DomainName "example.com"
        Returns "example.com".

    .LINK
        https://maester.dev/docs/commands/Get-MtRegistrableDomain
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DomainName
    )

    $labels = $DomainName.Trim('.').ToLowerInvariant().Split('.')
    # If the domain has less than 2 labels, return it as is (e.g., localhost or similar)
    if ($labels.Count -lt 2) {
        return $DomainName.ToLowerInvariant()
    }

    # Load public suffix list if not already loaded for performance
    if ($null -eq $script:MtPublicSuffixes) {
        Write-Verbose 'Loading public suffix list for registrable domain extraction'
        $pslPath = Join-Path -Path $PSScriptRoot -ChildPath '../assets/public_domain_suffix_list.dat'
        $script:MtPublicSuffixes = Get-Content -Path $pslPath -Encoding UTF8 |
            Where-Object { $_ -notmatch '^\s*//' -and $_.Trim() -ne '' } |
            ForEach-Object { $_.Trim().ToLowerInvariant() }
    }

    $last2 = "$($labels[-2]).$($labels[-1])"

    Write-Verbose 'Checking if the last two labels are a public suffix'
    if (($script:MtPublicSuffixes -contains $last2) -and $labels.Count -ge 3) {
        return "$($labels[-3]).$last2"
    }

    return $last2
}