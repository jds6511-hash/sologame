## 2막 표에 연결된 몬스터만 사용한다. 기존 레벨 곡선과 1막 보상은 수정하지 않는다.
extends RefCounted


static func gain(
	profile: Dictionary, overlevel: int, grade: float, leveldiff: float, night: float
) -> int:
	var factors: Array = profile.overlevel_factors
	if overlevel >= factors.size():
		return 1
	var decay: float = factors[maxi(0, overlevel)]
	return maxi(1, roundi(profile.base_exp * decay * grade * leveldiff * night))
