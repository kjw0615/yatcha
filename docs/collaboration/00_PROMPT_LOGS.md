# 에이전트 전송 프롬프트 및 진행 관리 기록 (Prompt Logs)

## Prompt Session #1 - 2026-11-19: 3D 리마스터 역할 분담 및 작업 착수 지시

### 1. Claude Code (`t3j`) 대상 프롬프트
- **전송 대상**: Herdr terminal `t3j` (Claude Code)
- **목적**: 3D 요트 다이스 조작법 및 UX/인터랙션 기획서 수립 (`docs/collaboration/02_CLAUDE_3D_DESIGN_SPEC.md`)
- **프롬프트 내용**:
```text
[요청: 3D Yacht Dice 게임플레이 조작법 및 UX/HUD 기획서 작성]
우리는 기존 2D Godot 요트 다이스(Yacht Club) 게임을 3D 물리 기반 인터랙티브 게임으로 탈바꿈하는 작업을 시작합니다.
SKILLS_OVERVIEW.md의 파이프라인에 따라 Claude Code는 '기획, 조작 스펙 정의 및 최종 시각/UX 검수'를 전담합니다.

규칙(12개 족보, 점수 규칙 scripts/rules.gd)은 100% 동일하게 유지합니다.
다음을 구체적으로 설계하여 'docs/collaboration/02_CLAUDE_3D_DESIGN_SPEC.md' 파일로 작성해주세요:
1. 3D 시점 및 카메라 뷰 (예: 부드러운 쿼터뷰/탑뷰 아이소메트릭, 컵 흔들 때와 점수판 볼 때의 반응)
2. 새로운 3D 조작법:
   - 주사위 굴리기 (스페이스바 또는 컵 클릭/드래그 흔들고 놓기)
   - 주사위 킵(Keep) / 롤(Roll) 인터랙션 (마우스 클릭/드래그로 킵 구역으로 이동, 호버 효과)
   - 남은 리롤 횟수(3회) 표시 방식
3. 3D 공간과 조화되는 UI/HUD 레이아웃 (반응형 점수표, 글래스모피즘 테마)
4. 사운드 및 햅틱/시각적 피드백 아이디어 (물리 충돌음, 주사위 슬립 판정 등)

작성 후 완료 메시지를 회신해 주세요.
```

---

### 2. OpenAI Codex (`t3k`) 대상 프롬프트
- **전송 대상**: Herdr terminal `t3k` (Codex)
- **목적**: 3D 주사위 물리(RigidBody3D) 및 상단 눈 판정 알고리즘(`scripts/die_3d.gd`) 구현
- **프롬프트 내용**:
```text
[요청: Godot 4.6 3D 주사위 물리 및 상단 눈 판정 스크립트 'scripts/die_3d.gd' 구현]
우리는 기존 2D Godot 요트 다이스 게임을 3D 물리 기반 인터랙티브 게임으로 리마스터하고 있습니다.
SKILLS_OVERVIEW.md의 파이프라인에 따라 Codex는 '3D 물리 엔지니어링 및 주사위 정밀 판정 로직'을 전담합니다.

Godot 4.6 GDScript로 작동하는 'scripts/die_3d.gd' (extends RigidBody3D)를 구현해주세요.
핵심 요구사항:
1. 물리적 굴림: roll(impulse, torque) 함수를 통해 무작위 충격량과 회전 토크를 받아 주사위가 자연스럽게 굴러가도록 설정
2. 주사위 눈 윗면 판정 (get_top_face() -> int):
   - 표준 D6 주사위 규격: (1의 반대편 6, 2의 반대편 5, 3의 반대편 4)
   - 주사위의 글로벌 로컬 축(Basis.x, Basis.y, Basis.z 등)과 Vector3.UP의 내적(dot product)을 비교하여 가장 위를 향하는 면의 숫자(1~6)를 정확히 판별
3. 정지 판정: linear_velocity와 angular_velocity가 일정 임계값 이하로 떨어지거나 sleeping 상태가 되었을 때 'stopped' 시그널 방출
4. 킵(Keep) 모드 지원: 킵 상태일 때는 freeze/freeze_mode를 활성화하고, 지정된 킵 슬롯 위치(Transform)로 부드럽게 보간(Tween) 이동
5. 구현 완료 후 'docs/collaboration/03_CODEX_3D_DIE_REPORT.md'에 구현 세부사항을 요약해주세요.

작업 완료 후 알려주세요.
```

