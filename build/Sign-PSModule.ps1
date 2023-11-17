param
(
    # Path to Module Manifest
    [Parameter(Mandatory = $false)]
    [string] $ModuleManifestPath = ".\release\*\*.*.*",
    # Specifies the certificate that will be used to sign the script or file.
    [Parameter(Mandatory = $false)]
    [object] $SigningCertificate = (Get-ChildItem Cert:\CurrentUser\My\E7413D745138A6DC584530AECE27CEFDDA9D9CD6 -CodeSigningCert),
    # Uses the specified time stamp server to add a time stamp to the signature.
    [Parameter(Mandatory = $false)]
    [string] $TimestampServer = 'http://timestamp.digicert.com',
    # Generate and sign catalog file
    [Parameter(Mandatory = $false)]
    [switch] $AddFileCatalog
)

## Initialize
Import-Module "$PSScriptRoot\CommonFunctions.psm1" -Force -WarningAction SilentlyContinue -ErrorAction Stop

[System.IO.FileInfo] $ModuleManifestFileInfo = Get-PathInfo $ModuleManifestPath -DefaultFilename "*.psd1" | Select-Object -Last 1

## Parse Signing Certificate
if ($SigningCertificate -is [System.Security.Cryptography.X509Certificates.X509Certificate2]) { }
elseif ($SigningCertificate -is [System.Security.Cryptography.X509Certificates.X509Certificate2Collection]) { $SigningCertificate = $SigningCertificate[-1] }
else { $SigningCertificate = Get-X509Certificate $SigningCertificate -EndEntityCertificateOnly }

## Read Module Manifest
$ModuleManifest = Import-PowerShellDataFile $ModuleManifestFileInfo.FullName

$FileList = $ModuleManifest['FileList'] -like "*.ps*1*"
for ($i = 0; $i -lt $FileList.Count; $i++) {
    $FileList[$i] = Join-Path $ModuleManifestFileInfo.DirectoryName $FileList[$i] -Resolve
}

#$FileList = Get-ChildItem $ModuleManifestFileInfo.DirectoryName -Filter "*.ps*1" -Recurse

## Sign PowerShell Files
Set-AuthenticodeSignature $FileList -Certificate $SigningCertificate -HashAlgorithm SHA256 -IncludeChain NotRoot -TimestampServer $TimestampServer

## Generate and Sign File Catalog
if ($AddFileCatalog) {
    $FileCatalogPath = Join-Path $ModuleManifestFileInfo.Directory ('{0}.cat' -f $ModuleManifestFileInfo.Name)
    $FileCatalogPath = New-FileCatalog $FileCatalogPath -Path $ModuleManifestFileInfo.Directory -CatalogVersion 2.0
    Set-AuthenticodeSignature $FileCatalog.FullName -Certificate $SigningCertificate -HashAlgorithm SHA256 -IncludeChain NotRoot -TimestampServer $TimestampServer
}
