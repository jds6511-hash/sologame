## 직업 정의 데이터 (Resource) — M3 B-5 전직 프레임워크.
##
## 한 직업(1차)이 무엇으로 구성되는지를 한 리소스에 모은다: 성장 배분(JobGrowthData),
## 기본 공격 무기(콤보·지급 무기), 스킬 로드아웃(승계형 교체 — m3-warrior-tier2-skills.md
## 1장). 전직 실행 시 PlayerJobTransition이 이 정의를 읽어 스탯 재계산·스킬 슬롯 개방·무기
## 교체를 일괄 적용한다. 직업이 늘어도(궁수 C-4 등) .tres만 추가하면 되도록 데이터 주도로 둔다.
##
## 승계형 교체(신규 키 0 — jobs.md 3장·D3-A2-1 확정): 슬롯 8칸(1/2/3/4/Q/E/궁극기/우클릭)을
## 이 정의가 통째로 규정한다. 모험가 공용 3종(강타·질주·응급 처치)은 slot_1~3에 그대로 두고,
## 직업 고유 스킬이 slot_4/Q/E/궁극기/우클릭을 채운다(하위 공용 슬롯을 상위 직업 스킬이
## 대체하되 새 키는 만들지 않는다). null 슬롯은 "미개방"(해당 직업이 아직 그 슬롯을 안 씀 —
## 궁수 고유 스킬은 C-4에서 채운다).
class_name JobDefinition
extends Resource

@export var job_id: StringName = &""
@export var display_name: String = ""
## 이 직업의 레벨당 스탯 성장 배분(전직 후 recompute_stats에 쓰인다).
@export var growth: JobGrowthData

@export_group("전직 계통 (jobs.md 1장 — 1차 Lv10 / 2차 Lv40)")
## 이 직업으로 전직하기 위해 먼저 갖춰야 할 직업 id. 비우면 모험가에서 바로 가는 1차
## 직업이고, 값이 있으면 그 직업일 때만 전직할 수 있는 상위 계통이다(검투사 = 전사 전제).
@export var required_job_id: StringName = &""
## 전직 임계 레벨을 직접 지정한다(0이면 growth.transition_level 사용). 2차 전직(Lv40)은
## growth의 transition_level(= "모험가 균등 배분이 끝나는 레벨" Lv10)과 의미가 달라
## 재사용할 수 없으므로 별도 필드로 둔다.
@export var transition_level_override: int = 0

@export_group("무기 (jobs.md 5·6장 — 전직 시 직업 전용 무기)")
## 기본 공격 콤보(대검 2타·활 연사 등). 전직 시 PlayerController.combo_data로 교체된다.
## 궁수 활 연사 콤보는 C-5에서 채운다(그전까지 null이면 전직 시 콤보 유지).
@export var basic_combo: WarriorComboData
## 전직 지급 무기(1차 C급, jobs.md 6장). 인벤토리/스마트 드랍 연동은 M3 범위 밖이라
## 지급 사실만 기록·노출한다(경제/도감 후속 훅). 궁수 활 아이템은 경제/C-6에서 채운다.
@export var granted_weapon: ItemData

@export_group("외형 (M3 3-A 정식 스프라이트)")
## 이 직업의 스프라이트 시트(직업당 9상태 x 3방향). 전직 시 PlayerController가 Sprite 노드에
## 그대로 꽂는다 — 무기(대검/활)와 직업 전용 상태(전사 attack2·charge / 궁수 aim·rollshot)가
## 시트마다 다르므로 상태별 교체가 아니라 시트째 교체가 맞다.
## 비우면 전용 시트가 없는 직업(검투사 — 전사 시트를 계속 쓴다)이라 현재 시트를 유지한다.
@export var sprite_frames: SpriteFrames

@export_group("스킬 로드아웃 (승계형 교체 — 신규 키 0)")
@export var skill_slot_1: WarriorSkillData  ## 1키 — 모험가 공용(강타)
@export var skill_slot_2: WarriorSkillData  ## 2키 — 모험가 공용(질주)
@export var skill_slot_3: WarriorSkillData  ## 3키 — 모험가 공용(응급 처치)
@export var skill_slot_4: WarriorSkillData  ## 4키 — 직업 고유
@export var skill_slot_q: WarriorSkillData  ## Q키 — 직업 고유
@export var skill_slot_e: WarriorSkillData  ## E키 — 직업 고유
@export var skill_ultimate: WarriorSkillData  ## R키 — 직업 궁극기
@export var skill_charge: WarriorSkillData  ## 우클릭 — 직업 보조 동작
## 우클릭의 조건부 파생 스킬(검투사 처형 일격 — 분노 ≥ 50에서 차지 강타를 대체한다).
## 신규 키를 만들지 않는 승계형 교체의 일부이며, 이 값이 있는 직업만 분노 게이지를 쓴다
## (m3-warrior-tier2-skills.md 1-1·2장).
@export var skill_rage_finisher: WarriorSkillData


## 전직 임계 레벨. override(2차 Lv40)가 있으면 그 값, 없으면 성장 데이터(1차 Lv10).
## 둘 다 없으면 10.
func transition_level() -> int:
	if transition_level_override > 0:
		return transition_level_override
	return growth.transition_level if growth != null else 10


## 스킬 로드아웃을 슬롯 이름 -> WarriorSkillData 사전으로 만든다
## (PlayerController.apply_transition_loadout 입력 규격). null 슬롯은 미개방.
func skill_loadout() -> Dictionary:
	return {
		"slot_1": skill_slot_1,
		"slot_2": skill_slot_2,
		"slot_3": skill_slot_3,
		"slot_4": skill_slot_4,
		"slot_q": skill_slot_q,
		"slot_e": skill_slot_e,
		"ultimate": skill_ultimate,
		"charge": skill_charge,
		"rage_finisher": skill_rage_finisher,
	}
