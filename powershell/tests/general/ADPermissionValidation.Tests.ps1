# Validates that every AD built-in test declares Permission attributes
# and that the engine parses them without errors.
# The engine (Read-MtNativeTest) validates service registration, kind correctness,
# and Service-attribute alignment per PR #2500.

BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue
    $script:repoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
    $script:adTests = @(Get-ChildItem -Path (Join-Path $script:repoRoot 'tests/ad') -Recurse -File -Filter 'Test.AD-*.ps1')
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
}
