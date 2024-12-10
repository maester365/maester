function Write-Telemetry {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("InvokeMaester")]
        [string]
        $EventName
    )
    Write-Verbose "Sending telemetry event: $EventName"

    $tenantId = Get-MgContext | Select-Object -ExpandProperty TenantId
    if (-not $tenantId) {
        $tenantId = "unknown"
    }
    # Define the JSON data
    $jsonData = @{
        api_key = "phc_VxA235FsdurMGycf9DHjlUeZeIhLuC7r11Ptum0WjRK"
        distinct_id = $tenantId
        event = $EventName
    }

    # Convert the data to JSON format
    $jsonBody = $jsonData | ConvertTo-Json

    # Define the URL
    $url = "https://us.i.posthog.com/capture/"

    # Send the POST request
    try {
        Invoke-RestMethod -Uri $url -Method Post -ContentType "application/json" -Body $jsonBody | Out-Null
    }
    catch {
        Write-Verbose $_
    }

}