<#
.SYNOPSIS
    Gets the value of a specific tag from the current Pester test.

.DESCRIPTION
    This function extracts tag values from the current Pester test context.
    It looks for tags in the format 'TagName:Value' and returns the value part.
    If no matching tag is found in the current test, it checks the parent block.

.EXAMPLE
    Get-MtPesterTagValue -TagName 'Severity'

    Returns the severity value (e.g. 'Critical', 'High') if a tag like 'Severity:Critical' exists.

.PARAMETER TagName
    The name of the tag to look for (without the colon).

#>
function Get-MtPesterTagValue {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $TagName
    )

    # Check if we're running in a Pester context
    if (-not $____Pester) {
        Write-Verbose "Not running in a Pester context."
        return $null
    }

    try {
        # Check if the test has the specified tag
        $tagPattern = "$TagName`:"
        $matchingTag = $____Pester.CurrentTest.Tag | Where-Object { $_ -match $tagPattern }

        # If not found in current test, check parent block
        if ([string]::IsNullOrEmpty($matchingTag)) {
            $matchingTag = $____Pester.CurrentTest.Block.Tag | Where-Object { $_ -match $tagPattern }
        }

        if ($matchingTag) {
            # Extract the tag value and trim it
            $tagValue = $matchingTag -replace $tagPattern, ''
            return $tagValue.Trim()
        }
    }
    catch {
        Write-Verbose "Error getting tag value for '$TagName': $_"
    }

    return $null
}