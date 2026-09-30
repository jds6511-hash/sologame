param([string]$Godot = 'godot', [ValidateRange(1, 10)][int]$Runs = 3, [switch]$Product)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$output = Join-Path $repo ('docs/qa/screenshots/onboarding/batch-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Force -Path $output | Out-Null
$engine = (Get-Command $Godot).Source
$probe = if ($Product) { 'm6_product_combat_probe.gd' } else { 'yeoulmok_onboarding_probe.gd' }
$results = [System.Collections.Generic.List[object]]::new()
$trials = [System.Collections.Generic.List[object]]::new()

function Run-Phase([string]$Phase, [int]$Expected, [bool]$Rendered) {
    $log = Join-Path $output ($Phase + '-' + $results.Count + '.log')
    $mode = if ($Rendered) { '' } else { '--headless ' }
    $arguments = $mode + '--path godot --fixed-fps 60 --log-file "' + $log + '" --script ../docs/qa/tools/' + $probe + ' -- ' + $Phase
    $process = Start-Process -FilePath $engine -WorkingDirectory $repo -WindowStyle Hidden -PassThru -ArgumentList $arguments
    if (-not $process.WaitForExit(300000)) {
        $process.Kill()
        throw "Timeout: $Phase"
    }
    $process.Refresh()
    $body = Get-Content -LiteralPath $log -Raw -Encoding UTF8
    $marker = if ($Expected -eq 0) { 'YEOULMOK_ONBOARDING_PASS' } else { 'YEOULMOK_ONBOARDING_FAIL' }
    $valid = $process.ExitCode -eq $Expected -and $body -notmatch 'SCRIPT ERROR:|(?m)^ERROR:' -and $body.Contains($marker)
    $record = @{trial=$trial; phase=$Phase; exit=$process.ExitCode; expected=$Expected; log=$log; valid=$valid}
    $results.Add($record)
    if (-not $valid) {
        throw "Phase failed: $Phase, exit=$($process.ExitCode), log=$log"
    }
    if ($Expected -eq 1) {
        $negative = switch ($Phase) {
            'blocked' { 'ONBOARDING_ATTACK_DISABLED_CONFIRMED' }
            'walk_blocked' { 'ONBOARDING_NAVIGATION_DISABLED_CONFIRMED' }
            default { 'ONBOARDING_MISSING_SAVE_CONFIRMED' }
        }
        if (-not $body.Contains($negative)) {
            $record.valid = $false
            throw "Wrong negative path: $Phase, log=$log"
        }
    }
    Write-Output "$Phase : expected exit $Expected"
}

try {
    Write-Output "Logs: $output"
    Write-Output "Probe: $probe"
    for ($trial = 1; $trial -le $Runs; $trial++) {
        @{status='running'; planned=$Runs; trials=$trials.ToArray(); results=$results.ToArray()} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $output 'result.json') -Encoding UTF8
        try {
            Run-Phase 'cleanup' 0 $false
            Run-Phase 'reload' 1 $false
            Run-Phase 'walk_blocked' 1 $true
            Run-Phase 'blocked' 1 $true
            Run-Phase 'play' 0 $true
            Run-Phase 'reload' 0 $false
            Run-Phase 'cleanup' 0 $false
            $trials.Add(@{trial=$trial; status='pass'})
        } catch {
            $trials.Add(@{trial=$trial; status='failed'; error=$_.Exception.Message})
        }
        Write-Output ("Trial {0}/{1}: {2}" -f $trial, $Runs, $trials[$trials.Count-1].status)
    }
    $passed = @($trials | Where-Object { $_.status -eq 'pass' }).Count
    $status = if ($passed -eq $Runs) { 'pass' } else { 'failed' }
    @{status=$status; planned=$Runs; passed=$passed; repeated_check=($Runs -ge 3 -and $passed -eq $Runs); human_play=$false; trials=$trials.ToArray(); results=$results.ToArray()} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $output 'result.json') -Encoding UTF8
    if ($passed -ne $Runs) { throw "Batch failed: $passed/$Runs; logs=$output" }
    Write-Output 'YEOULMOK_ONBOARDING_SUITE_PASS'
} catch {
    @{status='failed'; planned=$Runs; passed=@($trials | Where-Object { $_.status -eq 'pass' }).Count; error=$_.Exception.Message; trials=$trials.ToArray(); results=$results.ToArray()} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $output 'result.json') -Encoding UTF8
    throw
}
