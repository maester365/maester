<#
.SYNOPSIS
  Execute KQL query in Microsoft 365 Defender Advanced Hunting by using Graph API Security endpoint to get results programmatically.

.DESCRIPTION
  This cmdlet allows you to execute KQL queries against the Microsoft 365 Defender Advanced Hunting API.
  It simplifies the process of querying and retrieving data from the Microsoft Defender XDR for integration of Maester checks.

.EXAMPLE
  Invoke-MtGraphSecurityQuery -Query "IdentityInfo | where isnotempty(PrivilegedEntraPimRoles)" -Timespan "P14D"

  # Get identities with eligible Entra roles of the last 14 days

.LINK
    https://maester.dev/docs/commands/Invoke-MtGraphSecurityQuery
#>
function Invoke-MtGraphSecurityQuery {
    [CmdletBinding()]
    param(
        # Valid KQL query
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string] $Query,
        # Lookback/timespan for KQL query in ISO 8601 duration, e.g. P14D, PT6H, P2DT3H
        [Parameter(Mandatory = $false)]
        [ValidatePattern('^P(?=.+)(\d+Y)?(\d+M)?(\d+D)?(T(\d+H)?(\d+M)?(\d+S)?)?$')]
        [ValidateScript({
            try { [System.Xml.XmlConvert]::ToTimeSpan($_) | Out-Null; $true }
            catch { throw "Timespan must be ISO 8601 duration (e.g., P14D, PT6H, P2DT3H)." }
        })]
        [string] $Timespan = "P14D"
    )

    process {
        $Body = @{
            "Query" = $Query;
            "Timespan" = $Timespan;
        } | ConvertTo-Json

        $sleepDuration = 1
        $retry = $false
        $retryCount = 0
        $maxRetries = 3

        do {
            try {
                $retry = $false
                $QueryResponse = (Invoke-MtGraphRequest -ApiVersion "beta" -RelativeUri "security/runHuntingQuery" -Method POST -Body $Body -OutputType PSObject -ErrorVariable QueryError)
                $QueryResults = $QueryResponse.Results
            }
            catch {
                if ($_.Exception.Response.StatusCode.value__ -ne 429) {
                    $retry = $false
                    if ($QueryError[0].Message -match '{.*}$') {
                        $ErrorDetailsJson = ($QueryError[0].Message -split '\r?\n\r?\n', 2)[-1].Trim()   # grab content after the first empty line
                        $KqlQueryExecutionError = ($ErrorDetailsJson | ConvertFrom-Json).error.message
                        throw $KqlQueryExecutionError
                    }
                    throw $_
                    return
                } else {
                    $retry = $true
                    $retryCount++
                    Write-Verbose "API returned 429, retrying in $sleepDuration seconds (Attempt $retryCount of $maxRetries)"
                    Start-Sleep -Seconds $sleepDuration
                }
            }
        } until (-not $retry -or $retryCount -ge $maxRetries)

        if ( $QueryResults ) {
            # Convert JSON strings to objects
            $propertiesToConvert = ($QueryResponse.schema | Where-Object {$_.type -eq "Object"}).Name
            foreach ($item in $QueryResults) {
                foreach ($prop in $propertiesToConvert) {
                    if (![string]::IsNullOrWhiteSpace($item.$prop)) {
                        try {
                            $item.$prop = $item.$prop | ConvertFrom-Json -Depth 10
                        }
                        catch {
                            Write-Verbose "Failed to convert property $($item.$prop) on $($prop) for item with ID '$($item.Id)': $_"
                        }

                    }
                }
            }
        return $QueryResults
        }
    }
}