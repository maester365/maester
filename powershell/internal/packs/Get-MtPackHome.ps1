function Get-MtPackHome {
    <#
    .SYNOPSIS
    Returns the folders Maester keeps installed packs in (Maester Packs design, section 5.2).

    .DESCRIPTION
    Root is MAESTER_PACK_HOME when it is set, else ~/.maester/packs. Under it:

      Store      store/<digest>/   one read-only copy of each installed pack version, keyed by its digest
      Modules    modules/          PowerShell Gallery modules that packs declare in Uses.Modules, saved as
                                   <Name>/<Version>/ so the folder can be put on PSModulePath
      Seen       seen.json         when this computer first saw each pack content (the release cooldown)
      Blocklist  blocklist.json    the last signed blocklist fetched, and the highest serial seen
      UserConfig ~/.maester/maester-config.json, the user scope config (section 5.2)

    Nothing is created here; callers create the folders they write to.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $root = if ($env:MAESTER_PACK_HOME) { $env:MAESTER_PACK_HOME } else { Join-Path ([Environment]::GetFolderPath('UserProfile')) '.maester/packs' }
    $root = [System.IO.Path]::GetFullPath($root)
    $userFolder = Split-Path -Path $root -Parent
    [pscustomobject]@{
        Root       = $root
        Store      = Join-Path $root 'store'
        Modules    = Join-Path $root 'modules'
        Seen       = Join-Path $root 'seen.json'
        Blocklist  = Join-Path $root 'blocklist.json'
        UserConfig = Join-Path $userFolder 'maester-config.json'
    }
}
