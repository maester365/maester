AI agents with generative orchestration should have custom instructions.

Agents that use generative orchestration (generative actions enabled) without custom instructions rely entirely on the LLM's default behavior. This increases the risk of prompt injection attacks, off-topic or harmful responses, and uncontrolled tool invocation. Custom instructions act as a system prompt that constrains the agent's behavior.

### How to fix

Open each flagged agent in Copilot Studio and add custom instructions that define the agent's purpose, boundaries, and behavioral constraints. At minimum, instructions should specify what the agent is allowed to do, what topics are off-limits, and how it should handle attempts to override its instructions.

Learn more: [Create and edit custom instructions](https://learn.microsoft.com/en-us/microsoft-copilot-studio/authoring-instructions)

<!--- Results --->
%TestResult%
