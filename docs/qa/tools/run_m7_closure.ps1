param([string]$Godot='godot', [switch]$Combat)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$out=Join-Path $repo ('docs/qa/screenshots/m7-closure/' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Force $out | Out-Null
$engine=(Get-Command $Godot).Source
$records=[System.Collections.Generic.List[object]]::new()
# 시작 전 고정: 전투 3회, 내부900초/외부960초. 실패 표본을 모두 남긴다.
function Check-Phase([string]$Script,[string]$Phase,[string]$Marker,[bool]$Rendered,[int]$Run) {
    $log=Join-Path $out ($records.Count.ToString()+'-'+$Phase+'.log')
    $mode=if($Rendered){'--fixed-fps 60 '}else{'--headless '}
    $arguments=$mode+'--path godot --log-file "'+$log+'" -s ../docs/qa/tools/'+$Script+' -- '+$Phase
    $p=Start-Process -FilePath $engine -WorkingDirectory $repo -ArgumentList $arguments -WindowStyle Hidden -PassThru
    $timedOut=-not $p.WaitForExit(960000)
    if($timedOut){$p.Kill(); $p.WaitForExit()}
    $p.Refresh()
    $body=if(Test-Path -LiteralPath $log){Get-Content -LiteralPath $log -Raw -Encoding UTF8}else{''}
    $ok=-not $timedOut -and $p.ExitCode -eq 0 -and $body.Contains($Marker) -and $body -notmatch 'SCRIPT ERROR:|(?m)^ERROR:|: false'
    $records.Add(@{run=$Run;phase=$Phase;exit=$p.ExitCode;timeout=$timedOut;pass=$ok;log=$log})
    $records.ToArray() | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $out 'result.json')
    if(-not $ok){throw "실패: $Phase; $log"}
    Write-Output "M7_CLOSURE_PHASE_PASS $Phase"
}
$allPassed=$true
try{
    foreach($phase in @('cleanup','seed','reload_mid','reload','cleanup')){
        Check-Phase 'closure_candidate_probe.gd' $phase 'M7_CLOSURE_CANDIDATE_PASS' $false 0
    }
}catch{$allPassed=$false; Write-Output $_}
if($Combat){
    for($run=1;$run -le 3;$run++){
        try{
            foreach($phase in @('cleanup','play','reload_mid','reload','cleanup')){
                Check-Phase 'closure_combat_probe.gd' $phase 'M7_CLOSURE_COMBAT_PASS' ($phase -eq 'play') $run
            }
        }catch{ $allPassed=$false; Write-Output $_ }
    }
}
if(-not $allPassed){Write-Output "M7_CLOSURE_SUITE_FAIL $out"; exit 1}
Write-Output "M7_CLOSURE_SUITE_PASS $out"
