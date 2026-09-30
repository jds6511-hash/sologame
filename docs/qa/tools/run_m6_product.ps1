param([string]$Godot='godot')
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$out=Join-Path $repo ('docs/qa/screenshots/m6-product/' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Force $out | Out-Null
$engine=(Get-Command $Godot).Source
$records=[System.Collections.Generic.List[object]]::new()
foreach($phase in @('cleanup','seed','migrate','verify','cleanup')) {
    $log=Join-Path $out ($records.Count.ToString()+'-'+$phase+'.log')
    $arguments='--headless --path godot --log-file "'+$log+'" -s ../docs/qa/tools/m6_product_process_probe.gd -- '+$phase
    $p=Start-Process -FilePath $engine -WorkingDirectory $repo -ArgumentList $arguments -WindowStyle Hidden -PassThru
    $timeout=-not $p.WaitForExit(90000)
    if($timeout){$p.Kill(); $p.WaitForExit()}
    $p.Refresh()
    $body=if(Test-Path -LiteralPath $log){Get-Content -LiteralPath $log -Raw -Encoding UTF8}else{''}
    $ok=-not $timeout -and $p.ExitCode -eq 0 -and $body.Contains('M6_PRODUCT_PROCESS_PASS') -and $body -notmatch 'SCRIPT ERROR:|(?m)^ERROR:|: false'
    $records.Add(@{phase=$phase;exit=$p.ExitCode;timeout=$timeout;pass=$ok;log=$log})
    $records.ToArray() | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $out 'result.json')
    if(-not $ok){throw "M6_PRODUCT_PHASE_FAIL $phase $log"}
    Write-Output "M6_PRODUCT_PHASE_PASS $phase"
}
Write-Output "M6_PRODUCT_SUITE_PASS $out"
