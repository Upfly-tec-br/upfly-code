<#
.SYNOPSIS
  Atualiza o Upfly Code.

.DESCRIPTION
  - Executado de dentro de um pacote novo (pasta extraída): reaplica tudo
    (motor, ícone, configuração, explorador) mantendo os atalhos.
  - Em qualquer caso, atualiza o Claude Code, se instalado.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
try { $Host.UI.RawUI.WindowTitle = 'Atualizador Upfly Code' } catch { }
$InstallDir = Join-Path $env:LOCALAPPDATA 'UpflyCode'
$Log = Join-Path $env:TEMP 'upfly-code-update.log'
"Upfly Code - atualização em $(Get-Date)" | Out-File $Log -Encoding UTF8

Write-Host ''
Write-Host '  UPFLY CODE' -ForegroundColor Blue
Write-Host '  Atualizador para Windows' -ForegroundColor DarkGray
Write-Host ''

if (Get-Command claude -ErrorAction SilentlyContinue) {
    Write-Host '  > Atualizando o Claude Code...' -ForegroundColor Cyan
    try { & claude update 2>&1 | Out-File $Log -Append -Encoding UTF8 } catch { }
}

$packageInstaller = Join-Path $PSScriptRoot 'install.ps1'
if (Test-Path $packageInstaller) {
    $new = (Get-Content (Join-Path $PSScriptRoot '..\..\VERSION') -Raw).Trim()
    $old = if (Test-Path (Join-Path $InstallDir 'VERSION')) { (Get-Content (Join-Path $InstallDir 'VERSION') -Raw).Trim() } else { 'nenhuma' }
    Write-Host "  > Versão $old -> $new" -ForegroundColor Cyan
    $hasDesktop = Test-Path (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Upfly Code.lnk')
    & $packageInstaller -NoDesktopShortcut:(-not $hasDesktop)
} else {
    Write-Host '    Para receber a versão nova do Upfly Code, baixe o pacote novo e rode "Atualizar Upfly Code.cmd".' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  Upfly Code atualizado.' -ForegroundColor Green
}
