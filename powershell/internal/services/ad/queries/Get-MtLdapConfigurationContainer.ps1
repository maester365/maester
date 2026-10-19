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
        $searchParameters = @{ Connection = $Connection; SearchBase = $base; Scope = $Scope; Filter = $Filter; Attributes = $Attributes; PageSize = $(if ($Scope -eq 'Base') { 0 } else { 1000 }) }
        if ($PSBoundParameters.ContainsKey('SecurityDescriptorFlags')) { $searchParameters['SecurityDescriptorFlags'] = $SecurityDescriptorFlags }
        return @(Invoke-MtLdapSearch @searchParameters)
    }

    function Invoke-ConfigurationSearchSafe {
        param(
            [string] $RelativeSearchBase,
            [string] $Scope,
            [string] $Filter,
            [string[]] $Attributes,
            [System.DirectoryServices.SecurityMasks] $SecurityDescriptorFlags
        )
        try {
            $params = @{ RelativeSearchBase = $RelativeSearchBase; Scope = $Scope; Filter = $Filter; Attributes = $Attributes }
            if ($PSBoundParameters.ContainsKey('SecurityDescriptorFlags')) { $params['SecurityDescriptorFlags'] = $SecurityDescriptorFlags }
            return @(Invoke-ConfigurationSearch @params)
        } catch [System.DirectoryServices.Protocols.DirectoryOperationException] {
            if ($_.Exception.Response.ResultCode -eq [System.DirectoryServices.Protocols.ResultCode]::NoSuchObject) {
                return @()
            }
            throw  # Re-throw genuine LDAP failures so the category handler skips
        }
    }

    $commonAttributes = @('distinguishedName', 'name', 'objectClass', 'whenCreated', 'whenChanged')
    $pkiBase = 'CN=Public Key Services,CN=Services'

    $wellKnown = Invoke-ConfigurationSearchSafe -RelativeSearchBase 'CN=WellKnown Security Principals' -Scope OneLevel -Filter '(objectClass=*)' -Attributes ($commonAttributes + @('objectSid'))

    $rawSiteLinks = Invoke-ConfigurationSearchSafe -RelativeSearchBase 'CN=Inter-Site Transports,CN=Sites' -Scope Subtree -Filter '(objectClass=siteLink)' -Attributes ($commonAttributes + @('cost', 'replInterval', 'siteList', 'options'))
    $siteLinks = @($rawSiteLinks | ForEach-Object {
        $replInterval = if ($null -ne $_.replInterval) { [int]$_.replInterval } else { $null }
        $_ | Add-Member -NotePropertyName ReplicationFrequencyInMinutes -NotePropertyValue $replInterval -Force
        $_
    })

    $dhcp = Invoke-ConfigurationSearchSafe -RelativeSearchBase 'CN=NetServices,CN=Services' -Scope OneLevel -Filter '(|(objectClass=dhcpClass)(objectClass=dhcpServer)(objectClass=serviceConnectionPoint))' -Attributes ($commonAttributes + @('serviceBindingInformation', 'keywords'))

    $authN = Invoke-ConfigurationSearchSafe -RelativeSearchBase 'CN=AuthN Policy Configuration,CN=Services' -Scope Subtree -Filter '(objectClass=*)' -Attributes ($commonAttributes + @('msDS-ServiceAllowedToAuthenticateFrom', 'msDS-ServiceAllowedToAuthenticateTo'))

    $trustedRoots = Invoke-ConfigurationSearchSafe -RelativeSearchBase "CN=Certification Authorities,$pkiBase" -Scope OneLevel -Filter '(objectClass=certificationAuthority)' -Attributes ($commonAttributes + @('cACertificate'))

    $intermediate = Invoke-ConfigurationSearchSafe -RelativeSearchBase "CN=AIA,$pkiBase" -Scope OneLevel -Filter '(objectClass=certificationAuthority)' -Attributes ($commonAttributes + @('cACertificate'))

    $enterprise = Invoke-ConfigurationSearchSafe -RelativeSearchBase "CN=Enrollment Services,$pkiBase" -Scope OneLevel -Filter '(objectClass=pKIEnrollmentService)' -Attributes ($commonAttributes + @('certificateTemplates', 'dNSHostName', 'cACertificate', 'flags'))

    $securityDescriptorFlags = [System.DirectoryServices.SecurityMasks]::Owner -bor [System.DirectoryServices.SecurityMasks]::Group -bor [System.DirectoryServices.SecurityMasks]::Dacl
    $templates = Invoke-ConfigurationSearchSafe -RelativeSearchBase "CN=Certificate Templates,$pkiBase" -Scope OneLevel -Filter '(objectClass=pKICertificateTemplate)' -Attributes ($commonAttributes + @('displayName', 'pKIExtendedKeyUsage', 'msPKI-Enrollment-Flag', 'msPKI-Certificate-Name-Flag', 'nTSecurityDescriptor')) -SecurityDescriptorFlags $securityDescriptorFlags

    $cdp = Invoke-ConfigurationSearchSafe -RelativeSearchBase "CN=CDP,$pkiBase" -Scope OneLevel -Filter '(|(objectClass=cRLDistributionPoint)(objectClass=certificationAuthority))' -Attributes ($commonAttributes + @('certificateRevocationList'))

    $ntAuth = Invoke-ConfigurationSearchSafe -RelativeSearchBase "CN=NTAuthCertificates,$pkiBase" -Scope Base -Filter '(objectClass=certificationAuthority)' -Attributes ($commonAttributes + @('cACertificate'))

    $policies = Invoke-ConfigurationSearchSafe -RelativeSearchBase 'CN=Query Policies,CN=Directory Service,CN=Windows NT,CN=Services' -Scope OneLevel -Filter '(objectClass=queryPolicy)' -Attributes ($commonAttributes + @('lDAPAdminLimits'))

    $directoryService = Invoke-ConfigurationSearchSafe -RelativeSearchBase 'CN=Directory Service,CN=Windows NT,CN=Services' -Scope Base -Filter '(objectClass=nTDSService)' -Attributes @('tombstoneLifetime', 'dSHeuristics', 'sPNMappings') | Select-Object -First 1

    $kds = Invoke-ConfigurationSearch -RelativeSearchBase 'CN=Master Root Keys,CN=Group Key Distribution Service,CN=Services' -Scope OneLevel -Filter '(objectClass=msKds-ProvRootKey)' -Attributes ($commonAttributes + @('msKds-CreateTime', 'msKds-DomainID'))

    $activation = Invoke-ConfigurationSearchSafe -RelativeSearchBase 'CN=Activation Objects,CN=Microsoft SPP,CN=Services' -Scope OneLevel -Filter '(|(objectClass=msImaging-PSP)(objectClass=serviceConnectionPoint))' -Attributes ($commonAttributes + @('keywords', 'serviceBindingInformation'))

    $enrollmentTemplates = [string[]]@($enterprise | ForEach-Object { @($_.certificateTemplates) } | Sort-Object -Unique)

    return [PSCustomObject]@{
        WellKnownSecurityPrincipals = @($wellKnown); SiteLinks = @($siteLinks); DhcpServers = @($dhcp); AuthNPolicyContainers = @($authN)
        TrustedRootCAs = @($trustedRoots); IntermediateCAs = @($intermediate); EnterpriseCAs = @($enterprise); CertificateTemplates = @($templates)
        EnrollmentTemplates = $enrollmentTemplates; CrlDistributionPoints = @($cdp); NtAuthCertificates = @($ntAuth); LdapQueryPolicies = @($policies)
        TombstoneLifetime = if ($null -ne $directoryService) { $directoryService.tombstoneLifetime } else { $null }
        DsHeuristics = if ($null -ne $directoryService) { $directoryService.dSHeuristics } else { $null }
        SpnMappings = if ($null -ne $directoryService) { @($directoryService.sPNMappings | Where-Object { $null -ne $_ }) } else { @() }
        KdsRootKeys = $kds; ActivationObjects = @($activation)
    }
}
