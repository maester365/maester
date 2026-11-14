BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name Get-MtAdNtAuthCertificatePath, Get-MtAdCertificateInventory

    function New-PathTestCertificate {
        param(
            [string] $Name,
            $Issuer,
            [bool] $IsCa = $true,
            [bool] $CanSign = $true,
            [int] $PathLength = 5,
            [datetime] $NotBefore = (Get-Date).AddDays(-2),
            [datetime] $NotAfter = (Get-Date).AddDays(30),
            [string] $AiaUrl
        )
        $key = [Security.Cryptography.RSA]::Create(2048)
        try {
            $request = [Security.Cryptography.X509Certificates.CertificateRequest]::new("CN=$Name", $key, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
            $request.CertificateExtensions.Add([Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new($IsCa, $IsCa, $PathLength, $true))
            $usage = if ($CanSign) { [Security.Cryptography.X509Certificates.X509KeyUsageFlags]::KeyCertSign } else { [Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DigitalSignature }
            $request.CertificateExtensions.Add([Security.Cryptography.X509Certificates.X509KeyUsageExtension]::new($usage, $true))
            $request.CertificateExtensions.Add([Security.Cryptography.X509Certificates.X509SubjectKeyIdentifierExtension]::new($request.PublicKey, $false))
            if ($AiaUrl) {
                $request.CertificateExtensions.Add([Security.Cryptography.X509Certificates.X509AuthorityInformationAccessExtension]::new([string[]]@(), [string[]]@($AiaUrl), $false))
            }
            if ($Issuer) {
                $serial = [byte[]]::new(16)
                [Security.Cryptography.RandomNumberGenerator]::Fill($serial)
                $public = $request.Create($Issuer, $NotBefore, $NotAfter, $serial)
                try { return [Security.Cryptography.X509Certificates.RSACertificateExtensions]::CopyWithPrivateKey($public, $key) }
                finally { $public.Dispose() }
            }
            return $request.CreateSelfSigned($NotBefore, $NotAfter)
        } finally { $key.Dispose() }
    }

    $script:root = New-PathTestCertificate -Name 'Approved Root' -NotBefore (Get-Date).AddYears(-2) -NotAfter (Get-Date).AddYears(2)
    $script:intermediate = New-PathTestCertificate -Name 'Intermediate CA' -Issuer $script:root -NotBefore (Get-Date).AddYears(-1) -NotAfter (Get-Date).AddYears(1)
    $script:issuing = New-PathTestCertificate -Name 'Third-party Issuing CA' -Issuer $script:intermediate -PathLength 0
    $script:direct = New-PathTestCertificate -Name 'Direct Issuing CA' -Issuer $script:root -PathLength 0

    function Get-PathTestConfiguration {
        [pscustomobject]@{
            NtAuthCertificates = @([pscustomobject]@{ Name = 'NTAuthCertificates'; cACertificate = $script:issuing.RawData })
            TrustedRootCAs = @([pscustomobject]@{ Name = 'Root'; cACertificate = $script:root.RawData })
            IntermediateCAs = @([pscustomobject]@{ Name = 'Intermediate'; cACertificate = $script:intermediate.RawData })
            EnterpriseCAs = @()
        }
    }
}

AfterAll {
    foreach ($certificate in $script:root, $script:intermediate, $script:issuing, $script:direct) { $certificate.Dispose() }
}

Describe 'Offline NTAuth certificate paths' {
    It 'verifies a real three-certificate path without an enterprise CA registration' {
        $rows = @(Get-MtAdNtAuthCertificatePath -Configuration (Get-PathTestConfiguration))
        $rows.Count | Should -Be 1
        $rows[0].Verified | Should -BeTrue
        $rows[0].Path.Count | Should -Be 3
        $rows[0].RootThumbprint | Should -Be $script:root.Thumbprint
        $rows[0].Issues | Should -BeNullOrEmpty
    }
    It 'accepts an issuer supplied in the enterprise CA inventory' {
        $config = Get-PathTestConfiguration
        $config.EnterpriseCAs = $config.IntermediateCAs
        $config.IntermediateCAs = @()
        (Get-MtAdNtAuthCertificatePath $config).Verified | Should -BeTrue
    }
    It 'accepts a direct root-issued CA certificate in base64 form' {
        $config = Get-PathTestConfiguration
        $config.NtAuthCertificates[0].cACertificate = [Convert]::ToBase64String($script:direct.RawData)
        (Get-MtAdNtAuthCertificatePath $config).Verified | Should -BeTrue
    }
    It 'recognizes an explicitly published root also present in NTAuth' {
        $config = Get-PathTestConfiguration
        $config.NtAuthCertificates[0].cACertificate = $script:root.RawData
        (Get-MtAdNtAuthCertificatePath $config).Verified | Should -BeTrue
    }
    It 'does not promote an NTAuth certificate to a trust anchor' {
        $config = Get-PathTestConfiguration
        $config.TrustedRootCAs = @()
        $row = Get-MtAdNtAuthCertificatePath $config
        $row.Verified | Should -BeFalse
        $row.Issues | Should -Contain 'NoPublishedTrustAnchor'
    }
    It 'does not infer a missing intermediate from matching issuer names' {
        $config = Get-PathTestConfiguration
        $config.IntermediateCAs = @()
        (Get-MtAdNtAuthCertificatePath $config).Verified | Should -BeFalse
    }
    It 'requires a valid signature rather than a matching root subject' {
        $wrongRoot = New-PathTestCertificate -Name 'Approved Root'
        try {
            $config = Get-PathTestConfiguration
            $config.NtAuthCertificates[0].cACertificate = $script:direct.RawData
            $config.TrustedRootCAs[0].cACertificate = $wrongRoot.RawData
            (Get-MtAdNtAuthCertificatePath $config).Verified | Should -BeFalse
        } finally { $wrongRoot.Dispose() }
    }
    It 'rejects a changed signature on an otherwise parseable CA certificate' {
        $config = Get-PathTestConfiguration
        $tampered = [byte[]]$script:issuing.RawData.Clone()
        $tampered[-1] = $tampered[-1] -bxor 1
        $config.NtAuthCertificates[0].cACertificate = $tampered
        (Get-MtAdNtAuthCertificatePath $config).Verified | Should -BeFalse
    }
    It 'rejects an expired CA certificate' {
        $expired = New-PathTestCertificate -Name 'Expired CA' -Issuer $script:root -NotBefore (Get-Date).AddDays(-20) -NotAfter (Get-Date).AddDays(-10)
        try {
            $config = Get-PathTestConfiguration
            $config.NtAuthCertificates[0].cACertificate = $expired.RawData
            $row = Get-MtAdNtAuthCertificatePath $config
            $row.Verified | Should -BeFalse
            $row.Issues | Should -Contain 'NotTimeValid'
        } finally { $expired.Dispose() }
    }
    It 'rejects a CA certificate whose validity has not started' {
        $future = New-PathTestCertificate -Name 'Future CA' -Issuer $script:root -NotBefore (Get-Date).AddDays(1)
        try {
            $config = Get-PathTestConfiguration
            $config.NtAuthCertificates[0].cACertificate = $future.RawData
            (Get-MtAdNtAuthCertificatePath $config).Verified | Should -BeFalse
        } finally { $future.Dispose() }
    }
    It 'requires the NTAuth certificate itself to have CA constraints' {
        $leaf = New-PathTestCertificate -Name 'User Certificate' -Issuer $script:root -IsCa $false -CanSign $false
        try {
            $config = Get-PathTestConfiguration
            $config.NtAuthCertificates[0].cACertificate = $leaf.RawData
            $row = Get-MtAdNtAuthCertificatePath $config
            $row.Verified | Should -BeFalse
            $row.Issues | Should -Contain 'NtAuthCertificateIsNotCa'
        } finally { $leaf.Dispose() }
    }
    It 'rejects an NTAuth CA whose key usage forbids certificate signing' {
        $ca = New-PathTestCertificate -Name 'Wrong Usage CA' -Issuer $script:root -CanSign $false
        try {
            $config = Get-PathTestConfiguration
            $config.NtAuthCertificates[0].cACertificate = $ca.RawData
            $row = Get-MtAdNtAuthCertificatePath $config
            $row.Verified | Should -BeFalse
            $row.Issues | Should -Contain 'NtAuthCertificateCannotSignCertificates'
        } finally { $ca.Dispose() }
    }
    It 'enforces issuer path-length constraints' {
        $limited = New-PathTestCertificate -Name 'Limited Intermediate' -Issuer $script:root -PathLength 0
        $child = New-PathTestCertificate -Name 'Forbidden Child CA' -Issuer $limited -PathLength 0 -NotAfter (Get-Date).AddDays(20)
        try {
            $config = Get-PathTestConfiguration
            $config.IntermediateCAs[0].cACertificate = $limited.RawData
            $config.NtAuthCertificates[0].cACertificate = $child.RawData
            (Get-MtAdNtAuthCertificatePath $config).Verified | Should -BeFalse
        } finally { $child.Dispose(); $limited.Dispose() }
    }
    It 'deduplicates a CA published more than once and in multiple roles' {
        $config = Get-PathTestConfiguration
        $config.NtAuthCertificates[0].cACertificate = @($script:issuing.RawData, $script:issuing.RawData)
        $config.EnterpriseCAs = @([pscustomobject]@{ Name = 'Same CA'; cACertificate = $script:issuing.RawData })
        $rows = @(Get-MtAdNtAuthCertificatePath $config)
        $rows.Count | Should -Be 1
        $rows[0].Verified | Should -BeTrue
    }
    It 'does not retrieve a missing issuer from an AIA URL' {
        $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
        $listener.Start()
        $ca = $null
        try {
            $url = "http://127.0.0.1:$($listener.LocalEndpoint.Port)/issuer.cer"
            $ca = New-PathTestCertificate -Name 'CA with AIA' -Issuer $script:intermediate -AiaUrl $url
            $config = Get-PathTestConfiguration
            $config.NtAuthCertificates[0].cACertificate = $ca.RawData
            $config.IntermediateCAs = @()
            $row = Get-MtAdNtAuthCertificatePath $config
            $row.Verified | Should -BeFalse
            $listener.Pending() | Should -BeFalse
        } finally {
            if ($ca) { $ca.Dispose() }
            $listener.Stop()
        }
    }
    It 'keeps the shared inventory output unchanged unless DER data is requested' {
        $config = Get-PathTestConfiguration
        $plain = @(Get-MtAdCertificateInventory $config)
        $raw = @(Get-MtAdCertificateInventory $config -IncludeRawData)
        $plain[0].PSObject.Properties.Name | Should -Not -Contain RawData
        $raw[0].RawData | Should -BeOfType ([byte])
        [Convert]::ToBase64String($raw[0].RawData) | Should -Be ([Convert]::ToBase64String($script:root.RawData))
    }
    It 'returns no paths for an observed empty NTAuth store' {
        foreach ($empty in @(@(), @([pscustomobject]@{ cACertificate = $null }))) {
            $config = [pscustomobject]@{ NtAuthCertificates = $empty }
            @(Get-MtAdNtAuthCertificatePath $config).Count | Should -Be 0
        }
    }
    It 'does not turn a missing inventory into an empty-store observation' {
        { Get-MtAdNtAuthCertificatePath $null } | Should -Throw '*configuration data is unavailable*'
        $config = Get-PathTestConfiguration
        $config.TrustedRootCAs = $null
        { Get-MtAdNtAuthCertificatePath $config } | Should -Throw '*TrustedRootCAs data is unavailable*'
    }
    It 'does not treat an uncollected certificate attribute as an empty attribute' {
        $config = Get-PathTestConfiguration
        $config.NtAuthCertificates[0].PSObject.Properties.Remove('cACertificate')
        { Get-MtAdNtAuthCertificatePath $config } | Should -Throw '*attributes were not collected*'
    }
    It 'fails on malformed certificate data even alongside a valid NTAuth path' {
        $config = Get-PathTestConfiguration
        $config.IntermediateCAs += [pscustomobject]@{ Name = 'Malformed'; cACertificate = [byte[]](1, 2, 3) }
        { Get-MtAdNtAuthCertificatePath $config } | Should -Throw '*Unable to parse public certificate*'
    }
}

Describe 'AD-PKI-13 native engine outcomes' {
    BeforeEach {
        $script:pathConfiguration = Get-PathTestConfiguration
        Mock -ModuleName Maester Get-MtADDomainState { [pscustomobject]@{ Configuration = $script:pathConfiguration } }
        $script:pathRunConfig = @{ Environment = @{ Services = @{ ActiveDirectory = $true } } }
    }
    It 'has valid native metadata without claiming a scored authentication baseline' {
        $metadata = Get-MtTest AD-PKI-13
        $metadata.IsValid | Should -BeTrue
        $metadata.Errors | Should -BeNullOrEmpty
        $metadata.Severity.ToString() | Should -Be Info
        $metadata.Author | Should -Contain FiraSenax
    }
    It 'passes a verified published path and renders its root and issuer' {
        $row = Invoke-MtTest -Id AD-PKI-13 -Config $script:pathRunConfig
        $row.Result.ToString() | Should -Be Passed
        $row.ResultDetail.TestResult | Should -BeLike '*Well done*Third-party Issuing CA*Approved Root*'
    }
    It 'investigates an incomplete path rather than declaring actual authentication failure' {
        $script:pathConfiguration.IntermediateCAs = @()
        $row = Invoke-MtTest -Id AD-PKI-13 -Config $script:pathRunConfig
        $row.Result.ToString() | Should -Be Investigate
        $row.ResultDetail.TestResult | Should -BeLike '*could not be verified*'
    }
    It 'skips an observed empty store as NotApplicable' {
        $script:pathConfiguration.NtAuthCertificates = @()
        $row = Invoke-MtTest -Id AD-PKI-13 -Config $script:pathRunConfig
        $row.Result.ToString() | Should -Be Skipped
        $row.ReasonCode | Should -Be NotApplicable
    }
    It 'reports malformed evidence as an error' {
        $script:pathConfiguration.NtAuthCertificates[0].cACertificate = [byte[]](1, 2, 3)
        $row = Invoke-MtTest -Id AD-PKI-13 -Config $script:pathRunConfig
        $row.Result.ToString() | Should -Be Error
        $row.ReasonCode | Should -Be TestError
    }
    It 'escapes certificate-controlled Markdown and HTML in the result table' {
        $unsafe = New-PathTestCertificate -Name 'CA|<b>unsafe</b>' -Issuer $script:root
        try {
            $script:pathConfiguration.NtAuthCertificates[0].cACertificate = $unsafe.RawData
            $row = Invoke-MtTest -Id AD-PKI-13 -Config $script:pathRunConfig
            $row.Result.ToString() | Should -Be Passed
            $row.ResultDetail.TestResult | Should -Not -Match '<b>'
            $row.ResultDetail.TestResult | Should -BeLike '*CA&#124;&lt;b&gt;unsafe&lt;/b&gt;*'
        } finally { $unsafe.Dispose() }
    }
}
