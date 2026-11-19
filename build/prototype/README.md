# 3D Yacht Dice (야추 3D) 프로토타입 실행 가이드

## 1. 개요
기존 2D Godot 요트 다이스 게임을 물리 기반 3D 다이스 트레이 및 D6 시뮬레이션으로 전면 개편한 첫 번째 실행 가능한 **3D 프로토타입** 빌드입니다.

- **실행 파일 위치**: [`build/prototype/YachtClub3D.exe`](file:///C:/Users/admin/Desktop/game/glass/build/prototype/YachtClub3D.exe)
- **동봉 패키지 파일**: [`build/prototype/YachtClub3D.pck`](file:///C:/Users/admin/Desktop/game/glass/build/prototype/YachtClub3D.pck)
- **간편 실행 스크립트**: [`play_3d.cmd`](file:///C:/Users/admin/Desktop/game/glass/play_3d.cmd)

---

## 2. 새로운 3D 기능 및 조작법

### 🎲 3D 물리 시뮬레이션
- **Godot 4.6 RigidBody3D**: 주사위를 굴릴 때 3D 트레이 내부에서 무작위 물리 임펄스와 토크를 받아 회전하며 굴러갑니다.
- **상단 눈 기하 판정**: 주사위가 멈추었을 때 로컬 벡터와 `Vector3.UP`의 내적(Dot Product)을 통해 윗면(1~6)을 정밀 계산합니다.
- **킵(Keep) 보간**: 킵 상태로 전환 시 물리 엔진 동결 및 상단 킵 레일 슬롯으로 부드러운 트윈(Tween) 이동을 지원합니다.

### 🎮 키보드 단축키 지원 (Claude 기획 스펙 반영)
| 키 입력 | 동작 |
| :--- | :--- |
| **`Space`** | **3D 주사위 굴리기 (Roll)** |
| **`1` ~ `5`** | **1번 ~ 5번 주사위 킵(Keep) / 롤(Roll) 토글** |
| **`Enter`** | **점수 확정 (Commit)** |
| **마우스 클릭** | 3D 트레이 하단 주사위 버튼 클릭 또는 우측 족보 점수표 선택 |

---

## 3. 원클릭 실행 방법
- 탐색기에서 `build/prototype/YachtClub3D.exe`를 더블 클릭하여 즉시 실행하거나,
- 프로젝트 루트의 `play_3d.cmd`를 실행하면 됩니다.
