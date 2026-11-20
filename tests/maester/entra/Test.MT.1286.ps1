function Test-MtEntraAgentSponsorManager {
    <#
    .SYNOPSIS
    Finds users who sponsor Agent ID objects and have no manager, or a disabled one.

    .DESCRIPTION
    When a sponsor leaves or changes roles, the Lifecycle Workflows task "Transfer agent identity
    sponsorships to manager" adds the sponsor's manager as a sponsor and removes the user. The task
    requires a populated manager attribute: without one, the sponsorship has nowhere to go.

    This check reads the sponsors of agent identities, Agent Identity Blueprints and Blueprint
    Principals, and reports every user sponsor that has no manager or whose manager is a disabled
    account. Group and service principal sponsors have no manager and are not evaluated.

    A manager that is set but no longer the right successor still resolves, so the transfer goes
    through. Directory data cannot show that case.

    .EXAMPLE
    Test-MtEntraAgentSponsorManager

    .LINK
    https://maester.dev/docs/commands/Test-MtEntraAgentSponsorManager

    .LINK
    https://learn.microsoft.com/entra/id-governance/lifecycle-workflow-tasks#transfer-agent-identity-sponsorships-to-manager
    #>
    [MaesterTest(
        Id = 'MT.1286',
        Title = 'User sponsors of Agent ID objects should have a manager (Preview).',
        Product = 'entra',
        Feature = 'agent-identities',
        Area = 'ai',
        ResourceType = 'Agent',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'None',
        Control = 'nist-800-53-r5:AC-2',
        Service = 'Graph',
        Lifecycle = 'Preview',
        LongRunning,
        Author = 'julien-ly'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $ObjectKinds = @(
        @{
            Type     = 'Agent identity'
            List     = 'servicePrincipals/microsoft.graph.agentIdentity'
            Sponsors = 'servicePrincipals/{0}/microsoft.graph.agentIdentity/sponsors'
        }
        @{
            Type     = 'Agent blueprint principal'
            List     = 'servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal'
            Sponsors = 'servicePrincipals/{0}/microsoft.graph.agentIdentityBlueprintPrincipal/sponsors'
        }
        @{
            Type     = 'Agent blueprint'
            List     = 'applications/microsoft.graph.agentIdentityBlueprint'
            Sponsors = 'applications/{0}/microsoft.graph.agentIdentityBlueprint/sponsors'
        }
    )

    # A user often sponsors several objects: read each manager once.
    $ManagerBySponsorId = @{}
    $UserSponsorships = 0
    $Findings = [System.Collections.Generic.List[pscustomobject]]::new()

    try {
        foreach ($Kind in $ObjectKinds) {
            $Objects = @(
                Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri $Kind.List -Select @('id', 'displayName')
            )
            Write-Verbose "Reading the sponsors of $($Objects.Count) object(s) of type '$($Kind.Type)'."

            foreach ($Object in $Objects) {
                $ObjectId = [string]$Object.id
                if ([string]::IsNullOrWhiteSpace($ObjectId)) { continue }

                $Sponsors = @(
                    Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri ($Kind.Sponsors -f $ObjectId) `
                        -Select @('id', 'displayName', 'userPrincipalName', 'accountEnabled')
                )

                foreach ($Sponsor in $Sponsors) {
                    # Groups and service principals can be sponsors, but have no manager.
                    if ([string]$Sponsor.'@odata.type' -ne '#microsoft.graph.user') { continue }
                    $SponsorId = [string]$Sponsor.id
                    if ([string]::IsNullOrWhiteSpace($SponsorId)) { continue }
                    $UserSponsorships++

                    if (-not $ManagerBySponsorId.ContainsKey($SponsorId)) {
                        $Manager = $null
                        try {
                            $Manager = Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                                -RelativeUri "users/$SponsorId/manager" -Select @('id', 'displayName', 'accountEnabled')
                        } catch {
                            # For a user without a manager, Graph answers 404 Request_ResourceNotFound. Anything else is an error.
                            # The exception message only says "NotFound": read the status code, and the error body as a fallback.
                            $Status = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
                            if ($Status -ne 404 -and "$($_.ErrorDetails.Message)" -notmatch 'Request_ResourceNotFound') { throw }
                        }
                        $ManagerBySponsorId[$SponsorId] = $Manager
                    }
                    $Manager = $ManagerBySponsorId[$SponsorId]

                    $Issue = $null
                    if ($null -eq $Manager -or [string]::IsNullOrWhiteSpace([string]$Manager.id)) {
                        $Issue = 'No manager.'
                    } elseif ($Manager.accountEnabled -eq $false) {
                        $Issue = "Manager $([string]$Manager.displayName) is a disabled account."
                    }

                    if ($Issue) {
                        $Findings.Add([pscustomobject]@{
                                ObjectType = $Kind.Type
                                ObjectId   = $ObjectId
                                ObjectName = [string]$Object.displayName
                                Sponsor    = [string]$Sponsor.displayName
                                SponsorUpn = [string]$Sponsor.userPrincipalName
                                Issue      = $Issue
                            })
                    }
                }
            }
        }
    } catch {
        # Graph answers 403 when the signed-in account cannot read Agent ID objects, their sponsors or a manager.
        # Any other error goes to the engine, which reports it.
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 403) {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return $null
        }
        throw
    }

    if ($UserSponsorships -eq 0) {
        Add-MtTestResultDetail -SkippedBecause NotApplicable -Result 'No Agent ID object in this tenant has a user sponsor.'
        return $null
    }

    if ($Findings.Count -eq 0) {
        Add-MtTestResultDetail -Result (
            "Well done. All $UserSponsorships user sponsorship(s) of Agent ID objects belong to users with an enabled manager."
        )
        return $true
    }

    $Result = "Found $($Findings.Count) of $UserSponsorships user sponsorship(s) that cannot be transferred to an enabled manager. "
    $Result += 'When these sponsors leave or change roles, the Lifecycle Workflows task that transfers their sponsorships has no manager to transfer them to.'
    $Result += "`n`n| Object type | Object | Sponsor | Issue |"
    $Result += "`n| --- | --- | --- | --- |"
    foreach ($Item in $Findings) {
        $ObjectName = $Item.ObjectName
        if ([string]::IsNullOrWhiteSpace($ObjectName)) { $ObjectName = "(unnamed) $($Item.ObjectId)" }
        $SponsorText = $Item.Sponsor
        if (-not [string]::IsNullOrWhiteSpace($Item.SponsorUpn)) { $SponsorText = "$SponsorText ($($Item.SponsorUpn))" }
        $ObjectName = Get-MtSafeMarkdown -Text ([System.Net.WebUtility]::HtmlEncode($ObjectName))
        $SponsorText = Get-MtSafeMarkdown -Text ([System.Net.WebUtility]::HtmlEncode($SponsorText))
        $Issue = Get-MtSafeMarkdown -Text ([System.Net.WebUtility]::HtmlEncode($Item.Issue))
        $Result += "`n| $($Item.ObjectType) | $ObjectName | $SponsorText | $Issue |"
    }

    Add-MtTestResultDetail -Result $Result
    return $false
}
