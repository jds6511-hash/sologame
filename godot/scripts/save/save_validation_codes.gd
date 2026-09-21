extends RefCounted

## 복구/덮어쓰기로 우회하면 안 되는 저장 도메인 오류. 파일 계층과 스키마가 공유한다.
const PENDING_TRANSFER := "pending_transfer"
const UNSUPPORTED_TRANSFER_HISTORY := "unsupported_transfer_history"
const BLOCKED := [PENDING_TRANSFER, UNSUPPORTED_TRANSFER_HISTORY]
