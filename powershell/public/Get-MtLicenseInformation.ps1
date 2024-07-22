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
        [ValidateSet('EntraID', 'EntraWorkloadID')]
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

            Default {}
        }
    }
}