<#
.SYNOPSIS
    Get license relationships for a Microsoft 365 product

.DESCRIPTION
    This function retrieves the license relationships for a Microsoft 365 product from Microsoft's documentation

.PARAMETER regexSearchString
    Provide a regex search string that will be used against the license display names and part names.

.PARAMETER servicePlanId
    Provide a GUID for a specific subscription. For bundle only SKUs that are not a la carte products use skuId.

.PARAMETER servicePlanName
    Provide a string for a specific subscription part name. Same as servicePlanName.

.PARAMETER skuPartNumber
    Provide a string for a specific subscription part name. Same as skuPartNumber. Matches Graph property, https://learn.microsoft.com/en-us/graph/api/resources/subscribedsku#properties

.PARAMETER skuId
    Provide a GUID for a specific subscription.

.EXAMPLE
    Get-MtLicenseRelationship -regexSearchString "^.*Entra.*$"

    Returns all subscriptions that match part names and display names with Entra.

.EXAMPLE
    Get-MtLicenseRelationship -servicePlanId 41781fb2-bc02-4b7c-bd55-b576c07bb09d

    Returns all subscriptions that include the Entra ID Plan 1 subscription. Use skuId for bundle subscriptions.

.EXAMPLE
    Get-MtLicenseRelationship -servicePlanName AAD_PREMIUM

    Returns all subscriptions that include the Entra ID Plan 1 subscription. Same as skuPartNumber.

.EXAMPLE
    Get-MtLicenseRelationship -skuId cf6b0d46-4093-4546-a0ab-0b1546dcc10e

    Returns all subscriptions that include the Entra Identity Governance subscription.

.EXAMPLE
    Get-MtLicenseRelationship -skuPartNumber Microsoft_Entra_ID_Governance

    Returns all subscriptions that include the Entra Identity Governance subscription. Matches Graph property, https://learn.microsoft.com/en-us/graph/api/resources/subscribedsku#properties

.LINK
    https://maester.dev/docs/commands/Get-MtLicenseRelationship
#>
function Get-MtLicenseRelationship {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ParameterSetName = "regex")]
        [regex]$regexSearchString,
        [Parameter(Mandatory, ParameterSetName = "id")]
        [guid]$servicePlanId,
        [Parameter(Mandatory, ParameterSetName = "name")]
        [string]$servicePlanName,
        [Parameter(Mandatory, ParameterSetName = "sku")]
        [guid]$skuId,
        [Parameter(Mandatory, ParameterSetName = "pn")]
        [string]$skuPartNumber
    )

    process {
        if(-not (Test-Path $env:TEMP\maesterLicenses.csv)){
            Update-MtLicenseCache
        }

        $plans = Import-Csv -Path $env:TEMP\maesterLicenses.csv

        $relationships = @()

        if($skuId){
            $relationships = $plans | Where-Object {`
                $_.GUID -eq $skuId
            }
        }elseif($servicePlanId){
            $relationships = $plans | Where-Object {`
                $_.Service_Plan_Id -eq $servicePlanId
            }
        }elseif($servicePlanName){
            $relationships = $plans | Where-Object {`
                $_.String_Id -eq $servicePlanName -or `
                $_.Service_Plan_Name -eq $servicePlanName
            }
        }elseif($skuPartNumber){
            $relationships = $plans | Where-Object {`
                $_.String_Id -eq $skuPartNumber -or `
                $_.Service_Plan_Name -eq $skuPartNumber
            }
        }elseif($regexSearchString){
            foreach($plan in $plans){
                $match = $regexSearchString.Match($plan.Product_Display_Name).Success -or `
                    $regexSearchString.Match($plan.String_Id).Success -or `
                    $regexSearchString.Match($plan.Service_Plan_Name).Success -or `
                    $regexSearchString.Match($plan.Service_Plans_Included_Friendly_Names).Success

                if($match){
                    $relationships += $plan
                }
            }
        }

        return $relationships
    }
}