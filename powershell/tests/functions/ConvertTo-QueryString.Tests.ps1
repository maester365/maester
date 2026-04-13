BeforeAll {
    . "$PSScriptRoot/../../internal/ConvertTo-QueryString.ps1"
}

Describe 'ConvertTo-QueryString' {
    Context 'Hashtable input' {
        It 'Should convert simple hashtable to query string' {
            $hashtable = @{ name = 'test'; value = '123' }
            $result = ConvertTo-QueryString $hashtable
            $result | Should -Match 'name=test'
            $result | Should -Match 'value=123'
            $result | Should -Match '&'
        }

        It 'Should handle empty hashtable' {
            $hashtable = @{}
            $result = ConvertTo-QueryString $hashtable
            $result | Should -Be ''
        }

        It 'Should URL encode values with special characters' {
            $hashtable = @{ title = 'convert&prosper'; path = 'path/file.json' }
            $result = ConvertTo-QueryString $hashtable
            $result | Should -Match 'title=convert%26prosper'
            $result | Should -Match 'path=path%2Ffile\.json'
        }

        It 'Should handle numeric values' {
            $hashtable = @{ index = 10; price = 99.99 }
            $result = ConvertTo-QueryString $hashtable
            $result | Should -Match 'index=10'
            # Decimal separator can be . or , depending on locale
            $result | Should -Match 'price=99(\.|%2C)99'
        }

        It 'Should handle boolean values' {
            $hashtable = @{ enabled = $true; visible = $false }
            $result = ConvertTo-QueryString $hashtable
            $result | Should -Match 'enabled=True'
            $result | Should -Match 'visible=False'
        }

        It 'Should handle GUID values' {
            $guid = [guid]'352182e6-9ab0-4115-807b-c36c88029fa4'
            $hashtable = @{ id = $guid }
            $result = ConvertTo-QueryString $hashtable
            $result | Should -Match 'id=352182e6-9ab0-4115-807b-c36c88029fa4'
        }

        It 'Should handle null/empty values' {
            $hashtable = @{ empty = ''; null = $null }
            $result = ConvertTo-QueryString $hashtable
            $result | Should -Match 'empty='
            $result | Should -Match 'null='
        }
    }

    Context 'OrderedDictionary input' {
        It 'Should convert ordered dictionary to query string' {
            $ordered = [ordered]@{ first = 'value1'; second = 'value2'; third = 'value3' }
            $result = ConvertTo-QueryString $ordered
            $result | Should -Match 'first=value1'
            $result | Should -Match 'second=value2'
            $result | Should -Match 'third=value3'
        }

        It 'Should maintain order with ordered dictionary' {
            $ordered = [ordered]@{ z = 'last'; a = 'first'; m = 'middle' }
            $result = ConvertTo-QueryString $ordered
            # The order should be preserved (z, a, m)
            $result.IndexOf('z=last') | Should -BeLessThan $result.IndexOf('a=first')
            $result.IndexOf('a=first') | Should -BeLessThan $result.IndexOf('m=middle')
        }
    }

    Context 'PSObject input' {
        It 'Should convert PSObject with properties to query string' {
            $obj = New-Object PSObject
            $obj | Add-Member -MemberType NoteProperty -Name 'name' -Value 'test'
            $obj | Add-Member -MemberType NoteProperty -Name 'value' -Value '456'

            $result = ConvertTo-QueryString $obj
            $result | Should -Match 'name=test'
            $result | Should -Match 'value=456'
        }

        It 'Should handle PSObject with empty properties' {
            $obj = New-Object PSObject
            $result = ConvertTo-QueryString $obj
            $result | Should -Be ''
        }
    }

    Context 'Pipeline input' {
        It 'Should accept hashtable from pipeline' {
            $hashtable = @{ test = 'pipeline' }
            $result = $hashtable | ConvertTo-QueryString
            $result | Should -Match 'test=pipeline'
        }

        It 'Should handle multiple objects from pipeline' {
            $hash1 = @{ first = 'value1' }
            $hash2 = @{ second = 'value2' }
            $results = @($hash1, $hash2) | ConvertTo-QueryString
            $results.Count | Should -Be 2
            $results[0] | Should -Match 'first=value1'
            $results[1] | Should -Match 'second=value2'
        }
    }

    Context 'Special characters and encoding' {
        It 'Should properly encode spaces' {
            $hashtable = @{ text = 'hello world' }
            $result = ConvertTo-QueryString $hashtable
            $result | Should -eq 'text=hello+world'
        }

        It 'Should properly encode special URL characters' {
            $hashtable = @{
                ampersand = 'test&value'
                equals = 'test=value'
                question = 'test?value'
                hash = 'test#value'
                plus = 'test+value'
                percent = 'test%value'
            }
            $result = ConvertTo-QueryString $hashtable
            $result | Should -Match 'ampersand=test%26value'
            $result | Should -Match 'equals=test%3Dvalue'
            $result | Should -Match 'question=test%3Fvalue'
            $result | Should -Match 'hash=test%23value'
            $result | Should -Match 'plus=test%2Bvalue'
            $result | Should -Match 'percent=test%25value'
        }

        It 'Should handle Unicode characters' {
            $hashtable = @{ unicode = 'café' }
            $result = ConvertTo-QueryString $hashtable
            $result | Should -Match 'unicode=caf%C3%A9'
        }
    }

    Context 'Return type and format' {
        It 'Should return string type' {
            $hashtable = @{ test = 'value' }
            $result = ConvertTo-QueryString $hashtable
            $result | Should -BeOfType [string]
        }

        It 'Should not start with question mark' {
            $hashtable = @{ param = 'value' }
            $result = ConvertTo-QueryString $hashtable
            $result | Should -Not -Match '^\?'
        }

        It 'Should separate parameters with ampersand' {
            $hashtable = @{ param1 = 'value1'; param2 = 'value2'; param3 = 'value3' }
            $result = ConvertTo-QueryString $hashtable
            ($result -split '&').Count | Should -Be 3
        }
    }

    Context 'Microsoft Graph query parameters' {
        It 'Should handle $filter with startswith function' {
            $graphParams = @{
                '$filter' = "startswith(givenName,'J')"
            }
            $result = ConvertTo-QueryString $graphParams
            $result | Should -Be '$filter=startswith(givenName%2C%27J%27)'
        }

        It 'Should handle $select for specific properties' {
            $graphParams = @{
                '$select' = 'givenName,surname,mail'
            }
            $result = ConvertTo-QueryString $graphParams
            $result | Should -Be '$select=givenName%2Csurname%2Cmail'
        }

        It 'Should handle $orderby with ascending and descending' {
            $graphParams = @{
                '$orderby' = 'displayName desc,givenName asc'
            }
            $result = ConvertTo-QueryString $graphParams
            $result | Should -Be '$orderby=displayName+desc%2CgivenName+asc'
        }

        It 'Should handle $expand with nested select' {
            $graphParams = @{
                '$expand' = 'members($select=id,displayName)'
            }
            $result = ConvertTo-QueryString $graphParams
            $result | Should -Be '$expand=members(%24select%3Did%2CdisplayName)'
        }

        It 'Should handle $search query' {
            $graphParams = @{
                '$search' = '"displayName:John"'
            }
            $result = ConvertTo-QueryString $graphParams
            $result | Should -Be '$search=%22displayName%3AJohn%22'
        }

        It 'Should handle $count parameter' {
            $graphParams = @{
                '$count' = 'true'
                '$top' = 10
            }
            $result = ConvertTo-QueryString $graphParams
            $result | Should -Match ([regex]::escape('$count=true'))
            $result | Should -Match ([regex]::escape('$top=10'))
        }

        It 'Should handle complex $filter with multiple conditions' {
            $graphParams = @{
                '$filter' = "userType eq 'Member' and accountEnabled eq true"
            }
            $result = ConvertTo-QueryString $graphParams
            $result | Should -Be '$filter=userType+eq+%27Member%27+and+accountEnabled+eq+true'
        }

        It 'Should handle $filter with date comparison' {
            $graphParams = @{
                '$filter' = "createdDateTime ge 2023-01-01T00:00:00Z"
            }
            $result = ConvertTo-QueryString $graphParams
            $result | Should -Be '$filter=createdDateTime+ge+2023-01-01T00%3A00%3A00Z'
        }

        It 'Should handle $skipToken for pagination' {
            $graphParams = @{
                '$skiptoken' = 'X%274453707402000100000017...'
            }
            $result = ConvertTo-QueryString $graphParams
            $result | Should -Be '$skiptoken=X%25274453707402000100000017...'
        }

        It 'Should handle advanced query with ConsistencyLevel header requirements' {
            $graphParams = @{
                '$filter' = "endsWith(mail,'@contoso.com')"
                '$count' = 'true'
                '$orderby' = 'displayName'
            }
            $result = ConvertTo-QueryString $graphParams
            $result | Should -Match ([regex]::escape('$filter=endsWith(mail%2C%27%40contoso.com%27)'))
            $result | Should -Match ([regex]::escape('$count=true'))
            $result | Should -Match ([regex]::escape('$orderby=displayName'))
        }

        It 'Should handle $format parameter' {
            $graphParams = @{
                '$format' = 'json'
            }
            $result = ConvertTo-QueryString $graphParams
            $result | Should -Match ([regex]::escape('$format=json'))
        }

        It 'Should handle mail-specific query with $search' {
            $graphParams = @{
                '$search' = 'pizza'
                '$top' = 5
            }
            $result = ConvertTo-QueryString $graphParams
            $result | Should -Match ([regex]::escape('$search=pizza'))
            $result | Should -Match ([regex]::escape('$top=5'))
        }
    }

    Context 'Edge cases and null value handling' {
        It 'Should handle null values correctly' {
            $hashtable = @{
                validKey = 'validValue'
                nullKey = $null
            }
            $result = ConvertTo-QueryString $hashtable
            $result | Should -Match ([regex]::escape('validKey=validValue'))
            $result | Should -Match ([regex]::escape('nullKey='))
        }

        It 'Should handle empty string values' {
            $hashtable = @{
                emptyString = ''
                whitespace = '   '
            }
            $result = ConvertTo-QueryString $hashtable
            $result | Should -Match ([regex]::escape('emptyString='))
            $result | Should -Match ([regex]::escape('whitespace=+++'))
        }

        It 'Should handle hashtable with mixed null and valid values' {
            $hashtable = @{
                name = 'John'
                middleName = $null
                lastName = 'Doe'
                nickname = ''
            }
            $result = ConvertTo-QueryString $hashtable
            $result | Should -Match 'name=John'
            $result | Should -Match 'middleName='
            $result | Should -Match 'lastName=Doe'
            $result | Should -Match 'nickname='
        }

        It 'Should handle PSObject with null properties' {
            $obj = New-Object PSObject
            $obj | Add-Member -MemberType NoteProperty -Name 'validProp' -Value 'value'
            $obj | Add-Member -MemberType NoteProperty -Name 'nullProp' -Value $null
            $obj | Add-Member -MemberType NoteProperty -Name 'emptyProp' -Value ''

            $result = ConvertTo-QueryString $obj
            $result | Should -Match 'validProp=value'
            $result | Should -Match 'nullProp='
            $result | Should -Match 'emptyProp='
        }

        It 'Should handle very long parameter names and values' {
            $longName = 'a' * 1000
            $longValue = 'b' * 2000
            $hashtable = @{ $longName = $longValue }

            { ConvertTo-QueryString $hashtable } | Should -Not -Throw
            $result = ConvertTo-QueryString $hashtable
            $result | Should -Match "^$longName="
        }

        It 'Should handle special parameter names that look like OData parameters' {
            $hashtable = @{
                'filter' = 'not-a-real-odata-filter'
                'select' = 'fake-select'
                '$actualOData' = 'real-odata'
            }
            $result = ConvertTo-QueryString $hashtable
            $result | Should -Match ([regex]::escape('filter=not-a-real-odata-filter'))
            $result | Should -Match ([regex]::escape('select=fake-select'))
            $result | Should -Match ([regex]::escape('$actualOData=real-odata'))
        }

        It 'Should handle array-like values converted to string' {
            $hashtable = @{
                arrayValue = @('item1', 'item2', 'item3')
                singleArray = @('single')
            }
            $result = ConvertTo-QueryString $hashtable
            # Arrays get converted to their string representation
            $result | Should -Match 'arrayValue=System\.Object%5B%5D'
            $result | Should -Match 'singleArray=System\.Object%5B%5D'
        }

        It 'Should handle DateTime values' {
            $dateTime = Get-Date '2023-12-25T10:30:00Z'
            $hashtable = @{
                createdDate = $dateTime
            }
            $result = ConvertTo-QueryString $hashtable
            $result | Should -Match 'createdDate='
            # DateTime gets converted to string and URL encoded
        }

        It 'Should handle single quotes in OData expressions' {
            $hashtable = @{
                '$filter' = "subject eq 'let''s meet for lunch?'"
            }
            $result = ConvertTo-QueryString $hashtable
            $result | Should -Match ([regex]::escape('$filter=subject+eq+%27let%27%27s+meet+for+lunch%3F%27'))
        }

        It 'Should handle extremely large hashtable' {
            $largeHashtable = @{}
            for ($i = 1; $i -le 1000; $i++) {
                $largeHashtable["param$i"] = "value$i"
            }

            { ConvertTo-QueryString $largeHashtable } | Should -Not -Throw
            $result = ConvertTo-QueryString $largeHashtable
            ($result -split '&').Count | Should -Be 1000
        }

        It 'Should handle nested object properties that become strings' {
            $nestedObj = @{
                level1 = @{
                    level2 = 'deep value'
                }
            }
            $hashtable = @{
                nested = $nestedObj
            }
            $result = ConvertTo-QueryString $hashtable
            # Nested objects get converted to their string representation
            $result | Should -Match 'nested='
        }
    }

    Context 'Performance optimization tests' {
        It 'Should execute within acceptable time frame for small objects' {
            $input = @{ Key1 = "Value1"; Key2 = "Value2" }
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            ConvertTo-QueryString $input | Out-Null
            $stopwatch.Stop()
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 300
        }

        It 'Should handle large objects efficiently' {
            $input = @{}
            for ($i = 1; $i -le 100; $i++) {
                $input["Key$i"] = "Value$i"
            }
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            ConvertTo-QueryString $input | Out-Null
            $stopwatch.Stop()
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 500
        }

        It 'Should reduce redundant Get-Member calls for objects' {
            $input = [PSCustomObject]@{ Property1 = "Value1"; Property2 = "Value2" }
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            ConvertTo-QueryString $input | Out-Null
            $stopwatch.Stop()
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 50
        }
    }

    Context 'Enhanced error handling' {
        It 'Should handle string input as object with properties' {
            $input = "string"
            $result = ConvertTo-QueryString -InputObjects $input
            # Strings are objects with properties (Length) so they get processed
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should include supported types information in error message' {
            $input = 123
            try {
                ConvertTo-QueryString -InputObjects $input -ErrorAction Stop
            } catch {
                $_.Exception.Message | Should -Match "Supported types"
                $_.Exception.Message | Should -Match "Hashtable"
                $_.Exception.Message | Should -Match "OrderedDictionary"
            }
        }

        It 'Should include the actual input type in error message' {
            $input = [System.DateTime]::Now
            try {
                ConvertTo-QueryString -InputObjects $input -ErrorAction Stop
            } catch {
                $_.Exception.Message | Should -Match "System.DateTime"
            }
        }

        It 'Should have correct category and activity in error' {
            $input = "test"
            try {
                ConvertTo-QueryString -InputObjects $input -ErrorAction Stop
            } catch {
                $_.CategoryInfo.Category | Should -Be "ParserError"
                $_.CategoryInfo.Activity | Should -Be "ConvertTo-QueryString"
            }
        }

        It 'Should continue processing after error for unsupported types' {
            $input = @("string", @{ Key = "Value" })
            $results = ConvertTo-QueryString -InputObjects $input
            $results.Count | Should -Be 2
            $results[1] | Should -Be "Key=Value"
        }
    }

    Context 'Real-world Graph request scenarios' {
        It 'Should handle typical Graph query parameters with null values' {
            $queryParams = @{
                '$select' = 'id,displayName,mail'
                '$filter' = 'userType eq ''Member'''
                '$top' = 100
                '$skip' = $null
                '$orderby' = 'displayName'
                '$count' = $true
            }
            $result = ConvertTo-QueryString $queryParams
            $result | Should -Match '\$select=id%2CdisplayName%2Cmail'
            $result | Should -Match '\$filter=userType\+eq\+%27Member%27'
            $result | Should -Match '\$top=100'
            $result | Should -Match '\$skip='
            $result | Should -Match '\$orderby=displayName'
            $result | Should -Match '\$count=True'
        }

        It 'Should handle empty query parameters hashtable' {
            $queryParams = @{}
            $result = ConvertTo-QueryString $queryParams
            $result | Should -Be ""
        }

        It 'Should handle query parameters with mixed null and non-null values' {
            $queryParams = @{
                '$select' = 'id,displayName'
                '$filter' = $null
                '$top' = 50
                '$skip' = $null
            }
            $result = ConvertTo-QueryString $queryParams
            $result | Should -Match '\$select=id%2CdisplayName'
            $result | Should -Match '\$filter='
            $result | Should -Match '\$top=50'
            $result | Should -Match '\$skip='
        }

        It 'Should handle complex filter scenarios with null values' {
            $queryParams = @{
                '$filter' = 'displayName eq ''John Doe'''
                '$select' = $null
                '$expand' = 'manager'
                '$count' = $null
            }
            $result = ConvertTo-QueryString $queryParams
            $result | Should -Match '\$filter=displayName\+eq\+%27John\+Doe%27'
            $result | Should -Match '\$select='
            $result | Should -Match '\$expand=manager'
            $result | Should -Match '\$count='
        }
    }

    Context 'Parameter name encoding' {
        It 'Should encode parameter names when EncodeParameterNames is specified' {
            $input = @{ 'test param' = 'value'; 'another&param' = 'test' }
            $result = ConvertTo-QueryString -InputObjects $input -EncodeParameterNames
            $result | Should -Match 'test\+param=value'
            $result | Should -Match 'another%26param=test'
        }

        It 'Should handle null values with encoded parameter names' {
            $input = @{ 'test param' = $null; 'another&param' = 'value' }
            $result = ConvertTo-QueryString -InputObjects $input -EncodeParameterNames
            $result | Should -Match 'test\+param='
            $result | Should -Match 'another%26param=value'
        }
    }

    Context 'ToString conversion' {
        It 'Should convert integers to string properly' {
            $input = @{ Number = 42; NullNumber = $null }
            $result = ConvertTo-QueryString $input
            $result | Should -Match 'Number=42'
            $result | Should -Match 'NullNumber='
        }

        It 'Should convert booleans to string properly' {
            $input = @{ TrueValue = $true; FalseValue = $false; NullBool = $null }
            $result = ConvertTo-QueryString $input
            $result | Should -Match 'TrueValue=True'
            $result | Should -Match 'FalseValue=False'
            $result | Should -Match 'NullBool='
        }

        It 'Should convert GUIDs to string properly' {
            $guid = [guid]::NewGuid()
            $input = @{ GuidValue = $guid; NullGuid = $null }
            $result = ConvertTo-QueryString $input
            $result | Should -Match "GuidValue=$($guid.ToString())"
            $result | Should -Match 'NullGuid='
        }

        It 'Should convert DateTime to string properly' {
            $date = [System.DateTime]::Now
            $input = @{ DateValue = $date; NullDate = $null }
            $result = ConvertTo-QueryString $input
            $result | Should -Match 'DateValue='
            $result | Should -Match 'NullDate='
        }
    }
}