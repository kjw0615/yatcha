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
