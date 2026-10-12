# The version of the next preview or release (.github/workflows/Get-NextModuleVersion.ps1). A preview is a
# prerelease of the release it leads to, so it never uses up a release number and always sorts below its release.
Describe 'Get-NextModuleVersion' {
    BeforeAll {
        . "$PSScriptRoot/../../../.github/workflows/Get-NextModuleVersion.ps1"
    }

    It 'Numbers the first preview of a new major version <Major>.0.0-preview1' {
        $next = Get-NextModuleVersion -StableVersion 2.3.0 -Major 3 -Preview -PublishedVersion '2.3.0', '2.2.107-preview'
        $next.ModuleVersion | Should -Be '3.0.0'
        $next.Prerelease | Should -Be 'preview1'
        $next.FullVersion | Should -Be '3.0.0-preview1'
    }

    It 'Counts previews by number, not as text' {
        $published = '3.0.0-preview1', '3.0.0-preview9', '3.0.0-preview10', '2.3.0'
        (Get-NextModuleVersion -StableVersion 2.3.0 -Major 3 -Preview -PublishedVersion $published).FullVersion | Should -Be '3.0.0-preview11'
    }

    It 'Releases the number its previews carried' {
        $next = Get-NextModuleVersion -StableVersion 2.3.0 -Major 3
        $next.FullVersion | Should -Be '3.0.0'
        $next.Prerelease | Should -BeNullOrEmpty
    }

    It 'Moves previews to the next minor version after a release' {
        $published = '3.0.0-preview4', '3.0.0'
        (Get-NextModuleVersion -StableVersion 3.0.0 -Major 3 -Preview -PublishedVersion $published).FullVersion | Should -Be '3.1.0-preview1'
        (Get-NextModuleVersion -StableVersion 3.0.0 -Major 3).FullVersion | Should -Be '3.1.0'
    }

    It 'Keeps every preview below its release and above the release before it' {
        $preview = Get-NextModuleVersion -StableVersion 3.1.0 -Major 3 -Preview
        [version]$preview.ModuleVersion | Should -BeGreaterThan ([version]'3.1.0')
        $preview.FullVersion | Should -Be '3.2.0-preview1'
    }

    It 'Refuses a major version below the latest release' {
        { Get-NextModuleVersion -StableVersion 3.2.0 -Major 2 } | Should -Throw
    }
}
