#Requires -Modules Pester

Describe "ConvertTo-QueryString - Null Handling Tests" {
    BeforeAll {
        # Import the function for testing
        . "$PSScriptRoot/../powershell/internal/ConvertTo-QueryString.ps1"
    }

    Context "Null Input Validation" {
        It "Handles null input without throwing errors" {
            { ConvertTo-QueryString -InputObjects $null } | Should -Not -Throw
        }

        It "Returns empty string for null input" {
            $result = ConvertTo-QueryString -InputObjects $null
            $result | Should -Be ""
        }

        It "Handles null input in pipeline" {
            $result = $null | ConvertTo-QueryString
            $result | Should -Be ""
        }
    }

    Context "Hashtable with Null Values" {
        It "Processes hashtable with null values correctly" {
            $input = @{ Key1 = "Value1"; Key2 = $null; Key3 = "Value3" }
            $result = ConvertTo-QueryString -InputObjects $input
            $result | Should -Contain "Key1=Value1"
            $result | Should -Contain "Key3=Value3"
            $result | Should -Contain "Key2="
        }

        It "Handles hashtable with all null values" {
            $input = @{ Key1 = $null; Key2 = $null }
            $result = ConvertTo-QueryString -InputObjects $input
            $result | Should -Contain "Key1="
            $result | Should -Contain "Key2="
        }

        It "Handles empty hashtable" {
            $input = @{}
            $result = ConvertTo-QueryString -InputObjects $input
            $result | Should -Be ""
        }
    }

    Context "OrderedDictionary with Null Values" {
        It "Processes ordered dictionary with null values correctly" {
            $input = [ordered]@{ Key1 = "Value1"; Key2 = $null; Key3 = "Value3" }
            $result = ConvertTo-QueryString -InputObjects $input
            $result | Should -Contain "Key1=Value1"
            $result | Should -Contain "Key3=Value3"
            $result | Should -Contain "Key2="
        }
    }

    Context "Object Properties with Null Values" {
        It "Handles PSCustomObject properties with null values" {
            $input = [PSCustomObject]@{ Property1 = "Value1"; Property2 = $null; Property3 = "Value3" }
            $result = ConvertTo-QueryString -InputObjects $input
            $result | Should -Contain "Property1=Value1"
            $result | Should -Contain "Property3=Value3"
            $result | Should -Contain "Property2="
        }

        It "Handles object with all null properties" {
            $input = [PSCustomObject]@{ Property1 = $null; Property2 = $null }
            $result = ConvertTo-QueryString -InputObjects $input
            $result | Should -Contain "Property1="
            $result | Should -Contain "Property2="
        }
    }

    Context "Mixed Data Types with Null Values" {
        It "Handles mixed data types including null values" {
            $input = @{ 
                String = "test"
                Number = 42
                Boolean = $true
                NullValue = $null
                EmptyString = ""
                Guid = [guid]::NewGuid()
            }
            $result = ConvertTo-QueryString -InputObjects $input
            $result | Should -Contain "String=test"
            $result | Should -Contain "Number=42"
            $result | Should -Contain "Boolean=True"
            $result | Should -Contain "NullValue="
            $result | Should -Contain "EmptyString="
        }
    }
}

Describe "ConvertTo-QueryString - Performance Tests" {
    BeforeAll {
        . "$PSScriptRoot/../powershell/internal/ConvertTo-QueryString.ps1"
    }

    Context "Performance Optimization" {
        It "Executes within acceptable time frame for small objects" {
            $input = @{ Key1 = "Value1"; Key2 = "Value2" }
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            ConvertTo-QueryString -InputObjects $input | Out-Null
            $stopwatch.Stop()
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 300
        }

        It "Handles large objects efficiently" {
            $input = @{}
            for ($i = 1; $i -le 100; $i++) {
                $input["Key$i"] = "Value$i"
            }
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            ConvertTo-QueryString -InputObjects $input | Out-Null
            $stopwatch.Stop()
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 500
        }

        It "Reduces redundant Get-Member calls for objects" {
            $input = [PSCustomObject]@{ Property1 = "Value1"; Property2 = "Value2" }
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            ConvertTo-QueryString -InputObjects $input | Out-Null
            $stopwatch.Stop()
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 50
        }
    }
}

Describe "ConvertTo-QueryString - Error Handling Tests" {
    BeforeAll {
        . "$PSScriptRoot/../powershell/internal/ConvertTo-QueryString.ps1"
    }

    Context "Enhanced Error Messages" {
        It "Provides informative error for unsupported types" {
            $input = "string"
            { ConvertTo-QueryString -InputObjects $input -ErrorAction Stop } | Should -Throw -ExceptionType ([System.ArgumentException])
        }

        It "Error message includes supported types information" {
            $input = 123
            try {
                ConvertTo-QueryString -InputObjects $input -ErrorAction Stop
            } catch {
                $_.Exception.Message | Should -Contain "Supported types"
                $_.Exception.Message | Should -Contain "Hashtable"
                $_.Exception.Message | Should -Contain "OrderedDictionary"
            }
        }

        It "Error message includes the actual input type" {
            $input = [System.DateTime]::Now
            try {
                ConvertTo-QueryString -InputObjects $input -ErrorAction Stop
            } catch {
                $_.Exception.Message | Should -Contain "System.DateTime"
            }
        }

        It "Error has correct category and activity" {
            $input = "test"
            try {
                ConvertTo-QueryString -InputObjects $input -ErrorAction Stop
            } catch {
                $_.CategoryInfo.Category | Should -Be "ParserError"
                $_.CategoryInfo.Activity | Should -Be "ConvertTo-QueryString"
            }
        }
    }

    Context "Non-Terminating Errors" {
        It "Continues processing after error for unsupported types" {
            $input = @("string", @{ Key = "Value" })
            $results = ConvertTo-QueryString -InputObjects $input
            $results.Count | Should -Be 2
            $results[1] | Should -Be "Key=Value"
        }
    }
}

