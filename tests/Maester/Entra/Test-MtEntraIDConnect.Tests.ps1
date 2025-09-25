BeforeDiscovery {

    $IdentityLogonEventsAvailable = ((Invoke-MtGraphRequest -ApiVersion "beta" -RelativeUri "security/runHuntingQuery" -Method POST `
        -ErrorAction SilentlyContinue `
        -Body (@{"Query" = "IdentityLogonEvents | getschema"} | ConvertTo-Json) `
        -OutputType PSObject -Verbose).results.ColumnName -contains "LogonType")
    $DeviceInfoAvailable = ((Invoke-MtGraphRequest -ApiVersion "beta" -RelativeUri "security/runHuntingQuery" -Method POST `
        -ErrorAction SilentlyContinue `
        -Body (@{"Query" = "DeviceInfo | getschema"} | ConvertTo-Json) `
        -OutputType PSObject -Verbose).results.ColumnName -contains "DeviceId")
    $UnifiedMdiInfoAvailable = $IdentityLogonEventsAvailable & $DeviceInfoAvailable
    $EntraIDPlan = Get-MtLicenseInformation -Product "EntraID"

    Write-Verbose "IdentityLogonEvents available: $IdentityLogonEventsAvailable"
    Write-Verbose "DeviceInfo availble: $DeviceInfoAvailable"
    Write-Verbose "UnifiedMdiInfoAvailable is $UnifiedMdiInfoAvailable"

}

Describe "Maester/Entra" -Tag "EntraIdConnect", "Entra", "Graph", "Security" -Skip:( $EntraIDPlan -ne "P2" ) {
    It "MT.1084: Seamless Single SignOn should be disabled for all domains in EntraID Connect servers. See https://maester.dev/docs/tests/MT.1084" -Tag "MT.1084" {

    if ( $UnifiedMdiInfoAvailable -eq $false) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'This test requires availability of Microsoft Defender for Identity and Microsoft Defender for Endpoint to get data from Defender XDR Advanced Hunting tables (IdentityLogonEvents and DeviceInfo).'
        return $null
    }

    try {
        $DomainsWithSsso = Test-MtDomainsWithSsso
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }

    if ($return -or $DomainsWithSsso.Count -eq 0) {
        $testResultMarkdown = "Well done. We found no evidence of domains where Seamless Single SignOn was still enabled in EntraID Connect via the Microsoft Defender for Identity logs."
    } else {
        $testResultMarkdown = "At least one domain has sign-ins with Seamless Single SignOn enabled in Entra ID Connect.`n`n%TestResult%"
        $result = "| DomainName | AccountUpn | DeviceName | OnboardingStatus | JoinType | Ssso Expected |`n"
        $result += "| --- | --- | --- | ---  | --- | ---  |`n"
        foreach ($Domain in $DomainsWithSsso) {
            $DomainName = $Domain.OnPremisesDomainName
            $Domain.JsonArray | ForEach-Object {
                $AccountUpn = $_.AccountUpn
                $DeviceName = $_.DeviceName
                $OnboardingStatus = $_.OnboardingStatus
                $JoinType = $_.JoinType
                $SssoExpected = $_.'Seamless SSO Expected'
                $result += "| $($DomainName) | $($AccountUpn) | $($DeviceName) | $($OnboardingStatus) | $($JoinType) | $($SssoExpected) |`n"
            }
        }
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -Description "Enabling Seamless SSO in Entra ID Connect introduces risks of lateral movement between your On-premise domain and Entra ID.`n`nIn the results you will find which domains, users and devices are still using Seamless SSO. Via the column 'Ssso expected' you can learn if Seamless SSO is expected to be used based on enriched device data.`n`nFor more information on the risks regarding Seamless SSO and how to remediate, see: https://maester.dev/docs/tests/MT.1084" -Severity "High"
    $DomainsWithSsso.Count -eq "0" | Should -Be $True -Because "Seamless Single SignOn should be disabled for all domains in EntraID Connect servers."

    }

}
