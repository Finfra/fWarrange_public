# fWarrange Gemini CLI 에이전트

이 디렉토리는 **fWarrange** 프로젝트의 Gemini CLI 에이전트(`.agent`) 전용 워크플로우와 스킬을 포함하고 있습니다. 

## 디렉토리 구조

- `workflows/`: Gemini CLI 워크플로우 (`.md`)
- `skills/`: Gemini CLI 스킬 (`SKILL.md` 및 관련 스크립트 포함)

## 수동 설치 방법

로컬 프로젝트 환경에 이 워크플로우와 스킬을 설치하려면 아래 명령어를 사용하세요:

```bash
# 1. .agent 디렉토리가 없다면 생성
mkdir -p .agent

# 2. 워크플로우 복사
cp -r _public/agents/gemini/workflows .agent/workflows

# 3. 스킬 복사
cp -r _public/agents/gemini/skills .agent/skills
```

복사 후, Gemini CLI 에이전트는 `.agent` 폴더 내의 설정과 파일들을 기반으로 워크플로우와 스킬을 자동으로 인식하고 로드합니다.
