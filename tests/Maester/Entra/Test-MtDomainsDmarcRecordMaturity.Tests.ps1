Describe "Maester/Entra" -Tag "Maester", "Entra", "MT.1182" {
    It "MT.1182: Mature DMARC policy SHALL be published for every Entra managed and verified domain." {
        $mtDomainsDmarcRecordMaturity = Test-MtDomainsDmarcRecordMaturity -TestName $____Pester.CurrentTest.ExpandedName

        if ($null -ne $mtDomainsDmarcRecordMaturity) {
            $mtDomainsDmarcRecordMaturity | Should -Be $true -Because "DMARC record should exist."
        }
    }
}
