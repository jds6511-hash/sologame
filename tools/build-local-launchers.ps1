# 로컬 테스트 실행기만 생성한다. Godot 내보내기 템플릿/게임 데이터 패키징은 하지 않는다.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$source = Join-Path $PSScriptRoot 'LocalGameLauncher.cs'
foreach ($mode in @('game', 'm6', 'shop')) {
    $name = @{ game='게임 실행.exe'; m6='M6 후보 실행.exe'; shop='M6 상점 테스트.exe' }[$mode]
    $options = @('/nologo', '/target:winexe', '/reference:System.Windows.Forms.dll', ('/out:' + (Join-Path $repo $name)))
    if ($mode -eq 'm6') { $options += '/define:M6' }
    if ($mode -eq 'shop') { $options += '/define:SHOP' }
    & $compiler @options $source
    if ($LASTEXITCODE -ne 0) { throw "실행기 컴파일 실패: $mode" }
    Write-Output $name
}
