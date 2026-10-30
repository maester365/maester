# Guards the single source of truth for the repository's AI agents and skills: .github/agents/*.agent.md and
# .github/skills/*/SKILL.md. The Claude Code copies and website/docs/agents-and-skills.md are generated from them
# by build/github/Update-AgentFiles.ps1. When this fails, run that script and commit the result.
Describe 'Agent and skill files' {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
        $script:Generator = Join-Path $script:RepoRoot 'build/github/Update-AgentFiles.ps1'
    }

    It 'has generated Claude Code files and docs page that match the .github sources' {
        { & $script:Generator -Check } | Should -Not -Throw
    }
}
