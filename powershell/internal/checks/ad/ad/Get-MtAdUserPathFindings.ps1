function Get-MtAdUserPathFindings {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Internal helper returns a collection of path findings.')]
    [CmdletBinding()]
    param([object[]] $Users, [string[]] $ApprovedPathPrefixes)

    foreach ($user in $Users) {
        foreach ($field in @('HomeDirectory', 'ProfilePath', 'ScriptPath')) {
            $path = [string]$user.$field
            if ([string]::IsNullOrWhiteSpace($path)) { continue }
            $normalized = $path.Replace('/', '\').TrimEnd('\')
            $reason = $null
            if ($normalized -match '(^|\\)\.\.(\\|$)') { $reason = 'Parent traversal (reject)' }
            elseif ($field -eq 'ScriptPath' -and $normalized -notmatch '^(\\\\|[A-Za-z]:\\)') {
                $reason = 'Relative NETLOGON script: review (not failed)'
            } else {
                $approved = $false
                foreach ($prefix in $ApprovedPathPrefixes) {
                    if ([string]::IsNullOrWhiteSpace($prefix)) { continue }
                    $base = $prefix.Replace('/', '\').TrimEnd('\')
                    if ($base -match '(^|\\)\.\.(\\|$)') { throw "Approved prefix contains traversal: $prefix" }
                    if ($base -notmatch '^(\\\\[^\\]+\\[^\\]+|[A-Za-z]:\\)') { throw "Approved prefix must be an absolute UNC or drive path: $prefix" }
                    if ($normalized.Equals($base, [StringComparison]::OrdinalIgnoreCase) -or
                        $normalized.StartsWith($base + '\', [StringComparison]::OrdinalIgnoreCase)) { $approved = $true; break }
                }
                if (-not $approved) { $reason = 'Unapproved path' }
            }
            if ($null -ne $reason) {
                [pscustomobject]@{ SamAccountName = $user.SamAccountName; Field = $field; Path = $path; Finding = $reason }
            }
        }
    }
}
