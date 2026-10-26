# The version of the next preview or release (.github/workflows/Get-NextModuleVersion.ps1). A preview is a
# prerelease of the release it leads to, so it never uses up a release number and always sorts below its release.
Describe 'Get-NextModuleVersion' {
    BeforeAll {
        . "$PSScriptRoot/../../../.github/workflows/Get-NextModuleVersion.ps1"
    }

    It 'Numbers the first preview of a new major version <Major>.0.0-preview01' {
        $next = Get-NextModuleVersion -StableVersion 3.4.0 -Major 4 -Preview -PublishedVersion '3.4.0', '3.3.0-preview02'
        $next.ModuleVersion | Should -Be '4.0.0'
        $next.Prerelease | Should -Be 'preview01'
        $next.FullVersion | Should -Be '4.0.0-preview01'
    }

    It 'Numbers previews with two digits, so the gallery sorts preview10 above preview09' {
        $published = '3.1.0-preview01', '3.1.0-preview09', '3.0.0'
        $next = Get-NextModuleVersion -StableVersion 3.0.0 -Major 3 -Preview -PublishedVersion $published
        $next.FullVersion | Should -Be '3.1.0-preview10'
        [string]::CompareOrdinal($next.Prerelease, 'preview09') | Should -BeGreaterThan 0
    }

    It 'Goes on as rc01 after the 3.0.0 previews numbered up to preview9' {
        $published = (1..9 | ForEach-Object { "3.0.0-preview$_" }) + '2.3.0'
        (Get-NextModuleVersion -StableVersion 2.3.0 -Major 3 -Preview -PublishedVersion $published).FullVersion | Should -Be '3.0.0-rc01'
        (Get-NextModuleVersion -StableVersion 2.3.0 -Major 3 -Preview -PublishedVersion ($published + '3.0.0-rc01')).FullVersion | Should -Be '3.0.0-rc02'
    }

    It 'Releases the number its previews carried' {
        $next = Get-NextModuleVersion -StableVersion 2.3.0 -Major 3
        $next.FullVersion | Should -Be '3.0.0'
        $next.Prerelease | Should -BeNullOrEmpty
    }

    It 'Moves previews to the next minor version after a release' {
        $published = '3.0.0-preview4', '3.0.0'
        (Get-NextModuleVersion -StableVersion 3.0.0 -Major 3 -Preview -PublishedVersion $published).FullVersion | Should -Be '3.1.0-preview01'
        (Get-NextModuleVersion -StableVersion 3.0.0 -Major 3).FullVersion | Should -Be '3.1.0'
    }

    It 'Keeps every preview below its release and above the release before it' {
        $preview = Get-NextModuleVersion -StableVersion 3.1.0 -Major 3 -Preview
        [version]$preview.ModuleVersion | Should -BeGreaterThan ([version]'3.1.0')
        $preview.FullVersion | Should -Be '3.2.0-preview01'
    }

    It 'Refuses a major version below the latest release' {
        { Get-NextModuleVersion -StableVersion 3.2.0 -Major 2 } | Should -Throw
    }
}
