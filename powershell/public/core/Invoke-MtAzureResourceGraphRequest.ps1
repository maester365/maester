<#
    .SYNOPSIS
    Invoke a query request to the Azure Resource Graph.

    .DESCRIPTION
    This function allows you to query resources across Azure subscriptions using Azure Resource Graph.
    It provides a simplified interface for resource discovery and exploration.

    .EXAMPLE
    Invoke-MtAzureResourceGraphRequest -Query "Resources | where type =~ 'Microsoft.Compute/virtualMachines'"

    Lists all Azure virtual machines

    .EXAMPLE
    Invoke-MtAzureResourceGraphRequest -Query "ResourceContainers | where type=='microsoft.resources/subscriptions'"

    Lists all Azure subscriptions

    .LINK
    https://maester.dev/docs/commands/Invoke-MtAzureResourceGraphRequest
#>

function Invoke-MtAzureResourceGraphRequest {
    [CmdletBinding()]
    param(
        # The Resource Graph query to execute using KQL (Kusto Query Language)
        [Parameter(Mandatory = $true)]
        [string] $Query,

        # The API version to use for the Azure Resource Graph REST API
        [Parameter(Mandatory = $false)]
        [string] $ApiVersion = '2021-03-01'
    )

    # Get the Azure Resource Manager URL from the current Azure context to ensure connecting to the correct Azure environment (Public, Government, etc.)
    $resourceUrl = (Get-AzContext).Environment.ResourceManagerUrl

    # Build the complete URL for the Azure Resource Graph API endpoint
    $resourceGraphUrl = "$($resourceUrl)providers/Microsoft.ResourceGraph/resources?api-version=$($ApiVersion)"

    Write-Verbose "Resource Graph URL: $resourceGraphUrl"
    Write-Verbose "Retrieving all results with pagination"

    $allResults = New-Object 'System.Collections.Generic.List[psobject]'

    # Initialize pagination variables
    $currentSkip = 0                    # How many records to skip (for pagination)
    $pageSize = 1000                    # Maximum page size for Azure Resource Graph
    $skipToken = $null                  # Token for proper pagination (Azure-specific)

    # Start pagination loop - continues until all data is retrieved
    do {
        $requestOptions = @{
            '$skip' = $currentSkip          # Skip this many records (for subsequent pages)
            '$top' = $pageSize              # Return this many records per page
        }

        # Add skipToken if available (Azure's preferred pagination method)
        if ($skipToken) {
            $requestOptions['$skipToken'] = $skipToken
        }

        $body = @{
            query = $Query
            options = $requestOptions
        } | ConvertTo-Json -Depth 5

        Write-Verbose "Querying Azure Resource Graph (skip: $currentSkip, top: $pageSize)"

        $result = Invoke-AzRestMethod -Method POST -Uri $resourceGraphUrl -Payload $body

        # Check if the request was successful (HTTP status codes 200-299)
        if ($result.StatusCode -ge 200 -and $result.StatusCode -lt 300) {
            $response = $result.Content | ConvertFrom-Json

            # Check if the response contains data and handle different response formats from Azure Resource Graph
            if ($response.data) {
                if ($response.data -is [array]) {
                    # Multiple results: cast to PSObject array and add all items efficiently
                    $allResults.AddRange([PSObject[]]$response.data)
                } else {
                    # Single result: add the single object to our list
                    $allResults.Add($response.data)
                }
            } else {
                Write-Verbose "No data found in response"
            }

            # Prepare for next iteration of pagination
            $currentSkip += $pageSize

            # Check if there are more results to fetch
            $skipToken = $response.'$skipToken'
            $hasMoreResults = $null -ne $skipToken
        } else {
            Write-Error "Error querying Azure Resource Graph. Status code: $($result.StatusCode). Content: $($result.Content)"
            return $null
        }
    } while ($hasMoreResults)  # Continue looping while there are more results to fetch

    Write-Verbose "Total results retrieved: $($allResults.Count)"

    # Convert the Generic List to a PowerShell array and return it
    return $allResults.ToArray()
}