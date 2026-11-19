# 통합 스킬 & 도구 사용 가이드 (Skills Overview & Multi-Agent Architecture)

이 문서는 프로젝트(`C:\Users\admin\Desktop\스킬`)에 설치 및 구성된 모든 AI 에이전트의 스킬, 플러그인, 3D/2D 엔진 및 도구들을 **지원 에이전트**, **역할 분담 체계**, **설치 경로**, **실행/사용 방법**으로 종합 정리한 통합 마스터 가이드입니다.

---

## 1. 3대 AI 에이전트별 특화 역할 분담 체계 (Architecture)

각 AI가 모든 스킬을 중복 로드하여 발생하는 토큰 낭비 및 충돌을 방지하고, 가장 뛰어난 영역을 전담하도록 **3단계 파이프라인**으로 역할을 일원화했습니다.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1단계: [기획 및 기준표 정의] (Claude Code 전담)                             │
│   • 캐릭터 디자인 스펙(용도, 스타일, 폴리곤 예산, 관절 스펙) 기준표 수립     │
│   • 산출물: 캐릭터 스펙 정의서                                             │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 2단계: [참조 이미지 표준화 & 초벌 3D 생성] (Antigravity 전담)               │
│   • 2D 기준 이미지 삼면도/턴어라운드 정렬 (2dimg2motion)                    │
│   • Image-to-3D CLI (Tripo / Meshy)를 통한 초벌 메쉬 및 베이스 텍스처 생성  │
│   • 산출물: 원본 메쉬 파일(.glb / .fbx) 및 텍스처                           │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 3단계: [Blender 기술 제작, 리깅 & 자동 QA] (OpenAI Codex 전담)              │
│   • 헤드리스 Blender 5.3.0 Portable + Blender Skills 28종 + Image-to-Sculpt  │
│   • 토폴로지/UV 정리, Rigify 뼈대 스키닝, 표정 셰이프키 세팅, 게임 최적화   │
│   • blender-asset-qa 무결성 검증 통과 후 최종 포맷(glTF/FBX) 엔진 수출      │
│   • 산출물: 마스터 .blend 파일, 엔진용 모델, QA 검증 보고서                 │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 4단계: [최종 시각 검수 & 피드백] (Claude Code 전담)                         │
│   • 렌더링된 실루엣, 표정, 포즈, 애니메이션 시각적 무결성 검수              │
│   • 최종 사용자 컨펌 진행                                                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. 에이전트별 전담 파일 및 환경 매핑

