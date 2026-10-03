# 전사 낮은 검 보행과 공격 체중이동

최종 수정: 2026-10-03 / Codex. 선행: [중간 체감 피드백](../design/systems/act-two-midpoint-feedback.md).

변경 이력: 2026-10-03 기존 LPC 합성·직접 무기 작화 생성기에 낮은 보행 검과 공격 체중이동을 반영했다.

## 구현

- 런타임 보행은 `player_warrior_v2_walk_carry.png`의 64×64 셀을 사용한다. 몸 크기·6프레임·10fps를 유지하며 검은 수평에서 약 20도 아래로 든다. 28×36 구형 보행 시트는 소스 손 접점 검증용으로 남긴다.
- 공격은 발 행을 고정한 상태에서 몸·손을 함께 기울인다. 선딜의 어깨 당김, 활성 중 뻗는 팔 원본, 타격 이후 체중 유지, 대기 복귀를 구분했다. 측면의 팔을 뻗은 한 셀은 칼날을 17px로 단축해 64px 창 안에 둔다. 다른 셀은 22px다.
- 선딜2/활성3/후딜3과 판정시계, 충돌·공격 수치, 스프라이트 발 오프셋은 바꾸지 않았다.
- 모든 손 접점은 소스의 실제 피부 픽셀에 붙는다. 좌측은 기존 측면 반전이다. 해부학적으로 같은 손을 쓰는 좌측 전용 원화가 완성됐다는 의미가 아니다. 좌측 공급 시 보행 carry와 공격 sweep를 포함한 전 상태 완전성 검사를 유지한다.

## 재생성·검증

`python godot/assets/tools/gen_sword_sweep.py` 다음 `python godot/assets/tools/gen_player_spriteframes.py`.

Python player계열 19건과 sword_sweep 5건 통과. 피부 접점, 발 행 불변, 활성 중 서로 다른 몸, 낮은 보행 각도, 클리핑, EDG32, 좌측 불완전 세트 거절을 검사한다.

무기 배치 10건, GUT 공격·보행·좌측 9/9(43 assertions), gdformat 검사·gdlint 통과. 재생성 전후 전사 PNG 3장과 전사/궁수 tres 2개의 SHA256이 일치했다. 궁수 자산·프로젝트 설정 diff는 없다.

실제 Godot `docs/qa/tools/sword_sweep_probe.gd` 렌더에서 2타×4방향을 60Hz로 56장 저장했다. 종료0, stderr 없음. 시트와 활성 샘플을 눈으로 확인했다. 새 그림의 최종 미감·전투 체감 승인은 별도다.

로컬 증거: `docs/qa/screenshots/sword-sweep/walk.png`, `attack.png`, `attack2.png`, `runtime/000.png`~`055.png`. 원본 PNG를 픽셀 편집한 작업이 아니라 저장소 네이티브 생성기 변경과 재생성이다.
