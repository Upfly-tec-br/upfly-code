<#
.SYNOPSIS
  Cria os atalhos "Upfly Code" (Menu Iniciar e, opcionalmente, Área de Trabalho).

.NOTES
  O atalho aponta para UpflyCode.exe (cópia do motor com o ícone da Upfly),
  então a barra de tarefas também mostra o ícone da Upfly com a janela aberta.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$EnginePath,
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'UpflyCode'),
    [switch]$Desktop
)

$ErrorActionPreference = 'Stop'
$config = Join-Path $InstallDir 'config\wezterm.lua'
$icon   = Join-Path $InstallDir 'branding\icon.ico'
$arguments = "--config-file `"$config`" start --always-new-process --class UpflyCode --cwd `"$env:USERPROFILE`""

$targets = [ordered]@{ 'Menu Iniciar' = (Join-Path ([Environment]::GetFolderPath('Programs')) 'Upfly Code.lnk') }
if ($Desktop) { $targets['Área de Trabalho'] = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Upfly Code.lnk') }

$shell = New-Object -ComObject WScript.Shell
foreach ($place in $targets.Keys) {
    $lnkPath = $targets[$place]
    $lnk = $shell.CreateShortcut($lnkPath)
    $lnk.TargetPath = $EnginePath
    $lnk.Arguments = $arguments
    $lnk.WorkingDirectory = $env:USERPROFILE
    $lnk.IconLocation = "$icon,0"
    $lnk.Description = 'Upfly Code - terminal da Upfly'
    $lnk.Save()
    # Mesmo ID de aplicativo da janela: barra de tarefas mostra o ícone da Upfly
    $helper = Join-Path $InstallDir 'bin\upfly-taskbar.exe'
    if (Test-Path $helper) {
        Start-Process -FilePath $helper -ArgumentList @('--set-lnk-appid', "`"$lnkPath`"", 'Upfly.UpflyCode') -Wait -WindowStyle Hidden
    }
    Write-Host "    Atalho criado: $place" -ForegroundColor Green
}
