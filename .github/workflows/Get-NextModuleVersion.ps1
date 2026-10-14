function Get-NextModuleVersion {
    <#
    .SYNOPSIS
        Works out the version of the next Maester release or preview.

    .DESCRIPTION
        A preview is a prerelease of the release it leads to: 3.0.0-preview1, 3.0.0-preview2, then 3.0.0.
        After 3.0.0 ships the previews are 3.1.0-preview1 and so on.

        - The next release is <Major>.0.0 when Major is above the latest stable release, otherwise the latest
          stable release with its minor number raised by one.
        - A preview takes the next release's number and the label preview<N>, where N is one more than the
          highest preview of that release already published.

        So a preview never uses up a release number, and every preview sorts below its release.

    .EXAMPLE
        Get-NextModuleVersion -StableVersion 2.3.0 -PublishedVersion '3.0.0-preview1' -Major 3 -Preview

        Returns ModuleVersion 3.0.0, Prerelease preview2 and FullVersion 3.0.0-preview2.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # The latest stable version on the PowerShell Gallery.
        [Parameter(Mandatory)] [version] $StableVersion,

        # Every version on the gallery, including prereleases. Only needed for a preview.
        [Parameter()] [AllowEmptyCollection()] [string[]] $PublishedVersion = @(),

        # The major version being worked on. Raise it to start a new major version.
        [Parameter(Mandatory)] [int] $Major,

        [Parameter()] [switch] $Preview
    )

    if ($Major -lt $StableVersion.Major) { throw "Major $Major is below the latest stable release $StableVersion." }
    $target = if ($Major -gt $StableVersion.Major) { '{0}.0.0' -f $Major } else { '{0}.{1}.0' -f $StableVersion.Major, ($StableVersion.Minor + 1) }

    $label = ''
    if ($Preview) {
        $highest = 0
        foreach ($version in $PublishedVersion) {
            if ($version -match "^$([regex]::Escape($target))-preview(?<n>\d+)$") { $highest = [Math]::Max($highest, [int]$Matches.n) }
        }
        $label = 'preview{0}' -f ($highest + 1)
    }

    [pscustomobject]@{
        ModuleVersion = $target
        Prerelease    = $label
        FullVersion   = if ($label) { "$target-$label" } else { $target }
    }
}
