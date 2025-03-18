<#
.SYNOPSIS
    Returns the module version from the psd1 fle.

#>
function Get-MtModuleVersion {
    param()

    $psd1Version = $ModuleInfo.ModuleVersion
    # In dev, we'll call it vNext, if the static value in .psd1 is changed, update here as well
    if ('0.1.0' -eq $psd1Version) {
        return 'Next'
    }
    else {
        return $psd1Version
    }
}