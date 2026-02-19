<#
.SYNOPSIS
    Ensure Microsoft Entra seamless single sign-on is disabled for all domains.

.DESCRIPTION
    Microsoft Entra seamless single sign-on (SSSO) provides users with easy access to cloud-based applications by automatically signing them in when they are on their corporate devices connected to the corporate network.
    However, if not managed properly, it can introduce security risks, especially if devices are compromised or if there are misconfigurations.

.EXAMPLE
    Test-MtEntraIDConnectSsso

    Returns true if Microsoft Entra seamless single sign-on is disabled

.LINK
    https://maester.dev/docs/commands/Test-MtEntraIDConnectSsso
#>
function Test-MtEntraIDConnectSsso {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not (Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }
    $return = $true

    Write-Verbose "Checking if Microsoft Entra seamless single sign-on is disabled..."
    try {
        $organizationConfig = Invoke-MtGraphRequest -RelativeUri "organization"
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
    if ($organizationConfig.onPremisesSyncEnabled -ne $true) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'OnPremisesSynchronization is not configured'
        return $null
    }
    # Validate if MDI and MDE data is available
    try {
        # Check for availability of IdentityLogonEvents table
        $params = @{
            ApiVersion  = "beta"
            RelativeUri = "security/runHuntingQuery"
            Method      = "POST"
            ErrorAction = "SilentlyContinue"
            Body        = (@{"Query" = "IdentityLogonEvents | getschema" } | ConvertTo-Json)
            OutputType  = "PSObject"
        }
        $IdentityLogonEventsAvailable = ((Invoke-MtGraphRequest @params).results.ColumnName -contains "LogonType")
        # Check for availability of DeviceInfo table
        $params = @{
            ApiVersion  = "beta"
            RelativeUri = "security/runHuntingQuery"
            Method      = "POST"
            ErrorAction = "SilentlyContinue"
            Body        = (@{"Query" = "DeviceInfo | getschema" } | ConvertTo-Json)
            OutputType  = "PSObject"
        }
        $DeviceInfoAvailable = ((Invoke-MtGraphRequest @params).results.ColumnName -contains "DeviceId")
        $UnifiedMdiInfoAvailable = $IdentityLogonEventsAvailable -and $DeviceInfoAvailable
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }

    if ( $UnifiedMdiInfoAvailable -eq $false) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'This test requires availability of Microsoft Defender for Identity and Microsoft Defender for Endpoint to get data from Defender XDR Advanced Hunting tables (IdentityLogonEvents and DeviceInfo).'
        return $null
    }

    try {
        $Query = @"
// Get all device info we can find
let devices = (
    DeviceInfo
    // Search for 14 days
    | where Timestamp > ago(14d)
    // Normalize DeviceName
    // --> if it is an IP Address we keep it
    // --> If it is not an IP Address we only use the hostname for correlation
    | extend DeviceName = iff(ipv4_is_private(DeviceName), DeviceName, tolower(split(DeviceName, ".")[0]))
    // Only get interesting data
    | distinct DeviceName, OSPlatform, OSVersion, DeviceId, OnboardingStatus, Model, JoinType
);
IdentityLogonEvents
// Get the last 14 days of logon events on Domain Controllers
| where Timestamp > ago(14d)
// Search for Seamless SSO events
| where Application == "Active Directory" and Protocol == "Kerberos"
| where TargetDeviceName == "AZUREADSSOACC"
// Save the domain name of the Domain Controller
| extend OnPremisesDomainName = strcat(split(DestinationDeviceName, ".")[-2], ".", split(DestinationDeviceName, ".")[-1])
// Normalize DeviceName
// --> if it is an IP Address we keep it
// --> If it is not an IP Address we only use the hostname for correlation
| extend DeviceName = iff(ipv4_is_private(DeviceName), DeviceName, tolower(split(DeviceName, ".")[0]))
// Only use interesting data and find more info regarding the source device
| distinct AccountUpn, OnPremisesDomainName, DeviceName
| join kind=leftouter devices on DeviceName
| project-away DeviceName1
// Check if Seamless SSO usage is expected
| extend ['Seamless SSO Expected'] = case(
    // Cases where we do not expect Seamless SSO to be used
    JoinType == "Hybrid Azure AD Join" or
    JoinType == "AAD Joined" or
    JoinType == "AAD Registered", "No",
    // Cases where we do expect Seamless SSO to be used
    JoinType == "Domain Joined" or
    (OSPlatform startswith "Windows" and toreal(OSVersion) < 10.0) , "Yes",
    // Cases that need to be verified
    "Unknown (to verify)"
)
| extend Obj = bag_pack(
    "AccountUpn", AccountUpn,
    "DeviceName", DeviceName,
    "OSPlatform", OSPlatform,
    "OSVersion", OSVersion,
    "OnboardingStatus", OnboardingStatus,
    "JoinType", JoinType,
    "Seamless SSO Expected", ['Seamless SSO Expected']
)
| summarize JsonArray=make_list(Obj) by OnPremisesDomainName
"@

        Write-Verbose "Running KQL query to get domains with Seamless SSO usage"
        $DomainsWithSsso = Invoke-MtGraphSecurityQuery -Query $Query -Timespan "P14D"
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }

    try {
        if ($DomainsWithSsso.Count -gt 0) {
            $return = $false
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
        } else {
            $testResultMarkdown = "Well done. We found no evidence of domains where Seamless Single SignOn was still enabled in EntraID Connect via the Microsoft Defender for Identity logs."
        }
        Add-MtTestResultDetail -Result $testResultMarkdown

        return $return
    } Catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
