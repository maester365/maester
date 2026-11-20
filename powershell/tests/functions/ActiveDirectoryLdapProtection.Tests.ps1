[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Fake credentials for isolated unit tests.')]
param()

BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Explicit LDAP protection opt-outs' {
    BeforeEach {
        InModuleScope Maester {
            $script:protectionClient = [PSCustomObject]@{
                SessionOptions = [PSCustomObject]@{ ProtocolVersion = 0; ReferralChasing = 0; SecureSocketLayer = $false; Signing = $true; Sealing = $true }
                AuthType = $null
                Timeout = $null
                Credential = $null
                BindCount = 0
                DisposeCount = 0
                SigningAtBind = $null
                SealingAtBind = $null
            }
            $script:protectionClient | Add-Member ScriptMethod Bind {
                $this.BindCount++
                $this.SigningAtBind = $this.SessionOptions.Signing
                $this.SealingAtBind = $this.SessionOptions.Sealing
            }
            $script:protectionClient | Add-Member ScriptMethod Dispose { $this.DisposeCount++ }
            Mock New-Object { $script:protectionClient } -ParameterFilter { $TypeName -eq 'System.DirectoryServices.Protocols.LdapConnection' }
            Mock Write-Warning { }
        }
    }

    It 'Disables sealing before bind but leaves signing untouched unless requested' {
        InModuleScope Maester {
            $null = New-MtLdapConnection -Server localhost -Port 389 -ForceUnencrypted
            $script:protectionClient.BindCount | Should -Be 1
            $script:protectionClient.SealingAtBind | Should -BeFalse
            $script:protectionClient.SigningAtBind | Should -BeTrue
            Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like '*queries and results*' -and $Message -like '*Signing, if negotiated, protects message integrity, not confidentiality*' }
        }
    }

    It 'Disables signing and sealing before bind with both explicit opt-ins' {
        InModuleScope Maester {
            $null = New-MtLdapConnection -Server localhost -Port 389 -ForceUnencrypted -ForceUnsigned
            $script:protectionClient.SigningAtBind | Should -BeFalse
            $script:protectionClient.SealingAtBind | Should -BeFalse
            Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like '*SASL signing is explicitly disabled*' -and $Message -like '*not the plaintext password*' -and $Message -like '*not SMB/SYSVOL or WinRM*' }
        }
    }

    It 'Requires a lower-layer opt-in for LDAP without TLS' {
        InModuleScope Maester {
            { New-MtLdapConnection -Server localhost -Port 389 } | Should -Throw '*requires -ForceUnencrypted*'
            $script:protectionClient.BindCount | Should -Be 0
        }
    }

    It 'Requires the additional password acknowledgement for Basic without TLS' {
        InModuleScope Maester {
            { New-MtLdapConnection -Server localhost -Port 389 -AuthType Basic -ForceUnencrypted } | Should -Throw '*Basic authentication requires LDAPS*'
            $script:protectionClient.BindCount | Should -Be 0
        }
    }

    It 'Allows acknowledged plaintext Basic without writing SASL options' {
        InModuleScope Maester {
            $credential = [PSCredential]::new('fixture', (ConvertTo-SecureString 'fake-password' -AsPlainText -Force))
            $null = New-MtLdapConnection -Server localhost -Port 389 -AuthType Basic -Credential $credential -ForceUnencrypted -AllowPlaintextPassword
            $script:protectionClient.BindCount | Should -Be 1
            $script:protectionClient.SigningAtBind | Should -BeTrue
            $script:protectionClient.SealingAtBind | Should -BeTrue
            Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like '*username and password in plaintext*' -and $Message -like '*unsigned, have no integrity protection*' -and $Message -like '*localhost*' -and $Message -notlike '*fake-password*' }
        }
    }

    It 'Does not write SASL options or warn on the encrypted default' {
        InModuleScope Maester {
            $null = New-MtLdapConnection -Server localhost -ForceUnencrypted
            $script:protectionClient.SigningAtBind | Should -BeTrue
            $script:protectionClient.SealingAtBind | Should -BeTrue
            $script:protectionClient.SessionOptions.SecureSocketLayer | Should -BeTrue
            Should -Invoke Write-Warning -Times 0 -Exactly
        }
    }

    It 'Rejects unsigned or plaintext-password opt-ins on an encrypted transport' {
        InModuleScope Maester {
            { New-MtLdapConnection -Server localhost -ForceUnencrypted -ForceUnsigned } | Should -Throw '*ForceUnsigned requires LDAP without TLS*'
            { New-MtLdapConnection -Server localhost -AuthType Basic -ForceUnencrypted -AllowPlaintextPassword } | Should -Throw '*AllowPlaintextPassword requires Basic authentication without TLS*'
            $script:protectionClient.BindCount | Should -Be 0
        }
    }

    It 'Rejects the redundant unsigned option for Basic' {
        InModuleScope Maester {
            { New-MtLdapConnection -Server localhost -Port 389 -AuthType Basic -ForceUnencrypted -AllowPlaintextPassword -ForceUnsigned } | Should -Throw '*ForceUnsigned requires*'
            $script:protectionClient.BindCount | Should -Be 0
        }
    }

    It 'Fails before bind when the provider cannot disable sealing' {
        InModuleScope Maester {
            $script:protectionClient.SessionOptions | Add-Member ScriptProperty Sealing { $true } { throw 'Unsupported LDAP option' } -Force
            { New-MtLdapConnection -Server localhost -Port 389 -ForceUnencrypted } | Should -Throw '*cannot honor*No bind was attempted*'
            $script:protectionClient.BindCount | Should -Be 0
            $script:protectionClient.DisposeCount | Should -Be 1
        }
    }

    It 'Fails and disposes after bind if policy re-enables signing' {
        InModuleScope Maester {
            $script:protectionClient | Add-Member ScriptMethod Bind { $this.BindCount++; $this.SessionOptions.Signing = $true } -Force
            { New-MtLdapConnection -Server localhost -Port 389 -ForceUnencrypted -ForceUnsigned } | Should -Throw '*SASL signing was re-enabled*'
            $script:protectionClient.BindCount | Should -Be 1
            $script:protectionClient.DisposeCount | Should -Be 1
        }
    }

    It 'Fails and disposes after bind if policy re-enables sealing' {
        InModuleScope Maester {
            $script:protectionClient | Add-Member ScriptMethod Bind { $this.BindCount++; $this.SessionOptions.Sealing = $true } -Force
            { New-MtLdapConnection -Server localhost -Port 389 -ForceUnencrypted } | Should -Throw '*SASL sealing was re-enabled*'
            $script:protectionClient.DisposeCount | Should -Be 1
        }
    }

    It 'Rejects cached None evidence without an explicit opt-in' {
        InModuleScope Maester {
            { New-MtAdProtocolConnection -ProtocolEvidence ([PSCustomObject]@{ TlsMode = 'None'; ResolvedServer = 'localhost'; AuthenticationMode = 'Negotiate' }) } | Should -Throw '*requires the explicit ForceUnencrypted opt-in*'
            $script:protectionClient.BindCount | Should -Be 0
        }
    }

    It 'Reconstructs and applies every unsigned token-based opt-in' {
        InModuleScope Maester {
            $connection = New-MtAdProtocolConnection -ProtocolEvidence ([PSCustomObject]@{ TlsMode = 'None'; ResolvedServer = 'localhost'; AuthenticationMode = 'Negotiate'; ForceUnencrypted = $true; ForceUnsigned = $true })
            $script:protectionClient.SigningAtBind | Should -BeFalse
            $script:protectionClient.SealingAtBind | Should -BeFalse
            $connection.Dispose()
        }
    }

    It 'Pins plaintext-password reuse to the requested server, not the RootDSE name' {
        InModuleScope Maester {
            Mock New-MtLdapConnection { $script:protectionClient }
            $connection = New-MtAdProtocolConnection -ProtocolEvidence ([PSCustomObject]@{ TlsMode = 'None'; RequestedServer = 'chosen.example'; ResolvedServer = 'untrusted.example'; AuthenticationMode = 'Basic'; ForceUnencrypted = $true; AllowPlaintextPassword = $true })
            Should -Invoke New-MtLdapConnection -Times 1 -Exactly -ParameterFilter { $Server -eq 'chosen.example' -and $ForceUnencrypted -and $AllowPlaintextPassword }
            $connection.Dispose()
        }
    }

    It 'Rejects plaintext-password reuse without a requested server' {
        InModuleScope Maester {
            { New-MtAdProtocolConnection -ProtocolEvidence ([PSCustomObject]@{ TlsMode = 'None'; ResolvedServer = 'untrusted.example'; AuthenticationMode = 'Basic'; ForceUnencrypted = $true; AllowPlaintextPassword = $true }) } | Should -Throw '*requires an explicitly requested server*'
        }
    }

    It 'Partitions None caches by protection choices without changing encrypted cache keys' {
        InModuleScope Maester {
            $signed = [PSCustomObject]@{ TlsMode = 'None'; AuthenticationMode = 'Negotiate'; ForceUnsigned = $false; AllowPlaintextPassword = $false }
            $unsigned = [PSCustomObject]@{ TlsMode = 'None'; AuthenticationMode = 'Negotiate'; ForceUnsigned = $true; AllowPlaintextPassword = $false }
            $basic = [PSCustomObject]@{ TlsMode = 'None'; AuthenticationMode = 'Basic'; ForceUnsigned = $false; AllowPlaintextPassword = $true }
            (Get-MtAdLdapProtectionCacheSuffix $signed) | Should -Not -Be (Get-MtAdLdapProtectionCacheSuffix $unsigned)
            (Get-MtAdLdapProtectionCacheSuffix $basic) | Should -Not -Be (Get-MtAdLdapProtectionCacheSuffix $signed)
            Get-MtAdLdapProtectionCacheSuffix ([PSCustomObject]@{ TlsMode = 'Ldaps' }) | Should -Be ''
        }
    }

    It 'Redacts userinfo if a server argument contains credentials' {
        InModuleScope Maester {
            Write-MtLdapProtectionWarning -Server 'ldap://fixture:fake-password@localhost' -Port 389 -AuthType Basic
            Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like '*<redacted>@localhost*' -and $Message -notlike '*fake-password*' }
        }
    }
}
