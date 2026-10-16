# Legacy Pester fixture: a file that fails discovery because it does not parse (the last
# Describe is never closed). 2.x gives no rows for it; 3.0 gives one Error/LoadFailed row
# per statically known ID (BROKEN.0001, BROKEN.0002).
Describe "Contoso broken file" -Tag "Contoso" {
    It "BROKEN.0001: First test in a broken file" -Tag "BROKEN.0001" {
        $true | Should -BeTrue
    }

    It "BROKEN.0002: Second test in a broken file" -Tag "BROKEN.0002" {
        $values = @(1, 2, 3
        $values.Count | Should -Be 3
    }
