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
    It "MT.AD.0101: AD Forest Domains" -Tag "MT.AD.0100","MT.AD.0101","AD Forest" {
        $result = Test-MtAdForestDomain
        if ($null -ne $result){
            $result | Should -Be $true -Because "Forest has appropriate domains"
        }
    }
    It "MT.AD.0102: AD Forest LDAP Referrals" -Tag "MT.AD.0100","MT.AD.0102","AD Forest" {
        $result = Test-MtAdForestExternalLdap
        if ($null -ne $result){
            $result | Should -Be $true -Because "Forest does not use external LDAP referrals"
        }
    }
    It "MT.AD.0103: AD Forest FSMO Roles" -Tag "MT.AD.0100","MT.AD.0103","AD Forest" {
        $result = Test-MtAdForestFsmoStatus
        if ($null -ne $result){
            $result | Should -Be $true -Because "Forest-level FSMO roles are on single DC"
        }
    }
    It "MT.AD.0104: AD Forest Functional Level" -Tag "MT.AD.0100","MT.AD.0104","AD Forest" {
        $result = Test-MtAdForestFunctionalLevel
        if ($null -ne $result){
            $result | Should -Be $true -Because "Forest Functional Level is within n-1 of highest"
        }
    }
    It "MT.AD.0105: AD Forest Sites" -Tag "MT.AD.0100","MT.AD.0105","AD Forest" {
        $result = Test-MtAdForestSite
        if ($null -ne $result){
            $result | Should -Be $true -Because "Forest has appropriate sites"
        }
    }
    It "MT.AD.0106: AD Forest Suffixes" -Tag "MT.AD.0100","MT.AD.0106","AD Forest" {
        $result = Test-MtAdForestSuffix
        if ($null -ne $result){
            $result | Should -Be $true -Because "Forest uses appropriate UPN and SPN suffixes"
        }
    }
}