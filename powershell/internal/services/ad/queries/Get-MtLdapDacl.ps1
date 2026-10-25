function Get-MtLdapDacl {
    <#
    .SYNOPSIS
    Collects DACL entries from LDAP with incremental progress reporting.
    .DESCRIPTION
    Uses the opt-in ProcessPage callback to flatten descriptors and report
    object/ACE counts after each page. Progress is best-effort; a synchronous
    page request or descriptor conversion may still pause updates.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [Parameter(Mandatory)]
        [string] $SearchBase,

        [string] $Filter = '(|(objectClass=organizationalUnit)(objectClass=container)(objectClass=groupPolicyContainer)(objectClass=domainDNS)(objectClass=computer)(objectClass=user)(objectClass=group))',

        [ValidateScript({ $_ -ge [timespan]::Zero })]
        [timespan] $ProgressInterval = [timespan]::FromSeconds(1),

        [ValidateRange(1, 10000)]
        [int] $PageSize = 1000
    )

    $attributes = @('distinguishedName', 'objectClass', 'name', 'objectSid', 'ntSecurityDescriptor')
    $securityDescriptorFlags = [System.DirectoryServices.SecurityMasks]::Owner -bor [System.DirectoryServices.SecurityMasks]::Group -bor [System.DirectoryServices.SecurityMasks]::Dacl

    $pageState = @{
        Rows = [System.Collections.Generic.List[object]]::new()
        Objects = [long]0
        Aces = [long]0
        LastEmit = [DateTime]::MinValue
        Interval = $ProgressInterval
        BaseDN = $SearchBase
    }

    $emit = {
        param($objects, $aces, $pageNumber, $hasMore, $estimate, $baseDN, $isTerminal, $showPageStatus = $true)
        $stage = if ($isTerminal) { "Collected AD DACLs: $objects objects, $aces ACEs" } else { 'Collecting AD DACLs' }
        $completed = if ($objects -gt [int]::MaxValue) { [int]::MaxValue } else { [int]$objects }
        $statusParts = [System.Collections.Generic.List[string]]::new()
        if ($isTerminal) {
            $statusParts.Add("100% complete; $aces ACEs collected; base $baseDN")
        }
        else {
            if ($hasMore -and $estimate -gt $objects) {
                $pct = [int][Math]::Floor([Math]::Min(99.0, 100.0 * [double]$objects / [double]$estimate))
                $statusParts.Add("~$pct% (approximate)")
            }
            $statusParts.Add("$objects objects processed; $aces ACEs collected")
            if ($showPageStatus -and $pageNumber -gt 0) { $statusParts.Add("page $pageNumber complete") }
            if ($showPageStatus -and $hasMore) { $statusParts.Add("reading page $($pageNumber + 1)") }
            $statusParts.Add("base $baseDN")
        }
        $status = $statusParts -join '; '
        try {
            Write-MtTestProgress -Stage $stage -Completed $completed -Status $status
        }
        catch {
            Write-Debug "DACL progress emission failed: $_"
        }
    }

    $processPage = {
        param($page, $state)
        $pageAces = 0
        foreach ($entry in $page.Entries) {
            $state.Objects++
            $descriptor = $entry.ntSecurityDescriptor
            if ($descriptor -is [byte[]]) { $descriptor = ConvertFrom-MtLdapSecurityDescriptor -RawSecurityDescriptor $descriptor }
            $aces = if ($null -eq $descriptor) { @() } else { @($descriptor.Access) }
            foreach ($ace in $aces) {
                $properties = [ordered]@{
                    ObjectDN = [string]$entry.DistinguishedName
                    ObjectClass = @($entry.objectClass)[-1]
                    ObjectName = [string]$entry.name
                    ObjectSid = $entry.objectSid
                }
                foreach ($property in $ace.PSObject.Properties) { $properties[$property.Name] = $property.Value }
                $state.Rows.Add([PSCustomObject]$properties) | Out-Null
                $state.Aces++
                $pageAces++
            }

            # Check interval after every object so progress updates during long pages
            $now = [DateTime]::UtcNow
            $shouldEmit = ($state.LastEmit -eq [DateTime]::MinValue) -or
                          ($now - $state.LastEmit -ge $state.Interval)
            if ($shouldEmit) {
                $state.LastEmit = $now
                & $emit $state.Objects $state.Aces $page.PageNumber $page.HasMore $page.EstimatedTotal $state.BaseDN $false $false
            }
        }

        # After each nonempty page, emit one page-status update
        if ($page.Entries.Count -gt 0) {
            $state.LastEmit = [DateTime]::UtcNow
            & $emit $state.Objects $state.Aces $page.PageNumber $page.HasMore $page.EstimatedTotal $state.BaseDN $false $true
        }

        # Empty intermediate pages with HasMore still report progress
        if ($page.Entries.Count -eq 0) {
            $now = [DateTime]::UtcNow
            $shouldEmit = ($state.LastEmit -eq [DateTime]::MinValue) -or
                          ($now - $state.LastEmit -ge $state.Interval)
            if ($shouldEmit) {
                $state.LastEmit = $now
                & $emit $state.Objects $state.Aces $page.PageNumber $page.HasMore $page.EstimatedTotal $state.BaseDN $false $true
            }
        }
    }

    try {
        $pageState.LastEmit = [DateTime]::UtcNow
        & $emit 0 0 0 $true 0 $SearchBase $false $true
        $null = Invoke-MtLdapSearch -Connection $Connection -SearchBase $SearchBase -Scope Subtree -Filter $Filter -Attributes $attributes -SecurityDescriptorFlags $securityDescriptorFlags -PageSize $PageSize -ProcessPage $processPage -PageState $pageState
        & $emit $pageState.Objects $pageState.Aces 0 $false 0 $SearchBase $true $true
    }
    finally {
        try { Write-MtTestProgress -Clear } catch { Write-Debug "DACL progress clear failed: $_" }
    }

    return @($pageState.Rows)
}
