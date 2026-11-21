<#
.SYNOPSIS
  Remove o Upfly Code: atalhos, menu de contexto e a pasta
  %LOCALAPPDATA%\UpflyCode (motor portátil, Git Bash portátil, explorador e
  configuração). Mantém o Claude Code e um Git for Windows instalado à parte.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
try { $Host.UI.RawUI.WindowTitle = 'Desinstalador Upfly Code' } catch { }
$InstallDir = Join-Path $env:LOCALAPPDATA 'UpflyCode'

Write-Host ''
Write-Host '  UPFLY CODE' -ForegroundColor Blue
Write-Host '  Desinstalador para Windows' -ForegroundColor DarkGray
Write-Host ''

if (Get-Process -Name 'UpflyCode' -ErrorAction SilentlyContinue) {
    Write-Host '  Feche todas as janelas do Upfly Code e rode o desinstalador de novo.' -ForegroundColor Yellow
    Write-Host ''
    exit 1
}

Write-Host '  > Removendo o Upfly Code...' -ForegroundColor Cyan
Get-Process -Name 'upfly-taskbar', 'upfly-files' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
foreach ($p in @(
    (Join-Path ([Environment]::GetFolderPath('Programs')) 'Upfly Code.lnk'),
    (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Upfly Code.lnk'))) {
    if (Test-Path $p) { Remove-Item $p -Force }
}
foreach ($key in 'HKCU:\Software\Classes\Directory\shell\UpflyCode',
                 'HKCU:\Software\Classes\Directory\Background\shell\UpflyCode') {
    if (Test-Path $key) { Remove-Item $key -Recurse -Force }
}

if (Test-Path $InstallDir) {
    # Se este script estiver dentro da pasta instalada, apaga depois de sair.
    if ($PSScriptRoot -like "$InstallDir*") {
        Start-Process -WindowStyle Hidden -FilePath 'cmd.exe' -ArgumentList '/c', "timeout /t 2 >nul & rmdir /s /q `"$InstallDir`""
    } else {
        Remove-Item $InstallDir -Recurse -Force
    }
}
Write-Host ''
Write-Host '  Upfly Code removido.' -ForegroundColor Green
Write-Host '  O Claude Code foi mantido.' -ForegroundColor DarkGray
Write-Host ''
