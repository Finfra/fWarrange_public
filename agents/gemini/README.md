# fWarrange Gemini CLI Agents

This directory contains the workflows and skills specific to the Gemini CLI agent (`.agent`) for the **fWarrange** project.

## Directory Structure

- `workflows/`: Contains Gemini CLI workflows (`.md`)
- `skills/`: Contains Gemini CLI skills (including `SKILL.md` and related scripts)

## Manual Installation

To install these workflows and skills into your local project environment:

```bash
# 1. Create the .agent directory if it doesn't exist
mkdir -p .agent

# 2. Copy workflows
cp -r _public/agents/gemini/workflows .agent/workflows

# 3. Copy skills
cp -r _public/agents/gemini/skills .agent/skills
```

After copying, the Gemini CLI agent will automatically detect and load the available workflows and skills based on your `.agent` configuration.
