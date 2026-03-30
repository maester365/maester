<#
.SYNOPSIS
    Validates the Maester dev container environment.

.DESCRIPTION
    This script validates that all required components are installed and properly configured:
    - PowerShell version and required modules
    - Node.js and npm for website and report builds
    - Git for version control
    - Build directories and structure

.EXAMPLE
    ./.devcontainer/Initialize-DevContainer.ps1
#>

[CmdletBinding()]
param(
    [string]$ManifestPath = './powershell/*.psd1'
)

# Color helpers
function Write-Header {
    Write-Host ''
    Write-Host '=========================================' -ForegroundColor Cyan
    Write-Host $args[0] -ForegroundColor Cyan
    Write-Host '=========================================' -ForegroundColor Cyan
}

function Write-Success {
    Write-Host "✓ $($args[0])" -ForegroundColor Green
}

function Write-ErrorMessage {
    Write-Host "✗ $($args[0])" -ForegroundColor Red
}

function Write-Warning {
    Write-Host "⚠ $($args[0])" -ForegroundColor Yellow
}

Write-Header 'Maester Dev Container Initialization'

$allValid = $true

# Validate PowerShell
Write-Host ''
Write-Host 'PowerShell Environment:' -ForegroundColor Cyan
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -ge 7) {
    Write-Success "PowerShell $($psVersion.Major).$($psVersion.Minor).$($psVersion.Patch)"
} elseif ($psVersion.Major -ge 5 -and $psVersion.Minor -ge 1) {
    Write-Success "PowerShell $($psVersion.Major).$($psVersion.Minor)"
} else {
    Write-ErrorMessage "PowerShell $($psVersion.Major).$($psVersion.Minor) - Requires 5.1 or higher"
    $allValid = $false
}

# Validate PowerShell Modules
Write-Host ''
Write-Host 'PowerShell Modules:' -ForegroundColor Cyan

$requiredModules = @(
    @{ Name = 'Microsoft.Graph.Authentication'; MinVersion = '2.27.0' },
    @{ Name = 'Pester'; MinVersion = '5.5.0' },
    @{ Name = 'PSFramework'; MinVersion = '1.0' },
    @{ Name = 'PSModuleDevelopment'; MinVersion = '1.0' },
    @{ Name = 'PSScriptAnalyzer'; MinVersion = '1.0' }
)

foreach ($module in $requiredModules) {
    $installedModule = Get-InstalledModule -Name $module.Name -MinimumVersion $module.MinVersion -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1

    if ($installedModule) {
        Write-Success "$($module.Name) $($installedModule.Version)"
    } else {
        Write-ErrorMessage "$($module.Name) - Not found"
        $allValid = $false
    }
}

$manifestFiles = Get-ChildItem $ManifestPath
foreach ($file in $manifestFiles) {
    Write-Host "Validating dependencies for: $($file.Name)" -ForegroundColor Cyan

    try {
        $data = Import-PowerShellDataFile -Path $file.FullName
        $requiredModules = $data.RequiredModules

        foreach ($module in $requiredModules) {
            $name = if ($module -is [hashtable]) { $module.ModuleName } else { $module }

            Write-Host "Checking for $name..." -NoNewline
            if (Get-Module -ListAvailable -Name $name) {
                Write-Host ' [OK]' -ForegroundColor Green
            } else {
                Write-Host ' [MISSING]' -ForegroundColor Red
                Write-ErrorMessage "Module '$name' is required by $($file.Name) but is not installed in the container."
                Write-Warning "Action: Add '$name' to the 'features' section of your devcontainer.json and rebuild."
                $allValid = $false
            }
        }
    } catch {
        Write-ErrorMessage "Failed to parse manifest $($file.FullName): $($_.Exception.Message)"
        $allValid = $false
    }
}
if ($allValid) {
    Write-Host "`n✅ PowerShell dependencies validated successfully." -ForegroundColor Green
}

# Validate Node.js and npm
Write-Host ''
Write-Host 'Node.js Environment:' -ForegroundColor Cyan

try {
    $nodeVersion = node --version 2>$null
    if ($nodeVersion) {
        $nodeVersionObj = [version]$nodeVersion.Substring(1)
        if ($nodeVersionObj -ge [version]'20.18.1') {
            Write-Success "Node.js $nodeVersion"
        } else {
            Write-ErrorMessage "Node.js $nodeVersion - Requires 20.18.1 or higher"
            $allValid = $false
        }
    } else {
        Write-ErrorMessage 'Node.js not found'
        $allValid = $false
    }
} catch {
    Write-ErrorMessage 'Node.js not found'
    $allValid = $false
}

try {
    $npmVersion = npm --version 2>$null
    Write-Success "npm $npmVersion"
} catch {
    Write-ErrorMessage 'npm not found'
    $allValid = $false
}

# Validate Git
Write-Host ''
Write-Host 'Version Control:' -ForegroundColor Cyan

try {
    $gitVersion = git --version 2>$null
    if ($gitVersion) {
        Write-Success "$gitVersion"
    } else {
        Write-ErrorMessage 'Git not found'
        $allValid = $false
    }
} catch {
    Write-ErrorMessage 'Git not found'
    $allValid = $false
}

# Validate directory structure
Write-Host ''
Write-Host 'Project Structure:' -ForegroundColor Cyan

$requiredDirs = @(
    @{ Path = './powershell'; Description = 'PowerShell Module' },
    @{ Path = './website'; Description = 'Docusaurus Website' },
    @{ Path = './report'; Description = 'Vite Report' },
    @{ Path = './build'; Description = 'Build Scripts' },
    @{ Path = './tests'; Description = 'Test Files' }
)

foreach ($dir in $requiredDirs) {
    if (Test-Path -Path $dir.Path -PathType Container) {
        Write-Success "$($dir.Description) ($($dir.Path))"
    } else {
        Write-ErrorMessage "$($dir.Description) not found at $($dir.Path)"
        $allValid = $false
    }
}

# Validate npm packages are installed
Write-Host ''
Write-Host 'NPM Dependencies:' -ForegroundColor Cyan

$npmProjects = @(
    @{ Path = './website'; Name = 'Website' },
    @{ Path = './report'; Name = 'Report' }
)

foreach ($project in $npmProjects) {
    $nodeModulesPath = Join-Path $project.Path 'node_modules'
    if (Test-Path -Path $nodeModulesPath -PathType Container) {
        $pkgCount = (Get-ChildItem -Path $nodeModulesPath -Directory 2>$null | Measure-Object).Count
        Write-Success "$($project.Name) - $pkgCount packages installed"
    } else {
        Write-Host "$($project.Name) - Dependencies not installed yet (expected at $nodeModulesPath). This is a warning only; run the appropriate npm install task to set up dependencies." -ForegroundColor Yellow
    }
}

# Summary
Write-Host ''
Write-Header 'Validation Summary'

if ($allValid) {
    Write-Host ''
    Write-Host 'All checks passed! Dev container is ready for development.' -ForegroundColor Green
    Write-Host ''
    exit 0
} else {
    Write-Host ''
    Write-Host 'Some validations failed. Please review the errors above.' -ForegroundColor Yellow
    Write-Host ''
    exit 1
}
