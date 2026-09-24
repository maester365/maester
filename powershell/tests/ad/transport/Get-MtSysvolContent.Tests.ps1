[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingConvertToSecureStringWithPlainText',
    '',
    Justification = 'Test fixtures use a fake password to verify that transport arguments do not expose it.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidGlobalVars',
    '',
    Justification = 'Pester mocks and InModuleScope require shared capture state for temporary credential assertions.'
)]
param()

BeforeAll {
    Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force
}

Describe 'Get-MtSysvolContent transport contract' {
    BeforeEach {
        InModuleScope Maester {
            $securePassword = ConvertTo-SecureString 'UnitTest-Secret!' -AsPlainText -Force
            $__MtSession.ADConnection = [ordered]@{
                ProtocolValidated = $true
                ResolvedServer    = 'dc01.contoso.com'
                ResolvedDomain    = 'contoso.com'
            }
            $__MtSession.ADCredential = [PSCredential]::new('CONTOSO\reader', $securePassword)
        }
    }

    AfterEach {
        InModuleScope Maester {
            $__MtSession.ADConnection = $null
            $__MtSession.ADCredential = $null
        }
    }

    It 'rejects traversal, rooted, drive-qualified, and SMB command paths' -ForEach @(
        '../GPT.INI',
        'Machine/../../GPT.INI',
        '/etc/passwd',
        '\\server\share\file',
        'C:\Windows\win.ini',
        'Machine/file;rm'
    ) {
        InModuleScope Maester -Parameters @{ UnsafePath = $_ } {
            { Get-MtSysvolContent -Operation ReadText -GpoGuid '11111111-1111-1111-1111-111111111111' -RelativePath $UnsafePath } | Should -Throw '*safe relative path*'
        }
    }

    It 'requires a protocol-validated AD session' {
        InModuleScope Maester {
            $__MtSession.ADConnection.ProtocolValidated = $false
            { Get-MtSysvolContent -GpoGuid '11111111-1111-1111-1111-111111111111' } | Should -Throw '*protocol-validated*'
        }
    }

    It 'uses the Windows adapter and returns a normalized bounded analysis' {
        Mock Test-MtSysvolWindowsPlatform -ModuleName Maester { $true }
        Mock Invoke-MtSysvolWindowsAdapter -ModuleName Maester {
            if ($Operation -eq 'Connect') { return $true }
            if ($Operation -eq 'List') {
                return @(
                    [PSCustomObject]@{ RelativePath = 'GPT.INI'; Name = 'GPT.INI'; Length = 26 },
                    [PSCustomObject]@{ RelativePath = 'Machine/Preferences/Groups/Groups.xml'; Name = 'Groups.xml'; Length = 75 },
                    [PSCustomObject]@{ RelativePath = 'Machine/Microsoft/Windows NT/SecEdit/GptTmpl.inf'; Name = 'GptTmpl.inf'; Length = 130 }
                )
            }
            if ($RelativePath -eq 'GPT.INI') { return "[General]`nVersion=196610" }
            if ($RelativePath -like '*.xml') { return '<Groups><User cpassword="encrypted"/><Password>Welcome</Password></Groups>' }
            return "[Registry Values]`nMACHINE\Software\App\DefaultPassword=1,Password1`n[Privilege Rights]`nSeDebugPrivilege=*S-1-5-32-544"
        }

        InModuleScope Maester {
            $result = Get-MtSysvolContent -Operation Connect -GpoGuid '11111111-1111-1111-1111-111111111111'
            $result.Adapter | Should -Be 'Windows'
            $result.GpoGuid | Should -Be '{11111111-1111-1111-1111-111111111111}'
            $result.RootPath | Should -Be '//dc01.contoso.com/SYSVOL/contoso.com/Policies/{11111111-1111-1111-1111-111111111111}'
            $result.Files.Count | Should -Be 3
            $result.TotalBytes | Should -Be 231
            $result.GptIni.Version | Should -Be 196610
            $result.GptIni.UserVersion | Should -Be 3
            $result.GptIni.ComputerVersion | Should -Be 2
            $result.CpasswordFound | Should -BeTrue
            $result.DefaultPasswordFound | Should -BeTrue
            $result.SecurityTemplates[0].PrivilegeRights.SeDebugPrivilege | Should -Be '*S-1-5-32-544'
        }
    }

    It 'uses the Unix adapter with the same normalized file contract' {
        Mock Test-MtSysvolWindowsPlatform -ModuleName Maester { $false }
        Mock Invoke-MtSysvolUnixAdapter -ModuleName Maester {
            if ($Operation -eq 'List') {
                return [PSCustomObject]@{ RelativePath = 'Machine/Preferences/Groups/Groups.xml'; Name = 'Groups.xml'; Length = 20 }
            }
            if ($Operation -eq 'ReadText') {
                return '<Groups><User cpassword="encrypted" /></Groups>'
            }
            return $true
        }

        InModuleScope Maester {
            $result = Get-MtSysvolContent -Operation Connect -GpoGuid '{11111111-1111-1111-1111-111111111111}'
            $result.Adapter | Should -Be 'Unix'
            $result.Files[0].RelativePath | Should -Be 'Machine/Preferences/Groups/Groups.xml'
            $result.Files[0].Name | Should -Be 'Groups.xml'
            $result.Files[0].Length | Should -Be 20
            $result.CpasswordFound | Should -BeTrue
        }

        Should -Invoke Invoke-MtSysvolUnixAdapter -ModuleName Maester -ParameterFilter {
            $Server -eq 'dc01.contoso.com' -and
            $Domain -eq 'contoso.com' -and
            $null -ne $Credential -and
            $TimeoutSeconds -eq 60
        }
    }

    It 'throws rather than truncating a file over the single-file bound' {
        Mock Test-MtSysvolWindowsPlatform -ModuleName Maester { $true }
        Mock Invoke-MtSysvolWindowsAdapter -ModuleName Maester {
            if ($Operation -eq 'List') {
                return [PSCustomObject]@{ RelativePath = 'large.bin'; Name = 'large.bin'; Length = 101 }
            }
            return $true
        }

        InModuleScope Maester {
            { Get-MtSysvolContent -Operation Connect -GpoGuid '11111111-1111-1111-1111-111111111111' -MaxFileBytes 100 } | Should -Throw '*maximum single-file size*'
        }
    }

    It 'throws rather than truncating a GPO over the aggregate bound' {
        Mock Test-MtSysvolWindowsPlatform -ModuleName Maester { $true }
        Mock Invoke-MtSysvolWindowsAdapter -ModuleName Maester {
            if ($Operation -eq 'List') {
                return @(
                    [PSCustomObject]@{ RelativePath = 'one.bin'; Name = 'one.bin'; Length = 60 },
                    [PSCustomObject]@{ RelativePath = 'two.bin'; Name = 'two.bin'; Length = 50 }
                )
            }
            return $true
        }

        InModuleScope Maester {
            { Get-MtSysvolContent -Operation Connect -GpoGuid '11111111-1111-1111-1111-111111111111' -MaxFileBytes 100 -MaxGpoBytes 100 } | Should -Throw '*maximum aggregate size*'
        }
    }
}