Describe "ConvertTo-QueryString - Invoke-GraphRequest Integration Tests" {
    BeforeAll {
        . "$PSScriptRoot/../powershell/internal/ConvertTo-QueryString.ps1"
    }

    Context "Real-world Graph Request Scenarios" {
        It "Handles typical Graph query parameters with null values" {
            $queryParams = @{
                '$select' = 'id,displayName,mail'
                '$filter' = 'userType eq ''Member'''
                '$top' = 100
                '$skip' = $null
                '$orderby' = 'displayName'
                '$count' = $true
            }
            $result = ConvertTo-QueryString -InputObjects $queryParams
            $result | Should -Contain '$select=id%2CdisplayName%2Cmail'
            $result | Should -Contain '$filter=userType%20eq%20%27Member%27'
            $result | Should -Contain '$top=100'
            $result | Should -Contain '$skip='
            $result | Should -Contain '$orderby=displayName'
            $result | Should -Contain '$count=True'
        }

        It "Handles empty query parameters hashtable" {
            $queryParams = @{}
            $result = ConvertTo-QueryString -InputObjects $queryParams
            $result | Should -Be ""
        }

        It "Handles query parameters with mixed null and non-null values" {
            $queryParams = @{
                '$select' = 'id,displayName'
                '$filter' = $null
                '$top' = 50
                '$skip' = $null
            }
            $result = ConvertTo-QueryString -InputObjects $queryParams
            $result | Should -Contain '$select=id%2CdisplayName'
            $result | Should -Contain '$filter='
            $result | Should -Contain '$top=50'
            $result | Should -Contain '$skip='
        }

        It "Handles complex filter scenarios with null values" {
            $queryParams = @{
                '$filter' = 'displayName eq ''John Doe'''
                '$select' = $null
                '$expand' = 'manager'
                '$count' = $null
            }
            $result = ConvertTo-QueryString -InputObjects $queryParams
            $result | Should -Contain '$filter=displayName%20eq%20%27John%20Doe%27'
            $result | Should -Contain '$select='
            $result | Should -Contain '$expand=manager'
            $result | Should -Contain '$count='
        }
    }

    Context "Edge Cases for Graph Requests" {
        It "Handles special characters in values with null parameters" {
            $queryParams = @{
                'search' = 'test@domain.com'
                'filter' = $null
                'select' = 'id,userPrincipalName'
            }
            $result = ConvertTo-QueryString -InputObjects $queryParams
            $result | Should -Contain 'search=test%40domain.com'
            $result | Should -Contain 'filter='
            $result | Should -Contain 'select=id%2CuserPrincipalName'
        }

        It "Handles boolean values with null parameters" {
            $queryParams = @{
                '$count' = $true
                '$search' = $null
                '$orderby' = 'displayName'
            }
            $result = ConvertTo-QueryString -InputObjects $queryParams
            $result | Should -Contain '$count=True'
            $result | Should -Contain '$search='
            $result | Should -Contain '$orderby=displayName'
        }
    }
}

Describe "ConvertTo-QueryString - Parameter Encoding Tests" {
    BeforeAll {
        . "$PSScriptRoot/../powershell/internal/ConvertTo-QueryString.ps1"
    }

    Context "Parameter Name Encoding" {
        It "Encodes parameter names when EncodeParameterNames is specified" {
            $input = @{ 'test param' = 'value'; 'another&param' = 'test' }
            $result = ConvertTo-QueryString -InputObjects $input -EncodeParameterNames
            $result | Should -Contain 'test%20param=value'
            $result | Should -Contain 'another%26param=test'
        }

        It "Handles null values with encoded parameter names" {
            $input = @{ 'test param' = $null; 'another&param' = 'value' }
            $result = ConvertTo-QueryString -InputObjects $input -EncodeParameterNames
            $result | Should -Contain 'test%20param='
            $result | Should -Contain 'another%26param=value'
        }
    }
}

Describe "ConvertTo-QueryString - ToString Conversion Tests" {
    BeforeAll {
        . "$PSScriptRoot/../powershell/internal/ConvertTo-QueryString.ps1"
    }

    Context "Proper ToString Conversion" {
        It "Converts integers to string properly" {
            $input = @{ Number = 42; NullNumber = $null }
            $result = ConvertTo-QueryString -InputObjects $input
            $result | Should -Contain 'Number=42'
            $result | Should -Contain 'NullNumber='
        }

        It "Converts booleans to string properly" {
            $input = @{ TrueValue = $true; FalseValue = $false; NullBool = $null }
            $result = ConvertTo-QueryString -InputObjects $input
            $result | Should -Contain 'TrueValue=True'
            $result | Should -Contain 'FalseValue=False'
            $result | Should -Contain 'NullBool='
        }

        It "Converts GUIDs to string properly" {
            $guid = [guid]::NewGuid()
            $input = @{ GuidValue = $guid; NullGuid = $null }
            $result = ConvertTo-QueryString -InputObjects $input
            $result | Should -Contain "GuidValue=$($guid.ToString())"
            $result | Should -Contain 'NullGuid='
        }

        It "Converts DateTime to string properly" {
            $date = [System.DateTime]::Now
            $input = @{ DateValue = $date; NullDate = $null }
            $result = ConvertTo-QueryString -InputObjects $input
            $result | Should -Contain "DateValue=$($date.ToString())"
            $result | Should -Contain 'NullDate='
        }
    }
}
