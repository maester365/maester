function Get-MtServicePrincipalRiskDetectionInstance {
    <#
    .SYNOPSIS
    Returns one MT.1274 instance per Entra ID Protection workload identity risk detection type.

    .DESCRIPTION
    Instance source of the MT.1274 family. Returns one instance for each workload identity risk
    detection type that Microsoft documents (MT.1274.<riskEventType>), so every type has a row in the
    report whether or not it has open detections. Any riskEventType that Graph returns for an open
    detection and that is not in the list gets a row of its own, so a detection Microsoft adds later is
    reported rather than dropped. If the open detections cannot be read here, only the documented
    types are returned and each row reports the error itself.

    Source: https://learn.microsoft.com/entra/id-protection/concept-workload-identity-risk
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $investigate = 'https://learn.microsoft.com/entra/id-protection/concept-workload-identity-risk#investigate-risky-workload-identities'

    # Name, severity of an open detection and a short summary of each documented detection type.
    $catalog = @(
        @{ Id = 'investigationsThreatIntelligence'; Name = 'Microsoft Entra threat intelligence'; Severity = 'High'
            About = "The service principal's activity matches attack patterns known to Microsoft threat intelligence." }
        @{ Id = 'suspiciousSignins'; Name = 'Suspicious sign-ins'; Severity = 'Medium'
            About = 'The service principal signed in with properties unusual for it, such as a new IP address, ASN, country, target resource, user agent or credential type.' }
        @{ Id = 'adminConfirmedServicePrincipalCompromised'; Name = 'Admin confirmed service principal compromised'; Severity = 'High'
            About = 'An administrator confirmed this service principal compromised. Its credentials still need to be replaced.' }
        @{ Id = 'leakedCredentials'; Name = 'Leaked credentials'; Severity = 'High'
            About = "A valid credential of the service principal was found in public code or a leak, so anyone who found it can sign in as the app." }
        @{ Id = 'maliciousApplication'; Name = 'Malicious application'; Severity = 'High'
            About = 'Microsoft disabled the application for violating its terms of service.' }
        @{ Id = 'suspiciousApplication'; Name = 'Suspicious application'; Severity = 'Medium'
            About = 'Microsoft found that the application might violate its terms of service but has not disabled it.' }
        @{ Id = 'anomalousServicePrincipalActivity'; Name = 'Anomalous service principal activity'; Severity = 'Medium'
            About = 'The service principal made directory changes that differ from its usual administrative behaviour.' }
        @{ Id = 'suspiciousAPITraffic'; Name = 'Suspicious API traffic'; Severity = 'Medium'
            About = 'The service principal made unusual Microsoft Graph calls or enumerated the directory, which can be reconnaissance or data exfiltration.' }
    )

    $known = @{}
    foreach ($entry in $catalog) {
        $known[$entry.Id] = $true
        $entry.Tips = $investigate
        [pscustomobject]@{
            Id       = $entry.Id
            Title    = "Open '$($entry.Name)' workload identity risk detections should be reviewed in Entra ID Protection."
            Severity = $entry.Severity
            Data     = [pscustomobject]$entry
        }
    }

    # Detection types Microsoft has added since this list was written.
    try {
        $openTypes = @(Get-MtServicePrincipalRiskDetection | ForEach-Object { [string]$_.riskEventType } | Where-Object { $_ } | Sort-Object -Unique)
    } catch {
        Write-Verbose "MT.1274: could not read open risk detections for undocumented types. $($_.Exception.Message)"
        $openTypes = @()
    }
    foreach ($type in $openTypes) {
        if ($known.ContainsKey($type) -or $type -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$') { continue }
        [pscustomobject]@{
            Id       = $type
            Title    = "Open '$type' workload identity risk detections should be reviewed in Entra ID Protection."
            Severity = 'Medium'
            Data     = [pscustomobject]@{
                Id       = $type
                Name     = $type
                Severity = 'Medium'
                About    = 'Microsoft Graph returned this detection type, but it is not in the list Maester knows. Check the Microsoft documentation for what it means.'
                Tips     = $investigate
            }
        }
    }
}

function Test-MtEntraServicePrincipalRiskDetection {
    <#
    .SYNOPSIS
    Checks that no Entra ID Protection workload identity risk detection of a given type is left open.

    .DESCRIPTION
    Runs once per workload identity risk detection type (identityProtection/servicePrincipalRiskDetections).
    Fails when at least one detection of the type still has the risk state atRisk or
    confirmedCompromised, and lists those detections with the high-risk ones first. Detections that have
    been remediated or dismissed pass. The check reads risk only and never changes it.

    .EXAMPLE
    Invoke-MtTest -Id MT.1274

    .LINK
    https://maester.dev/docs/tests/MT.1274

    .LINK
    https://learn.microsoft.com/entra/id-protection/concept-workload-identity-risk
    #>
    [MaesterTest(
        Id = 'MT.1274',
        Title = 'Open Entra ID Protection workload identity risk detections should be reviewed.',
        Product = 'entra',
        Feature = 'identity-protection',
        Area = 'applications',
        ResourceType = 'ServicePrincipal',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1078.004', 'T1098.001', 'T1552'),
        Control = ('nist-800-53-r5:IR-4', 'nist-800-53-r5:AC-2(12)'),
        Service = 'Graph',
        License = ('AAD_WRKLDID_P1', 'AAD_WRKLDID_P2'),
        Permission = 'Graph:Scope:IdentityRiskEvent.Read.All',
        InstanceSource = 'Get-MtServicePrincipalRiskDetectionInstance',
        Lifecycle = 'Preview',
        Author = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The detection type to check, supplied by the engine.
        $Instance
    )

    # Rows shown in the result table.
    $MaxRows = 100

    $type = $Instance.Data
    $severity = $Instance.Severity
    $name = Get-MtSafeMarkdown ([string]$type.Name)
    $about = "**$name** ($([string]$type.Id)): $($type.About) [Investigation guidance]($($type.Tips))"

    try {
        $detections = @(Get-MtServicePrincipalRiskDetection)
    } catch {
        if ($_.Exception.Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -Severity $severity -SkippedBecause NotAuthorized
            return $null
        }
        throw
    }

    $open = @($detections | Where-Object { [string]$_.riskEventType -eq [string]$type.Id })
    Write-Verbose "MT.1274: $($open.Count) open '$($type.Id)' detection(s) out of $($detections.Count) open detection(s)."

    if ($open.Count -eq 0) {
        Add-MtTestResultDetail -Severity $severity -Result "Well done. No '$name' workload identity risk detections are open.`n`n$about"
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

    $result = "Found $($open.Count) open '$name' workload identity risk detection(s): $(@($counts) -join ', ').`n`n$about"
    $result += "`n`n| Service principal | App ID | Risk level | Risk state | Detected (UTC) | IP address |"
    $result += "`n| --- | --- | --- | --- | --- | --- |"
    foreach ($item in @($sorted | Select-Object -First $MaxRows)) {
        $displayName = [string]$item.servicePrincipalDisplayName
        if ([string]::IsNullOrWhiteSpace($displayName)) { $displayName = '(unnamed)' }
        $detected = if ($item.detectedDateTime) {
            ($item.detectedDateTime -as [datetime]).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')
        } else { 'Unknown' }
        $cells = @(
            $displayName
            [string]$item.appId
            [string]$item.riskLevel
            [string]$item.riskState
            $detected
            [string]$item.ipAddress
        ) | ForEach-Object { Get-MtSafeMarkdown ([string]$_) }
        $result += "`n| $($cells -join ' | ') |"
    }
    if ($sorted.Count -gt $MaxRows) {
        $result += "`n`nShowing the first $MaxRows of $($sorted.Count). See **ID Protection** > **Risk detections** > **Workload identity detections** in the Microsoft Entra admin center for the rest."
    }

    Add-MtTestResultDetail -Severity $severity -Result $result
    return $false
}
