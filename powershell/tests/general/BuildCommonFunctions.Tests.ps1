BeforeAll {
    $script:CommonFunctionsModule = Import-Module "$PSScriptRoot/../../../build/CommonFunctions.psm1" -Force -PassThru -DisableNameChecking
}

AfterAll {
    Remove-Module $script:CommonFunctionsModule
}

Describe 'Build directory resolution' {
    BeforeEach {
        $script:BaseDirectory = Join-Path $TestDrive 'base'
        $script:OtherDirectory = Join-Path $TestDrive 'other'
        $null = New-Item -ItemType Directory -Path $script:BaseDirectory, $script:OtherDirectory -Force
        Push-Location $script:OtherDirectory
        # Keep the .NET working directory distinct, and all baseline writes inside TestDrive.
        $script:PreviousProcessDirectory = [Environment]::CurrentDirectory
        [Environment]::CurrentDirectory = $TestDrive
    }

    AfterEach {
        Pop-Location
        [Environment]::CurrentDirectory = $script:PreviousProcessDirectory
    }

    It 'Creates relative paths under the specified base rather than the working directory' {
        $result = Assert-DirectoryExists -InputObjects 'relative-output' -BaseDirectory $script:BaseDirectory
        $result.FullName | Should -Be (Join-Path $script:BaseDirectory 'relative-output')
        Test-Path -LiteralPath (Join-Path $script:OtherDirectory 'relative-output') | Should -BeFalse
    }

    It 'Leaves existing paths under the specified base in place' {
        $path = Join-Path $script:BaseDirectory 'existing'
        $null = New-Item -ItemType Directory -Path $path
        $result = @(Assert-DirectoryExists -InputObjects 'existing' -BaseDirectory $script:BaseDirectory)
        $result.Count | Should -Be 0
        Test-Path -LiteralPath (Join-Path $script:OtherDirectory 'existing') | Should -BeFalse
    }

    It 'Keeps absolute paths independent of the base directory' {
        $path = Join-Path $TestDrive 'absolute-output'
        $result = Assert-DirectoryExists -InputObjects $path -BaseDirectory $script:BaseDirectory
        $result.FullName | Should -Be $path
    }

    It 'Resolves every string received through the pipeline against the base' {
        $result = @('first', 'second' | Assert-DirectoryExists -BaseDirectory $script:BaseDirectory)
        $result.FullName | Should -Be @((Join-Path $script:BaseDirectory 'first'), (Join-Path $script:BaseDirectory 'second'))
    }

    It 'Uses the current location when no base directory is specified' {
        $result = Assert-DirectoryExists -InputObjects 'default-output'
        $result.FullName | Should -Be (Join-Path $script:OtherDirectory 'default-output')
    }

    It 'Preserves DirectoryInfo and FileInfo input paths' {
        $directory = [System.IO.DirectoryInfo] (Join-Path $TestDrive 'directory-object')
        $file = [System.IO.FileInfo] (Join-Path $TestDrive 'file-parent/example.txt')
        $result = @($directory, $file | Assert-DirectoryExists -BaseDirectory $script:BaseDirectory)
        $result.FullName | Should -Be @($directory.FullName, $file.Directory.FullName)
    }
}
