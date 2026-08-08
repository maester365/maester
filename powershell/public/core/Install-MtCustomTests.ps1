function Install-MtCustomTests {
    <#
    .SYNOPSIS
    Installs custom Maester tests published in a GitHub repository's .maester folder.

    .DESCRIPTION
    Downloads a GitHub repository and copies the contents of its top-level .maester
    folder into Custom/<repo name>, so the tests run alongside the tests installed by
    Install-MaesterTests. This lets you pull in community-authored or internally shared
    Maester tests without manually copying files.

    The source repository must contain a top-level .maester folder - everything inside
    it is copied as-is into Custom/<repo name>. If that destination folder already
    exists, you are prompted to confirm before it is replaced with the latest content
    (skip that prompt with -Force).

    Maester cannot guarantee the security of tests published by third parties. Every run
    shows a confirmation prompt asking you to do your own due diligence before installing -
    this prompt is always shown, even when -Force is specified.

    If the .maester folder contains a maester-metadata.json file, it is used to show
    install-time information to you:
      - RequiredModules: an array of module names (or objects with Name and an optional
        MinimumVersion) the tests depend on. Any that are not installed, or are installed
        below MinimumVersion, are listed in a warning after install.
      - Message: free-form text (setup steps, links, configuration notes) displayed after
        install.
    Both fields are optional. A missing or unparsable maester-metadata.json does not
    fail the install.

    An example repository with custom Maester tests can be found at
    https://github.com/Mynster9361/Least_Privileged_MSGraph

    .PARAMETER Repository
    The source GitHub repository. Accepts the 'owner/repo' shorthand or a full
    https://github.com/owner/repo URL.

    .PARAMETER Path
    The path containing your installed Maester tests (the folder with the CISA, EIDSCA,
    Maester and Custom subfolders). Defaults to the current directory. Custom tests are
    installed to <Path>/Custom/<repo name>.

    .PARAMETER Branch
    The branch or tag to download. Defaults to the repository's default branch.

    .PARAMETER Force
    Skips the confirmation prompt when the destination folder already exists. Does not
    skip the security due-diligence confirmation, which is always shown.

    .EXAMPLE
    Install-MtCustomTests -Repository 'Mynster9361/Least_Privileged_MSGraph'

    Downloads the repository's .maester folder into .\Custom\Least_Privileged_MSGraph.

    .EXAMPLE
    Install-MtCustomTests -Repository 'https://github.com/Mynster9361/Least_Privileged_MSGraph' -Path .\maester-tests -Branch main

    Installs the custom tests from the main branch into .\maester-tests\Custom\Least_Privileged_MSGraph.

    .LINK
    https://maester.dev/docs/commands/Install-MtCustomTests
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This command installs multiple tests')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'TODO: Implement ShouldProcess')]
    [CmdletBinding()]
    param(
        # The source GitHub repository. Accepts the 'owner/repo' shorthand or a full https://github.com/owner/repo URL.
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Repository,

        # The path containing your installed Maester tests. Defaults to the current directory.
        [Parameter(Mandatory = $false)]
        [string] $Path = '.\',

        # The branch or tag to download. Defaults to the repository's default branch.
        [Parameter(Mandatory = $false)]
        [string] $Branch,

        # Skips the confirmation prompt when the destination folder already exists.
        [Parameter(Mandatory = $false)]
        [switch] $Force
    )

    $repoRef = Get-MtGitHubRepoFromString -Repository $Repository
    if ($null -eq $repoRef) {
        Write-Error "Unable to parse '$Repository' as a GitHub repository. Use the 'owner/repo' shorthand or a full https://github.com/owner/repo URL."
        return
    }

    # Always shown, even with -Force - custom tests run arbitrary Pester/PowerShell code
    # pulled from a third-party repository, so installing must always be an informed choice.
    $securityMessage = "`nMaester cannot guarantee the security of custom tests from third-party repositories.`nYou are about to install tests from '$($repoRef.Organization)/$($repoRef.Repository)'. Review the code and do your own due diligence before installing.`nDo you want to continue? (y/n): "
    if (!(Get-MtConfirmation $securityMessage)) {
        Write-Host 'Custom Maester tests not installed.' -ForegroundColor Red
        return
    }

    # Unauthenticated calls work for public repos. An optional token (same env vars honored
    # by Connect-MtGitHub) raises the GitHub API rate limit and allows access to private repos.
    $headers = @{
        'User-Agent' = 'Maester-CustomTests'
        'Accept'     = 'application/vnd.github+json'
    }
    $token = $null
    if (-not [string]::IsNullOrEmpty($env:MAESTER_GITHUB_TOKEN)) {
        $token = $env:MAESTER_GITHUB_TOKEN
    } elseif (-not [string]::IsNullOrEmpty($env:GH_TOKEN)) {
        $token = $env:GH_TOKEN
    }
    if ($token) { $headers['Authorization'] = "Bearer $token" }

    $ownerEncoded = [System.Uri]::EscapeDataString($repoRef.Organization)
    $repoEncoded = [System.Uri]::EscapeDataString($repoRef.Repository)

    Write-Verbose "Looking up repository $($repoRef.Organization)/$($repoRef.Repository) on GitHub."
    try {
        $repoResponse = Invoke-WebRequest -Uri "https://api.github.com/repos/$ownerEncoded/$repoEncoded" -Headers $headers -Method GET -UseBasicParsing -ErrorAction Stop
        $repoData = $repoResponse.Content | ConvertFrom-Json -ErrorAction Stop
    } catch {
        $rateLimitMessage = Get-MtGitHubRateLimitMessage -ErrorRecord $_
        if ($rateLimitMessage) {
            Write-Error "Unable to look up '$($repoRef.Organization)/$($repoRef.Repository)': $rateLimitMessage"
            return
        }
        $code = Get-MtGitHubErrorStatusCode -ErrorRecord $_
        if ($code -eq 404) {
            Write-Error "GitHub repository '$($repoRef.Organization)/$($repoRef.Repository)' was not found. If it's private, set the MAESTER_GITHUB_TOKEN or GH_TOKEN environment variable to a token with access to it."
            return
        }
        Write-Error "Unable to look up '$($repoRef.Organization)/$($repoRef.Repository)': $(Get-MtGitHubErrorMessage -ErrorRecord $_)"
        return
    }

    # Use the canonical owner/name and casing returned by GitHub, not the (possibly
    # differently-cased) values the user typed, so the destination folder name is stable.
    $repoOwner = $repoData.owner.login
    $repoName = $repoData.name
    $resolvedRef = if ([string]::IsNullOrWhiteSpace($Branch)) { $repoData.default_branch } else { $Branch }

    $tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "MaesterCustomTests-$([guid]::NewGuid())"
    $zipPath = Join-Path -Path $tempRoot -ChildPath 'repo.zip'
    $extractPath = Join-Path -Path $tempRoot -ChildPath 'extracted'
    New-Item -Path $tempRoot -ItemType Directory -Force | Out-Null

    try {
        $refEncoded = [System.Uri]::EscapeDataString($resolvedRef)
        $downloadUri = "https://github.com/$repoOwner/$repoName/archive/$refEncoded.zip"
        Write-Verbose "Downloading $downloadUri"
        try {
            Invoke-WebRequest -Uri $downloadUri -Headers $headers -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
        } catch {
            $rateLimitMessage = Get-MtGitHubRateLimitMessage -ErrorRecord $_
            if ($rateLimitMessage) {
                Write-Error "Unable to download '$repoOwner/$repoName': $rateLimitMessage"
                return
            }
            $code = Get-MtGitHubErrorStatusCode -ErrorRecord $_
            if ($code -eq 404) {
                Write-Error "Branch or tag '$resolvedRef' was not found in '$repoOwner/$repoName'."
                return
            }
            Write-Error "Unable to download '$repoOwner/$repoName': $(Get-MtGitHubErrorMessage -ErrorRecord $_)"
            return
        }

        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

        $extractedRepoFolder = Get-ChildItem -Path $extractPath -Directory | Select-Object -First 1
        if ($null -eq $extractedRepoFolder) {
            Write-Error "The downloaded archive for '$repoOwner/$repoName' did not contain any files."
            return
        }

        $maesterFolder = Get-ChildItem -Path $extractedRepoFolder.FullName -Directory -Force |
        Where-Object { $_.Name -ieq '.maester' } | Select-Object -First 1
        if ($null -eq $maesterFolder) {
            Write-Error "No '.maester' folder was found at the root of '$repoOwner/$repoName'. The repository must contain a top-level .maester folder with the custom Maester tests."
            return
        }

        $destination = Join-Path -Path (Join-Path -Path $Path -ChildPath 'Custom') -ChildPath $repoName

        if (Test-Path -Path $destination -PathType Container) {
            if (!$Force) {
                $message = "`nThe folder $destination already exists.`nInstalling will replace its contents with the latest tests from '$repoOwner/$repoName'.`nDo you want to continue? (y/n): "
                $continue = Get-MtConfirmation $message
                if (!$continue) {
                    Write-Host 'Custom Maester tests not installed.' -ForegroundColor Red
                    return
                }
            }
            Remove-Item -Path $destination -Recurse -Force
        }

        New-Item -Path $destination -ItemType Directory -Force | Out-Null
        Copy-Item -Path "$($maesterFolder.FullName)/*" -Destination $destination -Recurse -Force

        Write-Host "Custom Maester tests from '$repoOwner/$repoName' installed successfully to $destination!" -ForegroundColor Green

        $infoFile = Get-ChildItem -Path $destination -File -Force | Where-Object { $_.Name -ieq 'maester-metadata.json' } | Select-Object -First 1
        if ($infoFile) {
            $info = $null
            try {
                $info = Get-Content -Path $infoFile.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            } catch {
                Write-Warning "Unable to parse '$($infoFile.Name)' from '$repoOwner/$repoName': $($_.Exception.Message)"
            }

            if ($info) {
                if ($info.PSObject.Properties.Name -contains 'RequiredModules' -and $info.RequiredModules) {
                    $missingModules = Get-MtMissingRequiredModule -RequiredModules @($info.RequiredModules)
                    if ($missingModules.Count -gt 0) {
                        $missingList = ($missingModules | ForEach-Object { "  - $_" }) -join "`n"
                        Write-Warning "'$repoOwner/$repoName' requires PowerShell modules that are not installed (or are below the required version):`n$missingList`nInstall them with: Install-Module <name> -Scope CurrentUser"
                    }
                }

                if ($info.PSObject.Properties.Name -contains 'Message' -and -not [string]::IsNullOrWhiteSpace([string]$info.Message)) {
                    Write-Host "`nNotes from '$repoOwner/$repoName':" -ForegroundColor Cyan
                    Write-Host $info.Message
                }
            }
        }
    } finally {
        Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
