# Model arithmetic only. No Godot execution and no production save changes.
$ErrorActionPreference = 'Stop'
Write-Output 'BASELINE_REGRESSION: the following limitation applies before the new mandatory rewards'
. (Join-Path $PSScriptRoot 'verify_100_hour_budget.ps1')
$marginText = Get-Content -Encoding UTF8 (Join-Path $PSScriptRoot '../../design/100-hour-exp-margin.md')
function Cumulative([int]$level) {
    $sum = 0L
    for ($n = 1; $n -lt $level; $n++) { $sum += Req $n }
    return $sum
}
$schedule = @($marginText | Where-Object { $_ -match '^\| S(7|11|12):' })
Check ($schedule.Count -eq 3) 'Missing reward schedule'
$priorBonus = 0L; $bonuses = @{}; $frontloads = @{}
foreach ($line in $schedule) {
    $c = Cells $line
    $id = [int]([regex]::Match($c[1], '^S(\d+):').Groups[1].Value)
    $frontloads[$id] = Number $c[2]; $bonuses[$id] = Number $c[3]
    $priorBonus += $bonuses[$id]
    Check ($priorBonus -eq (Number $c[4])) 'Bonus cumulative mismatch'
    if ($id -ne 12) {
        $baseRow = Cells $xpRows[$id - 1]
        $report = Number $baseRow[3]
        Check ($frontloads[$id] -le $report - (RoundPositive ($report * 0.4))) 'Frontload exceeds main pool'
    }
}
Check ($priorBonus -eq (RoundPositive ((Cumulative 96) * 0.1))) 'Bonus must be 10% of campaign pool'
$gateRows = @($marginText | Where-Object { $_ -match '^\| G(40|80|95) \|' })
Check ($gateRows.Count -eq 3) 'Missing gate rows'
$aLoss = 0L; $bLoss = 0L; $snapshot = @{}
foreach ($line in $xpRows) {
    $c = Cells $line; $chapter = [int]$c[1]
    if ($chapter -gt 1) {
        $optional = RoundPositive ((Number $c[3]) * 0.4)
        $aLoss += RoundPositive ($optional * 0.2)
        $bLoss += RoundPositive (($optional + (Number $c[4])) * 0.2)
    }
    $snapshot[$chapter] = @($aLoss, $bLoss)
}
foreach ($line in $gateRows) {
    $c = Cells $line; $gate = [int]$c[1].Substring(1)
    switch ($gate) {
        40 { $supply = (Cumulative 39) + $frontloads[7] + $bonuses[7]; $loss = $snapshot[6] }
        80 { $supply = (Cumulative 80) + $frontloads[11] + $bonuses[7] + $bonuses[11]; $loss = $snapshot[10] }
        95 { $supply = (Cumulative 96) - 500000 + $priorBonus; $loss = $snapshot[12] }
    }
    $required = Cumulative $gate
    $aSupply = $supply - $loss[0]; $bSupply = $supply - $loss[1]
    Check ((Number $c[3]) -eq $required -and (Number $c[4]) -eq $supply) 'Gate baseline mismatch'
    Check ((Number $c[5]) -eq $aSupply -and (Number $c[6]) -eq $bSupply) 'Gate omission mismatch'
    Check ((Number $c[7]) -eq $bSupply - $required) 'Gate surplus mismatch'
    Check ($aSupply -ge $required -and $bSupply -ge $required) 'Gate cannot be reached'
    Check ($bSupply - $required -ge $required * 0.01) "Gate G$gate margin below 1%"
}
$postgame = (Cumulative 100) - (Cumulative 96) - $priorBonus
Check ($postgame -eq 2902526) 'Postgame residual mismatch'
Check ((RoundPositive ($postgame * 0.7)) -eq 2031768) 'Postgame report split mismatch'
Check ((ReachedLevel $supply) -eq 98 -and (ReachedLevel $aSupply) -eq 96 -and (ReachedLevel $bSupply) -eq 95) 'Final entry levels mismatch'
Check ($bonuses[7] -eq 500000 -and $bonuses[11] -eq 2060000 -and $bonuses[12] -eq 2799780) 'Reward schedule mismatch'
Write-Output 'EXP_MARGIN_MODEL_PASS: all gates B margin >=1%; G40 B+521943; G80 B+282608; G95 B+578104; final entry98/96/95; guaranteed bonus5359780; postgame2902526'
Write-Output 'CONTENT_TIMING_UNVERIFIED: mandatory quest slots, pre-boss allocation, quest reward rounding and real playtime remain untested'
