# fWarrange Gemini Agent Integrations

This directory contains specialized workflows and skills for the Gemini CLI to seamlessly interact with the fWarrange macOS application via its built-in REST API.

By adding these integrations to your Gemini workspace, you can instruct your agent to naturally manage your window layouts while fWarrange is running in the background.

## Directory Structure

- `workflows/`: Contains Gemini CLI workflows (`.md`)
- `skills/`: Contains Gemini CLI skills (including `SKILL.md` and related scripts)

## Installation

To enable your Gemini CLI environment to use these capabilities, you need to copy the `skills` and `workflows` to your active `.agent` directory.

From the root of this repository, run the following commands:

1. **Install Skills:**
   ```bash
   mkdir -p .agent/skills
   cp -r _public/agents/gemini/skills/* .agent/skills/
   ```

2. **Install Workflows:**
   ```bash
   mkdir -p .agent/workflows
   cp -r _public/agents/gemini/workflows/* .agent/workflows/
   ```

3. **Enable API in fWarrange:**
   - Ensure the fWarrange application is running.
   - Go to the app's **Settings (Preferences)**.
   - **Enable the REST API Server**. By default, it will run on port `3016` (localhost only).

## Usage Examples

Once installed, you can simply talk to the Gemini CLI to control your windows. Try commands like:

- *"List my saved fWarrange layouts."*
- *"Capture my current windows and save the layout as 'DevSetup'."*
- *"Restore the 'DevSetup' layout."*
- *"Delete the 'DevSetup' layout."*

Gemini will automatically utilize the `fwarrange-api` skill and `fwarrange-manage` workflow to execute the API calls in the background and report the results back to you.
