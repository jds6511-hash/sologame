# Documentation arithmetic only; does not launch Godot or validate real playtime.
$ErrorActionPreference = 'Stop'
$budgetPath = Join-Path $PSScriptRoot '../../design/100-hour-progression-budget.md'
$lines = Get-Content -Encoding UTF8 -LiteralPath $budgetPath
function Check($condition, $message) {
    if (-not $condition) { throw $message }
}
function Number($value) {
    return [double]::Parse(($value -replace ',', ''), [Globalization.CultureInfo]::InvariantCulture)
}
function Cells($line) { return @($line.Split('|') | ForEach-Object { $_.Trim() }) }
function Req([int]$level) {
    $multiplier = 0.4
    if ($level -lt 10) { $multiplier = 0.45 }
    elseif ($level -lt 20) { $multiplier = [Math]::Pow(0.4, ($level - 10) / 10.0) }
    return [long][Math]::Round(55 * [Math]::Pow($level, 2.5) * $multiplier, 0, [MidpointRounding]::AwayFromZero)
}
$times = @($lines | Where-Object { $_ -match '^\| \d+ [^|]+ \|' })
Check ($times.Count -eq 12) 'Expected 12 chapter rows'
$activities = @(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
$mainCount = 0; $sideCount = 0; $extraCount = 0; $levels = @(1)
foreach ($line in $times) {
    $c = Cells $line
    $levels += [int]$c[3]
    $mainCount += [int]$c[4]; $sideCount += [int]$c[5]; $extraCount += [int]$c[6]
    $parts = $c[7].Split('/')
    $range = $c[2] -split '\u2013'
    $rowSum = 0.0
    for ($i = 0; $i -lt 6; $i++) {
        $value = Number $parts[$i]; Check ($value -ge 0) 'Negative activity time'
        $activities[$i] += $value; $rowSum += $value
    }
    Check ([Math]::Abs($rowSum - ((Number $range[1]) - (Number $range[0]))) -lt 0.00001) "Chapter time mismatch: $line"
}
$post = Cells ($lines | Where-Object { $_ -match '^\| [^|]+ \| 85' })
$sideCount += [int]$post[5]
$postParts = $post[7].Split('/')
$expected = @(40,30,5,7,3,15)
for ($i = 0; $i -lt 6; $i++) { $activities[$i] += Number $postParts[$i]; Check ([Math]::Abs($activities[$i] - $expected[$i]) -lt 0.00001) 'Activity total mismatch' }
Check ($mainCount -eq 61 -and $sideCount -eq 120 -and $extraCount -eq 30) 'Content count mismatch'
$mainRep = 0; $sideRep = 0; $largestChapterRep = 0
foreach ($line in ($lines | Where-Object { $_ -match '^\| R\d+ \|' })) {
    $c = Cells $line; $gate = Number $c[3]; $supply = Number $c[4]
    Check ($supply -eq $mainRep + $sideRep) 'Reputation counted before earned'
    Check ($supply -ge 1.2 * $gate) 'Reputation margin below 20%'
    Check ((Number $c[6]) -eq $mainRep + 0.8 * $sideRep) 'Stress supply mismatch'
    Check ((Number $c[6]) -ge $gate) 'Stress gate failed'
    Check ($supply - $largestChapterRep -ge $gate) 'Whole chapter omission gate failed'
    $largestChapterRep = [Math]::Max($largestChapterRep, (Number $c[8]))
    $mainRep += Number $c[7]; $sideRep += Number $c[8]
}
Check ($mainRep -eq 8600 -and $sideRep -eq 5000) 'Reputation totals mismatch'
$xpRows = @($lines | Where-Object { $_ -match '^\| \d+ \|' })
Check ($xpRows.Count -eq 12) 'Expected 12 EXP rows'
$totalXp = 0; $lossA = 0; $lossB = 0
$stressRows = @($lines | Where-Object { $_ -match '^\| E\d+ \|' })
Check ($stressRows.Count -eq 12) 'Expected 12 EXP omission rows'
function RoundPositive($value) { return [long][Math]::Round($value, 0, [MidpointRounding]::AwayFromZero) }
function ReachedLevel($xp) {
    $level = 1
    while ($level -lt 100 -and $xp -ge (Req $level)) { $xp -= Req $level; $level++ }
    return $level
}
foreach ($line in $xpRows) {
    $c = Cells $line; $chapter = [int]$c[1]; $xp = 0
    for ($level = $levels[$chapter - 1]; $level -lt $levels[$chapter]; $level++) { $xp += Req $level }
    if ($chapter -eq 1) { $xp = 3820 }; if ($chapter -eq 2) { $xp -= 1093 }
    Check ($xp -eq (Number $c[2])) "EXP mismatch chapter $chapter"
    Check ((Number $c[3]) + (Number $c[4]) -eq $xp) 'EXP sources mismatch'
    if ($chapter -gt 1) {
        Check ((Number $c[3]) -eq (RoundPositive ($xp * 0.7))) 'Report rounding mismatch'
        $sideXp = RoundPositive ((Number $c[3]) * 0.4)
        $lossA += RoundPositive ($sideXp * 0.2)
        $lossB += RoundPositive (($sideXp + (Number $c[4])) * 0.2)
    }
    if ($chapter -eq 1) { $gold = 1130 }
    else {
        $g = [Math]::Round(2 * [Math]::Pow((Number $c[5]), 1.5), 0, [MidpointRounding]::AwayFromZero)
        $timeCells = Cells $times[$chapter - 1]
        $gold = (300 + 30 * [int]$timeCells[5]) * $g
    }
    Check ($gold -eq (Number $c[6])) "Gold mismatch chapter $chapter"
    $totalXp += $xp
    $stress = Cells $stressRows[$chapter - 1]
    Check ((ReachedLevel $totalXp) -eq (Number $stress[2])) 'Baseline level mismatch'
    Check ((ReachedLevel ($totalXp - $lossA)) -eq (Number $stress[3])) 'Omission A mismatch'
    Check ((ReachedLevel ($totalXp - $lossB)) -eq (Number $stress[4])) 'Omission B mismatch'
}
Write-Output 'EXP_OMISSION_LIMITATION_CONFIRMED: chapter10 A78/B77; chapter12 A94/B92; does not pass pacing acceptance'
$postXp = Cells ($lines | Where-Object { $_ -match '^\| [^\d|][^|]+ \| 8,' })
Check ((Number $postXp[2]) -eq 8262306) 'Postgame EXP mismatch'
Check ((Number $postXp[3]) + (Number $postXp[4]) -eq (Number $postXp[2])) 'Postgame split mismatch'
$totalXp += Number $postXp[2]
$sum = 0; $early = 0; $previous = 0
for ($level = 1; $level -lt 100; $level++) {
    $value = Req $level; Check ($value -gt $previous) "Non-increasing REQ at $level"
    $previous = $value; $sum += $value; if ($level -lt 10) { $early += $value }
}
Check ($early -eq 18612 -and (Req 9) -eq 6014 -and (Req 10) -eq 17393) 'Early pacing changed'
Check ($sum -eq 61860102 -and $totalXp -eq $sum) 'Cumulative EXP mismatch'
Write-Output 'BUDGET_ARITHMETIC_PASS: 100h; main61; side120+30; reputation gates/stress; EXP61860102; early18612; chapter gold; monotonic REQ'
