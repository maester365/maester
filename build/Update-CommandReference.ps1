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

# Get all the filenames in the ./powershell/internal folder without the extension
$internalCommands = Get-ChildItem ./powershell/internal -Filter *.ps1 | ForEach-Object { $_.BaseName }

New-DocusaurusHelp -Module ./powershell/Maester.psm1 -DocsFolder ./website/docs -NoPlaceHolderExamples -EditUrl https://github.com/maester365/maester/blob/main/powershell/public/ -Exclude $internalCommands

# Update the markdown to include the synopsis as description so it can be displayed correctly in the doc links.
$cmdMarkdownFiles = Get-ChildItem ./website/docs/commands
foreach ($file in $cmdMarkdownFiles) {
    $content = Get-Content $file
    $synopsis = $content[($content.IndexOf("## SYNOPSIS") + 2)] # Get the synopsis
    if (![string]::IsNullOrWhiteSpace($synopsis)) {
        $updatedContent = $content.Replace("id:", "sidebar_class_name: hidden`ndescription: $($synopsis)`nid:")
        Set-Content $file $updatedContent
    }
}

Set-Content $commandsIndexFile $readmeContent  # Restore the readme content
