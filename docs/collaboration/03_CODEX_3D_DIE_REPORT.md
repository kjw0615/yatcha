# Codex 3D 주사위 물리 및 윗면 판정 구현 보고

- 작성일: 2026-11-19
- 대상 엔진: Godot 4.6 stable (`89cea1439`), 프로젝트 기본 3D 물리 설정
- 구현: `scripts/die_3d.gd` (`extends RigidBody3D`)
- 검증: `tests/test_die_3d.gd`
- 기존 2D 씬과 점수 계산 파일은 수정하지 않음. 3D 씬 조립 및 입력/HUD 연결은 통합 담당 범위.

## 통합 API

```gdscript
# die는 die_3d.gd를 붙인 RigidBody3D 인스턴스.
die.stopped.connect(_on_die_stopped)
die.roll(Vector3(0.4, 3.0, 0.3), Vector3(0.4, 0.2, 0.3))
# 또는 내장 난수 굴림: 인수는 선형/회전 충격량의 크기.
die.roll_random(4.0, 1.0)

# 글로벌 Transform3D를 받음. 회전도 슬롯 회전으로 보간함.
die.set_kept(true, keep_slot.global_transform)
die.set_kept(false)

func _on_die_stopped(face: int) -> void:
    print(face) # 1~6. 신호 송신자는 필요하면 Callable.bind(die)로 전달.
```

- `roll(impulse: Vector3, torque: Vector3) -> void`: 호출자가 만든 글로벌 좌표계의 충격량 벡터를 받아 한 번 적용한다. 이전 굴림의 속도를 초기화한다. 킵 상태에서는 무시한다.
- 충격은 다음 `_integrate_forces()`에서 물리 상태에 적용한다. 처음 동결을 해제한 몸체의 관성이 갱신되기 전에 토크를 적용하면 회전이 누락되는 문제를 실제 테스트에서 발견하여 이 방식으로 처리했다. 물리 콜백 전 여러 번 호출하면 마지막 요청을 사용한다.
- `roll_random(impulse_strength = 4.0, torque_strength = 1.0)`: 위쪽 충격과 무작위 회전축을 생성한다. 수치는 대략 1 m / 1 kg 주사위 기준의 시작값이며 실제 에셋 크기와 트레이에 맞춰 조절한다.
- `get_top_face() -> int`: 현재 자세의 기하학적 윗면. 굴리는 중에도 계산되므로 점수 확정에는 `stopped(face)` 또는 정지 후 `value`를 사용한다.
- `set_kept(keep, slot = Transform3D.IDENTITY, duration = -1.0)`: 기본 0.3초 이동. `duration = 0`은 즉시 이동, 음수는 Inspector 기본값 사용. 킵할 때는 반드시 실제 슬롯 Transform을 전달한다.
- 읽기 전용 상태: `is_kept`, `is_rolling`. `value`는 정지 시 갱신되며 킵 이동 중 유지된다.
- 상태 변경은 `roll()`과 `set_kept()`를 통한다. 물리 충돌 처리 콜백에서 호출하려면 `call_deferred()`로 호출한다.

## 메쉬 및 충돌체 규격

| RigidBody3D 로컬 면 법선 | 기본 눈 |
| --- | --- |
| +Y | 1 |
| -Y | 6 |
| +X | 2 |
| -X | 5 |
| +Z | 3 |
| -Z | 4 |

양의 축 번호는 `positive_y_face`, `positive_x_face`, `positive_z_face`로 변경할 수 있고, 반대편 번호는 항상 `7 - 번호`로 계산한다. 세 축은 서로 다른 반대면 쌍을 사용해야 한다. 잘못된 조합은 `_ready()`에서 오류를 출력한다.

각 면의 글로벌 법선을 `global_transform.basis.orthonormalized()`에서 구하고 `Vector3.UP`과 내적한다. 최댓값의 번호를 반환하므로 부모 회전도 반영된다. 메쉬 자식만 임의 회전시키면 표시된 눈과 판정 축이 어긋나므로 모델 눈을 위 표에 맞추거나 양의 축 번호를 수정한다.

