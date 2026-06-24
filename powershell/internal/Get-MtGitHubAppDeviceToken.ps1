function Get-MtGitHubAppDeviceToken {
    <#
    .SYNOPSIS
    Gets a GitHub App user access token using OAuth device flow.

    .DESCRIPTION
    Starts the GitHub App device flow for the Maester CLI GitHub App and polls until
    the user authorizes the app, denies the request, or the device code expires.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ClientId
    )

    $headers = @{
        Accept       = 'application/json'
        'User-Agent' = 'Maester-GitHubCis'
    }

    try {
        $deviceResponse = Invoke-WebRequest -Uri 'https://github.com/login/device/code' -Method POST -Headers $headers -Body @{ client_id = $ClientId } -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing -ErrorAction Stop
        $deviceData = $deviceResponse.Content | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Host "`nFailed to start GitHub device authentication: $($_.Exception.Message)" -ForegroundColor Red
        return [pscustomobject]@{ AccessToken = $null; FailureReason = 'GitHubDeviceFlowStartFailed' }
    }

    $requiredFields = @('device_code', 'user_code', 'verification_uri')
    foreach ($field in $requiredFields) {
        if ($deviceData.PSObject.Properties.Name -notcontains $field -or [string]::IsNullOrWhiteSpace([string]$deviceData.$field)) {
            Write-Host "`nGitHub device authentication returned an incomplete response." -ForegroundColor Red
            return [pscustomobject]@{ AccessToken = $null; FailureReason = 'GitHubDeviceFlowStartFailed' }
        }
    }

    $interval = 5
    if ($deviceData.PSObject.Properties.Name -contains 'interval' -and $deviceData.interval -as [int]) {
        $interval = [int]$deviceData.interval
    }

    $expiresIn = 900
    if ($deviceData.PSObject.Properties.Name -contains 'expires_in' -and $deviceData.expires_in -as [int]) {
        $expiresIn = [int]$deviceData.expires_in
    }

    Write-Host ''
    Write-Host 'GitHub authentication required for Maester.' -ForegroundColor Yellow
    $openedBrowser = Open-MtBrowserUrl -Uri $deviceData.verification_uri
    if ($openedBrowser) {
        Write-Host "Opened $($deviceData.verification_uri) in your browser. Enter code $($deviceData.user_code)" -ForegroundColor Yellow
    } else {
        Write-Host "Open $($deviceData.verification_uri) and enter code $($deviceData.user_code)" -ForegroundColor Yellow
    }
    Write-Host 'Waiting for GitHub authorization...' -ForegroundColor DarkGray

    $deadline = (Get-Date).ToUniversalTime().AddSeconds($expiresIn)
    while ((Get-Date).ToUniversalTime() -lt $deadline) {
        Start-Sleep -Seconds $interval

        try {
            $tokenResponse = Invoke-WebRequest -Uri 'https://github.com/login/oauth/access_token' -Method POST -Headers $headers -Body @{
                client_id   = $ClientId
                device_code = $deviceData.device_code
                grant_type  = 'urn:ietf:params:oauth:grant-type:device_code'
            } -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing -ErrorAction Stop
            $tokenData = $tokenResponse.Content | ConvertFrom-Json -ErrorAction Stop
        } catch {
            Write-Host "`nFailed to complete GitHub device authentication: $($_.Exception.Message)" -ForegroundColor Red
            return [pscustomobject]@{ AccessToken = $null; FailureReason = 'GitHubDeviceFlowFailed' }
        }

        if ($tokenData.PSObject.Properties.Name -contains 'access_token' -and -not [string]::IsNullOrWhiteSpace([string]$tokenData.access_token)) {
            $expiresAt = $null
            if ($tokenData.PSObject.Properties.Name -contains 'expires_in' -and $tokenData.expires_in -as [int]) {
                $expiresAt = (Get-Date).ToUniversalTime().AddSeconds([int]$tokenData.expires_in)
            }
            return [pscustomobject]@{
                AccessToken   = [string]$tokenData.access_token
                ExpiresAt     = $expiresAt
                FailureReason = $null
            }
        }

        $errorName = if ($tokenData.PSObject.Properties.Name -contains 'error') { [string]$tokenData.error } else { $null }
        switch ($errorName) {
            'authorization_pending' {
                continue
            }
            'slow_down' {
                if ($tokenData.PSObject.Properties.Name -contains 'interval' -and $tokenData.interval -as [int]) {
                    $interval = [int]$tokenData.interval
                } else {
                    $interval += 5
                }
                continue
            }
            { $_ -in @('expired_token', 'token_expired') } {
                Write-Host "`nGitHub device authentication expired. Run Connect-MtGitHub again to get a new code." -ForegroundColor Red
                return [pscustomobject]@{ AccessToken = $null; FailureReason = 'GitHubDeviceFlowExpired' }
            }
            'access_denied' {
                Write-Host "`nGitHub device authentication was denied." -ForegroundColor Red
                return [pscustomobject]@{ AccessToken = $null; FailureReason = 'GitHubDeviceFlowDenied' }
            }
            'device_flow_disabled' {
                Write-Host "`nGitHub device flow is not enabled for the Maester GitHub App." -ForegroundColor Red
                return [pscustomobject]@{ AccessToken = $null; FailureReason = 'GitHubDeviceFlowDisabled' }
            }
            default {
                $details = if ($errorName) { " GitHub returned '$errorName'." } else { '' }
                Write-Host "`nGitHub device authentication failed.$details" -ForegroundColor Red
                return [pscustomobject]@{ AccessToken = $null; FailureReason = 'GitHubDeviceFlowFailed' }
            }
        }
    }

    Write-Host "`nGitHub device authentication expired. Run Connect-MtGitHub again to get a new code." -ForegroundColor Red
    return [pscustomobject]@{ AccessToken = $null; FailureReason = 'GitHubDeviceFlowExpired' }
}
