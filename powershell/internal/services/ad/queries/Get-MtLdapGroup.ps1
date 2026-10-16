function Get-MtLdapGroup {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [string] $SearchBase
    )

    try {
        if ([string]::IsNullOrWhiteSpace($SearchBase)) { $SearchBase = (Get-MtLdapRootDse -Connection $Connection).DefaultNamingContext }
        $attributes = @('distinguishedName', 'name', 'sAMAccountName', 'groupType', 'adminCount', 'whenCreated', 'whenChanged', 'managedBy', 'objectSid', 'sIDHistory', 'isCriticalSystemObject')
        $entries = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase $SearchBase -Scope Subtree -Filter '(objectClass=group)' -Attributes $attributes)
        return @($entries | ForEach-Object {
            $groupType = [long]$_.groupType
            $scope = if ($groupType -band 0x00000008) { 'Universal' } elseif ($groupType -band 0x00000004) { 'DomainLocal' } elseif ($groupType -band 0x00000002) { 'Global' } else { 'Unknown' }
            [PSCustomObject]@{
                DistinguishedName = [string]$_.DistinguishedName; Name = [string]$_.name; SamAccountName = [string]$_.sAMAccountName
                GroupCategory = if ($groupType -band 0x80000000L) { 'Security' } else { 'Distribution' }; GroupScope = $scope
                AdminCount = $_.adminCount; Created = $_.whenCreated; Modified = $_.whenChanged; ManagedBy = [string]$_.managedBy
                Sid = $_.objectSid; SidHistory = @($_.sIDHistory | Where-Object { $null -ne $_ }); IsCriticalSystemObject = if ($null -ne $_.isCriticalSystemObject) { [bool]$_.isCriticalSystemObject } else { $null }
            }
        })
    }
    catch {
        Write-Verbose "Could not query LDAP group objects: $($_.Exception.Message)"
        return @()
    }
}
