function Get-MtLdapConfigurationContainer {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Connection', Justification = 'Used by the nested configuration search helper.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'ConfigurationNamingContext', Justification = 'Used by the nested configuration search helper.')]
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [Parameter(Mandatory)]
        [string] $ConfigurationNamingContext
    )

    function Invoke-ConfigurationSearch {
        param(
            [string] $RelativeSearchBase,
            [string] $Scope,
            [string] $Filter,
            [string[]] $Attributes,
            [System.DirectoryServices.SecurityMasks] $SecurityDescriptorFlags
        )

        $base = if ([string]::IsNullOrEmpty($RelativeSearchBase)) { $ConfigurationNamingContext } else { "$RelativeSearchBase,$ConfigurationNamingContext" }
        try {
            $searchParameters = @{ Connection = $Connection; SearchBase = $base; Scope = $Scope; Filter = $Filter; Attributes = $Attributes; PageSize = $(if ($Scope -eq 'Base') { 0 } else { 1000 }) }
            if ($PSBoundParameters.ContainsKey('SecurityDescriptorFlags')) { $searchParameters['SecurityDescriptorFlags'] = $SecurityDescriptorFlags }
            return @(Invoke-MtLdapSearch @searchParameters)
        }
        catch {
            Write-Verbose "Could not query LDAP configuration path '$base': $($_.Exception.Message)"
            return @()
        }
    }

    $commonAttributes = @('distinguishedName', 'name', 'objectClass', 'whenCreated', 'whenChanged')
    $pkiBase = 'CN=Public Key Services,CN=Services'

    $wellKnown = @()
    try {
        $wellKnown = Invoke-ConfigurationSearch -RelativeSearchBase 'CN=WellKnown Security Principals' -Scope OneLevel -Filter '(objectClass=*)' -Attributes ($commonAttributes + @('objectSid'))
    }
    catch {
        Write-Verbose "Could not query WellKnown Security Principals: $($_.Exception.Message)"
    }

    $siteLinks = @()
    try {
        $siteLinks = Invoke-ConfigurationSearch -RelativeSearchBase 'CN=Inter-Site Transports,CN=Sites' -Scope Subtree -Filter '(objectClass=siteLink)' -Attributes ($commonAttributes + @('cost', 'replInterval', 'siteList', 'options'))
    }
    catch {
        Write-Verbose "Could not query Site Links: $($_.Exception.Message)"
    }

    $dhcp = @()
    try {
        $dhcp = Invoke-ConfigurationSearch -RelativeSearchBase 'CN=NetServices,CN=Services' -Scope OneLevel -Filter '(|(objectClass=dhcpClass)(objectClass=dhcpServer)(objectClass=serviceConnectionPoint))' -Attributes ($commonAttributes + @('serviceBindingInformation', 'keywords'))
    }
    catch {
        Write-Verbose "Could not query DHCP servers: $($_.Exception.Message)"
    }

    $authN = @()
    try {
        $authN = Invoke-ConfigurationSearch -RelativeSearchBase 'CN=AuthN Policy Configuration,CN=Services' -Scope Subtree -Filter '(objectClass=*)' -Attributes ($commonAttributes + @('msDS-ServiceAllowedToAuthenticateFrom', 'msDS-ServiceAllowedToAuthenticateTo'))
    }
    catch {
        Write-Verbose "Could not query AuthN Policy Configuration: $($_.Exception.Message)"
    }

    $trustedRoots = @()
    try {
        $trustedRoots = Invoke-ConfigurationSearch -RelativeSearchBase "CN=Certification Authorities,$pkiBase" -Scope OneLevel -Filter '(objectClass=certificationAuthority)' -Attributes ($commonAttributes + @('cACertificate'))
    }
    catch {
        Write-Verbose "Could not query Trusted Root CAs: $($_.Exception.Message)"
    }

    $intermediate = @()
    try {
        $intermediate = Invoke-ConfigurationSearch -RelativeSearchBase "CN=AIA,$pkiBase" -Scope OneLevel -Filter '(objectClass=certificationAuthority)' -Attributes ($commonAttributes + @('cACertificate'))
    }
    catch {
        Write-Verbose "Could not query Intermediate CAs: $($_.Exception.Message)"
    }

    $enterprise = @()
    try {
        $enterprise = Invoke-ConfigurationSearch -RelativeSearchBase "CN=Enrollment Services,$pkiBase" -Scope OneLevel -Filter '(objectClass=pKIEnrollmentService)' -Attributes ($commonAttributes + @('certificateTemplates', 'dNSHostName', 'cACertificate', 'flags'))
    }
    catch {
        Write-Verbose "Could not query Enterprise CAs: $($_.Exception.Message)"
    }

    $templates = @()
    try {
        $securityDescriptorFlags = [System.DirectoryServices.SecurityMasks]::Owner -bor [System.DirectoryServices.SecurityMasks]::Group -bor [System.DirectoryServices.SecurityMasks]::Dacl
        $templates = Invoke-ConfigurationSearch -RelativeSearchBase "CN=Certificate Templates,$pkiBase" -Scope OneLevel -Filter '(objectClass=pKICertificateTemplate)' -Attributes ($commonAttributes + @('displayName', 'pKIExtendedKeyUsage', 'msPKI-Enrollment-Flag', 'msPKI-Certificate-Name-Flag', 'nTSecurityDescriptor')) -SecurityDescriptorFlags $securityDescriptorFlags
    }
    catch {
        Write-Verbose "Could not query Certificate Templates: $($_.Exception.Message)"
    }

    $cdp = @()
    try {
        $cdp = Invoke-ConfigurationSearch -RelativeSearchBase "CN=CDP,$pkiBase" -Scope OneLevel -Filter '(|(objectClass=cRLDistributionPoint)(objectClass=certificationAuthority))' -Attributes ($commonAttributes + @('certificateRevocationList'))
    }
    catch {
        Write-Verbose "Could not query CRL Distribution Points: $($_.Exception.Message)"
    }

    $ntAuth = @()
    try {
        $ntAuth = Invoke-ConfigurationSearch -RelativeSearchBase "CN=NTAuthCertificates,$pkiBase" -Scope Base -Filter '(objectClass=certificationAuthority)' -Attributes ($commonAttributes + @('cACertificate'))
    }
    catch {
        Write-Verbose "Could not query NTAuth Certificates: $($_.Exception.Message)"
    }

    $policies = @()
    try {
        $policies = Invoke-ConfigurationSearch -RelativeSearchBase 'CN=Query Policies,CN=Directory Service,CN=Windows NT,CN=Services' -Scope OneLevel -Filter '(objectClass=queryPolicy)' -Attributes ($commonAttributes + @('lDAPAdminLimits'))
    }
    catch {
        Write-Verbose "Could not query LDAP Query Policies: $($_.Exception.Message)"
    }

    $directoryService = $null
    try {
        $directoryService = Invoke-ConfigurationSearch -RelativeSearchBase 'CN=Directory Service,CN=Windows NT,CN=Services' -Scope Base -Filter '(objectClass=nTDSService)' -Attributes @('tombstoneLifetime', 'dSHeuristics', 'sPNMappings') | Select-Object -First 1
    }
    catch {
        Write-Verbose "Could not query Directory Service: $($_.Exception.Message)"
    }

    $kds = @()
    try {
        $kds = Invoke-ConfigurationSearch -RelativeSearchBase 'CN=Master Root Keys,CN=Group Key Distribution,CN=Services' -Scope OneLevel -Filter '(objectClass=msKds-ProvRootKey)' -Attributes ($commonAttributes + @('msKds-CreateTime', 'msKds-DomainID', 'msKds-RootKeyData'))
    }
    catch {
        Write-Verbose "Could not query KDS Root Keys: $($_.Exception.Message)"
    }

    $activation = @()
    try {
        $activation = Invoke-ConfigurationSearch -RelativeSearchBase 'CN=Activation Objects,CN=Services' -Scope OneLevel -Filter '(|(objectClass=msImaging-PSP)(objectClass=serviceConnectionPoint))' -Attributes ($commonAttributes + @('keywords', 'serviceBindingInformation'))
    }
    catch {
        Write-Verbose "Could not query Activation Objects: $($_.Exception.Message)"
    }

    $enrollmentTemplates = @()
    try {
        $enrollmentTemplates = [string[]]@($enterprise | ForEach-Object { @($_.certificateTemplates) } | Sort-Object -Unique)
    }
    catch {
        Write-Verbose "Could not derive Enrollment Templates: $($_.Exception.Message)"
    }

    return [PSCustomObject]@{
        WellKnownSecurityPrincipals = @($wellKnown); SiteLinks = @($siteLinks); DhcpServers = @($dhcp); AuthNPolicyContainers = @($authN)
        TrustedRootCAs = @($trustedRoots); IntermediateCAs = @($intermediate); EnterpriseCAs = @($enterprise); CertificateTemplates = @($templates)
        EnrollmentTemplates = $enrollmentTemplates; CrlDistributionPoints = @($cdp); NtAuthCertificates = @($ntAuth); LdapQueryPolicies = @($policies)
        TombstoneLifetime = if ($null -ne $directoryService) { $directoryService.tombstoneLifetime } else { $null }
        DsHeuristics = if ($null -ne $directoryService) { $directoryService.dSHeuristics } else { $null }
        SpnMappings = if ($null -ne $directoryService) { @($directoryService.sPNMappings | Where-Object { $null -ne $_ }) } else { @() }
        KdsRootKeys = @($kds); ActivationObjects = @($activation)
    }
}
