function Test-MtEntraAgentSponsor {
    <#
    .SYNOPSIS
    Finds Agent Identity Blueprints and Blueprint Principals without assigned sponsors.
    .DESCRIPTION
    Checks that every Agent Identity Blueprint and Agent Identity Blueprint Principal has at least
    one assigned business sponsor. Sponsors provide organizational accountability and oversee the
    purpose and ongoing business justification for AI agents in the tenant.
    .EXAMPLE
    Test-MtEntraAgentSponsor
    .LINK
    https://maester.dev/docs/commands/Test-MtEntraAgentSponsor
    .LINK
    https://learn.microsoft.com/graph/api/agentidentityblueprint-list-sponsors?view=graph-rest-1.0
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        Write-Verbose 'Reading Agent Identity Blueprints and Blueprint Principals for sponsor checks.'
        $BlueprintPrincipals = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal' `
                -Select @('id', 'displayName', 'appId')
        )
        $Blueprints = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'applications/microsoft.graph.agentIdentityBlueprint' `
                -Select @('id', 'displayName', 'appId')
        )

        Write-Verbose (
            "Evaluating sponsors for $($BlueprintPrincipals.Count) Blueprint Principals and " +
            "$($Blueprints.Count) Blueprints."
        )

        $SponsorlessObjects = [System.Collections.Generic.List[pscustomobject]]::new()

        # Check Blueprint Principals
        foreach ($BlueprintPrincipal in $BlueprintPrincipals) {
            $PrincipalId = [string]$BlueprintPrincipal.id
            if ([string]::IsNullOrWhiteSpace($PrincipalId)) { continue }

            $Sponsors = @(
                Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                    -RelativeUri "servicePrincipals/$PrincipalId/microsoft.graph.agentIdentityBlueprintPrincipal/sponsors" `
                    -Select @('id', 'displayName', 'accountEnabled', 'userPrincipalName')
            )

            $ActiveSponsors = @($Sponsors | Where-Object { $null -eq $_.accountEnabled -or $_.accountEnabled -eq $true })
            if ($Sponsors.Count -eq 0) {
                $SponsorlessObjects.Add([pscustomobject]@{
                    ObjectId    = $PrincipalId
                    DisplayName = [string]$BlueprintPrincipal.displayName
                    ObjectType  = 'Blueprint Principal'
                    Reason      = 'No sponsors are assigned.'
                })
            } elseif ($ActiveSponsors.Count -eq 0) {
                $SponsorlessObjects.Add([pscustomobject]@{
                    ObjectId    = $PrincipalId
                    DisplayName = [string]$BlueprintPrincipal.displayName
                    ObjectType  = 'Blueprint Principal'
                    Reason      = 'All assigned sponsors are disabled accounts.'
                })
            }
        }

        # Check Blueprints
        foreach ($Blueprint in $Blueprints) {
            $BlueprintId = [string]$Blueprint.id
            if ([string]::IsNullOrWhiteSpace($BlueprintId)) { continue }

            $Sponsors = @(
                Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                    -RelativeUri "applications/$BlueprintId/microsoft.graph.agentIdentityBlueprint/sponsors" `
                    -Select @('id', 'displayName', 'accountEnabled', 'userPrincipalName')
            )

            $ActiveSponsors = @($Sponsors | Where-Object { $null -eq $_.accountEnabled -or $_.accountEnabled -eq $true })
            if ($Sponsors.Count -eq 0) {
                $SponsorlessObjects.Add([pscustomobject]@{
                    ObjectId    = $BlueprintId
                    DisplayName = [string]$Blueprint.displayName
                    ObjectType  = 'Agent Blueprint'
                    Reason      = 'No sponsors are assigned.'
                })
            } elseif ($ActiveSponsors.Count -eq 0) {
                $SponsorlessObjects.Add([pscustomobject]@{
                    ObjectId    = $BlueprintId
                    DisplayName = [string]$Blueprint.displayName
                    ObjectType  = 'Agent Blueprint'
                    Reason      = 'All assigned sponsors are disabled accounts.'
                })
            }
        }

        if ($SponsorlessObjects.Count -eq 0) {
            Add-MtTestResultDetail -Result (
                'Well done. All Agent Identity Blueprints and Blueprint Principals have assigned sponsors.'
            )
            return $true
        }

        $Result = "Found $($SponsorlessObjects.Count) Agent ID object(s) without assigned, active sponsors."
        $Result += "`n`n| Object ID | Display name | Object type | Reason |"
        $Result += "`n| --- | --- | --- | --- |"
        foreach ($Item in $SponsorlessObjects) {
            $DisplayName = [string]$Item.DisplayName
            if ([string]::IsNullOrWhiteSpace($DisplayName)) { $DisplayName = '(unnamed)' }
            $DisplayName = [System.Net.WebUtility]::HtmlEncode($DisplayName) -replace '\|', '&#124;'
            $DisplayName = $DisplayName -replace "`r?`n", ' '
            $Reason = [System.Net.WebUtility]::HtmlEncode([string]$Item.Reason) -replace '\|', '&#124;'
            $Result += "`n| $($Item.ObjectId) | $DisplayName | $($Item.ObjectType) | $Reason |"
        }

        Add-MtTestResultDetail -Result $Result -Severity 'Medium'
        return $false
    } catch {
        $ErrorRecord = $_
    }

    if ($ErrorRecord.Exception.Message -match '(?i)403|forbidden|authorization') {
        Add-MtTestResultDetail -SkippedBecause NotAuthorized
    } else {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $ErrorRecord
    }
    return $null
}
