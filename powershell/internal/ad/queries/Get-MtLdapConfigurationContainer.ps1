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

    try {
        $commonAttributes = @('distinguishedName', 'name', 'objectClass', 'whenCreated', 'whenChanged')
        $pkiBase = 'CN=Public Key Services,CN=Services'
        $wellKnown = Invoke-ConfigurationSearch -RelativeSearchBase 'CN=WellKnown Security Principals' -Scope OneLevel -Filter '(objectClass=*)' -Attributes ($commonAttributes + @('objectSid'))
        $siteLinks = Invoke-ConfigurationSearch -RelativeSearchBase 'CN=Inter-Site Transports,CN=Sites' -Scope Subtree -Filter '(objectClass=siteLink)' -Attributes ($commonAttributes + @('cost', 'replInterval', 'siteList', 'options'))
        $dhcp = Invoke-ConfigurationSearch -RelativeSearchBase 'CN=NetServices,CN=Services' -Scope OneLevel -Filter '(|(objectClass=dhcpClass)(objectClass=dhcpServer)(objectClass=serviceConnectionPoint))' -Attributes ($commonAttributes + @('serviceBindingInformation', 'keywords'))
        $authN = Invoke-ConfigurationSearch -RelativeSearchBase 'CN=AuthN Policy Configuration,CN=Services' -Scope Subtree -Filter '(objectClass=*)' -Attributes ($commonAttributes + @('msDS-ServiceAllowedToAuthenticateFrom', 'msDS-ServiceAllowedToAuthenticateTo'))
        $trustedRoots = Invoke-ConfigurationSearch -RelativeSearchBase "CN=Certification Authorities,$pkiBase" -Scope OneLevel -Filter '(objectClass=certificationAuthority)' -Attributes ($commonAttributes + @('cACertificate'))
        $intermediate = Invoke-ConfigurationSearch -RelativeSearchBase "CN=AIA,$pkiBase" -Scope OneLevel -Filter '(objectClass=certificationAuthority)' -Attributes ($commonAttributes + @('cACertificate'))
        $enterprise = Invoke-ConfigurationSearch -RelativeSearchBase "CN=Enrollment Services,$pkiBase" -Scope OneLevel -Filter '(objectClass=pKIEnrollmentService)' -Attributes ($commonAttributes + @('certificateTemplates', 'dNSHostName', 'cACertificate', 'flags'))
        $securityDescriptorFlags = [System.DirectoryServices.SecurityMasks]::Owner -bor [System.DirectoryServices.SecurityMasks]::Group -bor [System.DirectoryServices.SecurityMasks]::Dacl
        $templates = Invoke-ConfigurationSearch -RelativeSearchBase "CN=Certificate Templates,$pkiBase" -Scope OneLevel -Filter '(objectClass=pKICertificateTemplate)' -Attributes ($commonAttributes + @('displayName', 'pKIExtendedKeyUsage', 'msPKI-Enrollment-Flag', 'msPKI-Certificate-Name-Flag', 'nTSecurityDescriptor')) -SecurityDescriptorFlags $securityDescriptorFlags
        $cdp = Invoke-ConfigurationSearch -RelativeSearchBase "CN=CDP,$pkiBase" -Scope OneLevel -Filter '(|(objectClass=cRLDistributionPoint)(objectClass=certificationAuthority))' -Attributes ($commonAttributes + @('certificateRevocationList'))
        $ntAuth = Invoke-ConfigurationSearch -RelativeSearchBase "CN=NTAuthCertificates,$pkiBase" -Scope Base -Filter '(objectClass=certificationAuthority)' -Attributes ($commonAttributes + @('cACertificate'))
        $policies = Invoke-ConfigurationSearch -RelativeSearchBase 'CN=Query Policies,CN=Directory Service,CN=Windows NT,CN=Services' -Scope OneLevel -Filter '(objectClass=queryPolicy)' -Attributes ($commonAttributes + @('lDAPAdminLimits'))
        $directoryService = Invoke-ConfigurationSearch -RelativeSearchBase 'CN=Directory Service,CN=Windows NT,CN=Services' -Scope Base -Filter '(objectClass=nTDSService)' -Attributes @('tombstoneLifetime', 'dSHeuristics', 'sPNMappings') | Select-Object -First 1
        $kds = Invoke-ConfigurationSearch -RelativeSearchBase 'CN=Master Root Keys,CN=Group Key Distribution,CN=Services' -Scope OneLevel -Filter '(objectClass=msKds-ProvRootKey)' -Attributes ($commonAttributes + @('msKds-CreateTime', 'msKds-DomainID', 'msKds-RootKeyData'))
        $activation = Invoke-ConfigurationSearch -RelativeSearchBase 'CN=Activation Objects,CN=Services' -Scope OneLevel -Filter '(|(objectClass=msImaging-PSP)(objectClass=serviceConnectionPoint))' -Attributes ($commonAttributes + @('keywords', 'serviceBindingInformation'))
        $enrollmentTemplates = [string[]]@($enterprise | ForEach-Object { @($_.certificateTemplates) } | Sort-Object -Unique)

        return [PSCustomObject]@{
            WellKnownSecurityPrincipals = @($wellKnown); SiteLinks = @($siteLinks); DhcpServers = @($dhcp); AuthNPolicyContainers = @($authN)
            TrustedRootCAs = @($trustedRoots); IntermediateCAs = @($intermediate); EnterpriseCAs = @($enterprise); CertificateTemplates = @($templates)
            EnrollmentTemplates = $enrollmentTemplates; CrlDistributionPoints = @($cdp); NtAuthCertificates = @($ntAuth); LdapQueryPolicies = @($policies)
            TombstoneLifetime = $directoryService.tombstoneLifetime; DsHeuristics = $directoryService.dSHeuristics; SpnMappings = @($directoryService.sPNMappings | Where-Object { $null -ne $_ })
            KdsRootKeys = @($kds); ActivationObjects = @($activation)
        }
    }
    catch {
        Write-Verbose "Could not query LDAP configuration containers: $($_.Exception.Message)"
        return $null
    }
}
