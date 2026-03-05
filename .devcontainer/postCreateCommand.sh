#!/bin/bash
set -e

echo "=========================================="
echo "Maester Dev Container Setup"
echo "=========================================="

# Install system dependencies
echo -e "\nInstalling system dependencies..."
# Combined to reduce layer size and ensure fresh metadata
sudo apt-get update && sudo apt-get install -y --no-install-recommends \
    xdg-utils \
    curl \
    wget
&& sudo rm -rf /var/lib/apt/lists/*

# Install Node.js dependencies with reproducible lock files
# echo ""
# echo "Installing Node.js dependencies..."
# echo "Installing website dependencies..."
# cd ./website && npm ci > /dev/null

# echo "Installing report dependencies..."
# cd ./report && npm ci > /dev/null

# Run dev container validation
echo -e "\nRunning dev container validation..."
pwsh -NoProfile -File ./.devcontainer/Validate-DevContainer.ps1

echo -e "\n=========================================="
echo "Dev Container Setup Complete!"
echo "=========================================="
echo -e "\nAvailable commands:"
echo "  PowerShell Module:"
echo "    ./build/Test-PSModule.ps1        - Run Pester tests"
echo "    ./build/Build-PSModule.ps1       - Build the module"
echo ""
echo "  Website & Report:"
echo "    Click the 'Start Website' or 'Start Report' buttons in the Status Bar."
echo "    (The first run will automatically install Node dependencies)"
echo ""
echo "  Manual Install (if buttons aren't used):"
echo "    cd ./website && npm ci"
echo "    cd ./report && npm ci"
echo "=========================================="
