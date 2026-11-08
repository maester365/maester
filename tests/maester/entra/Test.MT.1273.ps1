function Get-MtUserRiskDetectionInstance {
    <#
    .SYNOPSIS
    Returns one MT.1273 instance per Entra ID Protection user risk detection type.

    .DESCRIPTION
    Instance source of the MT.1273 family. Returns one instance for each sign-in and user risk
    detection type that Microsoft documents (MT.1273.<riskEventType>), so every type has a row in the
    report whether or not it has open detections. Any riskEventType that Graph returns for an open
    detection and that is not in the list gets a row of its own, so a detection Microsoft adds later is
    reported rather than dropped. If the open detections cannot be read here, only the documented
    types are returned and each row reports the error itself.

    Source: https://learn.microsoft.com/entra/id-protection/concept-identity-protection-risks
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $investigate = 'https://learn.microsoft.com/entra/id-protection/howto-identity-protection-investigate-risk'

    # Name, whether Entra ID P2 is needed to see it, severity of an open detection, a short summary,
    # and Microsoft's investigation tips where they publish a section for the type.
    $catalog = @(
        @{ Id = 'riskyIPAddress'; Name = 'Activity from anonymous IP address'; Premium = $true; Severity = 'Medium'
            About = 'Microsoft Defender for Cloud Apps saw the user active from an IP address known as an anonymous proxy.' }
        @{ Id = 'authenticatorPhishing'; Name = 'Suspicious MFA authentication approval'; Premium = $true; Severity = 'High'
            About = 'An MFA approval in Microsoft Authenticator came from a device and location that do not match the sign-in it approved, a sign of a phishing or social engineering attack.' }
        @{ Id = 'generic'; Name = 'Additional risk detected'; Premium = $false; Severity = 'Medium'
            About = 'A premium detection fired. Its details are only shown to tenants with Microsoft Entra ID P2.' }
        @{ Id = 'adminConfirmedUserCompromised'; Name = 'Admin confirmed user compromised'; Premium = $false; Severity = 'High'
            About = 'An administrator confirmed this user compromised. The account still needs to be remediated.' }
        @{ Id = 'anomalousToken'; Name = 'Anomalous token'; Premium = $true; Severity = 'Medium'
            About = 'A session or refresh token has unusual characteristics, such as an unusual lifetime or use from an unfamiliar location, which can indicate token replay.'
            Tips = "$investigate#anomalous-token-and-token-issuer-anomaly-detections" }
        @{ Id = 'anonymizedIPAddress'; Name = 'Anonymous IP address'; Premium = $false; Severity = 'Low'
            About = 'The user signed in from an anonymous IP address, such as Tor or an anonymizing VPN.' }
        @{ Id = 'unlikelyTravel'; Name = 'Atypical travel'; Premium = $true; Severity = 'Medium'
            About = 'Two sign-ins came from locations too far apart for the user to travel between, and at least one location is unusual for the user.'
            Tips = "$investigate#atypical-travel-detections" }
        @{ Id = 'mcasImpossibleTravel'; Name = 'Impossible travel'; Premium = $true; Severity = 'Medium'
            About = 'Microsoft Defender for Cloud Apps saw activity from distant locations within a time shorter than the travel time between them.' }
        @{ Id = 'maliciousIPAddress'; Name = 'Malicious IP address'; Premium = $true; Severity = 'Medium'
            About = 'The user signed in from an IP address with a high rate of failed sign-ins or a bad reputation.'
            Tips = "$investigate#malicious-ip-address-detections" }
        @{ Id = 'mcasFinSuspiciousFileAccess'; Name = 'Mass access to sensitive files'; Premium = $true; Severity = 'Medium'
            About = 'Microsoft Defender for Cloud Apps saw the user access an unusual number of possibly sensitive files in SharePoint or OneDrive.' }
        @{ Id = 'investigationsThreatIntelligence'; Name = 'Microsoft Entra threat intelligence'; Premium = $false; Severity = 'High'
            About = "The user's activity matches attack patterns known to Microsoft threat intelligence."
            Tips = "$investigate#microsoft-entra-threat-intelligence" }
        @{ Id = 'newCountry'; Name = 'New country'; Premium = $true; Severity = 'Low'
            About = 'Microsoft Defender for Cloud Apps saw activity from a country new or infrequent for the organization.' }
        @{ Id = 'passwordSpray'; Name = 'Password spray'; Premium = $true; Severity = 'High'
            About = "A password spray attack correctly guessed the user's password."
            Tips = "$investigate#password-spray-detections" }
        @{ Id = 'suspiciousBrowser'; Name = 'Suspicious browser'; Premium = $true; Severity = 'Medium'
            About = 'The same browser was used for suspicious sign-ins across several tenants from different countries.'
            Tips = "$investigate#suspicious-browser-detections" }
        @{ Id = 'suspiciousInboxForwarding'; Name = 'Suspicious inbox forwarding'; Premium = $true; Severity = 'Medium'
            About = "Microsoft Defender for Cloud Apps found a suspicious forwarding rule on the user's mailbox, such as one that copies all mail to an external address." }
        @{ Id = 'mcasSuspiciousInboxManipulationRules'; Name = 'Suspicious inbox manipulation rules'; Premium = $true; Severity = 'Medium'
            About = "Microsoft Defender for Cloud Apps found suspicious rules that delete or move messages in the user's mailbox." }
        @{ Id = 'tokenIssuerAnomaly'; Name = 'Token issuer anomaly'; Premium = $true; Severity = 'High'
            About = 'A SAML token has unusual claims or claims that match known attacker patterns, which suggests the token issuer may be compromised.'
            Tips = "$investigate#anomalous-token-and-token-issuer-anomaly-detections" }
        @{ Id = 'unfamiliarFeatures'; Name = 'Unfamiliar sign-in properties'; Premium = $true; Severity = 'Medium'
            About = 'A sign-in had properties, such as IP address, ASN, location, device or browser, that are unfamiliar for the user.' }
        @{ Id = 'nationStateIP'; Name = 'Verified threat actor IP'; Premium = $true; Severity = 'High'
            About = 'The user signed in from an IP address that Microsoft threat intelligence ties to a nation-state actor or cybercrime group.' }
        @{ Id = 'anomalousUserActivity'; Name = 'Anomalous user activity'; Premium = $true; Severity = 'Medium'
            About = 'The user made directory changes that differ from their usual administrative behaviour.' }
        @{ Id = 'attackerinTheMiddle'; Name = 'Attacker in the middle'; Premium = $true; Severity = 'High'
            About = "The user's sign-in session went through a malicious reverse proxy, which can capture the password and the session token."
        }
        @{ Id = 'leakedCredentials'; Name = 'Leaked credentials'; Premium = $false; Severity = 'High'
            About = "The user's current, valid password was found in a known credential leak."
            Tips = "$investigate#leaked-credentials-detections" }
        @{ Id = 'attemptedPrtAccess'; Name = 'Possible attempt to access Primary Refresh Token (PRT)'; Premium = $true; Severity = 'High'
            About = "Microsoft Defender for Endpoint saw an attempt to read the user's Primary Refresh Token on a device." }
        @{ Id = 'suspiciousAPITraffic'; Name = 'Suspicious API traffic'; Premium = $true; Severity = 'Medium'
            About = 'The user made unusual Microsoft Graph calls or enumerated the directory, which can be reconnaissance by an attacker.' }
        @{ Id = 'suspiciousCredentialAddition'; Name = 'Suspicious credential addition'; Premium = $true; Severity = 'High'
            About = 'A new authentication method was registered on the account in suspicious circumstances. An attacker who registers a method keeps access after a password reset.' }
        @{ Id = 'suspiciousSendingPatterns'; Name = 'Suspicious sending patterns'; Premium = $true; Severity = 'Medium'
            About = 'Microsoft Defender for Office 365 saw the user send suspicious email, and the user is at risk of being, or has been, restricted from sending.' }
        @{ Id = 'userReportedSuspiciousActivity'; Name = 'User reported suspicious activity'; Premium = $true; Severity = 'Medium'
            About = 'The user denied an MFA prompt they did not start and reported it as suspicious, which means someone else may have their password.' }
    )

    $known = @{}
    foreach ($entry in $catalog) {
        $known[$entry.Id] = $true
        if (-not $entry.ContainsKey('Tips')) { $entry.Tips = $investigate }
        [pscustomobject]@{
            Id       = $entry.Id
            Title    = "Open '$($entry.Name)' risk detections should be reviewed in Entra ID Protection."
            Severity = $entry.Severity
            Data     = [pscustomobject]$entry
        }
    }

    # Detection types Microsoft has added since this list was written.
    try {
        $openTypes = @(Get-MtUserRiskDetection | ForEach-Object { [string]$_.riskEventType } | Where-Object { $_ } | Sort-Object -Unique)
    } catch {
        Write-Verbose "MT.1273: could not read open risk detections for undocumented types. $($_.Exception.Message)"
        $openTypes = @()
    }
    foreach ($type in $openTypes) {
        if ($known.ContainsKey($type) -or $type -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$') { continue }
        [pscustomobject]@{
            Id       = $type
            Title    = "Open '$type' risk detections should be reviewed in Entra ID Protection."
            Severity = 'Medium'
            Data     = [pscustomobject]@{
                Id       = $type
                Name     = $type
                Premium  = $false
                Severity = 'Medium'
                About    = 'Microsoft Graph returned this detection type, but it is not in the list Maester knows. Check the Microsoft documentation for what it means.'
                Tips     = $investigate
            }
        }
    }
}

function Test-MtEntraUserRiskDetection {
    <#
    .SYNOPSIS
    Checks that no Entra ID Protection user risk detection of a given type is left open.

    .DESCRIPTION
    Runs once per sign-in and user risk detection type (identityProtection/riskDetections). Fails when
    at least one detection of the type still has the risk state atRisk or confirmedCompromised, and
    lists those detections with the high-risk ones first. Detections that have been remediated,
    dismissed or confirmed safe pass. Rows for detection types that need Microsoft Entra ID P2 are
    skipped in tenants without it, because such tenants see those detections only as Additional risk
    detected. The check reads risk only and never changes it.

    .EXAMPLE
    Invoke-MtTest -Id MT.1273

    .LINK
    https://maester.dev/docs/tests/MT.1273

    .LINK
    https://learn.microsoft.com/entra/id-protection/concept-identity-protection-risks
    #>
    [MaesterTest(
        Id = 'MT.1273',
        Title = 'Open Entra ID Protection user risk detections should be reviewed.',
        Product = 'entra',
        Feature = 'identity-protection',
        Area = 'logging-and-detection',
        ResourceType = 'User',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1078.004', 'T1110.003', 'T1557', 'T1098.005', 'T1114.003'),
        Control = ('nist-800-53-r5:IR-4', 'nist-800-53-r5:AC-2(12)'),
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Permission = 'Graph:Scope:IdentityRiskEvent.Read.All',
        InstanceSource = 'Get-MtUserRiskDetectionInstance',
        Lifecycle = 'Preview',
        Author = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The detection type to check, supplied by the engine.
        $Instance
    )

    # Rows shown in the result table. A tenant can have thousands of detections of a noisy type.
    $MaxRows = 100

    $type = $Instance.Data
    $severity = $Instance.Severity
    $name = Get-MtSafeMarkdown ([string]$type.Name)
    $about = "**$name** ($([string]$type.Id)): $($type.About) [Investigation tips]($($type.Tips))"

    if ($type.Premium -and (Get-MtLicenseInformation -Product 'EntraID') -ne 'P2') {
        Add-MtTestResultDetail -Severity $severity -SkippedBecause NotLicensedEntraIDP2
        return $null
    }

    try {
        $detections = @(Get-MtUserRiskDetection)
    } catch {
        if ($_.Exception.Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -Severity $severity -SkippedBecause NotAuthorized
            return $null
        }
        throw
    }

    $open = @($detections | Where-Object { [string]$_.riskEventType -eq [string]$type.Id })
    Write-Verbose "MT.1273: $($open.Count) open '$($type.Id)' detection(s) out of $($detections.Count) open detection(s)."

    if ($open.Count -eq 0) {
        Add-MtTestResultDetail -Severity $severity -Result "Well done. No '$name' risk detections are open.`n`n$about"
        return $true
    }

    $levelOrder = @{ high = 0; medium = 1; low = 2 }
    $sorted = @(
        $open | Sort-Object -Property @(
            @{ Expression = { $order = $levelOrder[[string]$_.riskLevel]; if ($null -eq $order) { 3 } else { $order } } }
            @{ Expression = { $_.detectedDateTime -as [datetime] }; Descending = $true }
        )
    )

    $counts = foreach ($level in @('high', 'medium', 'low')) {
        $count = @($open | Where-Object { [string]$_.riskLevel -eq $level }).Count
        if ($count -gt 0) { "$count $level" }
    }
    $other = $open.Count - @($open | Where-Object { [string]$_.riskLevel -in @('high', 'medium', 'low') }).Count
    if ($other -gt 0) { $counts = @($counts) + "$other with no level shown" }

    $result = "Found $($open.Count) open '$name' risk detection(s): $(@($counts) -join ', ').`n`n$about"
    $result += "`n`n| User | User principal name | Risk level | Risk state | Detected (UTC) | Activity | IP address | Location |"
    $result += "`n| --- | --- | --- | --- | --- | --- | --- | --- |"
    foreach ($item in @($sorted | Select-Object -First $MaxRows)) {
        $displayName = [string]$item.userDisplayName
        if ([string]::IsNullOrWhiteSpace($displayName)) { $displayName = '(unnamed)' }
        $detected = if ($item.detectedDateTime) {
            ($item.detectedDateTime -as [datetime]).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')
        } else { 'Unknown' }
        $location = @($item.location.city, $item.location.countryOrRegion | Where-Object { $_ }) -join ', '
        $cells = @(
            $displayName
            [string]$item.userPrincipalName
            [string]$item.riskLevel
            [string]$item.riskState
            $detected
            [string]$item.activity
            [string]$item.ipAddress
            $location
        ) | ForEach-Object { Get-MtSafeMarkdown ([string]$_) }
        $result += "`n| $($cells -join ' | ') |"
    }
    if ($sorted.Count -gt $MaxRows) {
        $result += "`n`nShowing the first $MaxRows of $($sorted.Count). See **ID Protection** > **Risk detections** in the Microsoft Entra admin center for the rest."
    }

    Add-MtTestResultDetail -Severity $severity -Result $result
    return $false
}
