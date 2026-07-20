Describe "Active Directory - Printer" -Tag "AD", "AD.Printer", "AD-PRINT-01" {
    It "AD-PRINT-01: Printer total count should be retrievable" {

        $result = Test-MtAdPrinterTotalCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "printer data should be accessible"
        }
    }
}
