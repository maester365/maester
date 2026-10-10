# Legacy Pester fixture: BeforeDiscovery throws, so Pester fails the container during
# discovery. 2.x gives no rows; 3.0 gives an Error/LoadFailed row for THROWS.0001.
BeforeDiscovery {
    throw "Contoso API is unreachable during discovery"
}

Describe "Contoso discovery failure" -Tag "Contoso" {
    It "THROWS.0001: Never discovered" -Tag "THROWS.0001" {
        $true | Should -BeTrue
    }
}
