Describe "Maester/Active Directory" -Tag "Maester", "Active Directory", "MT.AD" {
    It "MT.AD.0001: AD Computer Containers" -Tag "MT.AD.0000","MT.AD.0001","AD Computer" {
        $result = Test-MtAdComputerContainer
        if ($null -ne $result){
            $result | Should -Be $true -Because "Computer Containers are properly used"
        }
    }
    It "MT.AD.0002: AD Computer Creator SID" -Tag "MT.AD.0000","MT.AD.0002","AD Computer" {
        $result = Test-MtAdComputerCreatorSid
        if ($null -ne $result){
            $result | Should -Be $true -Because "Computers do not use creator SID"
        }
    }
    It "MT.AD.0003: AD Computer DNS" -Tag "MT.AD.0000","MT.AD.0003","AD Computer" {
        $result = Test-MtAdComputerDns
        if ($null -ne $result){
            $result | Should -Be $true -Because "Computer DNS hostnames are properly used"
        }
    }
    It "MT.AD.0004: AD Computer Domain Controllers" -Tag "MT.AD.0000","MT.AD.0004","AD Computer" {
        $result = Test-MtAdComputerDomainController
        if ($null -ne $result){
            $result | Should -Be $true -Because "Domain Controllers are properly used"
        }
    }
    It "MT.AD.0005: AD Computer Kerberos" -Tag "MT.AD.0000","MT.AD.0005","AD Computer" {
        $result = Test-MtAdComputerKerberos
        if ($null -ne $result){
            $result | Should -Be $true -Because "Computer Kerberos configurations are properly used"
        }
    }
    It "MT.AD.0006: AD Computer Operating Systems" -Tag "MT.AD.0000","MT.AD.0006","AD Computer" {
        $result = Test-MtAdComputerOperatingSystem
        if ($null -ne $result){
            $result | Should -Be $true -Because "Computer operating systems are properly used"
        }
    }
    It "MT.AD.0007: AD Computer Primary Group" -Tag "MT.AD.0000","MT.AD.0007","AD Computer" {
        $result = Test-MtAdComputerPrimaryGroup
        if ($null -ne $result){
            $result | Should -Be $true -Because "Computer primary groups are properly used"
        }
    }
    It "MT.AD.0008: AD Computer Services" -Tag "MT.AD.0000","MT.AD.0008","AD Computer" {
        $result = Test-MtAdComputerService
        if ($null -ne $result){
            $result | Should -Be $true -Because "Computer services configurations are properly used"
        }
    }
    It "MT.AD.0009: AD Computer SID History" -Tag "MT.AD.0000","MT.AD.0009","AD Computer" {
        $result = Test-MtAdComputerSidHistory
        if ($null -ne $result){
            $result | Should -Be $true -Because "Computer SID History is properly used"
        }
    }
    It "MT.AD.0010: AD Computer Status" -Tag "MT.AD.0000","MT.AD.0010","AD Computer" {
        $result = Test-MtAdComputerStatus
        if ($null -ne $result){
            $result | Should -Be $true -Because "Computer state is proper"
        }
    }
}