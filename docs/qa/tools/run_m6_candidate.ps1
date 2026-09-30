param([string]$Godot = 'godot', [switch]$Combat)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$out = Join-Path $repo ('docs/qa/screenshots/m6/' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $out | Out-Null
$engine = (Get-Command $Godot).Source
$records = [System.Collections.Generic.List[object]]::new()
function Run-Check([string]$Script, [string]$Phase, [string]$Marker, [bool]$Rendered) {
    $log = Join-Path $out ($records.Count.ToString() + '-' + $Phase + '.log')
    $mode = if ($Rendered) { '--fixed-fps 60 ' } else { '--headless ' }
    $arguments = $mode + '--path godot --log-file "' + $log + '" --script ../docs/qa/tools/' + $Script + ' -- ' + $Phase
    $p = Start-Process -FilePath $engine -WorkingDirectory $repo -ArgumentList $arguments -WindowStyle Hidden -PassThru
    if (-not $p.WaitForExit(300000)) { $p.Kill(); throw "Timeout: $Phase" }
    $p.Refresh()
    $body = Get-Content -LiteralPath $log -Raw -Encoding UTF8
    $ok = $p.ExitCode -eq 0 -and $body.Contains($Marker) -and $body -notmatch 'SCRIPT ERROR:|(?m)^ERROR:|: false'
    $records.Add(@{phase=$Phase; exit=$p.ExitCode; pass=$ok; log=$log})
    $records.ToArray() | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $out 'result.json') -Encoding UTF8
    if (-not $ok) { throw "Failed: $Phase; $log" }
    Write-Output "M6_PHASE_PASS $Phase"
}
foreach ($phase in @('cleanup','seed','reload','cleanup')) {
    Run-Check 'm6_candidate_probe.gd' $phase 'M6_CANDIDATE_PASS' $false
}
if ($Combat) {
    foreach ($phase in @('cleanup','play','reload','cleanup')) {
        Run-Check 'm6_combat_probe.gd' $phase 'YEOULMOK_ONBOARDING_PASS' ($phase -eq 'play')
    }
}
Write-Output "M6_CANDIDATE_SUITE_PASS $out"
