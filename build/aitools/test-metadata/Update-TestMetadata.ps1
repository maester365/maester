# This script will read the tests in test-results.json and maester-config.json (if it exists)
# then determine the severity and required permissions of the test using the Gemini AI API.
# The test-results.json file is a copy of one of the latest runs of Invoke-Maester.

function Get-PromptResult($prompt) {
    $apiKey = $Env:GeminiApiKey
    if (-not $apiKey) {
        Write-Host "Gemini API key not found in environment variable. Set with the following command." -ForegroundColor Red
        Write-Host ">`$Env:GeminiApiKey = '<key>'" -ForegroundColor Red
        Write-Host "You can get a new key from https://ai.google.dev/gemini-api/docs/api-key"
        exit 1
    }
    $uri = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey"


    $Body = @{
        contents = @(
            @{
                parts = @(
                    @{
                        text = $prompt
                    }
                )
            }
        )
    } | ConvertTo-Json -Depth 5

    $Headers = @{
        "Content-Type" = "application/json"
    }

    $Response = Invoke-RestMethod -Uri $Uri -Method Post -Headers $Headers -Body $Body

    return $Response.candidates.content.parts.text
}

function Get-MtMaesterConfig($ConfigFilePath) {
    if (-not (Test-Path $ConfigFilePath)) {
        Write-Host "Maester config file not found. Creating a new one." -ForegroundColor Yellow
        $maesterConfig = @{
            TestSettings = @()
        }
    } else {
        Write-Host "Maester config file found. Loading existing settings." -ForegroundColor Green
        $maesterConfig = Get-Content -Path $ConfigFilePath -Raw | ConvertFrom-Json
    }
    return $maesterConfig
}

function Set-MtMaesterConfig($ConfigFilePath, $MaesterConfig) {
    # Always sort TestSettings by Id
    $MaesterConfig.TestSettings = $MaesterConfig.TestSettings | Sort-Object Id
    # Convert the test settings array to JSON
    $maesterConfigJson = $MaesterConfig | ConvertTo-Json -Depth 10
    # Save the setting
    Set-Content -Path $ConfigFilePath -Value $maesterConfigJson -Force
}

function Get-TestFunctionCode($ScriptBlock) {
    # Heuristic: Find the first Test-Mt* or Get-Mt* function called in the script block
    if ($ScriptBlock -match '(Test-Mt|Get-Mt|Get-ORCA|Get-Az|Get-EXO)[a-zA-Z0-9]+') {
        $functionName = $Matches[0]
        Write-Host "Searching for code for: $functionName" -ForegroundColor Cyan
        
        # Search in powershell/public and powershell/internal
        $file = Get-ChildItem -Path "../../powershell" -Recurse -Filter "$functionName.ps1" | Select-Object -First 1
        if ($file) {
            return Get-Content -Path $file.FullName -Raw
        }
    }
    return "# Code not found for this test.`n$ScriptBlock"
}

# Change to the script's directory context
$OriginalLocation = Get-Location
Set-Location $PSScriptRoot

try {
    # Read the test-results.json file
    $testResultsFilePath = "./test-results.json"
    if (-not (Test-Path $testResultsFilePath)) {
        Write-Error "test-results.json not found at $testResultsFilePath"
        exit 1
    }
    $testResults = Get-Content -Path $testResultsFilePath -Raw | ConvertFrom-Json

    $promptFilePath = "./prompt-severity.md"
    $promptTemplate = Get-Content -Path $promptFilePath -Raw | Out-String

    $configPath = "../../tests/maester-config.json"
    $maesterConfig = Get-MtMaesterConfig $configPath

    # Loop through each test result and create a test setting
    foreach ($testResult in $testResults.Tests) {

        # Skip if test already has both severity AND permissions (optional: force refresh logic)
        $existingSetting = $maesterConfig.TestSettings | Where-Object { $_.Id -eq $testResult.Id }
        
        if ($existingSetting -and $existingSetting.Severity -and $existingSetting.RequiredPermissions) {
            Write-Host "Test $($testResult.Id) already has metadata. Skipping." -ForegroundColor Yellow
            continue
        }

        # Find out the code of the test
        $testCode = Get-TestFunctionCode -ScriptBlock $testResult.ScriptBlock

        $testInfo = [PSCustomObject]@{
            Id          = $testResult.Id
            Title       = $testResult.Title
            Description = $testResult.ResultDetail.Description
        }
        $testInfoJson = $testInfo | ConvertTo-Json -Depth 5

        $prompt = $promptTemplate -replace "%TEST_INFO_JSON%", $testInfoJson
        $prompt = $prompt -replace "%TEST_CODE%", $testCode

        Write-Host "Processing $($testResult.Id): $($testResult.Title)" -ForegroundColor Green
        
        # Call the AI API with the prompt
        try {
            $aiResponse = Get-PromptResult -prompt $prompt
            Write-Host "AI Response: $aiResponse" -ForegroundColor Blue
            
            # AI response should be pure JSON now
            $metadata = $aiResponse | ConvertFrom-Json
            
            if ($existingSetting) {
                $existingSetting.Severity = $metadata.Severity
                $existingSetting.RequiredPermissions = $metadata.RequiredPermissions
            } else {
                # Create a new test setting object
                $testSetting = [PSCustomObject]@{
                    Id                  = $testResult.Id
                    Title               = $testResult.Title
                    Severity            = $metadata.Severity
                    RequiredPermissions = $metadata.RequiredPermissions
                }
                $maesterConfig.TestSettings += $testSetting
            }

            # Save periodically
            Set-MtMaesterConfig -ConfigFilePath $configPath -MaesterConfig $maesterConfig
        } catch {
            Write-Warning "Failed to process $($testResult.Id): $($_.Exception.Message)"
        }
        
        # Rate limiting friendly
        Start-Sleep -Seconds 2
    }
} finally {
    Set-Location $OriginalLocation
}
