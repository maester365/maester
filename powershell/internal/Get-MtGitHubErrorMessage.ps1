function Get-MtGitHubErrorMessage {
    param([Parameter(Mandatory)] $ErrorRecord)
    if (-not [string]::IsNullOrEmpty($ErrorRecord.ErrorDetails.Message)) {
        try {
            $parsed = $ErrorRecord.ErrorDetails.Message | ConvertFrom-Json -ErrorAction Stop
            if ($parsed.PSObject.Properties.Name -contains 'message' -and
                -not [string]::IsNullOrEmpty($parsed.message)) {
                return $parsed.message
            }
        } catch {
            Write-Debug "Get-MtGitHubErrorMessage: ErrorDetails.Message is not JSON, returning raw string."
        }
        return $ErrorRecord.ErrorDetails.Message
    }
    if (-not [string]::IsNullOrEmpty($ErrorRecord.Exception.Message)) {
        return $ErrorRecord.Exception.Message
    }
    return ($ErrorRecord | Out-String)
}
