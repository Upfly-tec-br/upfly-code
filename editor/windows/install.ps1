<#
  Upfly Code - instalador para Windows (editor com chat do Claude)

  Instala só para o seu usuário, sem pedir senha de administrador:
    %LOCALAPPDATA%\UpflyCode\app      o aplicativo (UpflyCode.exe)
    Menu Iniciar e Área de Trabalho   atalho "Upfly Code"
    Botão direito numa pasta          "Abrir no Upfly Code"
  Também instala o Git Bash portátil (o Claude precisa dele no Windows) se o
  Git ainda não estiver instalado, e deixa o português e o chat do Claude prontos.

  Opções antigas (-SkipWezTerm, -NoClaude, -WithClaude, -SkipGit) são aceitas,
  para que as versões antigas consigam atualizar para esta.
#>
param(
    [switch]$NoLaunch,
    [switch]$NoDesktopShortcut,
    [switch]$NoContextMenu,
    [switch]$WaitForClose,      # atualização: espera o Upfly Code fechar e abre de novo no fim
    [switch]$NoExtensions,
    [switch]$SkipGit,
    [switch]$SkipWezTerm, [switch]$NoClaude, [switch]$WithClaude
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { $Host.UI.RawUI.WindowTitle = 'Instalador Upfly Code' } catch { }

$GitVersion = '2.56.0.windows.4'
$GitFile    = 'PortableGit-2.56.0.4-64-bit.7z.exe'

$PackageRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$InstallDir  = Join-Path $env:LOCALAPPDATA 'UpflyCode'
$AppDir      = Join-Path $InstallDir 'app'
$GitDir      = Join-Path $InstallDir 'git'
$Exe         = Join-Path $AppDir 'UpflyCode.exe'
$Cli         = Join-Path $AppDir 'bin\upfly-code.cmd'
$UserData    = Join-Path $env:USERPROFILE '.upfly-code'
$SettingsDir = Join-Path $env:APPDATA 'Upfly Code\User'
$Version     = (Get-Content (Join-Path $PackageRoot 'VERSION') -Raw).Trim()
$Log         = Join-Path $env:TEMP 'upfly-code-install.log'
"Upfly Code $Version - instalação em $(Get-Date)" | Out-File $Log -Encoding UTF8

function Write-Step($msg) { Write-Host "  > $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    $msg" -ForegroundColor Green }
function Write-Note($msg) { Write-Host "    $msg" -ForegroundColor DarkGray }
function Write-Log($msg)  { $msg | Out-File $Log -Append -Encoding UTF8 }

function Wait-Closed {
    if (-not (Get-Process -Name 'UpflyCode' -ErrorAction SilentlyContinue)) { return }
    if (-not $WaitForClose) {
        throw 'Feche todas as janelas do Upfly Code e rode o instalador de novo.'
    }
    $asked = $false
    $start = Get-Date
    while (Get-Process -Name 'UpflyCode' -ErrorAction SilentlyContinue) {
        if (-not $asked -and ((Get-Date) - $start).TotalSeconds -gt 8) {
            Write-Host ''
            Write-Host '    Feche todas as janelas do Upfly Code para concluir a atualização.' -ForegroundColor Yellow
            Write-Host '    (esta janela continua sozinha assim que você fechar)' -ForegroundColor DarkGray
            $asked = $true
        }
        Start-Sleep -Milliseconds 500
    }
    Start-Sleep -Seconds 1
}

function Find-Bash {
    foreach ($c in @(
        (Join-Path $env:ProgramFiles 'Git\bin\bash.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Git\bin\bash.exe'),
        (Join-Path $GitDir 'bin\bash.exe'))) {
        if ($c -and (Test-Path $c)) { return $c }
    }
    return $null
}

function Install-GitBash {
    $sfx = Join-Path $env:TEMP $GitFile
    Write-Log "download: $GitFile"
    Invoke-WebRequest -Uri "https://github.com/git-for-windows/git/releases/download/v$GitVersion/$GitFile" -OutFile $sfx -UseBasicParsing
    if (Test-Path $GitDir) { Remove-Item $GitDir -Recurse -Force }
    $p = Start-Process -FilePath $sfx -ArgumentList "-o`"$GitDir`"", '-y' -Wait -PassThru -WindowStyle Hidden
    Write-Log "PortableGit sfx exit: $($p.ExitCode)"
    $post = Join-Path $GitDir 'post-install.bat'
    if (Test-Path $post) {
        Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', "cd /d `"$GitDir`" && post-install.bat" -Wait -WindowStyle Hidden | Out-Null
    }
    Remove-Item $sfx -Force -ErrorAction SilentlyContinue
}

