BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name ConvertTo-MtAdConfigurationInventoryCell, Get-MtAdConfigurationInventory,
    Get-MtAdCertificateInventory, Get-MtAdConfigurationInventorySiteLinkTransport, Invoke-MtAdConfigurationInventoryReport
}

Describe 'AD configuration inventory batch' {
    BeforeAll {
        $certificate = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new('CN=Inventory CA', [System.Security.Cryptography.RSA]::Create(2048), [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1).CreateSelfSigned((Get-Date).AddDays(-20), (Get-Date).AddDays(-1))
        $bytes = $certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
        $script:certBytes = $bytes
    }

    It 'treats a single DER byte array as one expired observation in each published role' {
        $config = [pscustomobject]@{ EnterpriseCAs = @([pscustomobject]@{ Name = 'CA'; cACertificate = $script:certBytes }); TrustedRootCAs = @([pscustomobject]@{ Name = 'Root'; cACertificate = @($script:certBytes, $script:certBytes) }); IntermediateCAs = @(); NtAuthCertificates = @() }
        $rows = @(Get-MtAdCertificateInventory -Configuration $config)
        $rows.Count | Should -Be 3
        @($rows | Where-Object Role -eq 'Trusted root').Count | Should -Be 2
        $rows[0].Status | Should -Be 'Expired (review)'
        $rows[0].Thumbprint | Should -Not -BeNullOrEmpty
    }

    It 'throws on malformed certificate data rather than reporting an incomplete inventory' {
        $config = [pscustomobject]@{ EnterpriseCAs = @([pscustomobject]@{ Name = 'Bad'; cACertificate = [byte[]](1, 2, 3) }); TrustedRootCAs = @(); IntermediateCAs = @(); NtAuthCertificates = @() }
        { Get-MtAdCertificateInventory -Configuration $config } | Should -Throw '*Unable to parse public certificate*'
    }

    It 'distinguishes missing data from a retrieved empty collection' {
        $state = [pscustomobject]@{ Configuration = [pscustomobject]@{ SiteLinks = @() } }
        @(Get-MtAdConfigurationInventory -State $state -Required SiteLinks).Count | Should -Be 1
        { Get-MtAdConfigurationInventory -State $state -Required CertificateTemplates } | Should -Throw '*unavailable*'
    }

    It 'classifies transport by parent DN and retains zero cost' {
        $config = [pscustomobject]@{ SiteLinks = @(
                [pscustomobject]@{ Name = 'A'; DistinguishedName = 'CN=A,CN=SMTP,CN=Inter-Site Transports,CN=Sites,DC=test'; cost = 0; ReplicationFrequencyInMinutes = 15; siteList = @('CN=Site1') },
                [pscustomobject]@{ Name = 'B'; DistinguishedName = 'CN=B,CN=IP,CN=Inter-Site Transports,CN=Sites,DC=test'; cost = 10; ReplicationFrequencyInMinutes = $null; siteList = @() }
            ) }
        $links = @(Get-MtAdConfigurationInventorySiteLinkTransport -Configuration $config)
        $links[0].Transport | Should -Be 'SMTP'
        $links[0].Cost | Should -Be 0
        $links[1].Transport | Should -Be 'IP'
    }

    It 'escapes Markdown table markup and HTML in directory values' {
        (ConvertTo-MtAdConfigurationInventoryCell "bad|<script>`nname") | Should -Be 'bad&#124;&lt;script&gt; name'
    }

    It 'includes unknown published names instead of silently omitting them' {
        Mock Get-MtADDomainState -ModuleName Maester { [pscustomobject]@{ Configuration = [pscustomobject]@{ CertificateTemplates = @([pscustomobject]@{ Name = 'Known'; displayName = 'Known' }); EnrollmentTemplates = @('Known', 'Unknown'); EnterpriseCAs = @([pscustomobject]@{ Name = 'CA'; certificateTemplates = @('Known', 'Unknown') }) } } }
        Mock Add-MtTestResultDetail -ModuleName Maester { $script:detail = $Result }
        Invoke-MtAdConfigurationInventoryReport -Kind Templates | Should -BeTrue
        $script:detail | Should -Match 'unknown template'
        $script:detail | Should -Match 'published names without a template object: 1'
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate }
    }

    It 'reports a valid empty optional certificate container as an inventory' {
        Mock Get-MtADDomainState -ModuleName Maester { [pscustomobject]@{ Configuration = [pscustomobject]@{ EnterpriseCAs = @(); TrustedRootCAs = @(); IntermediateCAs = @() } } }
        Mock Add-MtTestResultDetail -ModuleName Maester { $script:detail = $Result }
        Invoke-MtAdConfigurationInventoryReport -Kind Certificates | Should -BeTrue
        $script:detail | Should -Match 'public certificate entries: 0'
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate }
    }

    It 'does not mistake a missing published template list for an empty one' {
        Mock Get-MtADDomainState -ModuleName Maester { [pscustomobject]@{ Configuration = [pscustomobject]@{ EnterpriseCAs = @(); CertificateTemplates = @() } } }
        { Invoke-MtAdConfigurationInventoryReport -Kind Templates } | Should -Throw '*EnrollmentTemplates data is unavailable*'
    }
}
