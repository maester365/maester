function Test-MtEntraAgentBlueprintCredentialHygiene {
    <#
    .SYNOPSIS
    Audits Agent Identity Blueprints for expired, stale, or excessive client credentials.
    .DESCRIPTION
    Checks whether Agent Identity Blueprints have expired client secrets, credentials with
    excessively long validity periods (>730 days), more than two active client secrets, or an
    active client secret retained alongside a federated identity credential (FIC). Unmanaged
    blueprint credentials increase the blast radius and risk of credential reuse; a secret kept
    alongside a FIC is a live fallback that defeats the point of migrating to FIC.
    .EXAMPLE
    Test-MtEntraAgentBlueprintCredentialHygiene
    .LINK
    https://maester.dev/docs/commands/Test-MtEntraAgentBlueprintCredentialHygiene
    .LINK
    https://learn.microsoft.com/graph/api/agentidentityblueprint-list?view=graph-rest-1.0
    .LINK
    https://learn.microsoft.com/graph/api/application-list-federatedidentitycredentials?view=graph-rest-1.0
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Maximum allowed active client secrets per blueprint. Defaults to 2.
        [Parameter(Mandatory = $false)]
        [int]$MaxActiveSecrets = 2,
        # Maximum allowed validity period in days for credentials. Defaults to 730 days (2 years).
        [Parameter(Mandatory = $false)]
        [int]$MaxValidityDays = 730
    )

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        Write-Verbose 'Reading Agent Identity Blueprints with credential metadata.'
        $Blueprints = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'applications/microsoft.graph.agentIdentityBlueprint' `
                -Select @('id', 'displayName', 'appId', 'passwordCredentials', 'keyCredentials')
        )

        Write-Verbose "Found $($Blueprints.Count) Agent Identity Blueprints."

        if ($Blueprints.Count -eq 0) {
            Add-MtTestResultDetail -Result (
                'Well done. No Agent Identity Blueprints were found in the tenant.'
            )
            return $true
        }

        $CredentialFindings = [System.Collections.Generic.List[pscustomobject]]::new()
        $UtcNow = (Get-Date).ToUniversalTime()

        foreach ($Blueprint in $Blueprints) {
            $BlueprintId = [string]$Blueprint.id
            $DisplayName = [string]$Blueprint.displayName
            $AppId = [string]$Blueprint.appId

            $Passwords = @($Blueprint.passwordCredentials)
            $ActivePasswords = [System.Collections.Generic.List[object]]::new()

            foreach ($Password in $Passwords) {
                $KeyId = [string]$Password.keyId
                $EndDateTime = $null
                $StartDateTime = $null

                $parsedEnd = [datetime]::MinValue
                $parsedStart = [datetime]::MinValue
                if (![string]::IsNullOrWhiteSpace($Password.endDateTime) -and [datetime]::TryParse([string]$Password.endDateTime, [ref]$parsedEnd)) {
                    $EndDateTime = $parsedEnd.ToUniversalTime()
                }
                if (![string]::IsNullOrWhiteSpace($Password.startDateTime) -and [datetime]::TryParse([string]$Password.startDateTime, [ref]$parsedStart)) {
                    $StartDateTime = $parsedStart.ToUniversalTime()
                }

                # Check if expired
                if ($null -ne $EndDateTime -and $EndDateTime -lt $UtcNow) {
                    $DaysExpired = [int]($UtcNow.Subtract($EndDateTime).TotalDays)
                    $CredentialFindings.Add([pscustomobject]@{
                        BlueprintId = $BlueprintId
                        DisplayName = $DisplayName
                        AppId       = $AppId
                        KeyId       = $KeyId
                        Type        = 'Secret'
                        Issue       = "Expired secret ($DaysExpired days ago on $($EndDateTime.ToString('yyyy-MM-dd')))."
                    })
                } else {
                    $ActivePasswords.Add($Password)
                }

                # Check if lifespan exceeds max validity
                if ($null -ne $StartDateTime -and $null -ne $EndDateTime) {
                    $LifespanDays = [int]($EndDateTime.Subtract($StartDateTime).TotalDays)
                    if ($LifespanDays -gt $MaxValidityDays) {
                        $CredentialFindings.Add([pscustomobject]@{
                            BlueprintId = $BlueprintId
                            DisplayName = $DisplayName
                            AppId       = $AppId
                            KeyId       = $KeyId
                            Type        = 'Secret'
                            Issue       = "Excessive validity lifespan ($LifespanDays days exceeds limit of $MaxValidityDays days)."
                        })
                    }
                }
            }

            # Check excessive active secrets count
            if ($ActivePasswords.Count -gt $MaxActiveSecrets) {
                $CredentialFindings.Add([pscustomobject]@{
                    BlueprintId = $BlueprintId
                    DisplayName = $DisplayName
                    AppId       = $AppId
                    KeyId       = '(multiple)'
                    Type        = 'Secret'
                    Issue       = "Excessive active secrets ($($ActivePasswords.Count) active secrets exceeds limit of $MaxActiveSecrets)."
                })
            }

            # Check for a client secret retained alongside a federated identity credential (FIC) --
            # a live fallback that defeats the point of migrating to FIC.
            if ($ActivePasswords.Count -gt 0) {
                Write-Verbose "Reading federated identity credentials for Blueprint $BlueprintId."
                $FederatedCredentials = @(
                    Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                        -RelativeUri "applications/$BlueprintId/federatedIdentityCredentials" `
                        -Select @('id')
                )
                if ($FederatedCredentials.Count -gt 0) {
                    $CredentialFindings.Add([pscustomobject]@{
                        BlueprintId = $BlueprintId
                        DisplayName = $DisplayName
                        AppId       = $AppId
                        KeyId       = '(multiple)'
                        Type        = 'Secret + FIC'
                        Issue       = "Active client secret retained alongside $($FederatedCredentials.Count) federated identity credential(s) -- a live fallback that defeats the point of migrating to FIC. Remove the secret."
                    })
                }
            }
        }

        if ($CredentialFindings.Count -eq 0) {
            Add-MtTestResultDetail -Result (
                'Well done. All Agent Identity Blueprints have healthy credential configurations (no expired, excessive, or overly long-lived secrets).'
            )
            return $true
        }

        $Result = "Found $($CredentialFindings.Count) credential hygiene issue(s) across Agent Identity Blueprints."
        $Result += "`n`n| Blueprint object ID | Display name | App ID | Key ID | Type | Issue |"
        $Result += "`n| --- | --- | --- | --- | --- | --- |"
        foreach ($Item in $CredentialFindings) {
            $Name = [string]$Item.DisplayName
            if ([string]::IsNullOrWhiteSpace($Name)) { $Name = '(unnamed)' }
            $Name = [System.Net.WebUtility]::HtmlEncode($Name) -replace '\|', '&#124;'
            $Name = $Name -replace "`r?`n", ' '
            $Issue = [System.Net.WebUtility]::HtmlEncode([string]$Item.Issue) -replace '\|', '&#124;'
            $Result += "`n| ``$($Item.BlueprintId)`` | $Name | ``$($Item.AppId)`` | ``$($Item.KeyId)`` | $($Item.Type) | $Issue |"
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
