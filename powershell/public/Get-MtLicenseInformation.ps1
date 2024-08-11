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
        [ValidateSet('EntraID', 'EntraWorkloadID', 'ExoDlp')]
        [string] $Product
    )

    process {
        switch ($Product) {
            "EntraID" {
                Write-Verbose "Retrieving license information for Entra ID"
                $skus = Invoke-MtGraphRequest -RelativeUri "subscribedSkus" | Select-Object -ExpandProperty servicePlans | Select-Object -ExpandProperty servicePlanId
                if ( "eec0eb4f-6444-4f95-aba0-50c24d67f998" -in $skus ) {
                    $LicenseType = "P2"
                } elseif ( "e866a266-3cff-43a3-acca-0c90a7e00c8b" -in $skus ) {
                    $LicenseType = "Governance"
                } elseif ( "41781fb2-bc02-4b7c-bd55-b576c07bb09d" -in $skus ) {
                    $LicenseType = "P1"
                } else {
                    $LicenseType = "Free"
                }
                Write-Information "The license type for Entra ID is $LicenseType"
                return $LicenseType
                Break
            }
            "EntraWorkloadID" {
                Write-Verbose "Retrieving license SKU"
                $skus = Invoke-MtGraphRequest -RelativeUri "subscribedSkus" | Select-Object -ExpandProperty servicePlans | Select-Object -ExpandProperty servicePlanId
                if ("84c289f0-efcb-486f-8581-07f44fc9efad" -in $skus) {
                    $LicenseType = "P1"
                } elseif ("7dc0e92d-bf15-401d-907e-0884efe7c760" -in $skus) {
                    $LicenseType = "P2"
                } else {
                    $LicenseType = $null
                }
                Write-Information "The license type for Entra ID is $LicenseType"
                return $LicenseType
                Break
            }
            "ExoDlp" {
                Write-Verbose "Retrieving license SKU for ExoDlp"
                $skus = Invoke-MtGraphRequest -RelativeUri "subscribedSkus"
                $requiredSkus = @(
                    #skuId
                    "cbdc14ab-d96c-4c30-b9f4-6ada7cdc1d46", #Microsoft 365 Business Premium
                    "a3f586b6-8cce-4d9b-99d6-55238397f77a", #Microsoft 365 Business Premium EEA (no Teams)
                    #servicePlanId
                    "efb87545-963c-4e0d-99df-69c6916d9eb0" #Exchange Online (Plan 2)
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
                Write-Verbose "Retrieving license SKU for ExoDlp"
                #TODO, Refactor to store in module variable
                $skus = Invoke-MtGraphRequest -RelativeUri "subscribedSkus"
                $requiredSkus = @(
                    #servicePlanId
                    "8e0c0a52-6a6c-4d40-8370-dd62790dcd70" #Microsoft Defender for Office 365 (Plan 2)
                )
                $LicenseType = $null
                #TODO, Refactor to test function
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

            Default {}
        }
    }
}