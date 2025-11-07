BeforeDiscovery {
    $moduleRoot = "$PSScriptRoot/../.."
    # Using Import-PowerShellDataFile over Test-ModuleManifest as it's easier to navigate
    $manifest = Import-PowerShellDataFile -Path (Join-Path -Path $moduleRoot -ChildPath 'Maester.psd1')
}

Describe 'Validating the module manifest' -ForEach @{ moduleRoot = $moduleRoot; manifest = $manifest } {
    Context 'Basic resources validation' {
        BeforeAll {
            $files = Get-ChildItem -Path "$moduleRoot/public" -Recurse -File -Filter '*.ps1'
        }

        It 'Manifest is valid' {
            Test-ModuleManifest -Path (Join-Path -Path $moduleRoot -ChildPath 'Maester.psd1')
            # Throws if not valid = failure. Success if not.
        }

        It 'Exports all functions in the public folder' {
            $functions = (Compare-Object -ReferenceObject $files.BaseName -DifferenceObject $manifest.FunctionsToExport | Where-Object SideIndicator -Like '<=').InputObject
            $functions | Should -BeNullOrEmpty
        }
        It "Exports no function that isn't also present in the public folder" {
            $functions = (Compare-Object -ReferenceObject $files.BaseName -DifferenceObject $manifest.FunctionsToExport | Where-Object SideIndicator -Like '=>').InputObject
            $functions | Should -BeNullOrEmpty
        }

        It 'Exports none of its internal functions' {
            $files = Get-ChildItem "$moduleRoot/internal" -Recurse -File -Filter '*.ps1'
            $files | Where-Object BaseName -In $manifest.FunctionsToExport | Should -BeNullOrEmpty
        }
    }

    Context 'Testing tags' {
        It "Tag '<_>' should not include whitespace" -ForEach @($manifest.PrivateData.PSData.Tags) {
            $_ | Should -Not -Match '\s'
        }
    }

    Context 'Individual file validation' {
        It 'The root module file exists' {
            Join-Path -Path $moduleRoot -ChildPath $manifest.RootModule | Should -Exist
        }

        Context 'Testing format files' -Skip:$(-not $manifest.ContainsKey('FormatsToProcess')) {
            It 'The file <_> should exist' -ForEach $manifest.FormatsToProcess {
                Join-Path -Path $moduleRoot -ChildPath $_ | Should -Exist
            }
        }

        Context 'Testing types files' -Skip:$(-not $manifest.ContainsKey('TypesToProcess')) {
            It 'The file <_> should exist' -ForEach $manifest.TypesToProcess {
                Join-Path -Path $moduleRoot -ChildPath $_ | Should -Exist
            }
        }
    }
}