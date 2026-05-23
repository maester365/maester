Describe "Maester/Entra" -Tag "Maester", "Entra", "MT.1157" {
    It "MT.1157: A DMARC policy SHALL be published for every Entra managed and verified domain." {
        $mtDomainsDmarcRecordExists = Test-MtDomainsDmarcRecordExists

        if ($null -ne $mtDomainsDmarcRecordExists) {
            $mtDomainsDmarcRecordExists | Should -Be $true -Because "DMARC record should exist."
        }
    }
}
