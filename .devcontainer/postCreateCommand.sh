#!/bin/bash
set -e

echo "=========================================="
echo "Maester Dev Container Setup"
echo "=========================================="

# Install system dependencies
echo ""
echo "Installing system dependencies..."
sudo apt-get update
sudo apt-get install -y \
    xdg-utils \
    curl \
    wget \
    build-essential \
    python3-dev

# Install Node.js dependencies with reproducible lock files
echo ""
echo "Installing Node.js dependencies..."
echo "Installing website dependencies..."
cd ./website && npm ci && cd - > /dev/null

echo "Installing report dependencies..."
cd ./report && npm ci && cd - > /dev/null

# Restore PowerShell module dependencies
echo ""
echo "Restoring PowerShell module dependencies..."
pwsh -NoProfile -File ./build/Restore-PSModuleDependencies.ps1 -ModuleManifestPath ".\powershell\*.psd1"

# Run dev container initialization and validation
echo ""
echo "Running dev container initialization..."
pwsh -NoProfile -File ./.devcontainer/Initialize-DevContainer.ps1

echo ""
echo "=========================================="
echo "Dev Container Setup Complete!"
echo "=========================================="
echo ""
echo "Available commands:"
echo "  PowerShell Module:"
echo "    ./build/Test-PSModule.ps1        - Run Pester tests"
echo "    ./build/Build-PSModule.ps1       - Build the module"
echo "    ./build/Copy-MaesterTestsToPSModule.ps1  - Copy tests to module"
echo ""
echo "  Website (Docusaurus):"
echo "    cd ./website && npm start        - Start dev server (port 3000)"
echo "    cd ./website && npm run build    - Build for production"
echo ""
echo "  Report (Vite + React):"
echo "    cd ./report && npm run dev       - Start dev server (port 5173)"
echo "    cd ./report && npm run build     - Build report template (output to dist/)"
echo ""
echo "=========================================="