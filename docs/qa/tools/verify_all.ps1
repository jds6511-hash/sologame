# Product verification. Actual saves are read/copied/hashed, never written or restored.
param([string]$Godot = 'godot', [switch]$Combat)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$out = Join-Path $repo ('docs/qa/screenshots/verify-all/' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Force -Path $out | Out-Null
$engine = (Get-Command $Godot).Source
$userRoot = [IO.Path]::GetFullPath((Join-Path $env:APPDATA 'Godot/app_userdata/sologame'))
$actual = Join-Path $userRoot 'saves'
$copyRoot = Join-Path $userRoot 'product_real_copy'
$records = [System.Collections.Generic.List[object]]::new()
$status = 'running'
$failure = ''
$before = $null
$after = $null

function Save-Manifest([string]$Directory) {
    $result = [ordered]@{}
    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) { throw 'Actual save directory missing; real-copy verification cannot be skipped.' }
    foreach ($file in Get-ChildItem -LiteralPath $Directory -File -Recurse | Sort-Object FullName) {
        $relative = $file.FullName.Substring($Directory.Length).TrimStart('\','/')
        $result[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    }
    return $result
}

function Run-Engine([string]$Name, [string]$Arguments, [string]$Marker, [int]$Seconds = 180, [switch]$Negative, [switch]$Rendered) {
    $prefix = Join-Path $out ($records.Count.ToString('D3') + '-' + $Name)
    $log = $prefix + '.log'
    $stdout = $prefix + '-stdout.log'
    $stderr = $prefix + '-stderr.log'
    $mode = if ($Rendered) { '' } else { '--headless ' }
    $p = Start-Process -FilePath $engine -WorkingDirectory $repo -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr -ArgumentList ($mode + '--verbose --path godot --log-file "' + $log + '" ' + $Arguments)
    # Hold the native handle before a fast child exits (PowerShell 5.1 ExitCode race).
    $null = $p.Handle
    $timeout = -not $p.WaitForExit($Seconds * 1000)
    if ($timeout) { $p.Kill(); $p.WaitForExit() }
    $p.Refresh()
    $body = ''
    foreach ($path in @($log,$stdout,$stderr)) {
        if (Test-Path -LiteralPath $path) { $body += [IO.File]::ReadAllText($path) + "`n" }
    }
    $checked = $body
    # Only the existing deliberate GUT I/O fixture is allowed, and only with its marker.
    if ($Name -eq 'gut' -and $body.Contains('[ExpectedError]')) {
        $checked = [regex]::Replace($checked, '(?m)^ERROR: Could not create directory: ''user://m4_test_[0-9]+/file/child''\.\r?$', '')
    }
    # Existing BGM shutdown residue is non-blocking only when verbose type evidence
    # confirms exclusively the four known Ogg classes. Other resource errors fail.
    $leakedTypes = @([regex]::Matches($body, 'Leaked instance: ([A-Za-z0-9_]+):') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
    $knownOgg = $Name -ne 'gut' -and $leakedTypes.Count -gt 0 -and @($leakedTypes | Where-Object { $_ -notin @('OggPacketSequencePlayback','AudioStreamPlaybackOggVorbis','OggPacketSequence','AudioStreamOggVorbis') }).Count -eq 0
    if ($knownOgg) {
        $checked = [regex]::Replace($checked, '(?m)^ERROR: (?:2|4) resources still in use at exit(?: \(run with --verbose for details\))?\.\r?$', '')
    }
    $ok = -not $timeout -and $p.ExitCode -eq 0 -and $body.Contains($Marker) -and $checked -notmatch 'SCRIPT ERROR:|(?m)^ERROR:'
    if (-not $Negative -and $Name -ne 'gut' -and $body -match ': false') { $ok = $false }
    if ($Negative -and $body -match 'ONBOARDING_(MISSING_SAVE|ATTACK_DISABLED|NAVIGATION_DISABLED)_CONFIRMED') { $ok = $false }
    $warnings = @([regex]::Matches($body, '(?m)^.*(?:leaked|RID allocations|resources still in use).*$') | ForEach-Object { $_.Value } | Select-Object -Unique)
    $records.Add(@{name=$Name;pass=$ok;exit=$p.ExitCode;timeout=$timeout;log=$log;stderr=$stderr;warnings=$warnings;known_ogg_shutdown=$knownOgg;leaked_types=$leakedTypes})
    if (-not $ok) { throw "Verification failed: $Name ($log)" }
    return $body
}

function Probe-Series([string]$Name, [string]$Script, [string[]]$Phases, [string]$Marker, [switch]$Rendered) {
    foreach ($phase in $Phases) {
        $null = Run-Engine "$Name-$phase" ('-s ' + $Script + ' -- ' + $phase) $Marker -Rendered:$Rendered
    }
}

try {
    $before = Save-Manifest $actual
    $before | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $out 'actual-before.json') -Encoding UTF8
    foreach ($required in @('account.json','character_01.json','character_03.json')) {
        if (-not $before.Contains($required)) { throw "Required real-copy source missing: $required" }
    }
    # Explicit, flat QA directory only. No recursive deletion and no source mutation.
    if ([IO.Path]::GetFullPath($copyRoot) -ne [IO.Path]::GetFullPath((Join-Path $userRoot 'product_real_copy'))) { throw 'Unsafe QA destination' }
    New-Item -ItemType Directory -Force -Path $copyRoot | Out-Null
    if (Get-ChildItem -LiteralPath $copyRoot -Directory) { throw 'Unexpected subdirectory in QA copy root' }
    Get-ChildItem -LiteralPath $copyRoot -File | ForEach-Object { Remove-Item -LiteralPath $_.FullName }
    foreach ($name in @('account.json','account.json.bak','character_01.json','character_01.json.bak','character_03.json','character_03.json.bak')) {
        if ($before.Contains($name)) { Copy-Item -LiteralPath (Join-Path $actual $name) -Destination (Join-Path $copyRoot $name) }
    }
    foreach ($name in @('account.json','character_01.json','character_03.json')) {
        if ((Get-FileHash -LiteralPath (Join-Path $copyRoot $name)).Hash -ne $before[$name]) { throw 'Source changed during copy; stop the game and retry. No original is restored.' }
    }
    $null = Run-Engine 'gut' '-s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit' 'All tests passed!' 600
    # This frozen legacy cleanup predates missing-directory guards.
    New-Item -ItemType Directory -Force -Path (Join-Path $userRoot 'm4_session_process_probe') | Out-Null
    Probe-Series 'legacy-session' 'res://test/save/save_session_process_probe.gd' @('cleanup','seed','verify','cleanup') 'M4_SESSION_PROCESS_PASS'
    Probe-Series 'legacy-migration' 'res://test/save/m5_migration_process_probe.gd' @('cleanup','seed','upgrade','verify','cleanup') 'M5_MIGRATION_PROCESS_PASS'
    Probe-Series 'c1-migration' 'res://test/save/c1_session_process_probe.gd' @('cleanup','seed','hold','hold','save','verify','cleanup') 'C1_SESSION_PROCESS_PASS'
    Probe-Series 'm6-api' '../docs/qa/tools/m6_candidate_probe.gd' @('cleanup','seed','reload','cleanup') 'M6_CANDIDATE_PASS'
    Probe-Series 'm7-api' '../docs/qa/tools/m7_candidate_probe.gd' @('cleanup','seed','reload','cleanup') 'M7_CANDIDATE_PASS'
    Probe-Series 'closure-api' '../docs/qa/tools/closure_candidate_probe.gd' @('cleanup','seed','reload_mid','reload','cleanup') 'M7_CLOSURE_CANDIDATE_PASS'
    # Journey captures UI rectangles; it renders but never warps the OS pointer.
    Probe-Series 'journey' '../docs/qa/tools/yeoulmok_journey_probe.gd' @('cleanup','depart','return','reload','cleanup') 'YEOULMOK_JOURNEY_PASS' -Rendered
    foreach ($job in @('warrior','archer','gladiator')) {
        foreach ($phase in @('cleanup','play','reload','cleanup')) {
            $null = Run-Engine "job-$job-$phase" ('-s ../docs/qa/tools/job_save_menu_probe.gd -- ' + $job + ' ' + $phase) 'JOB_SAVE_MENU_PASS'
        }
    }
    Probe-Series 'product-migration' '../docs/qa/tools/m6_product_process_probe.gd' @('cleanup','seed','migrate','verify','cleanup') 'M6_PRODUCT_PROCESS_PASS'
    Probe-Series 'product-content' '../docs/qa/tools/product_content_probe.gd' @('cleanup','seed','reload_mid','reload','cleanup') 'PRODUCT_CONTENT_PASS'
    foreach ($slot in @(1,3)) {
        foreach ($phase in @('migrate','verify')) {
            $null = Run-Engine "real-copy-$slot-$phase" ('-s ../docs/qa/tools/product_real_copy_probe.gd -- ' + $phase + ' ' + $slot) 'PRODUCT_REAL_COPY_PASS'
        }
    }
    $null = Run-Engine 'guards-cleanup' '-s ../docs/qa/tools/yeoulmok_onboarding_probe.gd -- cleanup' 'YEOULMOK_ONBOARDING_PASS'
    foreach ($phase in @('reload','walk','hunt','death')) {
        $body = Run-Engine "guard-$phase" ('--fixed-fps 60 -s ../docs/qa/tools/onboarding_guard_probe.gd -- ' + $phase) 'ONBOARDING_GUARD_PROBE_DONE' 300 -Negative
        $target = switch ($phase) {
            'reload' { '별도 프로세스 로드: false' }
            'walk' { '동적 도보 시간 초과:' }
            'hunt' { '실제 처치 시간 초과:' }
            'death' { 'ONBOARDING_DEATH_GUARD: true' }
        }
        if (-not $body.Contains($target)) { throw "Guard did not reach target: $phase" }
    }
    if ($Combat) {
        # The only rendered/OS-pointer-moving path; fixed three runs, diagnostic, not an adoption gate.
        $combatLog = Join-Path $out 'combat.log'
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'run_yeoulmok_onboarding.ps1') -Godot $Godot -Product -Runs 3 *> $combatLog
        $records.Add(@{name='optional-combat';pass=($LASTEXITCODE -eq 0);exit=$LASTEXITCODE;log=$combatLog;adoption_gate=$false})
    }
    $status = 'pass'
} catch {
    $failure = $_.Exception.Message
    $status = 'failed'
} finally {
    try {
        $after = Save-Manifest $actual
        $after | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $out 'actual-after.json') -Encoding UTF8
        if ($null -eq $before -or ($before | ConvertTo-Json -Compress) -ne ($after | ConvertTo-Json -Compress)) {
            $status = 'failed'
            $failure += ' Actual save manifest changed (possibly a concurrently running game). Original files were not restored.'
        }
    } catch { $status='failed'; $failure += ' Cannot verify final actual-save hashes: ' + $_.Exception.Message }
    @{status=$status;error=$failure;format=6;content_revision=1;combat_requested=[bool]$Combat;actual_unchanged=($null -ne $before -and $null -ne $after -and ($before | ConvertTo-Json -Compress) -eq ($after | ConvertTo-Json -Compress));results=$records.ToArray()} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $out 'result.json') -Encoding UTF8
}
Write-Output ("VERIFY_ALL_{0} steps={1} result={2} {3}" -f $status.ToUpper(),$records.Count,(Join-Path $out 'result.json'),$failure)
if ($status -ne 'pass') { exit 1 }
