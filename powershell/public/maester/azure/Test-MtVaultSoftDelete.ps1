<#
.SYNOPSIS
    Checks if all Recovery Services Vaults have Soft Delete enabled

.DESCRIPTION
    This test ensures that all Recovery Services Vaults have Soft Delete enabled
    by evaluating the `enhancedSecurityState` property. Soft Delete protects backup
    data from accidental or malicious deletion and is a recommended security control.

.EXAMPLE
    Test-MtVaultSoftDelete

    Returns true if all vaults have Soft Delete enabled.

.LINK
    https://maester.dev/docs/commands/Test-MtVaultSoftDelete
#>
function Test-MtVaultSoftDelete {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Azure)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedAzure
        return $null
    }

    $nonCompliantVaults = @()
    $resultsMarkdown = ""

    try {
        $subsResponse = Invoke-MtAzureRequest -RelativeUri "/subscriptions" -ApiVersion "2020-01-01"
        $subscriptions = $subsResponse.value
    }
    catch {
        Add-MtTestResultDetail -SkippedBecause "Failed to get subscriptions" -SkippedError $_
        return $null
    }

    foreach ($sub in $subscriptions) {
        $subId = $sub.subscriptionId

        try {
            Write-Verbose "Getting vaults from sub: $subId"
            $vaultsResponse = Invoke-MtAzureRequest `
                -RelativeUri "/subscriptions/$subId/providers/Microsoft.RecoveryServices/vaults" `
                -ApiVersion "2023-04-01"

            $vaults = $vaultsResponse.value
        }
        catch {
            $resultsMarkdown += "Failed to retrieve vaults for subscription $subId`n"
            continue
        }

        foreach ($vault in $vaults) {
            try {
                $vaultName = $vault.name
                $vaultRg = ($vault.id -split "/")[4]

                $vaultConfig = Invoke-MtAzureRequest `
                    -RelativeUri "/subscriptions/$subId/resourceGroups/$vaultRg/providers/Microsoft.RecoveryServices/vaults/$vaultName/backupconfig/vaultconfig" `
                    -ApiVersion "2025-02-01"

                $softDeleteState = $vaultConfig.properties.enhancedSecurityState

                if (-not $softDeleteState) {
                    $softDeleteState = "Unknown"
                }

                if ($softDeleteState -ne "Enabled") {
                    $nonCompliantVaults += "- $vaultName (subscription: $subId) has soft delete not enabled (state: $softDeleteState)"
                }
                else {
                    $resultsMarkdown += "- $vaultName (subscription: $subId) soft delete is enabled.`n"
                }
            }
            catch {
                $resultsMarkdown += "- Failed to check vault $($vault.name) in subscription $subId`n"
                continue
            }
        }
    }

    $testResult = $nonCompliantVaults.Count -eq 0

    if ($testResult) {
        $testResultMarkdown = "All Recovery Services Vaults have soft delete enabled.`n`n$resultsMarkdown"
    }
    else {
        $testResultMarkdown = "Some vaults do not have soft delete enabled:`n`n"
        $testResultMarkdown += ($nonCompliantVaults -join "`n")
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
