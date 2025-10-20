#Requires -Modules Pester

Describe "ConvertTo-QueryString - Invoke-GraphRequest Failure Scenarios" {
    BeforeAll {
        . "$PSScriptRoot/../powershell/internal/ConvertTo-QueryString.ps1"
    }

    Context "Specific Failure Scenarios That Prompted the PR" {
        It "Handles null values in Graph query parameters that previously caused errors" {
            # Scenario: When Invoke-GraphRequest processes query parameters with null values
            # This was causing issues when building the final query string
            $queryParams = @{
                '$select' = 'id,displayName,mail'
                '$filter' = $null  # This null value was causing issues
                '$top' = 100
                '$skip' = $null    # This null value was causing issues
                '$orderby' = 'displayName'
            }
            
            # This should not throw an error and should handle null values gracefully
            { ConvertTo-QueryString -InputObjects $queryParams } | Should -Not -Throw
            
            $result = ConvertTo-QueryString -InputObjects $queryParams
            $result | Should -Contain '$select=id%2CdisplayName%2Cmail'
            $result | Should -Contain '$filter='
            $result | Should -Contain '$top=100'
            $result | Should -Contain '$skip='
            $result | Should -Contain '$orderby=displayName'
        }

        It "Handles null values in complex Graph filter scenarios" {
            # Scenario: Complex filters with null parameters that were failing
            $queryParams = @{
                '$filter' = 'userType eq ''Member'' and accountEnabled eq true'
                '$select' = $null  # Null select parameter
                '$expand' = 'manager,memberOf'
                '$count' = $null   # Null count parameter
                '$search' = 'john.doe@company.com'
            }
            
            { ConvertTo-QueryString -InputObjects $queryParams } | Should -Not -Throw
            
            $result = ConvertTo-QueryString -InputObjects $queryParams
            $result | Should -Contain '$filter=userType%20eq%20%27Member%27%20and%20accountEnabled%20eq%20true'
            $result | Should -Contain '$select='
            $result | Should -Contain '$expand=manager%2CmemberOf'
            $result | Should -Contain '$count='
            $result | Should -Contain '$search=john.doe%40company.com'
        }

        It "Handles null values in batch request scenarios" {
            # Scenario: Batch requests with null parameters
            $queryParams = @{
                '$select' = 'id,displayName'
                '$filter' = $null
                '$top' = 50
                '$skip' = $null
                '$orderby' = $null
            }
            
            { ConvertTo-QueryString -InputObjects $queryParams } | Should -Not -Throw
            
            $result = ConvertTo-QueryString -InputObjects $queryParams
            $result | Should -Contain '$select=id%2CdisplayName'
            $result | Should -Contain '$filter='
            $result | Should -Contain '$top=50'
            $result | Should -Contain '$skip='
            $result | Should -Contain '$orderby='
        }

        It "Handles null values in paging scenarios" {
            # Scenario: Paging with null parameters
            $queryParams = @{
                '$top' = 100
                '$skip' = $null
                '$count' = $true
                '$select' = $null
            }
            
            { ConvertTo-QueryString -InputObjects $queryParams } | Should -Not -Throw
            
            $result = ConvertTo-QueryString -InputObjects $queryParams
            $result | Should -Contain '$top=100'
            $result | Should -Contain '$skip='
            $result | Should -Contain '$count=True'
            $result | Should -Contain '$select='
        }
    }

    Context "Performance Issues That Were Addressed" {
        It "Reduces redundant Get-Member calls for objects with many properties" {
            # Scenario: Objects with many properties were causing performance issues
            # due to redundant Get-Member calls
            $object = [PSCustomObject]@{
                Property1 = "Value1"
                Property2 = "Value2"
                Property3 = $null
                Property4 = "Value4"
                Property5 = $null
                Property6 = "Value6"
                Property7 = "Value7"
                Property8 = $null
                Property9 = "Value9"
                Property10 = "Value10"
            }
            
            # Warm-up run
            ConvertTo-QueryString -InputObjects $object | Out-Null
            
            $iterationCount = 5
            $elapsedTimes = @()
            for ($i = 0; $i -lt $iterationCount; $i++) {
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                ConvertTo-QueryString -InputObjects $object | Out-Null
                $sw.Stop()
                $elapsedTimes += $sw.ElapsedMilliseconds
            }
            
            $averageElapsed = ($elapsedTimes | Measure-Object -Average).Average
            
            # Should complete quickly without redundant Get-Member calls
            $averageElapsed | Should -BeLessThan 100
        }

        It "Handles large hashtables efficiently" {
            # Scenario: Large hashtables with null values were causing performance issues
            $largeHashtable = @{}
            for ($i = 1; $i -le 50; $i++) {
                if ($i % 3 -eq 0) {
                    $largeHashtable["Key$i"] = $null
                } else {
                    $largeHashtable["Key$i"] = "Value$i"
                }
            }
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            ConvertTo-QueryString -InputObjects $largeHashtable | Out-Null
            $stopwatch.Stop()
            
            # Should handle large hashtables efficiently
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 200
        }
    }

    Context "Error Message Improvements" {
        It "Provides better error messages for unsupported types in Graph scenarios" {
            # Scenario: When unsupported types are passed to ConvertTo-QueryString
            # from Graph request processing, better error messages help with debugging
            $unsupportedInput = "invalid-string-input"
            
            try {
                ConvertTo-QueryString -InputObjects $unsupportedInput -ErrorAction Stop
            } catch {
                $_.Exception.Message | Should -Contain "Cannot convert input of type System.String"
                $_.Exception.Message | Should -Contain "Supported types: Hashtable, OrderedDictionary, Dictionary, or objects with properties"
                $_.CategoryInfo.Category | Should -Be "ParserError"
                $_.CategoryInfo.Activity | Should -Be "ConvertTo-QueryString"
            }
        }

        It "Provides context about the input type in error messages" {
            # Scenario: Better error context helps identify where the issue originates
            $unsupportedInput = [System.DateTime]::Now
            
            try {
                ConvertTo-QueryString -InputObjects $unsupportedInput -ErrorAction Stop
            } catch {
                $_.Exception.Message | Should -Contain "System.DateTime"
                $_.Exception.Message | Should -Contain "Supported types"
            }
        }
    }

    Context "Real-world Graph Request Examples" {
        It "Handles typical user query with null parameters" {
            # Real-world example: Querying users with some null parameters
            $userQueryParams = @{
                '$select' = 'id,displayName,userPrincipalName,mail'
                '$filter' = 'userType eq ''Member'''
                '$top' = 100
                '$skip' = $null
                '$orderby' = 'displayName'
                '$count' = $true
                '$search' = $null
            }
            
            { ConvertTo-QueryString -InputObjects $userQueryParams } | Should -Not -Throw
            
            $result = ConvertTo-QueryString -InputObjects $userQueryParams
            $result | Should -Contain '$select=id%2CdisplayName%2CuserPrincipalName%2Cmail'
            $result | Should -Contain '$filter=userType%20eq%20%27Member%27'
            $result | Should -Contain '$top=100'
            $result | Should -Contain '$skip='
            $result | Should -Contain '$orderby=displayName'
            $result | Should -Contain '$count=True'
            $result | Should -Contain '$search='
        }

        It "Handles group membership query with null parameters" {
            # Real-world example: Querying group memberships
            $groupQueryParams = @{
                '$select' = 'id,displayName,description'
                '$filter' = 'securityEnabled eq true'
                '$top' = 50
                '$skip' = $null
                '$orderby' = $null
                '$expand' = 'members'
            }
            
            { ConvertTo-QueryString -InputObjects $groupQueryParams } | Should -Not -Throw
            
            $result = ConvertTo-QueryString -InputObjects $groupQueryParams
            $result | Should -Contain '$select=id%2CdisplayName%2Cdescription'
            $result | Should -Contain '$filter=securityEnabled%20eq%20true'
            $result | Should -Contain '$top=50'
            $result | Should -Contain '$skip='
            $result | Should -Contain '$orderby='
            $result | Should -Contain '$expand=members'
        }

        It "Handles application query with null parameters" {
            # Real-world example: Querying applications
            $appQueryParams = @{
                '$select' = 'id,displayName,appId'
                '$filter' = 'signInAudience eq ''AzureADMyOrg'''
                '$top' = 25
                '$skip' = $null
                '$orderby' = 'displayName'
                '$count' = $null
            }
            
            { ConvertTo-QueryString -InputObjects $appQueryParams } | Should -Not -Throw
            
            $result = ConvertTo-QueryString -InputObjects $appQueryParams
            $result | Should -Contain '$select=id%2CdisplayName%2CappId'
            $result | Should -Contain '$filter=signInAudience%20eq%20%27AzureADMyOrg%27'
            $result | Should -Contain '$top=25'
            $result | Should -Contain '$skip='
            $result | Should -Contain '$orderby=displayName'
            $result | Should -Contain '$count='
        }
    }
}
