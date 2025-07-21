<#
  Test Suite: MT1060Drift.tests.ps1
  Description: This test suite checks for drift in JSON files supplied by the user.
      It compares the current JSON against a baseline JSON and reports any differences.
      It also checks for the existence of baseline and current JSON files in specified drift folders.
  Example Usage:
      Invoke-MtTest -Path "tests/Maester/Drift/MT1060Drift.tests.ps1"
  Setup:
      - If you want to do drift checks, create a folder named "drift" at the root of your project.
      - Inside the "drift" folder, create subfolders for each drift test.
      - Each subfolder should contain:
          - `baseline.json`: The expected JSON structure.
          - `current.json`: The actual JSON structure to compare against the baseline.
          - `settings.json` (optional): A JSON file with settings, currently only supports `ExcludeProperties` to skip certain properties during comparison.
  Author: Stephan van Rooij @svrooij
  Date:   2025-06-26
#>

# This is temporary code to load the correct Compare-MtJsonObject function during development.
# In production, this should be part of the Maester module.
BeforeAll {
    # Ensure the Compare-MtJsonObject function is available
    if (-not (Get-Command -Name Compare-MtJsonObject -ErrorAction SilentlyContinue)) {
        Write-Verbose "Loading Compare-MtJsonObject function from public/maester/drift/Compare-MtJsonObject.ps1"
        . "$PSScriptRoot/../../../powershell/public/maester/drift/Compare-MtJsonObject.ps1"
    }
}

# By default this will not run if either the function Compare-MtJsonObject is not available or if the user has not created the mandatory drift folder structure.
# Using discovery to dynamically add drift folders to the test suite.
# This allows the user to "define" drift tests by creating folders in the "drift" directory.
BeforeDiscovery {

    # Get root directory for drift tests
    # This assumes the drift tests are located in a folder named "drift" at the root of the current location
    # $driftRoot = Join-Path -Path $(Get-Location) -ChildPath "drift"
    $driftRoot = $env:MEASTER_FOLDER_DRIFT
    # Ensure the drift root directory exists
    if ($null -eq $driftRoot -or -not (Test-Path -Path $driftRoot)) {
        return $null
    }

    # Ensure the Compare-MtJsonObject function is available
    if (-not (Get-Command -Name Compare-MtJsonObject -ErrorAction SilentlyContinue)) {
        Write-Warning "Compare-MtJsonObject function missing, not the right version of Maester?"
        return $null
    }

    $driftFolders = Get-ChildItem -Path $driftRoot -Directory
    # if it is not an array but a single folder, convert it to an array
    if (-not ($driftFolders -is [array]) -and $driftFolders -is [System.IO.DirectoryInfo]) {
        $driftFolders = @($driftFolders)

    }

    # No drift folders found, return null, meaning no drift tests will be run
    if ($driftFolders.Count -eq 0) {
        return $null
    }
    Write-Verbose "Found drift folders: $($driftFolders | ForEach-Object { $_.Name })"
}

