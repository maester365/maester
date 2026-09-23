function Get-MtLdapFineGrainedPasswordPolicy {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [string] $SearchBase
    )

    try {
        if ([string]::IsNullOrWhiteSpace($SearchBase)) { $SearchBase = (Get-MtLdapRootDse -Connection $Connection).DefaultNamingContext }
        $attributes = @('distinguishedName', 'name', 'msDS-PasswordSettingsPrecedence', 'msDS-LockoutDuration', 'msDS-LockoutThreshold', 'msDS-MaximumPasswordAge', 'msDS-MinimumPasswordAge', 'msDS-MinimumPasswordLength', 'msDS-PasswordComplexityEnabled', 'msDS-PasswordHistoryLength', 'msDS-PSOAppliesTo')
        $entries = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase $SearchBase -Scope Subtree -Filter '(objectClass=msDS-PasswordSettings)' -Attributes $attributes)
        return @($entries | ForEach-Object { [PSCustomObject]@{
            DistinguishedName = [string]$_.DistinguishedName; Name = [string]$_.name; MsDsPasswordSettingsPrecedence = $_.'msDS-PasswordSettingsPrecedence'
            LockoutDuration = $_.'msDS-LockoutDuration'; LockoutThreshold = $_.'msDS-LockoutThreshold'; MaxPwdAge = $_.'msDS-MaximumPasswordAge'
            MinPwdAge = $_.'msDS-MinimumPasswordAge'; MinPwdLength = $_.'msDS-MinimumPasswordLength'; PwdProperties = $_.'msDS-PasswordComplexityEnabled'
            PwdHistoryLength = $_.'msDS-PasswordHistoryLength'; MsDsPsoAppliesTo = @($_.'msDS-PSOAppliesTo' | Where-Object { $null -ne $_ })
        } })
    }
    catch {
        Write-Verbose "Could not query LDAP fine-grained password policies: $($_.Exception.Message)"
        return @()
    }
}