## Prompt Session #2 - 2026-11-19: 3D 보드판 탈출 방지벽, 6면 주사위 핍 텍스처, 컵 흔들기 조작 추가

### 1. 사용자 요구사항
1. 주사위가 보드판 밖으로 튕겨져 나가지 않게 조치
2. 주사위에 숫자(핍 눈) 표시
3. 주사위 통(Cup) 안에 넣고 흔들다가 원하는 타이밍에 던질 수 있는 메커닉 구현

### 2. 구현 내역
1. **보드판 탈출 방지**:
   - `scenes/board_3d.tscn`: 벽 높이를 2.5m -> 5.0m로 2배 확장하고 보이지 않는 상단 물리 천장(`TrayCeiling` StaticBody3D) 추가.
   - `scenes/die_3d.tscn`: 선형/각속도 댐핑(linear_damp 0.25, angular_damp 0.35) 및 반발계수 조절.
2. **주사위 6면 핍(숫자) 텍스처**:
   - `assets/textures/die_face_1.png` ~ `die_face_6.png` 렌더링 및 `die_3d.tscn` 6면에 정밀 매핑 (1의 반대 6, 2의 반대 5, 3의 반대 4).
3. **주사위 통(Cup) 흔들기 및 던지기 조작**:
   - `scripts/board_3d.gd`: `DiceCup` 노드 및 반투명 3D 컵 구현, `start_shaking_cup()`, `release_and_throw_cup()`, 동적 파워 충격량 전달.
   - `scripts/main_3d.gd`: 스페이스바 길게 누르기(또는 마우스 버튼 누르고 있기)로 컵을 흔들고, 키를 떼는 순간 원하는 타이밍에 트레이 안으로 주사위를 투척.
4. **프로토타입 재빌드**:
   - `build/prototype/YachtClub3D.exe` 및 `.pck` 리빌드 완료.

## Prompt Session #3 - 2026-11-19: 사용자 피드백 3종(탈출 방지, 숫자 표시, 컵 던지기) 전담 분담 지시

### 1. Claude Code (`t3j`) 대상 지시
- **목적**: 컵 흔들기 게이지/타이밍 연출 및 HUD 파워 피드백, 시각적 주사위 숫자 식별성 검수
- **프롬프트**:
```text
[공동 작업 요청: 주사위 통 흔들기 HUD 연출 및 3D 시각 피드백 고도화]
사용자의 피드백 3가지가 전달되었습니다:
1) 주사위가 보드판 밖으로 나가지 않도록 방지
2) 주사위에 6면 숫자(눈) 명확히 표시
3) 특정 통 안에 주사위를 넣어서 흔들다가 원하는 타이밍에 던질 수 있는 조작

이 중 Claude Code는 SKILLS_OVERVIEW.md의 'UI/UX 및 시각 검수' 역할에 따라 다음을 전담해 주세요:
1. `scripts/main_3d.gd`의 HUD에 통을 흔들 때 실시간으로 흔들리는 파워/게이지와 타이밍 가이드(예: 흔들기 게이지 바 또는 텍스트 피드백) 연출 강화
2. 주사위 눈 텍스처와 보드판, 컵의 조화 및 시각적 가독성 검토
3. 작업 완료 후 'docs/collaboration/05_CLAUDE_CUP_FEEDBACK.md'에 변경 내용 및 검수 보고서를 작성해 주세요.
```

