function Get-MtDomainPasswordValidity {
    <#
    .SYNOPSIS
        Returns the password expiration period of each domain of the tenant.

    .DESCRIPTION
        The password expiration policy is stored per domain, as passwordValidityPeriodInDays. It applies only to
        domains that are verified and managed (not federated), so each domain is returned with IsApplicable.

        ValidityDays is the number of days a password is valid. NeverExpires is true when the value is the one
        Microsoft Entra ID uses for "never expire" (2147483647). IsSet is false when the domain stores no value; what
        applies then is not stated by the API, so each check decides how to report it.

    .EXAMPLE
        Get-MtDomainPasswordValidity | Where-Object IsApplicable

        Returns the verified, managed domains with their password expiration period.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param ()

    $neverExpires = [int]::MaxValue
    foreach ($domain in @(Invoke-MtGraphRequest -RelativeUri 'domains')) {
        $raw = $domain.passwordValidityPeriodInDays
        $days = 0
        # A boolean or a value that is not a number means no period is stored.
        $isSet = ($null -ne $raw) -and ($raw -isnot [bool]) -and [int]::TryParse($raw.ToString(), [ref]$days)
        [pscustomobject]@{
            Id           = $domain.id
            IsApplicable = ($domain.authenticationType -eq 'Managed') -and ($domain.isVerified -eq $true)
            IsSet        = $isSet
            ValidityDays = if ($isSet) { $days } else { $null }
            NeverExpires = $isSet -and $days -eq $neverExpires
        }
    }
}