function New-Shortcut($path, $target, $icon) {
    $ws = New-Object -ComObject WScript.Shell
    $s = $ws.CreateShortcut($path)
    $s.TargetPath = $target
    $s.WorkingDirectory = $env:USERPROFILE
    $s.IconLocation = "$icon,0"
    $s.Description = 'Upfly Code: seus arquivos, o terminal e o chat do Claude'
    $s.Save()
}

function Set-ContextMenu {
    $cmd = "`"$Exe`" `"%V`""
    foreach ($key in 'HKCU:\Software\Classes\Directory\shell\UpflyCode',
                     'HKCU:\Software\Classes\Directory\Background\shell\UpflyCode') {
        New-Item -Path "$key\command" -Force | Out-Null
        Set-ItemProperty -Path $key -Name '(default)' -Value 'Abrir no Upfly Code'
        Set-ItemProperty -Path $key -Name 'Icon' -Value "`"$Exe`""
        Set-ItemProperty -Path "$key\command" -Name '(default)' -Value $cmd
    }
}

function Add-UserPath($dir) {
    $cur = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $cur) { $cur = '' }
    $parts = $cur.Split(';') | Where-Object { $_ -and ($_ -notlike '*\UpflyCode\terminal*') }
    if ($parts -notcontains $dir) { $parts += $dir }
    [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')
}

# Roda um programa pelo cmd, com a saída indo para o log. (No PowerShell 5,
# redirecionar a saída de erro de um programa faz o script parar.)
function Invoke-Quiet([string]$commandLine) {
    $p = Start-Process -FilePath 'cmd.exe' -ArgumentList '/d', '/s', '/c', "`"$commandLine >> `"$Log`" 2>&1`"" `
        -Wait -PassThru -WindowStyle Hidden
    return $p.ExitCode
}

function Write-JsonNoBom($path, $text) {
    New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
    [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding($false)))
}

try {
    Write-Host ''
    Write-Host "  UPFLY CODE $Version" -ForegroundColor Blue
    Write-Host '  Instalador para Windows' -ForegroundColor DarkGray
    Write-Host ''

    if (-not (Test-Path (Join-Path $PackageRoot 'app\UpflyCode.exe'))) { throw 'pacote incompleto (falta a pasta app).' }

    Wait-Closed

    # 1. Aplicativo
    Write-Step 'Copiando o aplicativo...'
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    $new = "$AppDir.new"; $old = "$AppDir.old"
    foreach ($d in $new, $old) { if (Test-Path $d) { Remove-Item $d -Recurse -Force } }
    Copy-Item (Join-Path $PackageRoot 'app') $new -Recurse -Force
    if (Test-Path $AppDir) { Rename-Item $AppDir $old }
    Rename-Item $new $AppDir
    if (Test-Path $old) { Remove-Item $old -Recurse -Force -ErrorAction SilentlyContinue }
    Copy-Item (Join-Path $PackageRoot 'VERSION') $InstallDir -Force
    # Restos da versão antiga (terminal WezTerm)
    foreach ($d in 'terminal', 'config', 'bin', 'tools', 'state', 'branding', 'LICENSES') {
        $p = Join-Path $InstallDir $d
        if (Test-Path $p) { Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue }
    }
    Write-Ok "Aplicativo em $AppDir"

    # 2. Git Bash (o Claude Code usa no Windows)
    $bash = Find-Bash
    if (-not $bash -and -not $SkipGit) {
        Write-Step 'Instalando o Git Bash (o Claude precisa dele)...'
        try { Install-GitBash; $bash = Find-Bash } catch { Write-Log $_; Write-Note 'Não deu para instalar o Git Bash agora.' }
    }
    if ($bash -and $bash.StartsWith($GitDir)) {
        [Environment]::SetEnvironmentVariable('CLAUDE_CODE_GIT_BASH_PATH', $bash, 'User')
        $env:CLAUDE_CODE_GIT_BASH_PATH = $bash
    }

    # 3. Atalhos, menu de contexto e comando "upfly-code"
    Write-Step 'Criando os atalhos...'
    $startMenu = Join-Path ([Environment]::GetFolderPath('Programs')) 'Upfly Code.lnk'
    New-Shortcut $startMenu $Exe $Exe
    $desktop = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Upfly Code.lnk'
    if (-not $NoDesktopShortcut) { New-Shortcut $desktop $Exe $Exe }
    elseif (Test-Path $desktop) { New-Shortcut $desktop $Exe $Exe }
    if (-not $NoContextMenu) { Set-ContextMenu }
    Add-UserPath (Join-Path $AppDir 'bin')
    Write-Ok 'Atalho "Upfly Code" no Menu Iniciar'

    # 4. Primeira abertura simples e em português
    $settings = Join-Path $SettingsDir 'settings.json'
    if (-not (Test-Path $settings)) {
        $json = "{`n  `"security.workspace.trust.enabled`": false,`n  `"workbench.startupEditor`": `"none`""
        if ($bash) {
            $b = $bash.Replace('\', '\\')
            $json += ",`n  `"terminal.integrated.profiles.windows`": { `"Git Bash`": { `"path`": `"$b`", `"args`": [`"--login`", `"-i`"], `"icon`": `"terminal-bash`" } },"
            $json += "`n  `"terminal.integrated.defaultProfile.windows`": `"Git Bash`""
        }
        $json += "`n}`n"
        Write-JsonNoBom $settings $json
    }
    $argv = Join-Path $UserData 'argv.json'
    if (-not (Test-Path $argv)) {
        Write-JsonNoBom $argv "{`n`t`"locale`": `"pt-br`"`n}`n"
    } elseif (-not (Select-String -Path $argv -Pattern '"locale"' -Quiet)) {
        $t = (Get-Content $argv -Raw) -replace '^\s*\{', "{`n`t`"locale`": `"pt-br`","
        Write-JsonNoBom $argv $t
    }

    foreach ($vsix in Get-ChildItem (Join-Path $PackageRoot 'extensions') -Filter *.vsix -ErrorAction SilentlyContinue) {
        Invoke-Quiet "`"$Cli`" --install-extension `"$($vsix.FullName)`"" | Out-Null
    }
    $env:ELECTRON_RUN_AS_NODE = '1'
    $lp = Join-Path $PackageRoot 'scripts\common\languagepacks.js'
    Invoke-Quiet "`"$Exe`" `"$lp`" `"$(Join-Path $UserData 'extensions')`" `"$(Join-Path $env:APPDATA 'Upfly Code')`"" | Out-Null
    Remove-Item Env:\ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue

    if (-not $NoExtensions) {
        Write-Step 'Instalando o chat do Claude...'
        if ((Invoke-Quiet "`"$Cli`" --install-extension anthropic.claude-code") -eq 0) { Write-Ok 'Pronto' }
        else { Write-Note 'Sem internet agora. O Upfly Code termina isso quando abrir.' }
    }

    Write-Host ''
    Write-Host "  Upfly Code $Version instalado." -ForegroundColor Green
    Write-Note 'Procure "Upfly Code" no Menu Iniciar.'
    Write-Host ''

    if (-not $NoLaunch -or $WaitForClose) { Start-Process -FilePath $Exe }
    if (-not $WaitForClose) { Start-Sleep -Seconds 3 }
} catch {
    $_ | Out-String | Out-File $Log -Append -Encoding UTF8
    Write-Host ''
    Write-Host "  Não foi possível instalar o Upfly Code: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Detalhes para o suporte: $Log" -ForegroundColor Yellow
    Write-Host ''
    if (-not $WaitForClose) { Read-Host '  Pressione Enter para fechar' | Out-Null }
    exit 1
}
