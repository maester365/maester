function ConvertFrom-MtPermission {
    <#
    .SYNOPSIS
    Splits one [MaesterTest] Permission element into its alternatives.

    .DESCRIPTION
    A Permission element is one permission written <Service>:<Kind>:<Name>, or several joined with |, any one of
    which is enough (test attribute design, section 2.4). The service and the kind end at the first and the
    second colon; the name is the rest, so it may contain colons (GitHub's administration:read).

    Returns one object per alternative, in the order written: Service, Kind and Name, trimmed. An alternative that
    is not <Service>:<Kind>:<Name> is returned with Service and Kind $null and the text in Name.

    .EXAMPLE
    ConvertFrom-MtPermission 'Graph:Scope:Policy.Read.All | Graph:Role:Global Reader'
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)] [AllowEmptyString()] [string] $Value
    )
    foreach ($alternative in ($Value -split '\|')) {
        $text = $alternative.Trim()
        $parts = $text -split ':', 3
        if ($parts.Count -eq 3 -and $parts[0].Trim() -and $parts[1].Trim() -and $parts[2].Trim()) {
            [pscustomobject]@{ Service = $parts[0].Trim(); Kind = $parts[1].Trim(); Name = $parts[2].Trim() }
        } else {
            [pscustomobject]@{ Service = $null; Kind = $null; Name = $text }
        }
    }
}
