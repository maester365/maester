<#
.SYNOPSIS
    Check data from Defender for Identity to check domains with Seamless SSO usage.
.DESCRIPTION
    Executes KQL function over IdentityLogonEvents data to retrieve information about domains with Seamless SSO usage. It enriches the data with device insights.
.EXAMPLE
    Test-MtDomainsWithSsso
    Returns a detailed list of domains with Seamless SSO usage, including associated devices and their properties.
.LINK
    https://maester.dev/docs/commands/Test-MtDomainsWithSsso
#>

function Test-MtDomainsWithSsso {
    [CmdletBinding()]
    [OutputType([string])]
    param ()

    $Query = @"
        // Get all device info we can find
        let devices = (
            DeviceInfo
            // Search for 14 days
            | where TimeGenerated > ago(14d)
            // Normalize DeviceName
            // --> if it is an IP Address we keep it
            // --> If it is not an IP Address we only use the hostname for correlation
            | extend DeviceName = iff(ipv4_is_private(DeviceName), DeviceName, tolower(split(DeviceName, ".")[0]))
            // Only get interesting data
            | distinct DeviceName, OSPlatform, OSVersion, DeviceId, OnboardingStatus, Model, JoinType
        );
        IdentityLogonEvents
        // Get the last 14 days of logon events on Domain Controllers
        | where TimeGenerated > ago(14d)
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
    return $DomainsWithSsso
}