# Description: This script is used to generate the 'Command Reference' section of the Maester docusaurus site
# * This command needs to be run from the root of the project. e.g. ./build/Build-CommandReference.ps1
# * The New-DocusaurusHelp command deletes and recreates the ./docs/docs/commands folder
# * The Copy-Item command copies the ./docs/docs-templates/commands-index.md file to ./docs/docs/commands/index.md
# * If running the docusaurus site locally you will need to stop and start Docusaurus to clear the 'Module not found' errors after running this command

if (-not (Get-Module Alt3.Docusaurus.Powershell -ListAvailable)) {
    Install-Module Alt3.Docusaurus.Powershell -Scope CurrentUser -Force -SkipPublisherCheck
    Install-Module PlatyPS -Scope CurrentUser -Force -SkipPublisherCheck
}
Import-Module Alt3.Docusaurus.Powershell
Import-Module PlatyPS
New-DocusaurusHelp -Module ./src/Maester.psm1 -DocsFolder ./docs/docs -NoPlaceHolderExamples -EditUrl https://github.com/maester365/maester/blob/main/src/public/
Copy-Item ./docs/docs-templates/commands-index.md ./docs/docs/commands/index.md