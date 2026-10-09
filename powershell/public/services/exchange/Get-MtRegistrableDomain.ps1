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

    $normalizedDomainName = $DomainName.Trim('.').ToLowerInvariant()
    $labels = $normalizedDomainName.Split('.')
    # If the domain has less than 2 labels, return it as is (e.g., localhost or similar)
    if ($labels.Count -lt 2) {
        return $normalizedDomainName
    }

    # Load public suffix list if not already loaded for performance
    if ($null -eq $script:MtPublicSuffixRules) {
        Write-Verbose 'Loading public suffix list for registrable domain extraction'
        $pslPath = Join-Path -Path $PSScriptRoot -ChildPath '../assets/public_domain_suffix_list.dat'
        $exactRules = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $wildcardRules = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $exceptionRules = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        foreach ($rule in (Get-Content -Path $pslPath -Encoding UTF8)) {
            $trimmedRule = $rule.Trim().ToLowerInvariant()
            if (($trimmedRule -eq '') -or $trimmedRule.StartsWith('//')) {
                continue
            }

            if ($trimmedRule.StartsWith('!')) {
                $null = $exceptionRules.Add($trimmedRule.Substring(1))
            } elseif ($trimmedRule.StartsWith('*.')) {
                $null = $wildcardRules.Add($trimmedRule.Substring(2))
            } else {
                $null = $exactRules.Add($trimmedRule)
            }
        }

        $script:MtPublicSuffixRules = @{
            Exact = $exactRules
            Wildcard = $wildcardRules
            Exception = $exceptionRules
        }
    }

    # Apply the public suffix list longest-match algorithm, including wildcard and exception rules.
    $publicSuffixLabelCount = 1
    for ($i = 0; $i -lt $labels.Count; $i++) {
        $candidate = $labels[$i..($labels.Count - 1)] -join '.'
        $candidateLabelCount = $labels.Count - $i

        if ($script:MtPublicSuffixRules.Exception.Contains($candidate)) {
            $publicSuffixLabelCount = $candidateLabelCount - 1
            break
        }

        if ($script:MtPublicSuffixRules.Exact.Contains($candidate) -and ($candidateLabelCount -gt $publicSuffixLabelCount)) {
            $publicSuffixLabelCount = $candidateLabelCount
        }

        if (($i -gt 0) -and $script:MtPublicSuffixRules.Wildcard.Contains($candidate) -and (($candidateLabelCount + 1) -gt $publicSuffixLabelCount)) {
            $publicSuffixLabelCount = $candidateLabelCount + 1
        }
    }

    if ($labels.Count -le $publicSuffixLabelCount) {
        return $normalizedDomainName
    }

    $registrableLabelCount = $publicSuffixLabelCount + 1
    return ($labels[($labels.Count - $registrableLabelCount)..($labels.Count - 1)] -join '.')
}
