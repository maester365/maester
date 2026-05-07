function Get-MtGitHubErrorMessage {
    param([Parameter(Mandatory)] $ErrorRecord)
    if (-not [string]::IsNullOrEmpty($ErrorRecord.ErrorDetails.Message)) {
        return $ErrorRecord.ErrorDetails.Message
    }
    if (-not [string]::IsNullOrEmpty($ErrorRecord.Exception.Message)) {
        return $ErrorRecord.Exception.Message
    }
    return ($ErrorRecord | Out-String)
}
