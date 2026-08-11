function Get-MtDynamicGroupRuleAnalysis {
    <#
    .SYNOPSIS
    Extracts security-relevant properties and operators from a dynamic membership rule.

    .DESCRIPTION
    Parses property references without attempting to evaluate the complete Boolean expression.
    Classifies potentially influenceable user properties, custom attributes, and memberOf rules.

    .EXAMPLE
    Get-MtDynamicGroupRuleAnalysis -MembershipRule '(user.displayName -startsWith "Admin")'
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $MembershipRule
    )

    if ([string]::IsNullOrWhiteSpace($MembershipRule)) {
        return
    }

    $InfluenceableProperties = @(
        'city', 'companyname', 'country', 'department', 'displayname', 'givenname',
        'jobtitle', 'mail', 'mailnickname', 'mobile', 'othermails', 'preferredlanguage',
        'proxyaddresses', 'state', 'surname', 'telephonenumber', 'userprincipalname'
    )
    $OperatorNames = @(
        'all', 'any', 'contains', 'endswith', 'eq', 'ge', 'in', 'le', 'match', 'ne',
        'notcontains', 'notendswith', 'notin', 'notmatch', 'notstartswith', 'startswith'
    ) -join '|'
    $ExpressionPattern = [regex]::new(
        "(?i)\b(?<ObjectType>user|device)\.(?<Property>[a-z][a-z0-9_]*)" +
        "\s+(?<Operator>-?(?:$OperatorNames))\b"
    )
    $NestedOperatorPattern = [regex]::new(
        "(?i)\b_\s+(?<Operator>-?(?:$OperatorNames))\b"
    )
    $GuidPattern = [regex]::new(
        '(?i)\b[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\b'
    )
    $ExpressionMatches = $ExpressionPattern.Matches($MembershipRule)
    $Analysis = for ($Index = 0; $Index -lt $ExpressionMatches.Count; $Index++) {
        $ExpressionMatch = $ExpressionMatches[$Index]
        $ObjectType = $ExpressionMatch.Groups['ObjectType'].Value.ToLowerInvariant()
        $Property = $ExpressionMatch.Groups['Property'].Value
        $NormalizedProperty = $Property.ToLowerInvariant()
        $Operator = $ExpressionMatch.Groups['Operator'].Value.ToLowerInvariant()
        $NextIndex = if ($Index + 1 -lt $ExpressionMatches.Count) {
            $ExpressionMatches[$Index + 1].Index
        } else {
            $MembershipRule.Length
        }
        $SegmentLength = $NextIndex - $ExpressionMatch.Index
        $Segment = $MembershipRule.Substring($ExpressionMatch.Index, $SegmentLength)
        $NestedOperator = $NestedOperatorPattern.Match($Segment)
        if ($NestedOperator.Success) {
            $Operator += "/$($NestedOperator.Groups['Operator'].Value.ToLowerInvariant())"
        }

        $Category = 'Other'
        if ($NormalizedProperty -eq 'memberof') {
            $Category = 'MemberOf'
        } elseif ($ObjectType -eq 'user' -and $NormalizedProperty -in $InfluenceableProperties) {
            $Category = 'PotentiallyInfluenceable'
        } elseif ($ObjectType -eq 'user' -and (
                $NormalizedProperty -match '^extensionattribute(?:[1-9]|1[0-5])$' -or
                $NormalizedProperty -match '^extension_[a-z0-9_]+$')) {
            $Category = 'CustomAttribute'
        }

        $ReferencedGroupIds = if ($Category -eq 'MemberOf') {
            @($GuidPattern.Matches($Segment).Value | Select-Object -Unique)
        } else {
            @()
        }
        [pscustomobject]@{
            ObjectType         = $ObjectType
            Property           = $Property
            Operator           = $Operator
            Category           = $Category
            UsesPatternMatch   = $Operator -match 'match|contains|startswith|endswith'
            ReferencedGroupIds = $ReferencedGroupIds
        }
    }

    return $Analysis
}
