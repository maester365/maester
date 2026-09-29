BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    function New-MtTestFixtureZip {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Private Pester test fixture helper, not a shipped cmdlet - ShouldProcess semantics do not apply.')]
        param(
            [Parameter(Mandatory)] [string] $DestinationZip,
            [Parameter(Mandatory)] [string] $StageRoot,
            [Parameter(Mandatory)] [string] $RepoFolderName,
            [switch] $WithoutMaesterFolder,
            [string] $InfoJson
        )

        if (Test-Path -Path $StageRoot) { Remove-Item -Path $StageRoot -Recurse -Force }

        if ($WithoutMaesterFolder) {
            $repoDir = Join-Path $StageRoot $RepoFolderName
            New-Item -Path $repoDir -ItemType Directory -Force | Out-Null
            Set-Content -Path (Join-Path $repoDir 'README.md') -Value '# readme'
        } else {
            $maesterDir = Join-Path $StageRoot "$RepoFolderName/.maester"
            New-Item -Path $maesterDir -ItemType Directory -Force | Out-Null
            Set-Content -Path (Join-Path $maesterDir 'Sample.Tests.ps1') -Value 'Describe "Sample" { It "works" { $true | Should -BeTrue } }'
            Set-Content -Path (Join-Path $StageRoot "$RepoFolderName/README.md") -Value '# readme'
            if ($InfoJson) {
                Set-Content -Path (Join-Path $maesterDir 'maester-metadata.json') -Value $InfoJson
            }
        }

        if (Test-Path -Path $DestinationZip) { Remove-Item -Path $DestinationZip -Force }
        [System.IO.Compression.ZipFile]::CreateFromDirectory($StageRoot, $DestinationZip)
    }
}

