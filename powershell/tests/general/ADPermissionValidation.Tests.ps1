# Validates that every AD built-in test declares Permission attributes
# and that the engine parses them without errors.
# The engine (Read-MtNativeTest) validates service registration, kind correctness,
# and Service-attribute alignment per PR #2500.
# Cim permissions are also checked against the namespaces and classes the AD collector reads.

BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue
    $script:repoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
    $script:adTests = @(Get-ChildItem -Path (Join-Path $script:repoRoot 'tests/ad') -Recurse -File -Filter 'Test.AD-*.ps1')

    # <namespace>:<class> pairs the collector reads, as a Cim permission names them.
    $collector = Get-ChildItem -Path (Join-Path $script:repoRoot 'powershell/internal/services/ad') -Recurse -File -Filter '*.ps1' |
        Get-Content -Raw | Out-String
    $script:cimReads = @([regex]::Matches($collector, "Get-CimInstance\s+-Namespace\s+'([^']+)'\s+-ClassName\s+'([^']+)'") |
        ForEach-Object { "$($_.Groups[1].Value):$($_.Groups[2].Value)" })
    # Get-SmbServerConfiguration reads MSFT_SmbServerConfiguration through CIM.
    if ($collector -match 'Get-SmbServerConfiguration') { $script:cimReads += 'root\Microsoft\Windows\SMB:MSFT_SmbServerConfiguration' }
    $script:dnsReads = @($script:cimReads | Where-Object { $_ -like 'root\MicrosoftDNS:*' })
}

Describe 'AD Permission Attributes' {
    It 'every AD test declares at least one Permission' {
        $missing = @()
        foreach ($file in $script:adTests) {
            $content = Get-Content -Path $file.FullName -Raw
            if ($content -notmatch 'Permission\s*=') {
                $missing += $file.Name
            }
        }
        $missing | Should -BeNullOrEmpty
    }

    It 'every AD test Permission parses without engine errors' {
        $errors = @()
        foreach ($file in $script:adTests) {
            $result = InModuleScope Maester -Parameters @{ File = $file.FullName } {
                Read-MtNativeTest -Path $File -BuiltIn
            }
            $permErrors = @($result.Errors | Where-Object { $_.Message -like '*Permission*' })
            if ($permErrors.Count -gt 0) {
                $errors += "$($file.Name): $($permErrors[0].Message)"
            }
        }
        $errors | Should -BeNullOrEmpty
    }

    It 'every AD test Permission uses ActiveDirectory service' {
        $bad = @()
        foreach ($file in $script:adTests) {
            $result = InModuleScope Maester -Parameters @{ File = $file.FullName } {
                Read-MtNativeTest -Path $File -BuiltIn
            }
            foreach ($p in $result.Permission) {
                if ($p -notmatch '^ActiveDirectory:') {
                    $bad += "$($file.Name): $p"
                }
            }
        }
        $bad | Should -BeNullOrEmpty
    }

    It 'finds the CIM classes the collector reads' {
        $script:dnsReads.Count | Should -BeGreaterThan 0
    }

    It 'every Cim permission names a namespace and class the collector reads' {
        $bad = @()
        foreach ($file in $script:adTests) {
            $result = InModuleScope Maester -Parameters @{ File = $file.FullName } {
                Read-MtNativeTest -Path $File -BuiltIn
            }
            foreach ($p in @($result.Permission | Where-Object { $_ -like 'ActiveDirectory:Cim:*' })) {
                # ActiveDirectory:Cim:<namespace>:<class>:<right>
                $target = ($p -replace '^ActiveDirectory:Cim:', '') -replace ':[^:]+$', ''
                if ($target -notin $script:cimReads) { $bad += "$($file.Name): $p" }
            }
        }
        $bad | Should -BeNullOrEmpty
    }

    It 'every test that reads DNS data declares each DNS class the collector reads' {
        $bad = @()
        foreach ($file in $script:adTests) {
            if ((Get-Content -Path $file.FullName -Raw) -notmatch "-Categories\s+@\([^)]*'DNS'") { continue }
            $result = InModuleScope Maester -Parameters @{ File = $file.FullName } {
                Read-MtNativeTest -Path $File -BuiltIn
            }
            foreach ($read in $script:dnsReads) {
                if (-not ($result.Permission | Where-Object { $_ -like "ActiveDirectory:Cim:${read}:*" })) { $bad += "$($file.Name): $read" }
            }
        }
        $bad | Should -BeNullOrEmpty
    }
}
