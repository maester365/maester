<#
    .SYNOPSIS
    Invoke a query request to the Azure Resource Graph.

    .DESCRIPTION
    This function allows you to query resources across Azure subscriptions using Azure Resource Graph.
    It provides a simplified interface for resource discovery and exploration.

    .EXAMPLE
    Invoke-MtAzureResourceGraphRequest -Query "Resources | where type =~ 'Microsoft.Compute/virtualMachines' | limit 10"

    .EXAMPLE
    Invoke-MtAzureResourceGraphRequest -Query "ResourceContainers | where type=='microsoft.resources/subscriptions' | limit 10"

    .LINK
    https://maester.dev/docs/commands/Invoke-MtAzureResourceGraphRequest
#>

function Invoke-MtAzureResourceGraphRequest {
    [CmdletBinding()]
    param(
        # The Resource Graph query to execute.
        [Parameter(Mandatory = $true)]
        [string] $Query,

        # Subscription IDs to query. If not specified, uses all accessible subscriptions.
        [Parameter(Mandatory = $false)]
        [string[]] $SubscriptionId,

        # The number of results to skip. Default is 0.
        [Parameter(Mandatory = $false)]
        [int] $Skip = 0,

        # The API version to use. Default is 2021-03-01.
        [Parameter(Mandatory = $false)]
        [string] $ApiVersion = '2021-03-01'
    )

    $resourceGraphUrl = "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=$ApiVersion"

    # If no subscription is specified, get all accessible subscriptions
    if (-not $SubscriptionId) {
        Write-Verbose "No subscription specified, retrieving all accessible subscriptions"
        $allSubscriptions = Get-AzSubscription
        if ($allSubscriptions) {
            $SubscriptionId = $allSubscriptions.Id
            Write-Verbose "Found $($SubscriptionId.Count) accessible subscriptions"
        } else {
            Write-Warning "No accessible subscriptions found"
            $SubscriptionId = (Get-AzContext).Subscription.Id
        }
    }

    # Always retrieve all results with pagination
    Write-Verbose "Retrieving all results with pagination"
    $allResults = @()
    $currentSkip = $Skip
    $pageSize = 1000  # Maximum page size for Azure Resource Graph
    $skipToken = $null
    
    do {
        $requestOptions = @{
            '$skip' = $currentSkip
            '$top' = $pageSize
        }
        
        # Add skipToken if available (for proper pagination)
        if ($skipToken) {
            $requestOptions['$skipToken'] = $skipToken
        }

        $body = @{
            query = $Query
            subscriptions = $SubscriptionId
            options = $requestOptions
        } | ConvertTo-Json -Depth 5

        Write-Verbose "Querying Azure Resource Graph (skip: $currentSkip, top: $pageSize)"
        $result = Invoke-AzRestMethod -Method POST -Uri $resourceGraphUrl -Payload $body

        if ($result.StatusCode -ge 200 -and $result.StatusCode -lt 300) {
            $response = $result.Content | ConvertFrom-Json
            
            if ($response.data) {
                # ObjectArray format or direct data
                if ($response.data -is [array]) {
                    $allResults += $response.data
                } else {
                    # Single object, wrap in array
                    $allResults += @($response.data)
                }
            } else {
                Write-Verbose "No data found in response"
            }
            
            $currentSkip += $pageSize
            Write-Verbose "Retrieved $($response.count) results. Total so far: $($allResults.Count)"
            
            # Check for more results using skipToken or resultTruncated
            #$hasMoreResults = $response.'$skipToken' -ne $null
            $hasMoreResults = $response.resultTruncated -eq $true
            $skipToken = $response.'$skipToken'
            
            # If no skipToken but results are truncated, continue with skip increment
            if ($hasMoreResults -and -not $skipToken) {
                Write-Verbose "Results truncated but no skipToken, continuing with skip increment"
            }
            
        } else {
            Write-Error "Error querying Azure Resource Graph. Status code: $($result.StatusCode)"
            Write-Error $result.Content
            return $null
        }
    } while ($hasMoreResults)
    
    Write-Verbose "Total results retrieved: $($allResults.Count)"
    return $allResults
}