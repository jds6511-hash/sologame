# 게임 UI 글꼴

2026-09-30 디렉터 요청으로 Pretendard v1.3.9를 적용했다. Regular는 기본 UI·HUD·NPC 이름표, SemiBold는 제목에 사용한다. 기존 Galmuri는 과거 자산 재현용으로 남기며 제품 공통 경로는 새 폰트를 가리킨다.

- 제작자/공식 안내: https://github.com/orioncactus/pretendard
- 고정 배포: https://github.com/orioncactus/pretendard/tree/v1.3.9/packages/pretendard/dist/public/static/alternative
- 원본 파일: Pretendard-Regular.ttf, Pretendard-SemiBold.ttf. 글리프 데이터 수정 없음.
- 라이선스: SIL Open Font License 1.1. 저작권·라이선스 원문은 LICENSE-Pretendard.txt에 동봉한다. 폰트 단독 판매 금지, 배포 시 원문 동봉 등 원문의 조건을 따른다.
- Regular SHA-256: 6D0AF5258997AEC7354A6E340FC2325BA321C410CA48B3AF858C8C3D6E92A324
- SemiBold SHA-256: 5E1C548732AF70873103066C16E1369B9A8A871F0B38C321A1D5BC73E43CEA2D

두 .import 파일은 MSDF 활성·생성 크기64 설정을 보존하기 위해 소스와 함께 추적한다. NPC 이름표는 선형 필터를 사용하며, 타일·캐릭터의 최근접 필터는 바꾸지 않는다. 전역 기본 폰트는 project.godot의 gui/theme/custom_font, 명시 UI 폰트는 UiStyle에서 지정한다. 게임 실행 중 외부 네트워크로 폰트를 받지 않는다.
