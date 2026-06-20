# Description: This script is used to generate the 'Command Reference' section of the Maester docusaurus site
# * This command needs to be run from the root of the project. e.g. ./build/Build-CommandReference.ps1
# * If running the docusaurus site locally you will need to stop and start Docusaurus to clear the 'Module not found' errors after running this command

if (-not (Get-Module Alt3.Docusaurus.Powershell -ListAvailable)) { Install-Module Alt3.Docusaurus.Powershell -Scope CurrentUser -Force -SkipPublisherCheck }
if (-not (Get-Module PlatyPS -ListAvailable)) { Install-Module PlatyPS -Scope CurrentUser -Force -SkipPublisherCheck }
if (-not (Get-Module Pester -ListAvailable)) { Install-Module Pester -Scope CurrentUser -Force -SkipPublisherCheck }

Import-Module Alt3.Docusaurus.Powershell
Import-Module PlatyPS
Import-Module Pester
Import-Module DnsClient

# Generate the command reference markdown
$commandsIndexFile = "./website/docs/commands/readme.md"
$readmeContent = Get-Content $commandsIndexFile  # Backup the readme.md since it will be deleted by New-DocusaurusHelp

# Exclude internal script filenames as well as any helper function names declared inside
# internal script files so multi-function files do not leak private helpers into docs.
$internalCommandFiles = Get-ChildItem @("./powershell/internal", "./powershell/internal/orca") -Filter *.ps1
$internalCommands = $internalCommandFiles | ForEach-Object { $_.BaseName }
$internalFunctionNames = foreach ($file in $internalCommandFiles) {
    foreach ($match in [regex]::Matches((Get-Content $file.FullName -Raw), '(?m)^\s*function\s+([A-Za-z0-9-]+)\s*\{')) {
        $match.Groups[1].Value
    }
}
$commandsToExclude = ($internalCommands + $internalFunctionNames) | Sort-Object -Unique

New-DocusaurusHelp -Module ./powershell/Maester.psm1 -DocsFolder ./website/docs -NoPlaceHolderExamples -EditUrl https://github.com/maester365/maester/blob/main/powershell/public/ -Exclude $commandsToExclude

# Update the markdown to include the synopsis as description so it can be displayed correctly in the doc links.
$cmdMarkdownFiles = Get-ChildItem ./website/docs/commands
foreach ($file in $cmdMarkdownFiles) {
    $content = Get-Content $file
    $synopsis = $content[($content.IndexOf("## SYNOPSIS") + 2)] # Get the synopsis
    if (![string]::IsNullOrWhiteSpace($synopsis)) {
        # Escape embedded double quotes and wrap value in double quotes so YAML front matter
        # remains valid even when the synopsis contains characters like ':' that have YAML meaning.
        $escapedSynopsis = $synopsis -replace '"', '\"'
        $updatedContent = $content.Replace("id:", "sidebar_class_name: hidden`ndescription: `"$escapedSynopsis`"`nid:")
        Set-Content $file $updatedContent
    }
}

Set-Content $commandsIndexFile $readmeContent  # Restore the readme content

# Sync generated command files to all versioned doc folders
$versionedDocsRoot = "./website/versioned_docs"
if (Test-Path $versionedDocsRoot) {
    $sourceCommands = "./website/docs/commands"
    $versionFolders = Get-ChildItem $versionedDocsRoot -Directory
    foreach ($versionFolder in $versionFolders) {
        $targetCommands = Join-Path $versionFolder.FullName "commands"
        if (Test-Path $targetCommands) {
            $sourceFiles = Get-ChildItem $sourceCommands -Filter *.mdx
            $sourceNames = $sourceFiles.Name

            Get-ChildItem $targetCommands -Filter *.mdx | Where-Object { $_.Name -notin $sourceNames } | Remove-Item -Force

            foreach ($sourceFile in $sourceFiles) {
                $targetFile = Join-Path $targetCommands $sourceFile.Name
                if (-not (Test-Path $targetFile)) {
                    Copy-Item $sourceFile.FullName $targetFile
                    Write-Verbose "Copied $($sourceFile.Name) to $($versionFolder.Name)"
                }
            }
        }
    }
}