### 2. OpenAI Codex (`t3k`) 대상 지시
- **목적**: 주사위 물리 충돌 파라미터 최적화(바운스/마찰/각속도 제한) 및 컵 투척 물리 궤적/바운딩 박스 잠금
- **프롬프트**:
```text
[공동 작업 요청: 주사위 탈출 완전 방지 물리 파라미터 최적화 및 컵 투척 궤적 개선]
사용자의 피드백 3가지가 전달되었습니다:
1) 주사위가 보드판 밖으로 절대 튕겨져 나가지 않도록 물리 제어
2) 주사위에 6면 숫자(눈) 표시에 따른 판정 정확도 유지
3) 주사위 통에서 던질 때의 물리적 충격량 및 궤적 곡선 고도화

이 중 Codex는 SKILLS_OVERVIEW.md의 '3D 물리 엔지니어링 및 주사위 역학' 역할에 따라 다음을 전담해 주세요:
1. `scripts/die_3d.gd` 및 `scripts/board_3d.gd`의 충돌 마찰(friction), 반발(bounce), linear_damp, angular_damp 파라미터 조정 및 트레이 경계 클램프(Clamping) 안전장치 보강
2. 컵에서 쏟아질 때 주사위 간 충돌로 인해 발생하는 과도한 수직 튀어오름(Impulse spike) 방지
3. `tests/test_die_3d.gd` 실행을 통해 기존 42개 물리/눈 판정 테스트가 100% 정상 통과하는지 검증
4. 작업 완료 후 'docs/collaboration/06_CODEX_PHYSICS_IMPROVEMENTS.md'에 보고서를 작성해 주세요.
```

## Prompt Session #4 - 2026-11-19: 모듈형 Git 브랜칭 및 PR 워크플로우 전환 지시

### 1. 사용자 요구사항
- 모듈화 개발 원칙 적용
- 각자 기능별 브랜치를 분기하여 작업 후 원격 푸시 및 Pull Request(PR) 제출
- 팀장 Antigravity가 PR을 검토·정리하여 `main` 브랜치에 병합 및 빌드 관리

### 2. 팀원(Claude & Codex) 공지 프롬프트
- **Claude (`t3j`) 대상 공지**:
  - `main` 직접 작업 금지. UI/HUD/연출 작업 시 `feature/ui-*` 브랜치 분기 후 PR 제출 지시.
- **Codex (`t3k`) 대상 공지**:
  - `main` 직접 작업 금지. 물리/알고리즘/3D 에셋 작업 시 `feature/physics-*` 브랜치 분기 후 PR 제출 지시.

## Prompt Session #5 - 2026-11-19: 자체 종합 QA(품질 보증) 담당 지정 및 결함 도출 지시

### 1. Claude Code (`t3j`) - [QA 총괄 리드: UX, 조작, 시각, 게임 루프 전담]
- **브랜치 규칙**: 버그 수정 및 개선 시 `feature/ui-qa-fixes` 브랜치 사용
- **프롬프트**:
```text
[역할 지정: 3D Yacht Dice 자체 QA 총괄 리드 담당]
팀장 Antigravity입니다. SKILLS_OVERVIEW.md에 명시된 시각/UX 검수 책임에 따라, Claude Code를 이번 프로젝트의 '자체 QA 총괄 리드'로 지정합니다.

검증 범위:
1. 조작 및 게임 루프 UX:
   - Space 연타 및 마우스 연타 시의 비정상 입력(레이스 컨디션) 처리
   - 킵(Keep) 토글 및 점수 확정 플로우의 직관성
2. 3D 시각/HUD 연출:
   - 컵 흔들기 파워 게이지와 타이밍 피드백, 6면 주사위 눈 가독성
   - 'docs/collaboration/02_CLAUDE_3D_DESIGN_SPEC.md' 기획서와의 정합성 검토
3. 발견된 결함 및 개선사항을 'docs/collaboration/08_SELF_QA_REPORT.md'의 Claude 섹션에 정리해 주시고, 코드 수정이 필요한 경우 반드시 'feature/ui-qa-fixes' 브랜치를 분기하여 작업 후 PR을 요청해 주세요.
```

