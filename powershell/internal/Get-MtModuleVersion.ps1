function Get-MtModuleVersion {
    <#
    .SYNOPSIS
    Return the module version.
    #>
    [CmdletBinding()]
    [OutputType([string], [version])]
    param()

    $PSD1Version = $MyInvocation.MyCommand.Module.Version
    # In dev, we'll call it vNext, if the static value in the .PSD1 is changed, update here as well.
    if ('0.1.0' -eq $PSD1Version) {
        return 'Next'
    } else {
        return $PSD1Version
    }
}
