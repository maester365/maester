# AI Tools

This folder contains various AI related scripts that were used for one-off tasks or experiments such as the initial generation of Severity for tests and product info.

## Skill

The Claude skill and GitHub Copilot custom agent/skill are currently maintained as separate files because of their separate locations. Their contents are 99% mirrored, with the sole exception being a different relative URI that is used to point to the CONTRIBUTING.md guide.

- .claude/agents/maester-test-expert.md
- .github/skills/maester-test-expert/SKILL.md

An ideal future enhancement would be to maintain a single skill file in this directory and use the build workflow to push changes to the folders dedicated to Claude and GitHub.

## GitHub Copilot Agents

Custom agents for GitHub Copilot have been created as well:

- .github/agents/maester-issue-manager.agent.md
- .github/agents/maester-test-planner.agent.md
- .github/agents/maester-test-expert.agent.md

The **issue manager** and **planner** agents are designed primarily to support the **Maester Test Expert** skill and not be invoked by users directly. The **test-expert** agent may prove to be redundant, and is for now included as a proxy to the skill until the most effective entry point for GitHub Copilot is determined.

## Instructions

Standardized instructions for AI models may be added to the project after being vetted by the core team. These should be used to help ensure that the project is maintained with consistent patterns and practices.

Instructions may also be utilized by MCP servers that maintainers and contributers utilize. In general, these will be excluded by `.gitignore` unless directly determined otherwise.