| AI 에이전트 | 전담 가이드 파일 | 주요 탑재 도구 / 환경 | 전담 역할 요약 |
| :--- | :--- | :--- | :--- |
| **Claude Code** | [CLAUDE.md](file:///C:/Users/admin/Desktop/스킬/CLAUDE.md) | • `agent-sprite-forge` (플러그인)<br>• `~/.claude/skills/` (2D 스킬 5종)<br>• (선택) 단일 Live MCP | 요구사항 분석, 캐릭터 기준표 수립, 시각적 실루엣/포즈/표정 최종 검수 |
| **OpenAI Codex** | [AGENTS.md](file:///C:/Users/admin/Desktop/스킬/AGENTS.md) | • **Blender 5.3.0 Portable** (무설치)<br>• **Blender Skills 28종**<br>• **Image-to-Sculpt**<br>• `.venvs/` (가상환경 4개) | Blender 기술 제작, 메시 정리, Rigify 리깅, 애니메이션, 최적화, 자동 QA |
| **Antigravity (Gemini)** | [GEMINI.md](file:///C:/Users/admin/Desktop/스킬/GEMINI.md) | • **FFmpeg & FFprobe (v9.0.2)**<br>• **Image-to-3D CLI** (`tripo`, `meshy`)<br>• `2dimg2motion`, `pixelbolt` | 참조 이미지 표준화, Image-to-3D 초벌 메쉬 생성 및 작업 ID/비용 관리 |

---

## 3. 전체 스킬 및 도구 종합 일람표 (Total Catalog)

### 3.1 3D 모델링, 캐릭터 제작 및 DCC 도구군 (신규 3D)

| 스킬 / 도구명 | 담당 AI | 형태 및 설치 경로 | 주요 기능 및 사용법 |
| :--- | :---: | :--- | :--- |
| **Blender Skills (28종)** | **Codex 단일 전담** | `~/.agents/skills/blender-*` | **Blender 5.2/5.3 전문 파이프라인 28종**<br>(`blender-character-rigging`, `blender-sculpting`, `blender-retopology-uv`, `blender-facial-shapekeys`, `blender-asset-qa` 등) |
| **Blender 5.3.0 Portable** | **Codex 단일 전담** | `tools/blender/blender-5.3.0-windows-x64/blender.exe` | 무설치 공식 포터블 엔진. 헤드리스 배치 스크립트 실행 및 Rigify 리깅 완비 |
| **Image-to-Sculpt** | **Codex / Antigravity** | `~/.agents/skills/image-to-sculpt`<br>`.venvs/image-to-sculpt` | 2D 단일 이미지의 윤곽/깊이/노멀을 추론하여 정밀 수밀 3D 스컬프트를 형성하는 스킬 |
| **Tripo CLI (`tripo-3d`)** | **Antigravity 전담** | npm 전역 (`tripo.cmd` v0.11.2) | 텍스트/이미지 기반 초벌 3D 모델 자동 생성 CLI (`tripo make <image.png>`) |
| **Meshy CLI (`meshy-cli`)** | **Antigravity 전담** | npm 전역 (`meshy.cmd` v0.8.7) | 텍스트/이미지 기반 3D 메쉬 생성, 리깅, 텍스처 생성 CLI |

---

### 3.2 2D 스프라이트, 픽셀 아트 및 애니메이션 도구군 (기존 2D)

| 스킬 / 도구명 | 지원 AI | 형태 및 설치 경로 | 주요 기능 및 사용법 |
| :--- | :---: | :--- | :--- |
| **2dimg2motion** | 공용 | `~/.gemini/skills/2dimg2motion`<br>`~/.claude/skills/2dimg2motion`<br>`~/.codex/skills/2dimg2motion` | 단일 2D 기준 이미지의 정체성(외형/비율)을 유지하며 다각도/14프레임 모션 시퀀스를 구성하는 프롬프트 워크플로우 |
| **sprite-gen** | Claude, Codex | 프로젝트 `repos/sprite-gen`<br>`.venvs/sprite-tools` | 텍스트 설명으로부터 2D 스프라이트 아틀라스를 자동 생성하는 파이썬 CLI 도구 |
| **pixelfx** | Claude, Codex | 프로젝트 `repos/pixelfx` | Node.js 기반 절차적 픽셀 아트 이펙트(불, 물, 얼음, 마법) 60프레임 시트 렌더러 |
| **PixelOE** | Claude, Codex | `.venvs/pixeloe` | 고해상도 이미지를 윤곽선 손상 없이 깔끔한 도트 그래픽으로 변환하는 파이썬 도구 |
| **Agent Sprite Forge (5종)** | Claude, Codex | Claude 플러그인 (v0.6.0)<br>`~/.codex/skills/` (스킬 5종)<br>`.venvs/agent-sprite-forge` | 2D 게임 에셋 생성 대규모 툴킷 (`codeart2d`, `generate2dmap`, `generate2dsprite`, `generate2dmedia`, `video2dsprite`) |
| **codixel** | Claude, Codex | `~/.claude/skills/codixel`<br>`~/.codex/skills/codixel` | 레퍼런스 이미지를 바탕으로 단계적 픽셀화·리깅·애니메이션을 진행하는 프롬프트 가이드 |
| **Pixelbolt** | 전원 지원 | `npx -y pixelbolt@0.17.0` | 의존성 없는 JSON 레시피 기반 픽셀 스프라이트/유체/파티클 렌더링 도구 |
| **FFmpeg & FFprobe** | 전원 지원 | 시스템 PATH (공식 Gyan v9.0.2) | 비디오/오디오 인코딩, 루프, 프레임 분할, Remotion 필수 멀티미디어 엔진 |

---

## 4. 원클릭 환경 복원 및 셸 활성화 가이드 (New PC Setup)

다른 PC로 이 프로젝트 폴더를 복사했을 때 터미널에서 순서대로 실행하면 모든 환경이 복원됩니다:

### 4.1 시스템 멀티미디어 엔진 복원 (FFmpeg)
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-ffmpeg.ps1 -AddToUserPath
# 또는 winget 지원 환경:
winget install --id Gyan.FFmpeg -e
```

### 4.2 3D 파이프라인 및 가상환경 활성화 (Codex / Antigravity)
```powershell
# 현재 PowerShell 세션에 Blender 5.3 및 가상환경 PATH 등록
. .\scripts\activate-3d.ps1
```

### 4.3 2D 도구 및 가상환경 복원 (Codex / Claude)
```powershell
# Codex 가상환경 및 2D 스킬 12종 복원
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-codex.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-codex-round2.ps1
```

---

## 5. 관리 및 변경 이력

- **2026-11-16 (1차)**: 2D 캐릭터 모션 및 픽셀 도구 (`2dimg2motion`, `sprite-gen`, `pixelfx`, `PixelOE`) 설치
- **2026-11-16 (2차)**: 2D 게임 에셋 툴킷 (`Agent Sprite Forge`, `codixel`, `Pixelbolt`) 추가 (※ `Sprite Sheet Diffusion`은 제외)
- **2026-11-16 (3차)**: 비디오/오디오 멀티미디어 인코딩 엔진 **FFmpeg & FFprobe (v9.0.2)** 시스템 설치
- **2026-11-19 (4차 - 3D 모델링 확립)**:
  - 무설치 **Blender 5.3.0 Portable** 및 **Blender Skills 28종** 구축
  - **Image-to-Sculpt**, **Tripo CLI**, **Meshy CLI** 3D 도구 체인 완비
  - **역할 분담 최적화 완료**: 중복 로드를 제거하여 `Antigravity(초벌3D) → Codex(Blender제작/QA) → Claude(기획/시각검수)` 3단계 분담 체계로 일원화
