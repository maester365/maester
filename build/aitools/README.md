# AI Tools

This folder contains various AI related scripts that were used for one-off tasks or experiments such as the initial generation of Severity for tests and product info. They are kept as a record. The severity and the other attributes of a test are now chosen with the [attribute rubric](../../website/docs/writing-tests/attribute-rubric.md) and checked on pull requests by the attribute review (`build/review/Invoke-MtAttributeReview.ps1`).

## Agents and skills

The agents and skills now have one source file each, which GitHub Copilot reads directly:
`.github/agents/<name>.agent.md` and `.github/skills/<name>/SKILL.md`. The Claude Code copies under
`.claude/agents/` and `.claude/skills/`, and the list at `website/docs/agents-and-skills.md`, are
generated from them by `build/github/Update-AgentFiles.ps1`. Edit the source file and run the script;
never edit a generated copy. See [Agents and skills](../../website/docs/agents-and-skills.md).

## Instructions

Standardized instructions for AI models may be added to the project after being vetted by the core team. These should be used to help ensure that the project is maintained with consistent patterns and practices.

Instructions may also be utilized by MCP servers that maintainers and contributers utilize. In general, these will be excluded by `.gitignore` unless directly determined otherwise.