`CollisionShape3D`를 몸체 중심에 배치하고 활성 `BoxShape3D` 등 볼록 충돌체를 할당해야 충돌과 자동 관성이 작동한다. 몸체와 부모는 단위 스케일을 사용하고 크기는 Shape/Mesh 리소스로 맞춘다. 트레이에는 별도 StaticBody3D 바닥과 벽이 필요하다. damping 기본값은 선형 0.15, 회전 0.25이며 Inspector에서 조정 가능하다. `can_sleep`과 연속 충돌 검출을 켜고 접촉 보고 수를 최소 4로 설정한다. 재질·마찰·반발은 씬에서 설정할 수 있도록 강제 덮어쓰지 않는다.

## 정지 판정

- 굴림 요청으로 판정을 활성화하며, 생성 직후와 킵/해제만으로는 `stopped`를 방출하지 않는다.
- 기본 최소 굴림 시간 0.2초 후 `sleeping`이면 정지로 확정한다.
- 또는 선속도 ≤ 0.08 m/s, 각속도 ≤ 0.12 rad/s 상태가 0.35초 연속 유지되면 정지로 확정한다. 중간에 조건을 벗어나면 유지 시간을 초기화한다.
- 속도 기반 경로는 기본적으로 접촉도 요구한다. 따라서 공중에서 속도가 잠깐 줄어드는 상황을 정지로 확정하지 않는다. `require_contact_to_settle`로 이 조건을 끌 수 있다.
- 확정 시 잔여 속도를 0으로 만들고 sleep 상태로 두며 한 굴림당 `stopped(value: int)`를 한 번만 방출한다. 신호 전에 내부 상태를 정리하여 수신자가 즉시 다음 굴림이나 킵을 요청할 수 있다.

모서리/꼭짓점에 걸친 주사위도 가장 위쪽인 면을 반환한다. 내적이 정확히 같으면 +Y, -Y, +X, -X, +Z, -Z 순서로 결정한다. 기울어진 주사위 재굴림 정책은 포함하지 않았으므로 필요하면 통합 측에서 별도 처리한다.

## 킵 동작

킵 시 진행 중 굴림과 대기 충격을 취소하고 속도를 초기화한다. `freeze = true`, `FREEZE_MODE_KINEMATIC`으로 물리를 동결한 후 물리 프레임 Tween에서 위치와 회전을 보간한다. 재호출은 기존 Tween을 취소하고 현재 위치에서 새 목표로 이동한다. 해제 시 Tween을 취소하고 현재 위치에서 동결을 해제한다. 재굴림하려면 `set_kept(false)` 후 `roll()`을 호출한다.

킵 슬롯 회전 때문에 기하학적 윗면이 달라질 수 있으므로, 킵한 주사위 점수는 보존된 `value`를 사용한다. UI가 숫자를 위로 보여줘야 한다면 슬롯 회전도 해당 눈이 위를 향하도록 계산해야 한다. 킵 이동 경로의 충돌 영향과 슬롯 간격은 실제 트레이 씬에서 확인해야 한다.

## 실행 검증

아래 명령은 프로젝트 루트에서 실행했다.

```powershell
& tools/godot/Godot_v4.6-stable_win64_console.exe --headless --path . --check-only --script scripts/die_3d.gd
& tools/godot/Godot_v4.6-stable_win64_console.exe --headless --path . --script tests/test_die_3d.gd
& tools/godot/Godot_v4.6-stable_win64_console.exe --headless --path . --script tests/test_game.gd
```

- 스크립트 파싱 검사: 통과.
- 신규 3D 테스트: **42 checks 통과**. 24개 큐브 자세, 회전된 부모, 축 번호 변경, 공중 오판 방지, sleep 경로, 실제 충격/회전, 바닥 충돌 후 자동 sleep을 끈 임계값 정지 경로, 신호 중복 방지/재활성화, 킵 보간·점수 보존·해제 취소·즉시 이동 검증.
- 기존 게임 회귀 테스트: **23 checks 통과**, 24턴 전체 게임 포함.
- 아직 최종 3D 메쉬/트레이/카메라 씬이 연결되지 않아 최종 비주얼과 실사용 조작감 검수는 미실시.

API 기준: [Godot 4.6 RigidBody3D 공식 문서](https://docs.godotengine.org/en/4.6/classes/class_rigidbody3d.html).
