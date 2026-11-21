# Upfly Code - autoatualização pelo GitHub (Windows).
# Chamado pelo botão "Atualizar agora". Baixa o pacote da última release e
# roda o instalador numa janela separada (assim ele pode esperar o Upfly Code
# fechar, se precisar trocar o UpflyCode.exe).
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
try { $Host.UI.RawUI.WindowTitle = 'Atualização do Upfly Code' } catch { }

$InstallDir = Split-Path $PSScriptRoot -Parent
$repo = (Get-Content (Join-Path $InstallDir 'config\update-repo.txt') -TotalCount 1).Trim()
$current = (Get-Content (Join-Path $InstallDir 'VERSION') -TotalCount 1).Trim()
$Log = Join-Path $env:TEMP 'upfly-code-update.log'
"Upfly Code - autoatualização em $(Get-Date)" | Out-File $Log -Encoding UTF8

function Fail($msg) {
    Write-Host ''
    Write-Host "  Não foi possível atualizar: $msg" -ForegroundColor Red
    Write-Host "  Detalhes para o suporte: $Log" -ForegroundColor Yellow
    Write-Host ''
    Read-Host '  Pressione Enter para fechar'
    exit 1
}

Write-Host ''
Write-Host '  UPFLY CODE' -ForegroundColor Blue
Write-Host '  Atualização' -ForegroundColor DarkGray
Write-Host ''

if (-not $repo -or $repo.Contains('[')) { Fail 'repositório de atualizações não configurado.' }

try {
    Write-Host '  > Procurando a versão mais recente...' -ForegroundColor Cyan
    $headers = @{ 'User-Agent' = 'UpflyCode'; 'Accept' = 'application/vnd.github+json' }
    $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers $headers
    $latest = $rel.tag_name -replace '^v', ''
    $asset = $rel.assets | Where-Object { $_.name -like '*-windows.zip' } | Select-Object -First 1
    if (-not $asset) { Fail "a versão $latest não tem pacote para Windows." }
    Write-Host "    Versão instalada: $current  ·  nova: $latest"

    Write-Host '  > Baixando...' -ForegroundColor Cyan
    $work = Join-Path $env:TEMP "upfly-code-update-$latest"
    if (Test-Path $work) { Remove-Item $work -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    $zip = Join-Path $work $asset.name
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $work -Force
    $installer = Get-ChildItem $work -Recurse -Filter 'install.ps1' |
        Where-Object { $_.FullName -like '*scripts\windows\install.ps1' } | Select-Object -First 1
    if (-not $installer) { Fail 'pacote baixado está incompleto.' }

    Write-Host '  > Instalando...' -ForegroundColor Cyan
    $hasDesktop = Test-Path (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Upfly Code.lnk')
    $psArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$($installer.FullName)`"", '-WaitForClose')
    if (-not $hasDesktop) { $psArgs += '-NoDesktopShortcut' }
    Start-Process -FilePath 'powershell.exe' -ArgumentList $psArgs
    Write-Host ''
    Write-Host '  A instalação continua numa janela separada.' -ForegroundColor Green
    Write-Host '  A maioria das mudanças aparece na hora. Se a janela pedir, feche o Upfly Code' -ForegroundColor DarkGray
    Write-Host '  para concluir e abra de novo.' -ForegroundColor DarkGray
    Write-Host ''
} catch {
    $_.Exception.ToString() | Out-File $Log -Append -Encoding UTF8
    Fail $_.Exception.Message
}