Describe 'Install-MtCustomTests' {
    BeforeEach {
        $script:savedMaesterGitHubToken = $env:MAESTER_GITHUB_TOKEN
        $script:savedGhToken = $env:GH_TOKEN
        $env:MAESTER_GITHUB_TOKEN = $null
        $env:GH_TOKEN = $null

        # The security due-diligence confirmation is always shown (even with -Force), so
        # auto-accept it by default in every test. Tests that care about the *other*
        # (overwrite) confirmation mock Get-MtConfirmation again with a ParameterFilter
        # scoped to that message, which takes precedence without disturbing this default.
        Mock Get-MtConfirmation -ModuleName Maester -ParameterFilter { $message -match 'due diligence' } { $true }
    }

    AfterEach {
        $env:MAESTER_GITHUB_TOKEN = $script:savedMaesterGitHubToken
        $env:GH_TOKEN = $script:savedGhToken
    }

    Context 'Invalid repository input' {
        It 'Writes an error and does not call GitHub when Repository cannot be parsed' {
            Mock Invoke-WebRequest -ModuleName Maester { throw 'Should not be called' }

            Install-MtCustomTests -Repository 'https://evilgithub.com/maester365/repo' -Path $TestDrive -ErrorAction SilentlyContinue -ErrorVariable errRecord

            $errRecord | Where-Object { $_ -match 'Unable to parse' } | Should -Not -BeNullOrEmpty
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 0
        }
    }

    Context 'Security due-diligence confirmation' {
        It 'Aborts before calling GitHub when the security disclaimer is declined' {
            Mock Get-MtConfirmation -ModuleName Maester -ParameterFilter { $message -match 'due diligence' } { $false }
            Mock Invoke-WebRequest -ModuleName Maester { throw 'Should not be called' }

            Install-MtCustomTests -Repository 'Mynster9361/Least_Privileged_MSGraph' -Path $TestDrive

            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 0
        }

        It 'Shows the security disclaimer even with -Force' {
            $installPath = Join-Path $TestDrive 'install-force-security'
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -like 'https://api.github.com/repos/*' } {
                [PSCustomObject]@{ Content = '{"name":"Least_Privileged_MSGraph","owner":{"login":"Mynster9361"},"default_branch":"main"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -like 'https://github.com/*/archive/*' } { throw 'Should not be reached in this test' }
            Mock Get-MtConfirmation -ModuleName Maester -ParameterFilter { $message -match 'due diligence' } { $false }

            Install-MtCustomTests -Repository 'Mynster9361/Least_Privileged_MSGraph' -Path $installPath -Force

            Should -Invoke Get-MtConfirmation -ModuleName Maester -ParameterFilter { $message -match 'due diligence' } -Times 1 -Exactly
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 0
        }
    }

    Context 'Repository lookup failure' {
        It 'Writes an error when the repository is not found' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -like 'https://api.github.com/repos/*' } {
                $resp = [PSCustomObject]@{ StatusCode = 404; Headers = @{} }
                $ex = [System.Exception]::new('Not Found')
                Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $resp
                throw $ex
            }

            Install-MtCustomTests -Repository 'maester365/does-not-exist' -Path $TestDrive -ErrorAction SilentlyContinue -ErrorVariable errRecord

            # PowerShell logs the thrown exception at each scope boundary it crosses on the way
            # up to our catch block, so -ErrorVariable can contain intermediate duplicates -
            # assert our own message is present rather than pinning an exact array index/count.
            $errRecord | Where-Object { $_ -match 'was not found' } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Successful install' {
        BeforeEach {
            $script:stageRoot = Join-Path $TestDrive 'stage'
            $script:fixtureZip = Join-Path $TestDrive 'fixture.zip'
            New-MtTestFixtureZip -DestinationZip $script:fixtureZip -StageRoot $script:stageRoot -RepoFolderName 'Least_Privileged_MSGraph-main'

            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -like 'https://api.github.com/repos/*' } {
                [PSCustomObject]@{ Content = '{"name":"Least_Privileged_MSGraph","owner":{"login":"Mynster9361"},"default_branch":"main"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -like 'https://github.com/*/archive/*' } {
                Copy-Item -Path $script:fixtureZip -Destination $OutFile -Force
            }
        }

        It 'Installs the contents of the .maester folder into Custom folder named after the repo' {
            $installPath = Join-Path $TestDrive 'install1'
            Install-MtCustomTests -Repository 'Mynster9361/Least_Privileged_MSGraph' -Path $installPath

            $destination = Join-Path $installPath 'Custom/Least_Privileged_MSGraph'
            Test-Path (Join-Path $destination 'Sample.Tests.ps1') | Should -BeTrue
            # Only the contents of .maester are copied - sibling repo files like README.md are not.
            Test-Path (Join-Path $destination 'README.md') | Should -BeFalse

            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 1 -ParameterFilter { $Uri -eq 'https://github.com/Mynster9361/Least_Privileged_MSGraph/archive/main.zip' }
        }

        It 'Uses the explicit -Branch instead of the default branch' {
            $installPath = Join-Path $TestDrive 'install2'
            Install-MtCustomTests -Repository 'Mynster9361/Least_Privileged_MSGraph' -Path $installPath -Branch 'develop'

            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 1 -ParameterFilter { $Uri -eq 'https://github.com/Mynster9361/Least_Privileged_MSGraph/archive/develop.zip' }
        }

        It 'Prompts before replacing an existing destination folder and aborts on "n"' {
            $installPath = Join-Path $TestDrive 'install3'
            $destination = Join-Path $installPath 'Custom/Least_Privileged_MSGraph'
            New-Item -Path $destination -ItemType Directory -Force | Out-Null
            Set-Content -Path (Join-Path $destination 'Marker.txt') -Value 'keep me'

            Mock Get-MtConfirmation -ModuleName Maester -ParameterFilter { $message -match 'already exists' } { $false }

            Install-MtCustomTests -Repository 'Mynster9361/Least_Privileged_MSGraph' -Path $installPath

            Test-Path (Join-Path $destination 'Marker.txt') | Should -BeTrue
            Test-Path (Join-Path $destination 'Sample.Tests.ps1') | Should -BeFalse
        }

        It 'Replaces an existing destination folder after confirmation' {
            $installPath = Join-Path $TestDrive 'install4'
            $destination = Join-Path $installPath 'Custom/Least_Privileged_MSGraph'
            New-Item -Path $destination -ItemType Directory -Force | Out-Null
            Set-Content -Path (Join-Path $destination 'Marker.txt') -Value 'stale'

            Mock Get-MtConfirmation -ModuleName Maester -ParameterFilter { $message -match 'already exists' } { $true }

            Install-MtCustomTests -Repository 'Mynster9361/Least_Privileged_MSGraph' -Path $installPath

            Test-Path (Join-Path $destination 'Marker.txt') | Should -BeFalse
            Test-Path (Join-Path $destination 'Sample.Tests.ps1') | Should -BeTrue
        }

        It 'Skips only the overwrite prompt with -Force (the security disclaimer still shows)' {
            $installPath = Join-Path $TestDrive 'install5'
            $destination = Join-Path $installPath 'Custom/Least_Privileged_MSGraph'
            New-Item -Path $destination -ItemType Directory -Force | Out-Null
            Set-Content -Path (Join-Path $destination 'Marker.txt') -Value 'stale'

            Mock Get-MtConfirmation -ModuleName Maester -ParameterFilter { $message -match 'already exists' } { throw 'Should not be called' }

            Install-MtCustomTests -Repository 'Mynster9361/Least_Privileged_MSGraph' -Path $installPath -Force

            Test-Path (Join-Path $destination 'Sample.Tests.ps1') | Should -BeTrue
            Should -Invoke Get-MtConfirmation -ModuleName Maester -ParameterFilter { $message -match 'already exists' } -Times 0
            Should -Invoke Get-MtConfirmation -ModuleName Maester -ParameterFilter { $message -match 'due diligence' } -Times 1 -Exactly
        }

        It 'Preserves the existing installation if staging the new copy fails' {
            $installPath = Join-Path $TestDrive 'install6'
            $destination = Join-Path $installPath 'Custom/Least_Privileged_MSGraph'
            New-Item -Path $destination -ItemType Directory -Force | Out-Null
            Set-Content -Path (Join-Path $destination 'Marker.txt') -Value 'keep me'

            Mock Get-MtConfirmation -ModuleName Maester -ParameterFilter { $message -match 'already exists' } { $true }
            # -Recurse is unique to the staging copy - the archive-download mock's own
            # Copy-Item call (faking the zip download) doesn't pass it, so this filter
            # leaves that unrelated call alone.
            Mock Copy-Item -ModuleName Maester -ParameterFilter { $Recurse -eq $true } { throw 'Simulated disk failure' }

            Install-MtCustomTests -Repository 'Mynster9361/Least_Privileged_MSGraph' -Path $installPath -ErrorAction SilentlyContinue -ErrorVariable errRecord

            Test-Path (Join-Path $destination 'Marker.txt') | Should -BeTrue
            Test-Path (Join-Path $destination 'Sample.Tests.ps1') | Should -BeFalse
            $errRecord | Where-Object { $_ -match 'Unable to stage' } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'maester-metadata.json manifest' {
        It 'Displays the Message and warns about missing/outdated RequiredModules' {
            $stageRoot = Join-Path $TestDrive 'stage-info'
            $fixtureZip = Join-Path $TestDrive 'fixture-info.zip'
            $infoJson = @'
{
  "Message": "Remember to configure the Log Analytics workspace ID before running these tests.",
  "RequiredModules": ["NotInstalledModule", { "Name": "Pester", "MinimumVersion": "99.0.0" }]
}
'@
            New-MtTestFixtureZip -DestinationZip $fixtureZip -StageRoot $stageRoot -RepoFolderName 'Least_Privileged_MSGraph-main' -InfoJson $infoJson

            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -like 'https://api.github.com/repos/*' } {
                [PSCustomObject]@{ Content = '{"name":"Least_Privileged_MSGraph","owner":{"login":"Mynster9361"},"default_branch":"main"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -like 'https://github.com/*/archive/*' } {
                Copy-Item -Path $fixtureZip -Destination $OutFile -Force
            }
            Mock Get-Module -ModuleName Maester -ParameterFilter { $Name -eq 'NotInstalledModule' } { $null }
            Mock Get-Module -ModuleName Maester -ParameterFilter { $Name -eq 'Pester' } { [PSCustomObject]@{ Name = 'Pester'; Version = [version]'5.5.0' } }
            Mock Write-Host -ModuleName Maester { }

            $installPath = Join-Path $TestDrive 'install-info'
            Install-MtCustomTests -Repository 'Mynster9361/Least_Privileged_MSGraph' -Path $installPath -WarningAction SilentlyContinue -WarningVariable warnRecord

            $warnRecord | Where-Object { $_ -match 'NotInstalledModule' -and $_ -match 'Pester \(>= 99\.0\.0\)' } | Should -Not -BeNullOrEmpty
            Should -Invoke Write-Host -ModuleName Maester -ParameterFilter { $Object -match 'Log Analytics workspace ID' }
        }

        It 'Does not warn when all RequiredModules are satisfied' {
            $stageRoot = Join-Path $TestDrive 'stage-info-ok'
            $fixtureZip = Join-Path $TestDrive 'fixture-info-ok.zip'
            $infoJson = '{ "RequiredModules": ["Pester"] }'
            New-MtTestFixtureZip -DestinationZip $fixtureZip -StageRoot $stageRoot -RepoFolderName 'Least_Privileged_MSGraph-main' -InfoJson $infoJson

            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -like 'https://api.github.com/repos/*' } {
                [PSCustomObject]@{ Content = '{"name":"Least_Privileged_MSGraph","owner":{"login":"Mynster9361"},"default_branch":"main"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -like 'https://github.com/*/archive/*' } {
                Copy-Item -Path $fixtureZip -Destination $OutFile -Force
            }
            Mock Get-Module -ModuleName Maester -ParameterFilter { $Name -eq 'Pester' } { [PSCustomObject]@{ Name = 'Pester'; Version = [version]'5.5.0' } }

            $installPath = Join-Path $TestDrive 'install-info-ok'
            Install-MtCustomTests -Repository 'Mynster9361/Least_Privileged_MSGraph' -Path $installPath -WarningAction SilentlyContinue -WarningVariable warnRecord

            $warnRecord | Should -BeNullOrEmpty
        }

        It 'Warns but still installs when the manifest JSON is malformed' {
            $stageRoot = Join-Path $TestDrive 'stage-info-bad'
            $fixtureZip = Join-Path $TestDrive 'fixture-info-bad.zip'
            New-MtTestFixtureZip -DestinationZip $fixtureZip -StageRoot $stageRoot -RepoFolderName 'Least_Privileged_MSGraph-main' -InfoJson '{ this is not valid json'

            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -like 'https://api.github.com/repos/*' } {
                [PSCustomObject]@{ Content = '{"name":"Least_Privileged_MSGraph","owner":{"login":"Mynster9361"},"default_branch":"main"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -like 'https://github.com/*/archive/*' } {
                Copy-Item -Path $fixtureZip -Destination $OutFile -Force
            }

            $installPath = Join-Path $TestDrive 'install-info-bad'
            Install-MtCustomTests -Repository 'Mynster9361/Least_Privileged_MSGraph' -Path $installPath -WarningAction SilentlyContinue -WarningVariable warnRecord

            $warnRecord | Where-Object { $_ -match 'Unable to parse' } | Should -Not -BeNullOrEmpty
            Test-Path (Join-Path $installPath 'Custom/Least_Privileged_MSGraph/Sample.Tests.ps1') | Should -BeTrue
        }
    }

    Context 'Repository without a .maester folder' {
        It 'Writes an error and does not create a Custom folder' {
            $stageRoot = Join-Path $TestDrive 'stage-no-maester'
            $fixtureZip = Join-Path $TestDrive 'fixture-no-maester.zip'
            New-MtTestFixtureZip -DestinationZip $fixtureZip -StageRoot $stageRoot -RepoFolderName 'no-maester-main' -WithoutMaesterFolder

            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -like 'https://api.github.com/repos/*' } {
                [PSCustomObject]@{ Content = '{"name":"no-maester","owner":{"login":"contoso"},"default_branch":"main"}' }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -like 'https://github.com/*/archive/*' } {
                Copy-Item -Path $fixtureZip -Destination $OutFile -Force
            }

            $installPath = Join-Path $TestDrive 'install-no-maester'
            Install-MtCustomTests -Repository 'contoso/no-maester' -Path $installPath -ErrorAction SilentlyContinue -ErrorVariable errRecord

            $errRecord | Where-Object { $_ -match "No '.maester' folder" } | Should -Not -BeNullOrEmpty
            Test-Path (Join-Path $installPath 'Custom') | Should -BeFalse
        }
    }
}
