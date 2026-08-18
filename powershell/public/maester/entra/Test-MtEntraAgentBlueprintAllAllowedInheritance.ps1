function Test-MtEntraAgentBlueprintAllAllowedInheritance {
    <#
    .SYNOPSIS
    Finds Agent Identity Blueprints with inheritable permissions set to allow all scopes or roles.
    .DESCRIPTION
    Checks whether any Agent Identity Blueprint's inheritable permissions configuration uses the
    allAllowed pattern for delegated scopes or application roles on a resource. allAllowed inherits
    every current AND future permission granted to the blueprint on that resource to every child
    Agent Identity, without additional consent. A single future grant on the blueprint becomes
    effective on every agent immediately, so this is the highest-impact escalation path in the
    Agent ID permission model.
    .EXAMPLE
    Test-MtEntraAgentBlueprintAllAllowedInheritance
    .LINK
    https://maester.dev/docs/commands/Test-MtEntraAgentBlueprintAllAllowedInheritance
    .LINK
    https://learn.microsoft.com/graph/api/agentidentityblueprint-list-inheritablepermissions?view=graph-rest-1.0
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        Write-Verbose 'Reading Agent Identity Blueprints.'
        $Blueprints = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'applications/microsoft.graph.agentIdentityBlueprint' `
                -Select @('id', 'displayName', 'appId')
        )

        Write-Verbose "Found $($Blueprints.Count) Agent Identity Blueprints."

        if ($Blueprints.Count -eq 0) {
            Add-MtTestResultDetail -Result (
                'Well done. No Agent Identity Blueprints were found in the tenant.'
            )
            return $true
        }

        $InheritanceFindings = [System.Collections.Generic.List[pscustomobject]]::new()

        foreach ($Blueprint in $Blueprints) {
            $BlueprintId = [string]$Blueprint.id
            $DisplayName = [string]$Blueprint.displayName
            $AppId = [string]$Blueprint.appId

            Write-Verbose "Reading inheritable permissions for Blueprint $BlueprintId."
            $InheritablePermissions = @(
                Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                    -RelativeUri "applications/$BlueprintId/microsoft.graph.agentIdentityBlueprint/inheritablePermissions"
            )

            foreach ($Entry in $InheritablePermissions) {
                $ResourceAppId = [string]$Entry.resourceAppId
                $ScopesKind = [string]$Entry.inheritableScopes.kind
                $RolesKind = [string]$Entry.inheritableRoles.kind

                if ($ScopesKind -eq 'allAllowed') {
                    $InheritanceFindings.Add([pscustomobject]@{
                        BlueprintId = $BlueprintId
                        DisplayName = $DisplayName
                        AppId       = $AppId
                        Resource    = $ResourceAppId
                        Kind        = 'Delegated scopes'
                        Issue       = 'Inheritable delegated scopes set to allAllowed: every current and future scope granted to this blueprint on this resource is inherited by every child Agent Identity.'
                    })
                }
                if ($RolesKind -eq 'allAllowed') {
                    $InheritanceFindings.Add([pscustomobject]@{
                        BlueprintId = $BlueprintId
                        DisplayName = $DisplayName
                        AppId       = $AppId
                        Resource    = $ResourceAppId
                        Kind        = 'Application roles'
                        Issue       = 'Inheritable application roles set to allAllowed: every current and future application role granted to this blueprint on this resource is inherited by every child Agent Identity.'
                    })
                }
            }
        }

        if ($InheritanceFindings.Count -eq 0) {
            Add-MtTestResultDetail -Result (
                'Well done. No Agent Identity Blueprint uses the allAllowed inheritance pattern for delegated scopes or application roles.'
            )
            return $true
        }

        $Result = "Found $($InheritanceFindings.Count) allAllowed inheritable permission configuration(s) across Agent Identity Blueprints."
        $Result += "`n`n| Blueprint object ID | Display name | App ID | Resource app ID | Permission kind | Issue |"
        $Result += "`n| --- | --- | --- | --- | --- | --- |"
        foreach ($Item in $InheritanceFindings) {
            $Name = [string]$Item.DisplayName
            if ([string]::IsNullOrWhiteSpace($Name)) { $Name = '(unnamed)' }
            $Name = [System.Net.WebUtility]::HtmlEncode($Name) -replace '\|', '&#124;'
            $Name = $Name -replace "`r?`n", ' '
            $Issue = [System.Net.WebUtility]::HtmlEncode([string]$Item.Issue) -replace '\|', '&#124;'
            $Result += "`n| ``$($Item.BlueprintId)`` | $Name | ``$($Item.AppId)`` | ``$($Item.Resource)`` | $($Item.Kind) | $Issue |"
        }

        Add-MtTestResultDetail -Result $Result -Severity 'High'
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
