function Get-MtGitHubRateLimitMessage {
    <#
    .SYNOPSIS
    Internal: Returns a GitHub rate-limit diagnostic, or null for ordinary HTTP errors.
    .DESCRIPTION
    Retains the bootstrap diagnostic contract. Classification is shared with the transport guard;
    consumers should use structured GitHubRateLimit exception data rather than parse this text.
    #>
    param([Parameter(Mandatory)] $ErrorRecord)
    $limit = Get-MtGitHubRateLimit -ErrorRecord $ErrorRecord
    if ($limit) { $limit.Message }
}
