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
$qaMutex = New-Object System.Threading.Mutex($false, 'Local\sologame_verify_all')
$ownsQa = $false

function Save-Manifest([string]$Directory) {
    $result = [ordered]@{}
    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) { throw 'Actual save directory missing; real-copy verification cannot be skipped.' }
    foreach ($file in Get-ChildItem -LiteralPath $Directory -File -Recurse | Sort-Object FullName) {
        $relative = $file.FullName.Substring($Directory.Length).TrimStart('\','/')
        $result[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    }
    return $result
}

function Run-Engine([string]$Name, [string]$Arguments, [string]$Marker, [int]$Seconds = 180, [switch]$Negative, [switch]$Rendered, [switch]$ExpectedInterruption) {
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
    if ($ExpectedInterruption) {
        # Godot OS.kill(self) uses exit code 0 on Windows. The reached marker,
        # absent normal-return marker and the following independent disk check
        # distinguish interruption from an ordinary successful return.
        $ok = -not $timeout -and $p.ExitCode -eq 0 -and $body.Contains('M4_PROCESS_INTERRUPT_REACHED') -and -not $body.Contains('M4_PROCESS_INTERRUPT_RETURNED') -and $checked -notmatch 'SCRIPT ERROR:|(?m)^ERROR:'
    }
    if (-not $Negative -and $Name -ne 'gut' -and $body -match ': false') { $ok = $false }
    if ($Negative -and $body -match 'ONBOARDING_(MISSING_SAVE|ATTACK_DISABLED|NAVIGATION_DISABLED)_CONFIRMED') { $ok = $false }
    if ($leakedTypes.Count -gt 0 -and -not $knownOgg) { $ok = $false }
    if ($body -match "ObjectDB instances leaked|ObjectDB instances were leaked" -and $leakedTypes.Count -eq 0) { $ok = $false }
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
    $ownsQa = $qaMutex.WaitOne(0)
    if (-not $ownsQa) { throw 'Another verify_all is using shared QA directories. No QA files were changed.' }
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
    foreach ($check in @(
        @{name='content-tests';script='docs/qa/tools/test_chapter_content.py';arguments=@()},
        @{name='chapter-four-tests';script='docs/qa/tools/test_chapter_four_content.py';arguments=@()},
        @{name='chapter-six-tests';script='docs/qa/tools/test_chapter_six_content.py';arguments=@()},
        @{name='chapter-seven-tests';script='docs/qa/tools/test_chapter_seven_content.py';arguments=@()},
        @{name='chapter-five-tests';script='docs/qa/tools/test_chapter_five_content.py';arguments=@()},
        @{name='content-kill-exp-tests';script='docs/qa/tools/test_content_kill_exp.py';arguments=@()},
        @{name='content-generated';script='tools/generate_chapter_content.py';arguments=@('--check')}
    )) {
        $log = Join-Path $out ($check.name + '.log')
        $script = Join-Path $repo $check.script
        $arguments = $check.arguments
        $pythonArgs = '"' + $script + '" ' + ($arguments -join ' ')
        $process = Start-Process -FilePath (Get-Command python).Source -ArgumentList $pythonArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput $log -RedirectStandardError ($log + '.stderr')
        $null = $process.Handle
        $process.WaitForExit()
        $process.Refresh()
        $code = $process.ExitCode
        $records.Add(@{name=$check.name;pass=($code -eq 0);exit=$code;log=$log})
        if ($code -ne 0) { throw "Content verification failed: $($check.name)" }
    }
    $null = Run-Engine 'gut' '-s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit' 'All tests passed!' 600
    # This frozen legacy cleanup predates missing-directory guards.
    New-Item -ItemType Directory -Force -Path (Join-Path $userRoot 'm4_session_process_probe') | Out-Null
    Probe-Series 'legacy-session' 'res://test/save/save_session_process_probe.gd' @('cleanup','seed','verify','cleanup') 'M4_SESSION_PROCESS_PASS'
    Probe-Series 'legacy-migration' 'res://test/save/m5_migration_process_probe.gd' @('cleanup','seed','upgrade','verify','cleanup') 'M5_MIGRATION_PROCESS_PASS'
    Probe-Series 'c1-migration' 'res://test/save/c1_session_process_probe.gd' @('cleanup','seed','hold','hold','save','verify','cleanup') 'C1_SESSION_PROCESS_PASS'
    Probe-Series 'first-quest' 'res://test/quests/first_quest_process_probe.gd' @('cleanup','seed','active','ready','completed','legacy','third_seed','third_active','third_ready','third_completed','cleanup') 'M5_FIRST_QUEST_PROCESS_PASS'
    Probe-Series 'fourth-quest' 'res://test/quests/fourth_quest_process_probe.gd' @('cleanup','seed','active','reach','ready','completed','completed','cleanup') 'M5_FOURTH_PROCESS_PASS'
    Probe-Series 'chapter-departure' 'res://test/quests/chapter_departure_process_probe.gd' @('cleanup','seed','depart','verify','return','cleanup','unsaved','cleanup','legacy','cleanup','legacy2','cleanup') 'CHAPTER_DEPARTURE_PASS'
    foreach ($suffix in @('','_mid')) {
        Probe-Series "store-interrupt$suffix" 'res://test/save/save_store_process_probe.gd' @('cleanup','seed') 'M4_PROCESS_SETUP_PASS'
        $null = Run-Engine "store-interrupt$suffix-kill" ('-s res://test/save/save_store_process_probe.gd -- interrupt' + $suffix) 'M4_PROCESS_INTERRUPT_REACHED' -ExpectedInterruption
        $null = Run-Engine "store-interrupt$suffix-verify" ('-s res://test/save/save_store_process_probe.gd -- verify' + $suffix) 'M4_PROCESS_PRESERVATION_PASS'
        Probe-Series "store-interrupt$suffix" 'res://test/save/save_store_process_probe.gd' @('cleanup') 'M4_PROCESS_SETUP_PASS'
    }
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
    Probe-Series 'product-defense' '../docs/qa/tools/product_defense_probe.gd' @('cleanup','seed','reload_mid','reload','cleanup') 'PRODUCT_DEFENSE_PASS'
    Probe-Series 'second-job' '../docs/qa/tools/second_job_process_probe.gd' @('cleanup','seed','reload','cleanup') 'SECOND_JOB_PROCESS_PASS'
    Probe-Series 'product-territory' '../docs/qa/tools/product_territory_probe.gd' @('cleanup','seed','reload_mid','reload','cleanup') 'PRODUCT_TERRITORY_PASS'
    foreach ($phase in @('cleanup','seed','reload_mid','reload','cleanup')) {
        $null = Run-Engine "product-chapter-five-$phase" ('-s ../docs/qa/tools/product_territory_probe.gd -- ' + $phase + ' 5') 'PRODUCT_TERRITORY_PASS' 180
    }
    foreach ($phase in @('cleanup','seed','reload_mid','reload','cleanup')) {
        $null = Run-Engine "product-chapter-six-$phase" ('-s ../docs/qa/tools/product_territory_probe.gd -- ' + $phase + ' 6') 'PRODUCT_TERRITORY_PASS' 180
    }
    foreach ($phase in @('cleanup','seed','reload_mid','reload','cleanup')) {
        $null = Run-Engine "product-chapter-seven-$phase" ('-s ../docs/qa/tools/product_territory_probe.gd -- ' + $phase + ' 7') 'PRODUCT_TERRITORY_PASS' 180
    }
    foreach ($slot in @(1,3)) {
        foreach ($phase in @('migrate','verify')) {
            $null = Run-Engine "real-copy-$slot-$phase" ('-s ../docs/qa/tools/product_real_copy_probe.gd -- ' + $phase + ' ' + $slot) 'PRODUCT_REAL_COPY_PASS'
        }
    }
    $null = Run-Engine 'guards-cleanup' '-s ../docs/qa/tools/yeoulmok_onboarding_probe.gd -- cleanup' 'YEOULMOK_ONBOARDING_PASS'
    foreach ($phase in @('reload','walk','hunt','death')) {
        # Existing walk/hunt guards require rendering and may move the OS pointer,
        # even when -Combat is absent. Do not run alongside manual game input.
        $body = Run-Engine "guard-$phase" ('--fixed-fps 60 -s ../docs/qa/tools/onboarding_guard_probe.gd -- ' + $phase) 'ONBOARDING_GUARD_PROBE_DONE' 300 -Negative -Rendered:($phase -in @('walk','hunt'))
        $target = switch ($phase) {
            'reload' { '별도 프로세스 로드: false' }
            'walk' { '동적 도보 시간 초과:' }
            'hunt' { '실제 처치 시간 초과:' }
            'death' { 'ONBOARDING_DEATH_GUARD: true' }
        }
        if (-not $body.Contains($target)) { throw "Guard did not reach target: $phase" }
        if ($phase -eq 'death' -and -not $body.Contains('대기 포함 전체 세션 사망 감지: false')) { throw 'Death guard did not record the injected session failure' }
    }
    if ($Combat) {
        # Additional full combat path; fixed three runs, diagnostic, not an adoption gate.
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
    @{status=$status;error=$failure;format=7;content_revision=6;combat_requested=[bool]$Combat;actual_unchanged=($null -ne $before -and $null -ne $after -and ($before | ConvertTo-Json -Compress) -eq ($after | ConvertTo-Json -Compress));results=$records.ToArray()} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $out 'result.json') -Encoding UTF8
}
if ($ownsQa) { $qaMutex.ReleaseMutex() }
$qaMutex.Dispose()
Write-Output ("VERIFY_ALL_{0} steps={1} result={2} {3}" -f $status.ToUpper(),$records.Count,(Join-Path $out 'result.json'),$failure)
if ($status -ne 'pass') { exit 1 }
