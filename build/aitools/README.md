# AI Tools

This folder contains various AI related scripts that were used for one-off tasks or experiments such as the initial generation of Severity for tests and product info. They are kept as a record. The severity and the other attributes of a test are now chosen with the [attribute rubric](../../website/docs/writing-tests/attribute-rubric.md) and checked on pull requests by the attribute review (`build/review/Invoke-MtAttributeReview.ps1`).

## Skill

The skill is maintained in one file, which GitHub Copilot reads directly:

- .github/skills/maester-test-expert/SKILL.md

Claude Code reaches it through two pointer files. Each holds a description and a link to the skill and no rules of its own, so there is no second copy to keep in step:

- .claude/skills/maester-test-expert/SKILL.md
- .claude/agents/maester-test-expert.md

The descriptions in their front matter repeat the skill's. Update them when the skill's description changes.

## GitHub Copilot Agents

Custom agents for GitHub Copilot have been created as well:

- .github/agents/maester-issue-manager.agent.md
- .github/agents/maester-test-planner.agent.md
- .github/agents/maester-test-expert.agent.md

The **issue manager** and **planner** agents are designed primarily to support the **Maester Test Expert** skill and not be invoked by users directly. The **test-expert** agent may prove to be redundant, and is for now included as a proxy to the skill until the most effective entry point for GitHub Copilot is determined.

The issue manager and planner agents have Claude Code twins, `.claude/agents/maester-issue-manager.md` and `.claude/agents/maester-test-planner.md`, with the same body and their own front matter. Edit both files of a pair together.

## Instructions

Standardized instructions for AI models may be added to the project after being vetted by the core team. These should be used to help ensure that the project is maintained with consistent patterns and practices.

Instructions may also be utilized by MCP servers that maintainers and contributers utilize. In general, these will be excluded by `.gitignore` unless directly determined otherwise.
