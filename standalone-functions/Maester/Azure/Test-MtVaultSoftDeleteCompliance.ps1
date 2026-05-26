function Test-MtVaultSoftDeleteCompliance {
    <#
    .SYNOPSIS
    Checks if all Recovery Services Vaults have Soft Delete enabled

    .DESCRIPTION
    This test ensures that all Recovery Services Vaults have Soft Delete enabled
    by evaluating the `enhancedSecurityState` property. Soft Delete protects backup
    data from accidental or malicious deletion and is a recommended security control.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtVaultSoftDeleteCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    try {
        $azContext = Get-AzContext
        if ($null -eq $azContext) {
            Write-Verbose "Not connected to Azure"
            return $null
        }
    } catch {
        Write-Verbose "Azure connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation

    $nonCompliantVaults = @()
    $resultsMarkdown = ""

    try {
        # Use Azure Resource Graph to get all Recovery Services Vaults across all subscriptions
        $query = "Resources | where type =~ 'Microsoft.RecoveryServices/vaults' | project id, name, resourceGroup, subscriptionId, location"
        $vaults = Invoke-MtAzureResourceGraphRequest -Query $query
    }
    catch {
        return $null
    }

    Write-Verbose "Found $($vaults.Count) Recovery Services Vaults to check"

    foreach ($vault in $vaults) {
        try {
            $vaultName = $vault.name
            $vaultRg = $vault.resourceGroup
            $subId = $vault.subscriptionId

            # Get the vault configuration to check soft delete status
            $vaultConfig = Invoke-MtAzureRequest `
                -RelativeUri "/subscriptions/$subId/resourceGroups/$vaultRg/providers/Microsoft.RecoveryServices/vaults/$vaultName/backupconfig/vaultconfig" `
                -ApiVersion "2025-02-01"

            $softDeleteState = $vaultConfig.properties.enhancedSecurityState

            if (-not $softDeleteState) {
                $softDeleteState = "Unknown"
            }

            if ($softDeleteState -ne "Enabled") {
                $nonCompliantVaults += "- $vaultName (subscription: $subId, resource group: $vaultRg) has soft delete not enabled (state: $softDeleteState)"
            }
            else {
                $resultsMarkdown += "- $vaultName (subscription: $subId, resource group: $vaultRg) soft delete is enabled.`n"
            }
        }
        catch {
            $resultsMarkdown += "- Failed to check vault $($vault.name) in subscription $($vault.subscriptionId): $($_.Exception.Message)`n"
            continue
        }
    }

    if (!$vaults) {
        $testResult = $true
    }
    else {
        $testResult = $nonCompliantVaults.Count -eq 0
    }

    return $testResult

}