# $driftFolders is coming from BeforeDiscovery.
Describe "Maester/Drift" -ForEach $driftFolders {
    # BeforeAll is run once for each drift folder, allowing us to set up the context for each drift test.
    BeforeAll {
        # Capture the drift folder context for each test
        # This allows us to access the drift folder in each test
        $driftFolder = $_
        $baselinePath = Join-Path -Path $driftFolder.FullName -ChildPath "baseline.json"
        $hasBaseline = Test-Path -Path $baselinePath -ErrorAction SilentlyContinue

        # Initialize variables to avoid linting errors
        $script:baselineData = $null
        $script:currentData = $null
        $script:settingsObject = $null

        if ($hasBaseline) {
            $script:baselineData = Get-Content -Path $baselinePath -Raw | ConvertFrom-Json -Depth 100
        }

        $driftCurrentPath = Join-Path -Path $driftFolder.FullName -ChildPath "current.json"
        $hasCurrent = Test-Path -Path $driftCurrentPath -ErrorAction SilentlyContinue
        if ($hasCurrent) {
            $script:currentData = Get-Content -Path $driftCurrentPath -Raw | ConvertFrom-Json -Depth 100
        }

        # Detect and parse settings.json for all settings
        $settingsPath = Join-Path -Path $driftFolder.FullName -ChildPath "settings.json"
        if (Test-Path -Path $settingsPath -ErrorAction SilentlyContinue) {
            try {
                $script:settingsObject = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
            } catch {
                Write-Warning "Could not parse settings.json in $($driftFolder.Name): $($_.Exception.Message)"
                $script:settingsObject = $null
            }
        }

        # Preload the differences if both the current data and baseline data are available
        if ($hasBaseline -and $hasCurrent) {
            try {
                # Use the recursive comparison function to find all differences, passing settingsObject
                $script:driftIssues = Compare-MtJsonObject -Baseline $baselineData -Current $currentData -Settings $settingsObject
            } catch {
                # If an error occurs during comparison, capture it as an issue
                $script:driftIssues = @([MtPropertyDifference]::new("", "N/A", "N/A", "An error occurred while comparing JSON objects: $($_.Exception.Message)", "ComparisonError"))

            }
        }
    }

    # MT1060.1: Validate that the baseline JSON file is valid, if you're using drift checks. you probably want it to fail if the baseline file is not valid or missing.
    # The ID of this test will be `MT1060.{folderName}.1` and has a tag of `MT1060`, `MT1060.1`, `MT1060.{folderName}`, and `MT1060.{folderName}.1`.
    It "MT1060.<_.Name>.1: Drift baseline in '<_.Name>' is valid JSON" -Tag "MT1060","MT1060.1","MT1060.$($_.Name)","MT1060.$($_.Name).1" {
        Add-MtTestResultDetail -Description "The ``baseline.json`` file should be valid JSON."
        $hasBaseline | Should -BeTrue -Because "the baseline file should exist for drift checks"
        $baselineData | Should -Not -BeNullOrEmpty -Because "the baseline file should contain valid JSON data"
    }

    # MT1060.2: Validate that the current JSON file is valid, if you're using drift checks. you probably want it to fail if the current file is not valid or missing.
    # The ID of this test will be `MT1060.{folderName}.2` and has a tag of `MT1060`, `MT1060.2`, `MT1060.{folderName}`, and `MT1060.{folderName}.2`.
    It "MT1060.<_.Name>.2: Drift current in '<_.Name>' is valid JSON" -Tag "MT1060","MT1060.2","MT1060.$($_.Name)","MT1060.$($_.Name).2" {
        Add-MtTestResultDetail -Description "The ``current.json`` file should be valid JSON, how else can we compare it?"
        $hasCurrent | Should -BeTrue -Because "the current file should exist for drift checks"
        $currentData | Should -Not -BeNullOrEmpty -Because "the current file should contain valid JSON data"
    }

    # MT1060.3: Validate that there are missing properties between baseline and current JSON files, skipping if either file is missing.
    # The ID of this test will be `MT1060.{folderName}.3` and has a tag of `MT1060`, `MT1060.3`, `MT1060.{folderName}`, and `MT1060.{folderName}.3`.
    It "MT1060.<_.Name>.3: Drift current in '<_.Name>' has no missing properties" -Tag "MT1060","MT1060.3","MT1060.$($_.Name)","MT1060.$($_.Name).3" -Skip:(($hasBaseline -eq $false) -or ($hasCurrent -eq $false)) {
        $description = "The ``current.json`` file should not have any missing properties compared to the ``baseline.json`` file."

        $missingProperties = $script:driftIssues | Where-Object { $_.Reason -eq "MissingProperty" } |
            Select-Object -ExpandProperty PropertyName -Unique

        if ($missingProperties.Count -gt 0) {
            # If there are missing properties, format them for the test result
            $formattedMissing = "The following properties are in the baseline but missing in ``current.json``: `n`n"
            $missingProperties | ForEach-Object {
                $formattedMissing += "- ``$_```n"
            }

            $formattedMissing += "`n"
            $formattedMissing += "Files compared in folder: ``$($driftFolder.FullName)```n"

            Add-MtTestResultDetail -Result $formattedMissing -Description $description
        } else {
            Add-MtTestResultDetail -Result "No missing properties found in current.json." -Description $description
        }
        $missingProperties | Should -BeNullOrEmpty -Because "there should be no missing properties in current.json"
    }

    # MT1060.4: Validate that there are no drift issues between baseline and current JSON files, skipping if either file is missing.
    # The ID of this test will be `MT1060.{folderName}.4` and has a tag of `MT1060`, `MT1060.4`, `MT1060.{folderName}`, and `MT1060.{folderName}.4`.
    It "MT1060.<_.Name>.4: Drift all values in '<_.Name>' match" -Tag "MT1060","MT1060.4","MT1060.$($_.Name)","MT1060.$($_.Name).4" -Skip:(($hasBaseline -eq $false) -or ($hasCurrent -eq $false)) {
        $description = "The ``current.json`` file should not drift from the ``baseline.json`` file."

        $propertyIssues = $script:driftIssues | Where-Object { $_.Reason -ne "MissingProperty" }

        # Format issues into a more readable format if there are any
        if ($propertyIssues.Count -gt 0) {
            # Convert issues to a more readable format for error messages
            $formattedIssues = "| Property | Reason | Expected Value | Actual Value | Description |" + "`n"
            $formattedIssues += "|----------|---------|----------------|--------------|-------------|" + "`n"
            $propertyIssues | ForEach-Object {
                $formattedIssues += "| ``$($_.PropertyName)`` | $($_.Reason) | ``$($_.ExpectedValue)`` | ``$($_.ActualValue)`` | $($_.Description) |`n"
            }
            $script:driftIssues | ForEach-Object {

            }
            $formattedIssues += "`n"
            $formattedIssues += "Files compared in folder: ``$($driftFolder.FullName)```n"

            Add-MtTestResultDetail -Result $formattedIssues -Description $description
        }
        else {
            Add-MtTestResultDetail -Result "No issues found in current.json." -Description $description
        }

        # Report all issues at once
        $propertyIssues.Count | Should -Be 0 -Because "there should be no differences between baseline and current JSON files"
    }
}