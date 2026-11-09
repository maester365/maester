function Test-MtCisParkedDomain {
    <#
    .SYNOPSIS
    Returns true when a domain is in the list of parked domains an admin gave a CIS email-authentication check.

    .DESCRIPTION
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.1.8 to 2.1.10) sets different requirements for domains that
    are not used to send email, but leaves it to the auditor to say which domains those are. Maester does not
    guess from DNS: a domain is parked only when it is listed in the check's ParkedDomains parameter. The
    comparison ignores case and a trailing dot.

    .PARAMETER DomainName
    The accepted domain to look up.

    .PARAMETER ParkedDomains
    The domains the admin listed as parked.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$DomainName,

        [string[]]$ParkedDomains = @()
    )

    $name = $DomainName.TrimEnd('.')
    return @($ParkedDomains | Where-Object {
        $_ -and [string]::Equals($_.Trim().TrimEnd('.'), $name, [System.StringComparison]::OrdinalIgnoreCase)
    }).Count -gt 0
}
