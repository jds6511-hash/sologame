param([string]$Godot='godot', [switch]$Combat, [ValidateRange(1,3)][int]$Runs=3)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$out=Join-Path $repo ('docs/qa/screenshots/m7/' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Force $out | Out-Null
$engine=(Get-Command $Godot).Source
$records=[System.Collections.Generic.List[object]]::new()
function Check-Phase([string]$Script,[string]$Phase,[string]$Marker,[bool]$Rendered,[int]$Run) {
    $log=Join-Path $out ($records.Count.ToString()+'-'+$Phase+'.log')
    $mode=if($Rendered){'--fixed-fps 60 '}else{'--headless '}
    $arguments=$mode+'--path godot --log-file "'+$log+'" -s ../docs/qa/tools/'+$Script+' -- '+$Phase
    $p=Start-Process -FilePath $engine -WorkingDirectory $repo -ArgumentList $arguments -WindowStyle Hidden -PassThru
    if(-not $p.WaitForExit(660000)){ $p.Kill(); throw "시간 초과: $Phase" }
    $p.Refresh()
    $body=Get-Content -LiteralPath $log -Raw -Encoding UTF8
    $ok=$p.ExitCode -eq 0 -and $body.Contains($Marker) -and $body -notmatch 'SCRIPT ERROR:|(?m)^ERROR:|: false'
    $records.Add(@{run=$Run;phase=$Phase;exit=$p.ExitCode;pass=$ok;log=$log})
    $records.ToArray() | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $out 'result.json')
    if(-not $ok){throw "실패: $Phase; $log"}
    Write-Output "M7_PHASE_PASS $Phase"
}
foreach($phase in @('cleanup','seed','reload','cleanup')){
    Check-Phase 'm7_candidate_probe.gd' $phase 'M7_CANDIDATE_PASS' $false 0
}
$allPassed=$true
if($Combat){
    for($run=1;$run -le $Runs;$run++){
        try{
            foreach($phase in @('cleanup','play','reload','cleanup')){
                Check-Phase 'm7_combat_probe.gd' $phase 'YEOULMOK_ONBOARDING_PASS' ($phase -eq 'play') $run
            }
        }catch{ $allPassed=$false; Write-Output $_ }
    }
}
if(-not $allPassed){Write-Output "M7_CANDIDATE_SUITE_FAIL $out"; exit 1}
Write-Output "M7_CANDIDATE_SUITE_PASS $out"
