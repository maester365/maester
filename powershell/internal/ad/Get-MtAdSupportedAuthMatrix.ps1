function Get-MtAdSupportedAuthMatrix {
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param()

    $profiles = [ordered]@{
        WindowsPS51 = [ordered]@{
            Platform                    = 'Windows'
            PSEdition                   = 'Desktop'
            PowerShellVersionFloor      = [version]'5.1'
            SupportedAuthModes          = @('Negotiate', 'Kerberos', 'Ntlm', 'Basic')
            TlsModes                    = @('Ldaps', 'StartTls')
            TlsRequiredAuthModes        = @('Basic')
            ExplicitCredentialAuthModes = @('Negotiate', 'Kerberos', 'Ntlm', 'Basic')
            IntegratedAuthModes         = @('Negotiate', 'Kerberos', 'Ntlm')
            Notes                       = @(
                'Uses Windows SSPI for integrated authentication.',
                'WinRM and SMB transports are available natively on Windows.'
            )
        }
        WindowsPS7 = [ordered]@{
            Platform                    = 'Windows'
            PSEdition                   = 'Core'
            PowerShellVersionFloor      = [version]'7.0'
            SupportedAuthModes          = @('Negotiate', 'Kerberos', 'Ntlm', 'Basic')
            TlsModes                    = @('Ldaps', 'StartTls')
            TlsRequiredAuthModes        = @('Basic')
            ExplicitCredentialAuthModes = @('Negotiate', 'Kerberos', 'Ntlm', 'Basic')
            IntegratedAuthModes         = @('Negotiate', 'Kerberos', 'Ntlm')
            Notes                       = @(
                'Uses the .NET runtime implementation of System.DirectoryServices.Protocols.',
                'WinRM and SMB transports are available natively on Windows.'
            )
        }
        LinuxPS7 = [ordered]@{
            Platform                    = 'Linux'
            PSEdition                   = 'Core'
            PowerShellVersionFloor      = [version]'7.2'
            SupportedAuthModes          = @('Negotiate', 'Kerberos', 'Basic')
            TlsModes                    = @('Ldaps', 'StartTls')
            TlsRequiredAuthModes        = @('Basic')
            ExplicitCredentialAuthModes = @('Negotiate', 'Kerberos', 'Basic')
            IntegratedAuthModes         = @('Negotiate', 'Kerberos')
            Notes                       = @(
                'Requires the System.DirectoryServices.Protocols assembly from the .NET runtime and compatible LDAP native libraries.',
                'PSWSMan is required for WSMan/PSRP transport on non-Windows platforms.',
                'NTLM is not supported for cross-platform LDAP on Linux.'
            )
        }
        MacOSPS7 = [ordered]@{
            Platform                    = 'macOS'
            PSEdition                   = 'Core'
            PowerShellVersionFloor      = [version]'7.2'
            SupportedAuthModes          = @('Negotiate', 'Kerberos', 'Basic')
            TlsModes                    = @('Ldaps', 'StartTls')
            TlsRequiredAuthModes        = @('Basic')
            ExplicitCredentialAuthModes = @('Negotiate', 'Kerberos', 'Basic')
            IntegratedAuthModes         = @('Negotiate', 'Kerberos')
            Notes                       = @(
                'Requires the System.DirectoryServices.Protocols assembly from the .NET runtime and compatible LDAP native libraries.',
                'PSWSMan is required for WSMan/PSRP transport on non-Windows platforms.',
                'NTLM is not supported for cross-platform LDAP on macOS.'
            )
        }
    }

    return [ordered]@{
        VersionFloors                   = [ordered]@{
            WindowsPS51 = '5.1'
            WindowsPS7  = '7.0'
            LinuxPS7    = '7.2'
            MacOSPS7    = '7.2'
        }
        Profiles                        = $profiles
        UnsupportedCombinationMessages  = [ordered]@{
            WindowsPS51 = [ordered]@{
                BasicWithoutTls    = 'Basic authentication requires LDAPS or StartTLS on Windows PowerShell 5.1.'
                IntegratedWithBasic = 'Basic authentication does not support integrated sign-in. Supply an explicit credential and enable LDAPS or StartTLS.'
            }
            WindowsPS7 = [ordered]@{
                BasicWithoutTls    = 'Basic authentication requires LDAPS or StartTLS on Windows PowerShell 7.'
                IntegratedWithBasic = 'Basic authentication does not support integrated sign-in. Supply an explicit credential and enable LDAPS or StartTLS.'
            }
            LinuxPS7 = [ordered]@{
                Ntlm               = 'NTLM authentication is not supported for cross-platform LDAP on Linux PowerShell 7. Use Kerberos, Negotiate, or Basic over TLS.'
                BasicWithoutTls    = 'Basic authentication requires LDAPS or StartTLS on Linux PowerShell 7.'
                IntegratedWithBasic = 'Basic authentication does not support integrated sign-in. Supply an explicit credential and enable LDAPS or StartTLS.'
            }
            MacOSPS7 = [ordered]@{
                Ntlm               = 'NTLM authentication is not supported for cross-platform LDAP on macOS PowerShell 7. Use Kerberos, Negotiate, or Basic over TLS.'
                BasicWithoutTls    = 'Basic authentication requires LDAPS or StartTLS on macOS PowerShell 7.'
                IntegratedWithBasic = 'Basic authentication does not support integrated sign-in. Supply an explicit credential and enable LDAPS or StartTLS.'
            }
        }
    }
}
