function Get-MtConditionalAccessPolicy {
    <#
    .Synopsis
    Returns all the Conditional Access policies in the tenant.

    .Description
    Returns all the Conditional Access policies in the tenant.

    .Example
    Get-MtConditionalAccessPolicy

    .LINK
    https://maester.dev/docs/commands/Get-MtConditionalAccessPolicy
    #>
  [CmdletBinding()]
  param(
    # Specify if this request should skip cache and go directly to Graph.
    [Parameter(Mandatory = $false)]
    [Switch]$DisableCache
  )

  Write-Verbose -Message "Getting Conditional Access policies."

  # riskRemediation and other newer grant controls are only returned with this header.
  return Invoke-MtGraphRequest -RelativeUri 'identity/conditionalAccess/policies' -ApiVersion beta -IncludeUnknownEnumMembers -DisableCache:$DisableCache

}
