function Get-MtADDacls {
    <#
    .SYNOPSIS
    Collects Active Directory ACLs (Access Control Lists).

    .DESCRIPTION
    Collects ACLs from AD objects including domains, OUs, GPOs, users, computers, and groups.
    Results are cached for the session to avoid repeated queries.

    .PARAMETER DnBase
    The distinguished name base(s) to search. Defaults to the domain root.

    .PARAMETER Refresh
    Forces a refresh of the data from Active Directory, bypassing the cache.

    .EXAMPLE
    Get-MtADDacls

    Returns cached DACLs or collects if not already cached.

    .EXAMPLE
    Get-MtADDacls -Refresh

    Forces a fresh collection of ACL data from Active Directory.

    .EXAMPLE
    Get-MtADDacls -DnBase "OU=Users,DC=contoso,DC=com"

    Collects ACLs only from the specified OU.

    .LINK
    https://maester.dev/docs/commands/Get-MtADDacls
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using Details')]
    [CmdletBinding()]
    param(
        [string[]]$DnBase,
        [switch]$Refresh
    )

    $cacheKey = 'Dacls'

    if ($Refresh -or -not $__MtSession.ADCache.ContainsKey($cacheKey)) {
        Write-Verbose 'Collecting AD ACLs from Active Directory'

        try {
            if (-not $DnBase) {
                $DnBase = (Get-ADDomain).DistinguishedName
            }

            $dacls = @()

            foreach ($base in $DnBase) {
                Write-Verbose "Searching DN base: $base"

                $objSearcher = New-Object System.DirectoryServices.DirectorySearcher ([ADSI]"LDAP://$base")
                $objSearcher.PageSize = 200
                $objSearcher.Filter = "(|(objectClass=domain)(objectCategory=organizationalUnit)(objectCategory=groupPolicyContainer)(samAccountType=805306368)(samAccountType=805306369)(samaccounttype=268435456)(samaccounttype=268435457)(samaccounttype=536870912)(samaccounttype=536870913))"
                $objSearcher.SecurityMasks = [System.DirectoryServices.SecurityMasks]::Dacl -bor [System.DirectoryServices.SecurityMasks]::Group -bor [System.DirectoryServices.SecurityMasks]::Owner -bor [System.DirectoryServices.SecurityMasks]::Sacl
                [void]$objSearcher.PropertiesToLoad.AddRange(('displayname', 'distinguishedname', 'name', 'ntsecuritydescriptor', 'objectclass', 'objectsid'))
                $objSearcher.SearchScope = 'Subtree'

                $results = $objSearcher.FindAll()
                Write-Verbose "Found $($results.Count) objects in $base"

                foreach ($obj in $results) {
                    $aces = ([adsi]$obj.Path).ObjectSecurity.Access
                    $aces | Add-Member -MemberType NoteProperty -Name Object -Value $obj.Path -PassThru | ForEach-Object {
                        $dacls += $_
                    }
                }
                $objSearcher.Dispose()
            }

            $__MtSession.ADCache[$cacheKey] = $dacls
            $__MtSession.ADCollectionTime = Get-Date

            Write-Verbose "Successfully collected $($dacls.Count) ACL entries"
        } catch [Management.Automation.CommandNotFoundException] {
            Write-Error "The Active Directory module is not installed. Please install RSAT-AD-PowerShell or run on a domain-joined machine."
            return $null
        } catch {
            Write-Error "Failed to collect AD ACLs: $($_.Exception.Message)"
            return $null
        }
    } else {
        Write-Verbose 'Using cached AD ACL data'
    }

    return $__MtSession.ADCache[$cacheKey]
}


