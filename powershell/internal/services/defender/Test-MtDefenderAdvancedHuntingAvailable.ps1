function Test-MtDefenderAdvancedHuntingAvailable {
    <#
    .SYNOPSIS
    Returns whether the Defender for Endpoint device tables answer advanced hunting on this tenant.

    .DESCRIPTION
    The Defender Vulnerability Management checks read DeviceTvm* tables through advanced hunting. On a
    tenant where those tables are not served, the query comes back as an execution error and the check
    ends in Error with the API's own text, which on some tenants is reduced to
    ". Fix semantic errors in your query." and does not even name the table. That reads as a defect in
    the check rather than as a tenant that cannot answer the question.

    A licence gate cannot tell the two apart. A tenant holding both Defender for Business (from Business
    Premium) and Defender for Endpoint Plan 2 (for instance from an E5 trial) keeps the Defender for
    Business experience until Support switches it, and advanced hunting belongs to Plan 2 only. Both
    DEFENDER_XDR and a gate on Plan 2 pass on such a tenant while the tables stay silent.

    So this probes instead of inferring. The query is a constant and minimal one over DeviceInfo, the
    table every Defender for Endpoint device reports into. It cannot fail because of anything a caller
    composed, which is what makes its failure attributable to the tenant rather than to the query.

    An empty result is availability, not absence: a table that resolves and returns no row has answered.
    The distinction matters, because a tenant with no onboarded device must still be skipped by the
    caller's own no-data path, with its own reason.

    The answer is a property of the tenant, not of the caller, so it is read once per run and kept in
    $__MtSession.DefenderHuntingTables. Three checks depend on it and advanced hunting is rate limited;
    asking the same question three times a run is a cost paid by every tenant, including the ones where
    nothing is wrong. Invoke-Maester clears it between runs.

    .OUTPUTS
    [bool] - True when the Defender for Endpoint tables answer, false when they do not.

    .EXAMPLE
    Test-MtDefenderAdvancedHuntingAvailable

    Returns $true on a tenant whose Defender for Endpoint tables are served by advanced hunting.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -ne $__MtSession.DefenderHuntingTables) {
        return [bool]$__MtSession.DefenderHuntingTables
    }

    try {
        $null = Invoke-MtGraphSecurityQuery -Query 'DeviceInfo | project DeviceId | take 1' -Timespan 'P1D'
        $__MtSession.DefenderHuntingTables = $true
        return $true
    } catch {
        # Deliberately broad. Invoke-MtGraphSecurityQuery surfaces the API's message, and that message is
        # not reliable enough to match on: the same unavailability reaches us as
        # "Failed to resolve table or column expression named ..." for some tables and as
        # ". Fix semantic errors in your query." for others. Matching the text would make the probe fail
        # open on the tenants it exists for. The query being a constant is what bounds this catch.
        Write-Verbose "Defender for Endpoint tables did not answer advanced hunting: $($_.Exception.Message)"
        $__MtSession.DefenderHuntingTables = $false
        return $false
    }
}
