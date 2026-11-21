<#
.SYNOPSIS
  Instala o Upfly Code para o usuário atual (sem precisar de administrador).

.DESCRIPTION
  Nota técnica para a TI:
  - Motor de terminal: WezTerm oficial (MIT), versão portátil em
    %LOCALAPPDATA%\UpflyCode\terminal. É criada uma cópia do executável
    chamada UpflyCode.exe com o ícone e o nome da Upfly (via rcedit, MIT).
    O wezterm-gui.exe original fica intacto ao lado.
  - Shell padrão: Git Bash. Se o Git for Windows não estiver instalado, é
    usada a versão portátil oficial em %LOCALAPPDATA%\UpflyCode\git.
  - Barra lateral de arquivos: upfly-files (Upfly) em %LOCALAPPDATA%\UpflyCode\tools.
  - Ícone na barra de tarefas: bin\upfly-taskbar.exe, compilado aqui a partir de
    tools\upfly-taskbar.cs (AppUserModelID + ícone da janela).
  - Claude Code: instalado pelo instalador oficial (use -NoClaude para pular).
  - Menu de contexto "Abrir no Upfly Code" nas pastas (HKCU, sem admin).
  - Saída técnica em %TEMP%\upfly-code-install.log.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File install.ps1
#>
[CmdletBinding()]
param(
    [switch]$WithClaude,       # mantido por compatibilidade (o Claude Code já é instalado por padrão)
    [switch]$NoClaude,         # não instala o Claude Code
    [switch]$NoLaunch,         # não abre o Upfly Code no final
    [switch]$SkipWezTerm,      # não baixa/atualiza o motor (usado pela atualização)
    [switch]$SkipGit,          # não instala o Git Bash portátil
    [switch]$NoDesktopShortcut,
    [switch]$NoContextMenu,
    [switch]$WaitForClose      # atualização: espera o Upfly Code fechar se precisar trocar o .exe
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { $Host.UI.RawUI.WindowTitle = 'Instalador Upfly Code' } catch { }

# Versões das dependências baixadas na instalação
$EngineVersion = '20240203-110809-5046fc22'
$GitVersion    = '2.56.0.windows.4'
$GitFile       = 'PortableGit-2.56.0.4-64-bit.7z.exe'

$PackageRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$InstallDir  = Join-Path $env:LOCALAPPDATA 'UpflyCode'
$TermDir     = Join-Path $InstallDir 'terminal'
$GitDir      = Join-Path $InstallDir 'git'
$ToolsDir    = Join-Path $InstallDir 'tools'
$Version     = (Get-Content (Join-Path $PackageRoot 'VERSION') -Raw).Trim()
$Tools       = Join-Path $PackageRoot 'tools'
$Log         = Join-Path $env:TEMP 'upfly-code-install.log'
"Upfly Code $Version - instalação em $(Get-Date)" | Out-File $Log -Encoding UTF8

function Write-Step($msg) { Write-Host "  > $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    $msg" -ForegroundColor Green }
function Write-Note($msg) { Write-Host "    $msg" -ForegroundColor DarkGray }
function Write-Log($msg)  { $msg | Out-File $Log -Append -Encoding UTF8 }

$script:EngineReplaced = $false

# Garante que o Upfly Code está fechado antes de trocar o executável
function Wait-Closed {
    if (-not (Get-Process -Name 'UpflyCode' -ErrorAction SilentlyContinue)) { return }
    if (-not $WaitForClose) {
        throw 'Feche todas as janelas do Upfly Code e rode o instalador de novo.'
    }
    Write-Host ''
    Write-Host '    Feche todas as janelas do Upfly Code para concluir a atualização.' -ForegroundColor Yellow
    Write-Host '    (esta janela continua sozinha assim que você fechar)' -ForegroundColor DarkGray
    while (Get-Process -Name 'UpflyCode' -ErrorAction SilentlyContinue) { Start-Sleep -Seconds 2 }
}

function Get-File($url, $dest) {
    Write-Log "download: $url"
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
}

# ---------------------------------------------------------------- motor
function Install-Engine {
    $marker = Join-Path $TermDir '.upfly-engine-version'
    if ((Test-Path (Join-Path $TermDir 'wezterm-gui.exe')) -and (Test-Path $marker) -and
        ((Get-Content $marker -Raw).Trim() -eq $EngineVersion)) {
        Write-Log 'motor já instalado nesta versão'
        return
    }
    if ($SkipWezTerm -and (Test-Path (Join-Path $TermDir 'wezterm-gui.exe'))) { return }

    Write-Note 'Baixando os componentes (pode levar alguns minutos)...'
    $zip = Join-Path $env:TEMP 'upfly-code-terminal.zip'
    $tmp = Join-Path $env:TEMP 'upfly-code-terminal'
    Get-File "https://github.com/wezterm/wezterm/releases/download/$EngineVersion/WezTerm-windows-$EngineVersion.zip" $zip
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    $inner = Get-ChildItem $tmp -Directory | Select-Object -First 1
    Wait-Closed
    if (Test-Path $TermDir) { Remove-Item $TermDir -Recurse -Force }
    Move-Item $inner.FullName $TermDir
    Set-Content -Path $marker -Value $EngineVersion -Encoding ASCII
    $script:EngineReplaced = $true
    Remove-Item $zip -Force
}

# Cria UpflyCode.exe (cópia do motor com ícone e nome da Upfly)
function Set-Branding {
    $src = Join-Path $TermDir 'wezterm-gui.exe'
    $exe = Join-Path $TermDir 'UpflyCode.exe'
    $rcedit = Join-Path $Tools 'rcedit-x64.exe'
    $icon = Join-Path $InstallDir 'branding\icon.ico'
    $hashFile = Join-Path $TermDir '.upfly-icon-hash'
    $hash = (Get-FileHash $icon -Algorithm SHA256).Hash
    if ((Test-Path $exe) -and -not $script:EngineReplaced -and (Test-Path $hashFile) -and
        ((Get-Content $hashFile -Raw).Trim() -eq $hash)) {
        return $exe   # já está com o ícone atual: não precisa mexer (nem fechar a janela)
    }
    try {
        Wait-Closed
        Copy-Item $src $exe -Force
        & $rcedit $exe `
            --set-icon $icon `
            --set-version-string 'FileDescription' 'Upfly Code' `
            --set-version-string 'ProductName' 'Upfly Code' `
            --set-version-string 'CompanyName' 'Upfly' `
            --set-version-string 'InternalName' 'UpflyCode' `
            --set-version-string 'OriginalFilename' 'UpflyCode.exe' `
            --set-version-string 'LegalCopyright' 'Upfly Code - motor WezTerm (c) Wez Furlong, licenca MIT' `
            2>&1 | Out-File $Log -Append -Encoding UTF8
        if ($LASTEXITCODE -ne 0) { throw "rcedit retornou $LASTEXITCODE" }
        Set-Content -Path $hashFile -Value $hash -Encoding ASCII
        return $exe
    } catch {
        if ($_.Exception.Message -like 'Feche todas*') { throw }
        Write-Log "ícone não aplicado: $_"
        if (Test-Path $exe) { Remove-Item $exe -Force -ErrorAction SilentlyContinue }
        return $src
    }
}

# ---------------------------------------------------------------- Git Bash
function Find-Bash {
    foreach ($c in @(
        (Join-Path $env:ProgramFiles 'Git\bin\bash.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Git\bin\bash.exe'),
        (Join-Path $GitDir 'bin\bash.exe'))) {
        if (Test-Path $c) { return $c }
    }
    return $null
}

function Install-GitBash {
    $sfx = Join-Path $env:TEMP $GitFile
    Get-File "https://github.com/git-for-windows/git/releases/download/v$GitVersion/$GitFile" $sfx
    if (Test-Path $GitDir) { Remove-Item $GitDir -Recurse -Force }
    $p = Start-Process -FilePath $sfx -ArgumentList "-o`"$GitDir`"", '-y' -Wait -PassThru -WindowStyle Hidden
    Write-Log "PortableGit sfx exit: $($p.ExitCode)"
    $post = Join-Path $GitDir 'post-install.bat'
    if (Test-Path $post) {
        Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', "cd /d `"$GitDir`" && post-install.bat" `
            -Wait -WindowStyle Hidden | Out-Null
    }
    Remove-Item $sfx -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------- menu de contexto
function Set-ContextMenu($exe) {
    $cfg = Join-Path $InstallDir 'config\wezterm.lua'
    $icon = Join-Path $InstallDir 'branding\icon.ico'
    $cmd = "`"$exe`" --config-file `"$cfg`" start --always-new-process --class UpflyCode --cwd `"%V`""
    foreach ($key in 'HKCU:\Software\Classes\Directory\shell\UpflyCode',
                     'HKCU:\Software\Classes\Directory\Background\shell\UpflyCode') {
        New-Item -Path "$key\command" -Force | Out-Null
        Set-ItemProperty -Path $key -Name '(default)' -Value 'Abrir no Upfly Code'
        Set-ItemProperty -Path $key -Name 'Icon' -Value $icon
        Set-ItemProperty -Path "$key\command" -Name '(default)' -Value $cmd
    }
}

# ================================================================= principal
try {
    Write-Host ''
    Write-Host "  UPFLY CODE $Version" -ForegroundColor Blue
    Write-Host '  Instalador para Windows' -ForegroundColor DarkGray
    Write-Host ''

    # 1. Motor
    Write-Step 'Instalando o Upfly Code...'
    Install-Engine

    # 2. Arquivos
    Write-Step 'Aplicando a identidade visual Upfly...'
    foreach ($d in 'config', 'branding', 'bin', 'LICENSES', 'tools', 'state') {
        New-Item -ItemType Directory -Force -Path (Join-Path $InstallDir $d) | Out-Null
    }
    Copy-Item (Join-Path $PackageRoot 'config\wezterm.lua')   (Join-Path $InstallDir 'config') -Force
    Copy-Item (Join-Path $PackageRoot 'config\starship.toml') (Join-Path $InstallDir 'config') -Force
    Copy-Item (Join-Path $PackageRoot 'config\update-repo.txt') (Join-Path $InstallDir 'config') -Force
    if (Test-Path (Join-Path $InstallDir 'config\broot')) { Remove-Item (Join-Path $InstallDir 'config\broot') -Recurse -Force }
    Copy-Item (Join-Path $PackageRoot 'config\shell\*') (Join-Path $InstallDir 'bin') -Force
    Copy-Item (Join-Path $PackageRoot 'branding\*') (Join-Path $InstallDir 'branding') -Force -Recurse
    Copy-Item (Join-Path $PackageRoot 'LICENSES\*') (Join-Path $InstallDir 'LICENSES') -Force -Recurse
    Copy-Item (Join-Path $PackageRoot 'VERSION') $InstallDir -Force
    foreach ($s in 'update.ps1', 'uninstall.ps1', 'create-shortcut.ps1') {
        Copy-Item (Join-Path $PSScriptRoot $s) (Join-Path $InstallDir 'bin') -Force
    }
    $exe = Set-Branding
    Set-Content -Path (Join-Path $InstallDir 'engine-path.txt') -Value $exe -Encoding UTF8

    # 3. Git Bash (shell padrão)
    $bash = Find-Bash
    if (-not $bash -and -not $SkipGit) {
        Write-Step 'Instalando o Git Bash...'
        Install-GitBash
        $bash = Find-Bash
    }
    if ($bash) { Write-Log "bash: $bash" } else { Write-Note 'Git Bash não instalado; o Upfly Code vai usar o PowerShell.' }

    # 4. Barra lateral de arquivos
    Write-Step 'Instalando a barra lateral de arquivos...'
    Get-Process -Name 'upfly-files' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Copy-Item (Join-Path $Tools 'upfly-files.exe') $ToolsDir -Force
    foreach ($old in 'broot.exe') {
        $op = Join-Path $ToolsDir $old
        if (Test-Path $op) { Remove-Item $op -Force -ErrorAction SilentlyContinue }
    }

    # 5. Ícone da Upfly na barra de tarefas (helper compilado neste computador)
    $helper = Join-Path $InstallDir 'bin\upfly-taskbar.exe'
    try {
        Get-Process -Name 'upfly-taskbar' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 300
        if (Test-Path $helper) { Remove-Item $helper -Force }
        $src = Get-Content (Join-Path $Tools 'upfly-taskbar.cs') -Raw
        Add-Type -TypeDefinition $src -Language CSharp -OutputAssembly $helper -OutputType WindowsApplication
        Write-Log "helper compilado: $helper"
    } catch {
        Write-Log "helper da barra de tarefas não compilado: $_"
    }

    # 6. Atalhos e menu de contexto
    Write-Step 'Criando atalhos...'
    & (Join-Path $InstallDir 'bin\create-shortcut.ps1') -EnginePath $exe -InstallDir $InstallDir -Desktop:(-not $NoDesktopShortcut)
    if (-not $NoContextMenu) {
        Set-ContextMenu $exe
        Write-Ok 'Clique direito numa pasta: "Abrir no Upfly Code"'
    }
    try { Start-Process -FilePath 'ie4uinit.exe' -ArgumentList '-show' -WindowStyle Hidden -ErrorAction SilentlyContinue } catch { }

    # 7. Claude Code
    $claudeExe = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
    if (-not $NoClaude) {
        if ((Get-Command claude -ErrorAction SilentlyContinue) -or (Test-Path $claudeExe)) {
            Write-Ok 'Claude Code já estava instalado.'
        } else {
            Write-Step 'Instalando o Claude Code...'
            try {
                Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression *>> $Log
                Write-Ok 'Claude Code instalado.'
            } catch {
                Write-Log "Claude Code: $_"
                Write-Note 'Não foi possível instalar o Claude Code agora. O Upfly Code vai oferecer de novo ao abrir.'
            }
        }
    }

    Write-Host ''
    Write-Host "  Upfly Code $Version instalado com sucesso!" -ForegroundColor Green
    Write-Host '  Ctrl+Shift+O abre uma pasta  ·  Ctrl+Shift+E mostra os arquivos' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  Inclui componentes de código aberto. Licenças em LICENSES.' -ForegroundColor DarkGray
    Write-Host ''
    if (-not $NoLaunch) {
        Write-Host '  Abrindo o Upfly Code... na primeira vez ele ajuda você a conectar sua conta do Claude.' -ForegroundColor Cyan
        $cfg = Join-Path $InstallDir 'config\wezterm.lua'
        Start-Process -FilePath $exe -ArgumentList @('--config-file', "`"$cfg`"", 'start', '--always-new-process', '--class', 'UpflyCode', '--cwd', "`"$env:USERPROFILE`"")
        Write-Host ''
    } else {
        Write-Host '  Abra "Upfly Code" pelo Menu Iniciar ou pela Área de Trabalho.'
    }
    if ($WaitForClose) { Read-Host '  Pressione Enter para fechar' | Out-Null }
} catch {
    Write-Log $_.Exception.ToString()
    Write-Host ''
    Write-Host '  Não foi possível concluir a instalação do Upfly Code.' -ForegroundColor Red
    Write-Host "  Motivo: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Detalhes para o suporte: $Log" -ForegroundColor Yellow
    Write-Host ''
    if ($WaitForClose) { Read-Host '  Pressione Enter para fechar' | Out-Null }
    exit 1
}
