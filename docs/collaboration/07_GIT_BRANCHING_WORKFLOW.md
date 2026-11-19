# Git 브랜칭 전략 및 Pull Request (PR) 협업 가이드

## 1. 개요 및 협업 원칙
모든 팀원(Claude, Codex, Antigravity)은 작업 시 `main` 브랜치에 직접 커밋/푸시하지 않고, **기능별 모듈 브랜치**를 생성하여 작업한 뒤 **Pull Request (PR)**를 생성합니다.
- **총괄 검수 및 머지 (팀장 Antigravity 전담)**: 팀원들이 올린 PR 및 브랜치를 Antigravity가 테스트 및 코드 리뷰 후 `main`에 머지(Merge)하고 프로토타입 빌드를 갱신합니다.

---

## 2. 모듈별 브랜치 명명 규칙 (Branch Naming Convention)

| 모듈 영역 | 브랜치 접두사 / 예시 | 담당 에이전트 예시 |
| :--- | :--- | :--- |
| **UI / UX / 연출** | `feature/ui-*` (예: `feature/ui-glass-hud`) | Claude Code (`t3j`) |
| **물리 / 메커닉스 / 판정** | `feature/physics-*` (예: `feature/physics-trajectory`) | OpenAI Codex (`t3k`) |
| **3D 모델 / 에셋 / 애니메이션** | `feature/assets-*` (예: `feature/assets-dice-model`) | OpenAI Codex / Antigravity |
| **시스템 통합 / 빌드 / 릴리즈** | `feature/integration-*` 또는 `release/*` | Antigravity (팀장) |

---

## 3. 작업 파이프라인 (Step-by-Step Workflow)

### Step 1: 최신 `main` 동기화 및 작업 브랜치 분기
```bash
git checkout main
git pull origin main
git checkout -b feature/<모듈명>
```

### Step 2: 모듈 단위 개발 및 로컬 테스트 검증
- 담당 모듈 파일만 분리하여 수정 (타 모듈과의 결합도 최소화).
- 헤드리스 검증 명령 실행:
  ```powershell
  & ".\tools\godot\Godot_v4.6-stable_win64_console.exe" --headless --path . --script tests/test_die_3d.gd
  & ".\tools\godot\Godot_v4.6-stable_win64_console.exe" --headless --path . --script tests/test_game.gd
  ```

### Step 3: 브랜치 커밋 및 원격 푸시
```bash
git add <작업파일들>
git commit -m "feat(<모듈명>): 작업 세부 내용 기술"
git push -u origin feature/<모듈명>
```

### Step 4: Pull Request(PR) 요청 및 팀장(Antigravity) 검수/정리
- PR을 생성하고 팀장(Antigravity)에게 Herdr로 브랜치명과 작업 내용을 노티.
- 팀장 Antigravity는 다음 검수를 수행:
  1. 단위 테스트 및 회귀 테스트 통과 여부 검증
  2. 코드 컨플릭트(Conflict) 해결 및 모듈 호환성 검토
  3. `main` 브랜치로 병합(Merge) 및 최신 프로토타입 실행 파일 리빌드 배포
