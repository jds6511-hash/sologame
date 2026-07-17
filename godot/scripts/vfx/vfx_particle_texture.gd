## 타격 이펙트용 파티클 텍스처 절차 생성 유틸리티 (vfx-artist, AR-4).
##
## godot\assets\에 아직 파티클 전용 스프라이트(pixel-artist 산출물)가 없어 "텍스처 요청"
## 전까지는 코드로 단순 도형(부드러운 원)을 생성해 사용한다 — vfx-artist 역할 규칙
## "파티클 텍스처가 필요하면 pixel-artist 산출물 사용, 없으면 단순 도형(코드 생성)" 준수.
##
## 텍스처 자체는 흰색 + 방사형 알파 감쇠로만 만든다 — STYLE_GUIDE.md 6-2장 "이펙트 스프라이트도
## EDG32 색만 사용, 반투명은 알파값으로만(중간색 생성 금지)" 규칙에 맞춰, 실제 색(EDG32 팔레트)은
## 이 텍스처를 쓰는 GPUParticles2D의 color/color_ramp에서 곱연산으로 입힌다.
##
## pixel-artist가 정식 파티클 스프라이트를 제작하면 이 유틸리티 대신 해당 텍스처로 교체할 것.
class_name VfxParticleTexture
extends RefCounted


## size_px 정사각 크기의 부드러운 원형(흰색, 중심 알파 1.0 → 가장자리 알파 0.0) 텍스처를 생성한다.
static func make_soft_circle(size_px: int = 8) -> ImageTexture:
	var image := Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	var center := Vector2(size_px, size_px) * 0.5
	var max_dist := size_px * 0.5
	for y in range(size_px):
		for x in range(size_px):
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(center)
			var alpha := clampf(1.0 - dist / max_dist, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)
