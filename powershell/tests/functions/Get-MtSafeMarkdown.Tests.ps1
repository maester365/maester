Describe 'Get-MtSafeMarkdown' {
    It 'Returns empty and null input unchanged' {
        Get-MtSafeMarkdown -Text '' | Should -BeNullOrEmpty
        Get-MtSafeMarkdown -Text $null | Should -BeNullOrEmpty
    }

    It 'Leaves ordinary text unchanged' {
        Get-MtSafeMarkdown 'Contoso HR App 2.0' | Should -Be 'Contoso HR App 2.0'
    }

    It 'Escapes markdown syntax: <Text>' -ForEach @(
        @{ Text = '![x](https://attacker.example/p.png)'; Expected = '\!\[x\]\(https\://attacker.example/p.png\)' }
        @{ Text = '[Sign in](https://phish.example)'; Expected = '\[Sign in\]\(https\://phish.example\)' }
        @{ Text = 'a | b'; Expected = 'a \| b' }
        @{ Text = '**bold** _em_ ~~del~~ `code`'; Expected = '\*\*bold\*\* \_em\_ \~\~del\~\~ \`code\`' }
        @{ Text = '<img src=x>'; Expected = '\<img src=x\>' }
        @{ Text = 'back\slash'; Expected = 'back\\slash' }
    ) {
        Get-MtSafeMarkdown $Text | Should -BeExactly $Expected
    }

    # GFM autolink literals are not markdown syntax, but the report renders with
    # `gfm: true`, so a bare URL, a `www.` host or an email in a tenant-controlled
    # name becomes a live link. The escapes below are consumed by the renderer, so
    # the reader sees the original text.
    It 'Escapes GFM autolink literals: <Text>' -ForEach @(
        @{ Text = 'Sign in at https://phish.example/login'; Expected = 'Sign in at https\://phish.example/login' }
        @{ Text = 'Sign in at http://phish.example/login'; Expected = 'Sign in at http\://phish.example/login' }
        @{ Text = 'Get it at ftp://phish.example/x'; Expected = 'Get it at ftp\://phish.example/x' }
        @{ Text = 'Sign in at www.phish.example/login'; Expected = 'Sign in at www\.phish.example/login' }
        @{ Text = 'Contact admin@phish.example'; Expected = 'Contact admin\@phish.example' }
        @{ Text = 'Write to mailto:admin@phish.example'; Expected = 'Write to mailto\:admin\@phish.example' }
        # Escaped case-insensitively on purpose. marked 18 does not autolink `WWW.`
        # today, but a backslash the renderer consumes costs nothing, and this does
        # not depend on that staying true.
        @{ Text = 'WWW.contoso.com'; Expected = 'WWW\.contoso.com' }
        # GFM accepts `_` immediately before the `www.`, and `_` is a word character, so a
        # word boundary before `www` does not match `_www.`: the first pass escapes the
        # underscore, the renderer consumes that backslash, and the autolink comes back.
        # Reported by @SamErde on #2715 with a Marked + DOMPurify reproduction.
        @{ Text = '_www.phish.example/login'; Expected = '\_www\.phish.example/login' }
        @{ Text = 'a_www.phish.example/login'; Expected = 'a\_www\.phish.example/login' }
        # The other characters GFM accepts in that position, for the same reason.
        @{ Text = '*www.phish.example'; Expected = '\*www\.phish.example' }
        @{ Text = '~www.phish.example'; Expected = '\~www\.phish.example' }
        @{ Text = '(www.phish.example'; Expected = '\(www\.phish.example' }
        # Over-escaped on purpose: GFM does not autolink `awww.`, but the backslash is
        # consumed by the renderer, so covering it costs nothing and keeps the rule simple.
        @{ Text = 'awww.host'; Expected = 'awww\.host' }
    ) {
        Get-MtSafeMarkdown $Text | Should -BeExactly $Expected
    }

    It 'Leaves a plain host alone, so the escape does not widen to every dot: <Text>' -ForEach @(
        @{ Text = 'Cuenta de contoso.com' }
        @{ Text = 'mail.contoso.com' }
    ) {
        # GFM only autolinks a host when it starts with `www.`, so a plain domain needs
        # no escaping. This guards the new rule from growing into every dot in every
        # tenant name, which would be noise in the JSON output for no benefit.
        Get-MtSafeMarkdown $Text | Should -BeExactly $Text
    }

    It 'Replaces line breaks so values stay on one line' {
        Get-MtSafeMarkdown "line1`r`n| --- |`nline3" | Should -BeExactly 'line1 \| --- \| line3'
    }
}
