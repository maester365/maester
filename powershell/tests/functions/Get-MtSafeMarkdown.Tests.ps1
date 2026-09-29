Describe 'Get-MtSafeMarkdown' {
    It 'Returns empty and null input unchanged' {
        Get-MtSafeMarkdown -Text '' | Should -BeNullOrEmpty
        Get-MtSafeMarkdown -Text $null | Should -BeNullOrEmpty
    }

    It 'Leaves ordinary text unchanged' {
        Get-MtSafeMarkdown 'Contoso HR App 2.0' | Should -Be 'Contoso HR App 2.0'
    }

    It 'Escapes markdown syntax: <Text>' -ForEach @(
        @{ Text = '![x](https://attacker.example/p.png)'; Expected = '\!\[x\]\(https://attacker.example/p.png\)' }
        @{ Text = '[Sign in](https://phish.example)'; Expected = '\[Sign in\]\(https://phish.example\)' }
        @{ Text = 'a | b'; Expected = 'a \| b' }
        @{ Text = '**bold** _em_ ~~del~~ `code`'; Expected = '\*\*bold\*\* \_em\_ \~\~del\~\~ \`code\`' }
        @{ Text = '<img src=x>'; Expected = '\<img src=x\>' }
        @{ Text = 'back\slash'; Expected = 'back\\slash' }
    ) {
        Get-MtSafeMarkdown $Text | Should -BeExactly $Expected
    }

    It 'Replaces line breaks so values stay on one line' {
        Get-MtSafeMarkdown "line1`r`n| --- |`nline3" | Should -BeExactly 'line1 \| --- \| line3'
    }
}
