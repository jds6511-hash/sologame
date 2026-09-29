param([string]$Godot = 'godot')
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$output = Join-Path $repo 'docs/qa/screenshots/onboarding'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$engine = (Get-Command $Godot).Source
$results = [System.Collections.Generic.List[object]]::new()

function Run-Phase([string]$Phase, [int]$Expected, [bool]$Rendered) {
    $log = Join-Path $output ($Phase + '-' + $results.Count + '.log')
    $mode = if ($Rendered) { '' } else { '--headless ' }
    $arguments = $mode + '--path godot --fixed-fps 60 --log-file "' + $log + '" --script ../docs/qa/tools/yeoulmok_onboarding_probe.gd -- ' + $Phase
    $process = Start-Process -FilePath $engine -WorkingDirectory $repo -WindowStyle Hidden -PassThru -ArgumentList $arguments
    if (-not $process.WaitForExit(300000)) {
        $process.Kill()
        throw "Timeout: $Phase"
    }
    $process.Refresh()
    $body = Get-Content -LiteralPath $log -Raw -Encoding UTF8
    $marker = if ($Expected -eq 0) { 'YEOULMOK_ONBOARDING_PASS' } else { 'YEOULMOK_ONBOARDING_FAIL' }
    if ($process.ExitCode -ne $Expected -or $body -match 'SCRIPT ERROR:|(?m)^ERROR:' -or -not $body.Contains($marker)) {
        throw "Phase failed: $Phase, exit=$($process.ExitCode), log=$log"
    }
    if ($Expected -eq 1) {
        $negative = if ($Phase -eq 'blocked') { 'ONBOARDING_ATTACK_DISABLED_CONFIRMED' } else { 'ONBOARDING_MISSING_SAVE_CONFIRMED' }
        if (-not $body.Contains($negative)) { throw "Wrong negative path: $Phase, log=$log" }
    }
    $results.Add(@{phase=$Phase; exit=$process.ExitCode; expected=$Expected; log=$log})
    Write-Output "$Phase : expected exit $Expected"
}

try {
    @{status='running'} | ConvertTo-Json | Set-Content (Join-Path $output 'result.json') -Encoding UTF8
    Run-Phase 'cleanup' 0 $false
    Run-Phase 'reload' 1 $false
    Run-Phase 'blocked' 1 $true
    Run-Phase 'play' 0 $true
    Run-Phase 'reload' 0 $false
    Run-Phase 'cleanup' 0 $false
    @{status='pass'; human_play=$false; results=$results.ToArray()} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $output 'result.json') -Encoding UTF8
    Write-Output 'YEOULMOK_ONBOARDING_SUITE_PASS'
} catch {
    @{status='failed'; error=$_.Exception.Message; results=$results.ToArray()} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $output 'result.json') -Encoding UTF8
    throw
}
