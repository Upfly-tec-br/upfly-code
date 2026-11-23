<#
  Upfly Code - atualização automática (Windows).
  Chamado pelo botão "Atualizar agora": baixa a versão nova e deixa a troca
  preparada numa janela separada. A troca acontece assim que o Upfly Code
  fecha, e ele abre de novo sozinho.
#>
param([string]$Url, [string]$Version = 'nova', [string]$AppRoot)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Log = Join-Path $env:TEMP 'upfly-code-update.log'
"Upfly Code - atualização para $Version em $(Get-Date)" | Out-File $Log -Encoding UTF8

function Fail($msg) {
    Write-Host ''
    Write-Host "  Não foi possível atualizar: $msg" -ForegroundColor Red
    Write-Host "  Detalhes para o suporte: $Log" -ForegroundColor Yellow
    Read-Host '  Pressione Enter para fechar' | Out-Null
    exit 1
}

Write-Host ''
Write-Host '  UPFLY CODE' -ForegroundColor Blue
Write-Host "  Atualizando para a versão $Version" -ForegroundColor DarkGray
Write-Host ''
try {
    $work = Join-Path $env:TEMP "upfly-code-update-$Version"
    if (Test-Path $work) { Remove-Item $work -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    $zip = Join-Path $work 'pacote.zip'
    Write-Host '  > Baixando...' -ForegroundColor Cyan
    Invoke-WebRequest -Uri $Url -OutFile $zip -UseBasicParsing
    Write-Host '  > Preparando...' -ForegroundColor Cyan
    Expand-Archive -Path $zip -DestinationPath $work -Force
    $installer = Get-ChildItem $work -Recurse -Filter 'install.ps1' |
        Where-Object { $_.FullName -like '*scripts\windows\install.ps1' } | Select-Object -First 1
    if (-not $installer) { Fail 'o pacote baixado está incompleto.' }
    $hasDesktop = Test-Path (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Upfly Code.lnk')
    $psArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$($installer.FullName)`"", '-WaitForClose', '-NoExtensions')
    if (-not $hasDesktop) { $psArgs += '-NoDesktopShortcut' }
    Start-Process -FilePath 'powershell.exe' -ArgumentList $psArgs -WindowStyle Minimized
} catch {
    $_ | Out-String | Out-File $Log -Append -Encoding UTF8
    Fail $_.Exception.Message
}
Write-Host ''
Write-Host "  Tudo pronto. O Upfly Code vai fechar e abrir de novo na versão $Version." -ForegroundColor Green
Start-Sleep -Seconds 2
exit 0
