# Upfly Code - linha de boas-vindas discreta (modo PowerShell no Windows).
# Executado com -NoExit, então o shell continua aberto depois.
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$esc = [char]27
Write-Host "$esc[38;2;0;128;255m▲$esc[0m $esc[2mUpfly Code  ·  F1 menu  ·  Ctrl+Shift+O abrir pasta  ·  Ctrl+Shift+E arquivos  ·  Ctrl+Shift+A Claude$esc[0m"
Write-Host ""
