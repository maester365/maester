function Get-NextModuleVersion {
    <#
    .SYNOPSIS
        Works out the version of the next Maester release or preview.

    .DESCRIPTION
        A preview is a prerelease of the release it leads to: 3.1.0-preview01, 3.1.0-preview02, then 3.1.0.

        - The next release is <Major>.0.0 when Major is above the latest stable release, otherwise the latest
          stable release with its minor number raised by one.
        - A preview takes the next release's number and the label preview<NN>, where NN is one more than the
          highest preview of that release already published, with two digits because the PowerShell Gallery
          compares labels as text. The 3.0.0 previews after preview9 are rc01, rc02 and so on.

        So a preview never uses up a release number, and every preview sorts below its release.

    .EXAMPLE
        Get-NextModuleVersion -StableVersion 3.0.0 -PublishedVersion '3.1.0-preview01' -Major 3 -Preview

        Returns ModuleVersion 3.1.0, Prerelease preview02 and FullVersion 3.1.0-preview02.
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
        # The gallery compares prerelease labels as text, so the number has two digits (preview09 sorts below
        # preview10). The 3.0.0 previews were numbered preview1 to preview9 before this, and preview9 sorts
        # above every preview<NN>, so a release that has one of those goes on as rc01, rc02 and so on.
        $published = @($PublishedVersion | Where-Object { $_ -like "$target-*" } | ForEach-Object { $_.Substring($target.Length + 1) })
        $next = {
            param($prefix)
            $highest = 0
            foreach ($text in $published) {
                if ($text -match "^$prefix(?<n>\d+)$") { $highest = [Math]::Max($highest, [int]$Matches.n) }
            }
            '{0}{1:D2}' -f $prefix, ($highest + 1)
        }
        $label = & $next 'preview'
        if (@($published | Where-Object { [string]::CompareOrdinal($_, $label) -ge 0 }).Count) { $label = & $next 'rc' }
        if (@($published | Where-Object { [string]::CompareOrdinal($_, $label) -ge 0 }).Count) {
            throw "No preview label of $target sorts above the published ones ($($published -join ', '))."
        }
    }

    [pscustomobject]@{
        ModuleVersion = $target
        Prerelease    = $label
        FullVersion   = if ($label) { "$target-$label" } else { $target }
    }
}
