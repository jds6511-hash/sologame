## 저장 버전의 고정 규칙. 런타임 리소스 변경으로 과거 저장의 의미를 바꾸지 않는다.
## V1/V2는 Legacy, V3는 C1이다. codec/store의 지원 버전은 별도로 유지한다.
extends RefCounted


static func for_version(version: int) -> RefCounted:
	if version in [1, 2]:
		return Legacy.new()
	if version in [3, 4]:
		return Candidate.new()
	return null


class Legacy:
	extends RefCounted
	# 배포 V1/V2: roundi(55 * L^2.5 * (0.45 if L < 10 else 1)).
	const REQUIREMENTS := [
		25,
		140,
		386,
		792,
		1384,
		2182,
		3209,
		4480,
		6014,
		17393,
		22072,
		27436,
		33514,
		40335,
		47928,
		56320,
		65537,
		75604,
		86546,
		98387,
		111150,
		124859,
		139535,
		155200,
		171875,
		189582,
		208340,
		228170,
		249091,
		271123,
		294284,
		318594,
		344071,
		370732,
		398596,
		427680,
		458002,
		489578,
		522425,
		556561,
		592001,
		628761,
		666859,
		706308,
		747126,
		789328,
		832928,
		877942,
		924385,
		972272,
		1021617,
		1072435,
		1124741,
		1178547,
		1233870,
		1290722,
		1349118,
		1409070,
		1470594,
		1533701,
		1598407,
		1664723,
		1732663,
		1802240,
		1873467,
		1946357,
		2020923,
		2097176,
		2175131,
		2254799,
		2336192,
		2419323,
		2504205,
		2590848,
		2679266,
		2769470,
		2861472,
		2955284,
		3050917,
		3148384,
		3247695,
		3348863,
		3451898,
		3556812,
		3663616,
		3772323,
		3882941,
		3995484,
		4109961,
		4226384,
		4344764,
		4465111,
		4587436,
		4711751,
		4838065,
		4966389,
		5096735,
		5229111,
		5363530,
	]
	const NORMAL_COSTS := [1, 1, 2, 4]
	const ULTIMATE_COSTS := [3, 3]
	const JOB_LEVELS := {"warrior": 10, "archer": 10, "gladiator": 40}

	func req(level: int) -> int:
		return REQUIREMENTS[level - 1] if level >= 1 and level < max_level() else 0

	func max_level() -> int:
		return 100

	func transition_level(job_id: String) -> int:
		return JOB_LEVELS.get(job_id, -1)

	func points_per_level() -> int:
		return 1

	func points_per_transition() -> int:
		return 2

	func max_skill_level(ultimate: bool) -> int:
		return 1 + (ULTIMATE_COSTS.size() if ultimate else NORMAL_COSTS.size())

	func upgrade_cost(step: int, ultimate: bool) -> int:
		var costs: Array = ULTIMATE_COSTS if ultimate else NORMAL_COSTS
		return costs[step - 1] if step >= 1 and step <= costs.size() else -1


class Candidate:
	extends Legacy
	# C1: L11~19에서 0.4^((L-10)/10), L20부터0.4, L1~10 유지.
	const C1_REQUIREMENTS := [
		25,
		140,
		386,
		792,
		1384,
		2182,
		3209,
		4480,
		6014,
		17393,
		20140,
		22842,
		25459,
		27958,
		30312,
		32501,
		34509,
		36324,
		37940,
		39355,
		44460,
		49944,
		55814,
		62080,
		68750,
		75833,
		83336,
		91268,
		99636,
		108449,
		117714,
		127438,
		137628,
		148293,
		159438,
		171072,
		183201,
		195831,
		208970,
		222624,
		236800,
		251505,
		266743,
		282523,
		298850,
		315731,
		333171,
		351177,
		369754,
		388909,
		408647,
		428974,
		449896,
		471419,
		493548,
		516289,
		539647,
		563628,
		588238,
		613481,
		639363,
		665889,
		693065,
		720896,
		749387,
		778543,
		808369,
		838871,
		870052,
		901920,
		934477,
		967729,
		1001682,
		1036339,
		1071706,
		1107788,
		1144589,
		1182114,
		1220367,
		1259353,
		1299078,
		1339545,
		1380759,
		1422725,
		1465447,
		1508929,
		1553177,
		1598194,
		1643984,
		1690554,
		1737906,
		1786044,
		1834975,
		1884700,
		1935226,
		1986556,
		2038694,
		2091644,
		2145412,
	]

	func req(level: int) -> int:
		return C1_REQUIREMENTS[level - 1] if level >= 1 and level < max_level() else 0
