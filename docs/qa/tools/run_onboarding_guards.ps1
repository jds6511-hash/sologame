param([string]$Godot = 'godot')
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$output = Join-Path $repo ('docs/qa/screenshots/onboarding/guards-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Force -Path $output | Out-Null
$engine = (Get-Command $Godot).Source
foreach ($phase in @('cleanup', 'reload', 'walk', 'hunt', 'death')) {
    $script = if ($phase -eq 'cleanup') { 'yeoulmok_onboarding_probe.gd' } else { 'onboarding_guard_probe.gd' }
    $mode = if ($phase -in @('walk', 'hunt')) { '' } else { '--headless ' }
    $log = Join-Path $output ($phase + '.log')
    $arguments = $mode + '--path godot --fixed-fps 60 --log-file "' + $log + '" --script ../docs/qa/tools/' + $script + ' -- ' + $phase
    $process = Start-Process -FilePath $engine -WorkingDirectory $repo -ArgumentList $arguments -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(300000)) { $process.Kill(); throw "Timeout: $phase" }
    $process.Refresh()
    $body = Get-Content -LiteralPath $log -Raw -Encoding UTF8
    $marker = if ($phase -eq 'cleanup') { 'YEOULMOK_ONBOARDING_PASS' } else { 'ONBOARDING_GUARD_PROBE_DONE' }
    if ($process.ExitCode -ne 0 -or $body -match 'SCRIPT ERROR:|(?m)^ERROR:' -or -not $body.Contains($marker)) { throw "Guard failed: $phase; $log" }
    if ($body -match 'ONBOARDING_(MISSING_SAVE|ATTACK_DISABLED|NAVIGATION_DISABLED)_CONFIRMED') { throw "False negative acceptance: $phase; $log" }
    $reached = switch ($phase) {
        'reload' { '별도 프로세스 로드: false' }
        'walk' { '동적 도보 시간 초과:' }
        'hunt' { '실제 처치 시간 초과:' }
        'death' { '대기 포함 전체 세션 사망 감지: false' }
        default { 'YEOULMOK_ONBOARDING_PASS' }
    }
    if (-not $body.Contains($reached)) { throw "Target branch not reached: $phase; $log" }
    if ($phase -eq 'death' -and -not $body.Contains('ONBOARDING_DEATH_GUARD: true')) { throw "Missed death: $log" }
    Write-Output "ONBOARDING_GUARD_PASS $phase"
}
Write-Output "ONBOARDING_GUARDS_PASS $output"
