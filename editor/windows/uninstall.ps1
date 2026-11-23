<#
  Upfly Code - desinstalador para Windows.
  Remove o aplicativo, os atalhos e o menu de contexto. Suas configurações e
  conversas ficam guardadas, a menos que use -Tudo.
#>
param([switch]$Tudo)
$ErrorActionPreference = 'SilentlyContinue'

Get-Process -Name 'UpflyCode' | Stop-Process -Force
Start-Sleep -Seconds 1
$InstallDir = Join-Path $env:LOCALAPPDATA 'UpflyCode'
Remove-Item (Join-Path $InstallDir 'app') -Recurse -Force
Remove-Item (Join-Path $InstallDir 'VERSION') -Force
Remove-Item (Join-Path ([Environment]::GetFolderPath('Programs')) 'Upfly Code.lnk') -Force
Remove-Item (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Upfly Code.lnk') -Force
Remove-Item 'HKCU:\Software\Classes\Directory\shell\UpflyCode' -Recurse -Force
Remove-Item 'HKCU:\Software\Classes\Directory\Background\shell\UpflyCode' -Recurse -Force
$cur = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($cur) {
    $parts = $cur.Split(';') | Where-Object { $_ -and ($_ -notlike '*\UpflyCode\app\bin*') }
    [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')
}
if ($Tudo) {
    Remove-Item $InstallDir -Recurse -Force
    Remove-Item (Join-Path $env:USERPROFILE '.upfly-code') -Recurse -Force
    Remove-Item (Join-Path $env:APPDATA 'Upfly Code') -Recurse -Force
    [Environment]::SetEnvironmentVariable('CLAUDE_CODE_GIT_BASH_PATH', $null, 'User')
}
Write-Host '  Upfly Code removido.' -ForegroundColor Green
if (-not $Tudo) { Write-Host '  Suas configurações ficaram guardadas. Para apagar tudo: uninstall.ps1 -Tudo' -ForegroundColor DarkGray }