### 2. OpenAI Codex (`t3k`) - [엔지니어링 & 3D 물리 QA 담당]
- **브랜치 규칙**: 버그 수정 및 테스트 보강 시 `feature/physics-qa-tests` 브랜치 사용
- **프롬프트**:
```text
[역할 지정: 3D 물리 엔진 & 극한 상황 QA 엔지니어 담당]
팀장 Antigravity입니다. 이번 자체 QA에서 Codex는 '3D 물리 및 엔진 극한 상황 QA'를 전담합니다.

검증 범위:
1. 물리 터널링 및 충돌 극한 테스트:
   - MAX 파워(초고속 투척) 및 최대 각속도 회전 시 벽/천장 통과(터널링) 여부 검증
   - 주사위가 서로 겹치거나 모서리로 멈추었을 때의 윗면 판정 안정성 검증
2. 자동화 QA 테스트 추가:
   - 'tests/test_die_3d.gd' 또는 'tests/test_qa_physics.gd'에 극한 물리 충돌 테스트 케이스를 보강
3. 결함 발견 및 테스트 보강 시 반드시 'feature/physics-qa-tests' 브랜치를 분기하여 작업 후 PR을 생성하고, 검증 결과를 'docs/collaboration/08_SELF_QA_REPORT.md'의 Codex 섹션에 기록해 주세요.
```

## Prompt Session #6 - 2026-11-19: 프리미엄 가죽 다이스 컵/원형 레드 펠트 트레이 및 마우스 쉐이크 조작 적용

### 1. 사용자 요구사항
1. 주사위 2번 눈이 비어 보이는 현상 해결
2. 스페이스바 누르고 있을 때 단순 파워 증가 대신 **마우스를 실제로 흔들어야** 컵이 흔들리고 파워가 축적되도록 변경
3. 첨부된 이미지 레퍼런스 스타일 적용:
   - 외피 블랙 스티치 레더 + 내피 레드 펠트 라이닝의 프리미엄 가죽 다이스 컵(Dice Cup)
   - 주사위 5개가 넉넉히 들어갈 수 있는 여유로운 사이즈 조절
4. 주사위가 튕겨지되 통(트레이) 밖으로는 절대 나가지 않도록 완벽 가둠 조절

### 2. 구현 내역 (브랜치: `feature/leather-cup-mouse-shake` -> `main` 머지)
- **주사위 2번 및 전면 눈 투명 알파 텍스처 개편**: 불투명 회색 배경을 완전히 걷어내고 투명 알파 채널의 고화질 256x256 핍 텍스처로 재생성.
- **마우스 모션 인터랙티브 컵 쉐이크**: Space(또는 롤 버튼)를 누른 채 실제로 마우스를 이리저리 흔들면 그 변위와 속도(`InputEventMouseMotion.relative`)를 연산하여 3D 컵이 흔들리며 파워가 쌓이고, 컵 내부에서 5개 주사위가 덜컹거림.
- **레퍼런스 이미지 기반 3D 가죽 컵 & 트레이**:
  - 다이스 컵: 외경 3.3m, 높이 3.6m의 블랙 레더 + 레드 벨벳 내피 + 상단 림 스티칭.
  - 다이스 트레이: 반경 4.8m의 원형 8각 가죽 벽 + 바닥 레드 펠트(Felt) + 상단 물리 씰링.
- **물리 튕김 및 탈출 방지**: 컵 입구에서 트레이 중앙으로 쏟아지는 방사형 궤적과 충돌 감쇠 적용으로 트레이 내부에서만 튕기며 안착.
- **전체 단위 테스트 통과 및 프로토타입 리빌드**: `test_die_3d.gd` (42 checks PASS), `test_qa_3d.gd` (14 checks PASS), `test_game.gd` (23 checks PASS) 완료.
