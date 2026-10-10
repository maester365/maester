# Legacy Pester fixture: BeforeAll dot-sources a helper file, the most common 2.x custom pattern.
BeforeAll {
    . $PSScriptRoot/helpers/Get-ContosoPolicy.ps1
}

Describe "Contoso password policy" -Tag "Contoso", "Password" {
    It "CONTOSO.1101: Passwords are set to never expire" -Tag "CONTOSO.1101" {
        (Get-ContosoPolicy -Name PasswordExpiry).Value | Should -Be 0
    }

    It "CONTOSO.1102: Account lockout threshold is 10 or fewer" -Tag "CONTOSO.1102" {
        (Get-ContosoPolicy -Name LockoutThreshold).Value | Should -BeLessOrEqual 10
    }
}
