<#
.SYNOPSIS
    Get license information for a Microsoft 365 product

.DESCRIPTION
    This function retrieves the license information for a Microsoft 365 product from the current tenant.

.PARAMETER Product
    The Microsoft 365 product for which to retrieve the license information.

.EXAMPLE
    Get-MtLicenseInformation -Product EntraID
#>
function Get-MtLicenseInformation {
    [OutputType([string])]
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory)]
        [ValidateSet("EntraID")]
        $Product
    )

    Write-Verbose "Retrieving license information for $Product"
    switch ($Product) {
        "EntraID" {
            Write-Verbose "Retrieving license information for Entra ID"
            $AvailablePlans = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/organization" | Select-Object -ExpandProperty value | Select-Object -ExpandProperty assignedPlans | Where-Object service -EQ "AADPremiumService" | Select-Object -ExpandProperty servicePlanId
            if ( "eec0eb4f-6444-4f95-aba0-50c24d67f998" -in $AvailablePlans ) {
                $LicenseType = "P2"
            } elseif ( "41781fb2-bc02-4b7c-bd55-b576c07bb09d)" -in $AvailablePlans ) {
                $LicenseType = "P1"
            } else {
                $LicenseType = "Free"
            }
            Write-Information "The license type for Entra ID is $LicenseType"
            return $LicenseType
            Break
        }
        Default {}
    }
}