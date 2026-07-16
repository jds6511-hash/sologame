// 피격 화이트 플래시 — 공용 canvas_item 셰이더 (CB-8)
//
// 용도: 스프라이트가 피격당한 순간, 원본 색을 흰색으로 덮어 씌워 "맞았다"는 신호를 즉시 전달한다.
// 근거: docs/art/STYLE_GUIDE.md 6-1장 "피격 피드백 = #ffffff, 몬스터 피격 시 2프레임(약 0.06초,
//       히트스톱 '중'과 동기)". 흰색(EDG32 #20)은 이 용도 전용 — 다른 이펙트에 재사용 금지.
//
// 적용 대상: Sprite2D, AnimatedSprite2D 등 임의의 CanvasItem. material에 이 셰이더로 만든
//           ShaderMaterial을 꽂고 flash_strength 유니폼을 0~1로 애니메이션하면 된다.
// 지속시간(duration)은 이 셰이더 자체가 아니라 값을 구동하는 쪽(Tween 등)의 책임이다 —
// 셰이더는 "그 순간의 강도"만 그린다. godot/scripts/vfx_common/hit_flash.gd 가 이 셰이더에
// duration을 얹어 재생하는 공용 헬퍼이며, HitFeedback(CB-7)은 그 헬퍼를 호출하면 된다.
//
// 파라미터:
//   flash_color    : 덮어씌울 색 (기본값 #ffffff 흰색 — STYLE_GUIDE 6-1 고정색, 변경 금지)
//   flash_strength : 0.0(원본 그대로) ~ 1.0(완전한 flash_color). 알파는 원본 텍스처를 그대로 사용
//                    하므로 실루엣(아웃라인 포함)은 유지된 채 색만 flash_color로 밀린다.
shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(tex_color.rgb, flash_color.rgb, flash_strength), tex_color.a);
}
