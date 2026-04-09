---
title: fWarrange Claude Code Plugin
description: fWarrange Claude Code 플러그인 통합 레포지터리 안내
date: 2026-03-26
---

# 새 위치

fWarrange Claude Code 플러그인은 통합 플러그인 레포지토리에서 관리됩니다:

* **레포지토리**: [Finfra/f-claude-plugins](https://github.com/Finfra/f-claude-plugins)
* **경로**: `fWarrange/`

# 설치 방법

```
/plugin marketplace add Finfra/f-claude-plugins
/plugin install fwarrange@f-claude-plugins
```

# 수동 설치

```bash
git clone https://github.com/Finfra/f-claude-plugins.git
cp -r f-claude-plugins/fWarrange/plugin.json .claude-plugin/plugin.json
cp -r f-claude-plugins/fWarrange/skills .claude/skills
```
