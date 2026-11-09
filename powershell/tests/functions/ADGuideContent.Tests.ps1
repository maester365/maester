BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    $script:adTestsById = @{}
    foreach ($test in Get-MtTest -Product ad) { $script:adTestsById[$test.Id] = $test }
    $script:adGuideRoot = (Resolve-Path "$PSScriptRoot/../../../tests/ad").Path
}

Describe 'AD guide references preserve full current test identities' {
    It 'includes the test ID, exact title and cmdlet in each related-test bullet' {
        $problems = @()
        foreach ($file in Get-ChildItem $script:adGuideRoot -Recurse -Filter 'Test.*.md') {
            $text = Get-Content $file.FullName -Raw
            $sections = [regex]::Matches($text, '(?ms)^#### Related [Tt]ests\s*\r?\n(.*?)(?=^#### |^<!--- Results --->|\z)')
            foreach ($section in $sections) {
                foreach ($line in $section.Groups[1].Value -split '\r?\n') {
                    if ($line -notmatch '^\s*[-*]' -or $line -notmatch '(AD-[A-Z]+-\d+|Test-Mt)') { continue }
                    $idMatch = [regex]::Match($line, 'AD-[A-Z]+-\d+')
                    $reference = if ($idMatch.Success) { $script:adTestsById[$idMatch.Value] } else { $null }
                    if ($idMatch.Success -and $file.BaseName -eq "Test.$($idMatch.Value)") {
                        $problems += "$($file.Name): self-reference: $line"
                    }
                    if ($null -eq $reference -or -not $line.Contains($reference.Title) -or -not $line.Contains($reference.FunctionName)) {
                        $problems += "$($file.Name): $line"
                    }
                }
            }
        }
        $problems | Should -BeNullOrEmpty
    }

    It 'keeps the description and exactly one result footer in every AD guide' {
        foreach ($file in Get-ChildItem $script:adGuideRoot -Recurse -Filter 'Test.*.md') {
            $text = Get-Content $file.FullName -Raw
            [regex]::Matches($text, '<!--- Results --->').Count | Should -Be 1 -Because $file.Name
            $text | Should -Match '(?s)\S.+<!--- Results --->\s*%TestResult%\s*$' -Because $file.Name
        }
    }
    It 'does not pair DHCP authorization with unrelated SPN mapping checks' {
        $guide = Get-Content (Join-Path $script:adGuideRoot 'config/Test.AD-CFG-11.md') -Raw
        $guide | Should -Match 'DHCP'
        $guide | Should -Not -Match 'AD-SPN-0[17]|configured mappings'
    }

    It 'retains native invocation examples and a help link in every AD check' {
        foreach ($file in Get-ChildItem $script:adGuideRoot -Recurse -Filter 'Test.*.ps1') {
            $text = Get-Content $file.FullName -Raw
            $text | Should -Match '(?im)^\s*\.EXAMPLE\s*$' -Because $file.Name
            $text | Should -Match '(?im)^\s*\.LINK\s*$' -Because $file.Name
        }
    }
}
