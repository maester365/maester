function Get-CntSampleSetting {
    <#
    .SYNOPSIS
    Returns the sample service's settings from the connection state.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    $state = Get-MtConnectionState
    if ($state) { $state.Settings } else { $null }
}