Describe 'SYSVOL bounded parsers' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force
    }

    It 'parses GPT.INI user and computer version words' {
        InModuleScope Maester {
            $result = ConvertFrom-MtSysvolGptIni -Content "[General]`r`nVersion = 327687"
            $result.Version | Should -Be 327687
            $result.UserVersion | Should -Be 5
            $result.ComputerVersion | Should -Be 7
        }
    }

    It 'finds cpassword recursively and weak plaintext password properties without exposing values' {
        InModuleScope Maester {
            $xml = '<ScheduledTasks><Task><Properties><Nested cpassword="cipher" Password="changeme" /></Properties></Task></ScheduledTasks>'
            $result = ConvertFrom-MtSysvolGppXml -Content $xml -RelativePath 'Machine/Preferences/ScheduledTasks/ScheduledTasks.xml'
            $result.CpasswordFound | Should -BeTrue
            $result.CpasswordCount | Should -Be 1
            $result.DefaultPasswordFound | Should -BeTrue
            ($result.PSObject.Properties.Value -join '|') | Should -Not -Match 'cipher|changeme'
        }
    }

    It 'prohibits XML document type declarations' {
        InModuleScope Maester {
            { ConvertFrom-MtSysvolGppXml -Content '<!DOCTYPE x [<!ENTITY y SYSTEM "file:///etc/passwd">]><x>&y;</x>' -RelativePath 'Groups.xml' } | Should -Throw
        }
    }

    It 'parses only Registry Values and Privilege Rights and detects weak INF defaults' {
        InModuleScope Maester {
            $content = @"
[Unicode]
Unicode=yes
[Registry Values]
MACHINE\Software\Vendor\DefaultPassword=1,"password1"
MACHINE\Software\Vendor\Enabled=4,1
[Privilege Rights]
SeServiceLogonRight=*S-1-5-20,*S-1-5-32-544
[System Access]
MinimumPasswordLength=14
"@
            $result = ConvertFrom-MtSysvolSecurityTemplate -Content $content
            $result.RegistryValues.Count | Should -Be 2
            $result.PrivilegeRights.Count | Should -Be 1
            $result.PrivilegeRights.SeServiceLogonRight | Should -Be '*S-1-5-20,*S-1-5-32-544'
            $result.DefaultPasswordFound | Should -BeTrue
            $result.PSObject.Properties.Name | Should -Not -Contain 'SystemAccess'
        }
    }
}

