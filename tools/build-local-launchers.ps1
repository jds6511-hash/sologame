# 설치된 Godot과 현재 소스를 사용하는 단일 로컬 실행기를 만든다.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$source = Join-Path $PSScriptRoot 'LocalGameLauncher.cs'
& $compiler /nologo /target:winexe /reference:System.Windows.Forms.dll ('/out:' + (Join-Path $repo '게임 실행.exe')) $source
if ($LASTEXITCODE -ne 0) { throw '실행기 컴파일 실패' }
Write-Output '게임 실행.exe'
