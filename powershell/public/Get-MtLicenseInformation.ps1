<#
.SYNOPSIS
    Get license information for a Microsoft 365 product

.DESCRIPTION
    This function retrieves the license information for a Microsoft 365 product from the current tenant.

.PARAMETER Product
    The Microsoft 365 product for which to retrieve the license information.

.EXAMPLE
    Get-MtLicenseInformation -Product EntraID

.LINK
    https://maester.dev/docs/commands/Get-MtLicenseInformation
#>
function Get-MtLicenseInformation {
    [OutputType([string])]
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory)]
        [ValidateSet('EntraID', 'EntraWorkloadID', 'Eop', 'ExoDlp', 'Mdo', 'MdoV2','AdvAudit', 'ExoLicenseCount', 'DefenderXDR')]
        [string] $Product
    )

    process {
        switch ($Product) {
            "EntraID" {
                Write-Verbose "Retrieving license information for Entra ID"
                $skus = Invoke-MtGraphRequest -RelativeUri "subscribedSkus" | Where-Object {$_.capabilityStatus -eq 'Enabled'} | Select-Object -ExpandProperty servicePlans | Select-Object -ExpandProperty servicePlanId
                if ( "eec0eb4f-6444-4f95-aba0-50c24d67f998" -in $skus ) {
                    $LicenseType = "P2" # Microsoft Entra ID P2 / AAD_PREMIUM_P2
                } elseif ( "e866a266-3cff-43a3-acca-0c90a7e00c8b" -in $skus ) {
                    $LicenseType = "Governance" # Microsoft Entra ID Governance / Entra_Identity_Governance
                } elseif ( "41781fb2-bc02-4b7c-bd55-b576c07bb09d" -in $skus ) {
                    $LicenseType = "P1" # Microsoft Entra ID P1 / AAD_PREMIUM
                } else {
                    $LicenseType = "Free"
                }
                Write-Information "The license type for Entra ID is $LicenseType"
                return $LicenseType
                Break
            }
            "EntraWorkloadID" {
                Write-Verbose "Retrieving license SKU"
                $skus = Invoke-MtGraphRequest -RelativeUri "subscribedSkus" | Where-Object {$_.capabilityStatus -eq 'Enabled'} | Select-Object -ExpandProperty servicePlans | Select-Object -ExpandProperty servicePlanId
                if ("84c289f0-efcb-486f-8581-07f44fc9efad" -in $skus) {
                    $LicenseType = "P1" # Microsoft Entra Workload ID P1 / AAD_WRKLDID_P1
                } elseif ("7dc0e92d-bf15-401d-907e-0884efe7c760" -in $skus) {
                    $LicenseType = "P2" # Microsoft Entra Workload ID P2 / AAD_WRKLDID_P2
                } else {
                    $LicenseType = $null
                }
                Write-Information "The license type for Entra ID is $LicenseType"
                return $LicenseType
                Break
            }
            "Eop" {
                Write-Verbose "Retrieving license SKU for Eop"
                $skus = Invoke-MtGraphRequest -RelativeUri "subscribedSkus" | Where-Object {$_.capabilityStatus -eq 'Enabled'}
                $requiredSkus = @(
                    #servicePlanId
                    "326e2b78-9d27-42c9-8509-46c827743a17" # Exchange Online Protection / EOP_ENTERPRISE
                )
                $LicenseType = $null
                foreach($sku in $requiredSkus){
                    $skuId = $sku -in $skus.skuId
                    $servicePlanId = $sku -in $skus.servicePlans.servicePlanId
                    if($skuId -or $servicePlanId){
                        $LicenseType = "Eop"
                    }
                }
                Write-Information "The license type for Exchange Online Protection is $LicenseType"
                return $LicenseType
                Break
            }
            "ExoDlp" {
                Write-Verbose "Retrieving license SKU for ExoDlp"
                $skus = Invoke-MtGraphRequest -RelativeUri "subscribedSkus" | Where-Object {$_.capabilityStatus -eq 'Enabled'}
                $requiredSkus = @(
                    #skuId
                    "cbdc14ab-d96c-4c30-b9f4-6ada7cdc1d46", # Microsoft 365 Business Premium > could be removed after add of 'Data Loss Prevention'
                    "a3f586b6-8cce-4d9b-99d6-55238397f77a", # Microsoft 365 Business Premium EEA (no Teams) > could be removed after add of 'Data Loss Prevention'
                    #servicePlanId
                    "efb87545-963c-4e0d-99df-69c6916d9eb0", # Exchange Online (Plan 2) / EXCHANGE_S_ENTERPRISE
                    "8c3069c0-ccdb-44be-ab77-986203a67df2", # Exchange Online (Plan 2) for Government / EXCHANGE_S_ENTERPRISE_GOV
                    "9bec7e34-c9fa-40b7-a9d1-bd6d1165c7ed"  # Data Loss Prevention
                )
                $LicenseType = $null
                foreach($sku in $requiredSkus){
                    $skuId = $sku -in $skus.skuId
                    $servicePlanId = $sku -in $skus.servicePlans.servicePlanId
                    if($skuId -or $servicePlanId){
                        $LicenseType = "ExoDlp"
                    }
                }
                Write-Information "The license type for Exchange Online DLP is $LicenseType"
                return $LicenseType
                Break
            }
            "Mdo" {
                Write-Verbose "Retrieving license SKU for Mdo"
                $skus = Invoke-MtGraphRequest -RelativeUri "subscribedSkus" | Where-Object {$_.capabilityStatus -eq 'Enabled'}
                $requiredSkus = @(
                    #servicePlanId
                    "8e0c0a52-6a6c-4d40-8370-dd62790dcd70", # Microsoft Defender for Office 365 (Plan 2) / THREAT_INTELLIGENCE
                    "900018f1-0cdb-4ecb-94d4-90281760fdc6"  # Microsoft Defender for Office 365 (Plan 2) for Government / THREAT_INTELLIGENCE_GOV
                )
                $LicenseType = $null
                foreach($sku in $requiredSkus){
                    $skuId = $sku -in $skus.skuId
                    $servicePlanId = $sku -in $skus.servicePlans.servicePlanId
                    if($skuId -or $servicePlanId){
                        $LicenseType = "Mdo"
                    }
                }
                Write-Information "The license type for Defender for Office is $LicenseType"
                return $LicenseType
                Break
            }
            "MdoV2" {
                Write-Verbose "Retrieving license SKU for MDO"
                $skus = Invoke-MtGraphRequest -RelativeUri "subscribedSkus" | Where-Object {$_.capabilityStatus -eq 'Enabled'} | Select-Object -ExpandProperty servicePlans | Select-Object -ExpandProperty servicePlanId
                if ("8e0c0a52-6a6c-4d40-8370-dd62790dcd70" -in $skus -or "900018f1-0cdb-4ecb-94d4-90281760fdc6" -in $skus) {
                    $LicenseType = "P2","P1","EOP" # Microsoft Defender for Office 365 (Plan 2) / THREAT_INTELLIGENCE
                                                   # Microsoft Defender for Office 365 (Plan 2) for Government / THREAT_INTELLIGENCE_GOV
                                                   # Includes P1 and EOP capabilities
                } elseif ("f20fedf3-f3c3-43c3-8267-2bfdd51c0939" -in $skus -or "493ff600-6a2b-4db6-ad37-a7d4eb214516" -in $skus) {
                    $LicenseType = "P1","EOP" # Microsoft Defender for Office 365 (Plan 1) / ATP_ENTERPRISE
                                              # Microsoft Defender for Office 365 (Plan 1) for Government / ATP_ENTERPRISE_GOV
                                              # Includes EOP capabilities
                } else {
                    $LicenseType = "EOP" # Exchange Online Protection / EOP_ENTERPRISE (326e2b78-9d27-42c9-8509-46c827743a17)
                }
                Write-Information "The license type for Defender for Office is $LicenseType"
                return $LicenseType
                Break
            }
            "AdvAudit" {
                Write-Verbose "Retrieving license SKU for AdvAudit"
                $skus = Invoke-MtGraphRequest -RelativeUri "subscribedSkus" | Where-Object {$_.capabilityStatus -eq 'Enabled'}
                $requiredSkus = @(
                    #servicePlanId
                    "2f442157-a11c-46b9-ae5b-6e39ff4e5849" # Microsoft 365 Advanced Auditing / M365_ADVANCED_AUDITING
                )
                $LicenseType = $null
                foreach($sku in $requiredSkus){
                    $skuId = $sku -in $skus.skuId
                    $servicePlanId = $sku -in $skus.servicePlans.servicePlanId
                    if($skuId -or $servicePlanId){
                        $LicenseType = "AdvAudit"
                    }
                }
                Write-Information "The license type for Advanced Audit is $LicenseType"
                return $LicenseType
                Break
            }
            "ExoLicenseCount" {
                Write-Verbose "Retrieving Exchange Online license count"
                $skus = Invoke-MtGraphRequest -RelativeUri "subscribedSkus" | Where-Object {$_.capabilityStatus -eq 'Enabled'}

                # Exchange Online service plan IDs that count towards the 5,000 license requirement
                $exchangeOnlineServicePlans = @(
                    "efb87545-963c-4e0d-99df-69c6916d9eb0", # Exchange Online (Plan 2) / EXCHANGE_S_ENTERPRISE
                    "9aaf7827-d63c-4b61-89c3-182f06f82e5c", # Exchange Online (Plan 1) / EXCHANGE_S_STANDARD
                    "8c3069c0-ccdb-44be-ab77-986203a67df2", # Exchange Online (Plan 2) for Government / EXCHANGE_S_ENTERPRISE_GOV
                    "e9b4930a-925f-45e2-ac2a-3f7788ca6fdd", # Exchange Online (Plan 1) for Government / EXCHANGE_S_STANDARD_GOV
                    "4a82b400-a79f-41a4-b4e2-e94f5787b113", # Exchange Online Kiosk / EXCHANGE_S_DESKLESS
                    "1126bef5-da20-4f07-b45e-ad25d2581aa8", # Exchange Online Essentials / EXCHANGE_S_ESSENTIALS
                    "90b5e015-709a-4b8b-b08e-3200f994494c", # Exchange Online Archiving for Exchange Online / EXCHANGEARCHIVE_ADDON
                    "176a09a6-7ec5-4039-ac02-b2791c6ba793"  # Exchange Online Kiosk (legacy) / EXCHANGE_S_DESKLESS
                )

                $totalLicenses = 0

                foreach ($sku in $skus) {
                    foreach ($servicePlan in $sku.servicePlans) {
                        if ($servicePlan.servicePlanId -in $exchangeOnlineServicePlans) {
                            # Only count enabled (non-trial) licenses
                            $enabledUnits = $sku.prepaidUnits.enabled
                            if ($enabledUnits -gt 0) {
                                $totalLicenses += $enabledUnits
                                Write-Verbose "Found $enabledUnits licenses for service plan: $($servicePlan.servicePlanName) in SKU: $($sku.skuPartNumber)"
                                break # Avoid double counting if multiple Exchange plans in same SKU
                            }
                        }
                    }
                }

                Write-Information "Total Exchange Online licenses: $totalLicenses"
                return $totalLicenses
                Break
            }
            "DefenderXDR" {
                Write-Verbose "Retrieving license SKU for Defender XDR"
                $subscribedSkus = Invoke-MtGraphRequest -RelativeUri "subscribedSkus" | Where-Object {$_.capabilityStatus -eq 'Enabled'}
                $uniqueServicePlans = $subscribedSkus.servicePlans.servicePlanId | Sort-Object -Unique
                $requiredServicePlans = @(
                    # https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference
                    "871d91ec-ec1a-452b-a83f-bd76c7d770ef", # Microsoft Defender for Endpoint Plan 2
                    "8e0c0a52-6a6c-4d40-8370-dd62790dcd70", # Microsoft Defender for Office 365 (Plan 2)
                    "14ab5db5-e6c4-4b20-b4bc-13e36fd2227f", # Microsoft Defender for Identity
                    "2e2ddb96-6af9-4b1d-a3f0-d6ecfd22edb2" # Microsoft Defender for Cloud Apps
                )
                $LicenseType = $null
                foreach($servicePlans in $requiredServicePlans){
                    if($servicePlans -in $uniqueServicePlans){
                        $LicenseType = "DefenderXDR"
                    }
                }
                Write-Information "The tenant is licensed for Defender XDR"
                return $LicenseType
                Break
            }
            Default {}
        }
    }
}