Describe 'SYSVOL credential and temporary resource cleanup' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force
    }

    It 'always removes the temporary Windows PSDrive after success' {
        Mock New-PSDrive -ModuleName Maester {}
        Mock Test-Path -ModuleName Maester { $true }
        Mock Remove-PSDrive -ModuleName Maester {}

        InModuleScope Maester {
            Invoke-MtSysvolWindowsAdapter -Operation Connect -Server dc01.contoso.com -Domain contoso.com -GpoGuid '{11111111-1111-1111-1111-111111111111}' -MaxFileBytes 100 | Should -BeTrue
        }
        Should -Invoke New-PSDrive -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Root -eq '\\dc01.contoso.com\SYSVOL' -and $Scope -eq 'Global' }
        Should -Invoke Remove-PSDrive -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Scope -eq 'Global' -and $Force }
    }

    It 'always removes the temporary Windows PSDrive after an error' {
        Mock New-PSDrive -ModuleName Maester { throw 'mapping failed' }
        Mock Remove-PSDrive -ModuleName Maester {}

        InModuleScope Maester {
            { Invoke-MtSysvolWindowsAdapter -Operation Connect -Server dc01.contoso.com -Domain contoso.com -GpoGuid '{11111111-1111-1111-1111-111111111111}' -MaxFileBytes 100 } | Should -Throw '*mapping failed*'
        }
        Should -Invoke Remove-PSDrive -ModuleName Maester -Times 1 -Exactly
    }

    It 'uses a mode-600 auth file, excludes the password from arguments, and deletes the file after success' {
        $global:MtSysvolCapturedArguments = $null
        $global:MtSysvolCapturedAuthPath = $null
        $global:MtSysvolAuthExistedDuringCall = $null
        $global:MtSysvolAuthModeDuringCall = $null
        Mock Invoke-MtSysvolProcess -ModuleName Maester {
            $global:MtSysvolCapturedArguments = @($Arguments)
            $authArgument = $global:MtSysvolCapturedArguments | Where-Object { $_ -like '--authentication-file=*' }
            $global:MtSysvolCapturedAuthPath = $authArgument.Substring('--authentication-file='.Length)
            $global:MtSysvolAuthExistedDuringCall = [IO.File]::Exists($global:MtSysvolCapturedAuthPath)
            $global:MtSysvolAuthModeDuringCall = [IO.File]::GetUnixFileMode($global:MtSysvolCapturedAuthPath)
            return [PSCustomObject]@{ StandardOutput = ''; StandardError = ''; ExitCode = 0 }
        }

        InModuleScope Maester {
            $credential = [PSCredential]::new('CONTOSO\reader', (ConvertTo-SecureString 'UnitTest-Secret!' -AsPlainText -Force))
            Invoke-MtSysvolSmbClient -Server dc01.contoso.com -Domain contoso.com -Credential $credential -Arguments @('--command', 'ls') | Out-Null
            $global:MtSysvolAuthExistedDuringCall | Should -BeTrue
            $global:MtSysvolAuthModeDuringCall | Should -Be ([IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite)
            ($global:MtSysvolCapturedArguments -join ' ') | Should -Not -Match 'UnitTest-Secret!'
            [IO.File]::Exists($global:MtSysvolCapturedAuthPath) | Should -BeFalse
        }
        Remove-Variable -Name MtSysvolCapturedArguments, MtSysvolCapturedAuthPath, MtSysvolAuthExistedDuringCall, MtSysvolAuthModeDuringCall -Scope Global -ErrorAction SilentlyContinue
    }

    It 'deletes the Unix auth file when smbclient fails' {
        Mock Invoke-MtSysvolProcess -ModuleName Maester {
            $authArgument = $Arguments | Where-Object { $_ -like '--authentication-file=*' }
            $script:failedAuthPath = $authArgument.Substring('--authentication-file='.Length)
            throw 'simulated smbclient failure'
        }

        InModuleScope Maester {
            $credential = [PSCredential]::new('CONTOSO\reader', (ConvertTo-SecureString 'UnitTest-Secret!' -AsPlainText -Force))
            { Invoke-MtSysvolSmbClient -Server dc01.contoso.com -Domain contoso.com -Credential $credential -Arguments @('--command', 'ls') } | Should -Throw '*simulated smbclient failure*'
            [IO.File]::Exists($script:failedAuthPath) | Should -BeFalse
        }
    }

    It 'uses Kerberos without creating an auth file when no credential is supplied' {
        $global:MtSysvolKerberosArguments = $null
        Mock Invoke-MtSysvolProcess -ModuleName Maester {
            $global:MtSysvolKerberosArguments = @($Arguments)
            return [PSCustomObject]@{ StandardOutput = ''; StandardError = ''; ExitCode = 0 }
        }

        InModuleScope Maester {
            Invoke-MtSysvolSmbClient -Server dc01.contoso.com -Domain contoso.com -Arguments @('--command', 'ls') | Out-Null
            $global:MtSysvolKerberosArguments | Should -Contain '--kerberos'
            ($global:MtSysvolKerberosArguments | Where-Object { $_ -like '--authentication-file=*' }) | Should -BeNullOrEmpty
        }
        Remove-Variable -Name MtSysvolKerberosArguments -Scope Global -ErrorAction SilentlyContinue
    }
}
