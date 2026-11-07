function Resolve-MtLearnPage {
    <#
    .SYNOPSIS
    Finds the mirror file of a Microsoft Learn URL, following the redirects that Update-MtLearnMirror.ps1 recorded.

    .DESCRIPTION
    Makes no network calls: it reads only the index that Read-MtLearnIndex returns. Returns an object with Url,
    Key, ResolvedKey (the page the URL ends up at), Mirror, Path (relative to the mirror's root), Detail and Status:

    - Mirrored     a mirror has the page under this URL
    - Redirected   Learn redirects the URL to a page a mirror has
    - NotInMirror  the page is in the scope of a mirror (its include pattern), but the mirror doesn't have it
    - NotMirrored  the page exists, but no mirror covers it (Microsoft Graph, PowerShell reference and so on)
    - Missing      Learn answers 404 for it
    - External     Learn redirects it to another site (Detail holds the URL)
    - Unresolved   neither the index nor the redirect answers know it: run Update-MtLearnMirror.ps1

    .PARAMETER Index
    The index from Read-MtLearnIndex.

    .PARAMETER Url
    The Learn URL.

    .EXAMPLE
    Resolve-MtLearnPage -Index $index -Url 'https://learn.microsoft.com/mem/intune/protect/device-compliance-get-started'
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Index,

        [Parameter(Mandatory)]
        [string] $Url
    )

    $key = ConvertTo-MtLearnKey $Url
    $result = [pscustomobject][ordered]@{
        Url         = $Url
        Key         = $key
        ResolvedKey = $null
        Status      = 'Unresolved'
        Mirror      = $null
        Path        = $null
        Detail      = $null
    }
    if ($null -eq $key) { $result.Detail = 'Not a Microsoft Learn URL.'; return $result }

    $usePage = {
        param($pageKey, $status)
        $page = $Index.Pages[$pageKey]
        $result.Status = if ($page['Target']) { 'Redirected' } else { $status }
        $result.ResolvedKey = if ($page['Target']) { $page['Target'] } else { $pageKey }
        $result.Mirror = $page['Mirror']
        $result.Path = $page['Path']
    }

    if ($Index.Pages.ContainsKey($key)) { & $usePage $key 'Mirrored'; return $result }
    if (-not $Index.Redirects.ContainsKey($key)) { return $result }

    $answer = $Index.Redirects[$key]
    switch ($answer['Status']) {
        'Missing' { $result.Status = 'Missing'; $result.Detail = 'Learn answers 404.' }
        'External' { $result.Status = 'External'; $result.Detail = $answer['To'] }
        default {
            $target = if ($answer['To']) { [string] $answer['To'] } else { $key }
            if ($answer['Status'] -eq 'Redirect' -and $Index.Pages.ContainsKey($target)) { & $usePage $target 'Redirected'; break }
            $result.ResolvedKey = $target
            $result.Status = 'NotMirrored'
            # The localized URL is what the mirrors' include patterns describe.
            $localized = 'https://learn.microsoft.com/' + 'en-us/' + $target
            foreach ($mirror in $Index.Mirrors.GetEnumerator()) {
                $include = $mirror.Value['Include']
                if (-not $include -or $localized -notmatch "(?i)$include") { continue }
                if (@($mirror.Value['Exclude']) | Where-Object { $_ -and $localized -match "(?i)$_" }) { continue }
                $result.Status = 'NotInMirror'
                $result.Mirror = $mirror.Key
                $result.Detail = "The page is in the scope of $($mirror.Key), but the mirror doesn't have it yet."
                break
            }
        }
    }
    $result
}
