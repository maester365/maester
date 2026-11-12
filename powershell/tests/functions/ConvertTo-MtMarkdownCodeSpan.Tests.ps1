Describe 'ConvertTo-MtMarkdownCodeSpan' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
    }

    It 'Returns an empty string for <Name> input' -ForEach @(
        @{ Name = 'null'; Text = $null }
        @{ Name = 'empty'; Text = '' }
        @{ Name = 'blank'; Text = '   ' }
    ) {
        InModuleScope Maester -Parameters @{ Text = $Text } {
            ConvertTo-MtMarkdownCodeSpan -Text $Text
        } | Should -BeExactly ''
    }

    It 'Formats <Name>' -ForEach @(
        @{ Name = 'a membership rule'; Text = '(user.department -eq "Sales")'; Expected = '` (user.department -eq "Sales") `' }
        @{ Name = 'a Markdown link as typed'; Text = '[Sign in](https://phish.example)'; Expected = '` [Sign in](https://phish.example) `' }
        @{ Name = 'HTML as typed'; Text = '<img src=x>'; Expected = '` <img src=x> `' }
        @{ Name = 'a backtick with a longer delimiter'; Text = 'a`b'; Expected = '`` a`b ``' }
        @{ Name = 'two backticks with a longer delimiter'; Text = 'a``b'; Expected = '``` a``b ```' }
        @{ Name = 'a leading backtick'; Text = '`a'; Expected = '`` `a ``' }
        @{ Name = 'line breaks as spaces'; Text = "a`r`nb`nc"; Expected = '` a b c `' }
        @{ Name = 'a pipe outside a table as typed'; Text = 'a|b'; Expected = '` a|b `' }
    ) {
        InModuleScope Maester -Parameters @{ Text = $Text } {
            ConvertTo-MtMarkdownCodeSpan -Text $Text
        } | Should -BeExactly $Expected
    }

    It 'Escapes pipes for a table cell: <Name>' -ForEach @(
        @{ Name = 'a pipe'; Text = 'user.department -match "Sales|HR"'; Expected = '` user.department -match "Sales\|HR" `' }
        @{ Name = 'an escaped pipe, left as is'; Text = 'a\|b'; Expected = '` a\|b `' }
        @{ Name = 'a pipe after an escaped backslash'; Text = 'a\\|b'; Expected = '` a\\\|b `' }
    ) {
        InModuleScope Maester -Parameters @{ Text = $Text } {
            ConvertTo-MtMarkdownCodeSpan -Text $Text -TableCell
        } | Should -BeExactly $Expected
    }
}
