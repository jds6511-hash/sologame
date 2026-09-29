# 기능 증거 묶음. G3/G4/G5 승인이나 미술 품질 판정을 출력하지 않는다.
param([string]$Godot = 'godot', [string]$Python = 'python')
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$output = Join-Path $repo 'docs/qa/screenshots/functional-gates'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$engine = (Get-Command $Godot).Source
$results = [System.Collections.Generic.List[object]]::new()

function Run-Engine([string]$Name, [string]$Arguments, [string]$Marker) {
    $log = Join-Path $output ($Name + '.log')
    if (Test-Path -LiteralPath $log) { Remove-Item -LiteralPath $log }
    $process = Start-Process -FilePath $engine -WorkingDirectory $repo -WindowStyle Hidden -PassThru -ArgumentList ('--path godot --log-file "' + $log + '" ' + $Arguments)
    if (-not $process.WaitForExit(90000)) {
        $process.Kill()
        throw "$Name 시간 초과"
    }
    $process.Refresh()
    $body = Get-Content -LiteralPath $log -Raw -Encoding UTF8
    # GUT의 의도적 파일/디렉터리 충돌만 허용한다. 다른 엔진 오류는 실패다.
    $checked = $body
    if ($Name -eq 'gut' -and $body.Contains('[ExpectedError]디렉터리 대신 파일을 둔 의도적 I/O 실패')) {
        $checked = [regex]::Replace($checked, '(?m)^ERROR: Could not create directory: ''user://m4_test_[0-9]+/file/child''\.\r?$', '')
    }
    if ($process.ExitCode -ne 0 -or $checked -match 'SCRIPT ERROR:|(?m)^ERROR:' -or $body -notmatch [regex]::Escape($Marker)) {
        throw "$Name 실패: exit=$($process.ExitCode), 로그=$log"
    }
    $results.Add(@{name=$Name; exit=$process.ExitCode; marker=$Marker; log=$log})
    Write-Output "$Name PASS"
}

Push-Location $repo
try {
    # 이전 실행의 PASS 기록을 현재 실행 결과로 오인하지 않게 먼저 덮어쓴다.
    @{status='running'; approvals='미판정'} | ConvertTo-Json | Set-Content (Join-Path $output 'result.json') -Encoding UTF8
    foreach ($script in @('test_player_archer_art.py', 'test_weapon_placement.py')) {
        $ErrorActionPreference = 'Continue'
        $text = (& $Python (Join-Path 'godot/assets/tools' $script) 2>&1 | Out-String)
        $code = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        $text | Set-Content (Join-Path $output ($script + '.log')) -Encoding UTF8
        if ($code -ne 0 -or $text -notmatch '(?m)^OK\s*$' -or $text -match 'skipped=') { throw "$script 실패 또는 원본 부재로 건너뜀" }
        $results.Add(@{name=$script; exit=$code})
        Write-Output "$script PASS"
    }
    Run-Engine 'gut' '--headless -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit' 'All tests passed!'
    foreach ($phase in @('cleanup','depart','return','reload','cleanup')) {
        $name = 'journey-' + $results.Count + '-' + $phase
        Run-Engine $name ('--script ../docs/qa/tools/yeoulmok_journey_probe.gd -- ' + $phase) 'YEOULMOK_JOURNEY_PASS'
    }
    @{status='functional_evidence_pass'; approvals='G3/G4/G5·미술 미판정'; results=$results.ToArray()} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $output 'result.json') -Encoding UTF8
    Write-Output 'FUNCTIONAL_EVIDENCE_PASS — 게이트 승인 아님'
} catch {
    @{status='failed'; error=$_.Exception.Message; results=$results.ToArray()} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $output 'result.json') -Encoding UTF8
    throw
} finally {
    Pop-Location
}
