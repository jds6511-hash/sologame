param([string]$Godot = 'godot')
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$out = Join-Path $repo ('docs/qa/screenshots/job-save-menu/' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $out | Out-Null
$engine = (Get-Command $Godot).Source
foreach ($job in @('warrior', 'archer', 'gladiator')) {
    foreach ($phase in @('cleanup', 'play', 'reload', 'cleanup')) {
        $log = Join-Path $out ($job + '-' + $phase + '-' + (Get-Date -Format 'HHmmssfff') + '.log')
        $arguments = '--headless --path godot --log-file "' + $log + '" --script ../docs/qa/tools/job_save_menu_probe.gd -- ' + $job + ' ' + $phase
        $process = Start-Process -FilePath $engine -WorkingDirectory $repo -ArgumentList $arguments -WindowStyle Hidden -PassThru
        if (-not $process.WaitForExit(120000)) { $process.Kill(); throw "Timeout: $job $phase" }
        $process.Refresh()
        $body = Get-Content -LiteralPath $log -Raw -Encoding UTF8
        if ($process.ExitCode -ne 0 -or $body -match 'SCRIPT ERROR:|(?m)^ERROR:|: false' -or -not $body.Contains('JOB_SAVE_MENU_PASS')) { throw "Failed: $job $phase; $log" }
        Write-Output "JOB_SAVE_MENU_PHASE_PASS $job $phase"
    }
}
Write-Output "JOB_SAVE_MENU_SUITE_PASS $out"
