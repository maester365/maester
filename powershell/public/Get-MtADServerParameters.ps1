function Get-MtADServerParameters {
    <#
    .SYNOPSIS
    Builds AD cmdlet server parameters for the active Maester AD target.

    .DESCRIPTION
    Returns a hashtable that includes -Server when Connect-Maester selected an
    Active Directory target server. Returns an empty hashtable when no explicit
    target server is set.

    .EXAMPLE
    $adServerParameters = Get-MtADServerParameters
    Get-ADDomain @adServerParameters
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $adServerParameters = @{}

    if ($__MtSession -and $null -ne $__MtSession.ADConnection -and
        -not [string]::IsNullOrWhiteSpace($__MtSession.ADConnection.TargetServer)) {
        $adServerParameters['Server'] = $__MtSession.ADConnection.TargetServer
    }

    return $adServerParameters
}
