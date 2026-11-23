-- =============================================================================
--  Upfly Code — configuração do terminal
--  Motor: WezTerm (https://wezterm.org), © Wez Furlong, licença MIT.
--  Explorador de arquivos: upfly-files (tools/upfly-files, próprio da Upfly).
--
--  Este arquivo é carregado pelo atalho "Upfly Code" via --config-file,
--  então NÃO interfere em uma configuração pessoal do WezTerm (~/.wezterm.lua).
--
--  Para personalizar: edite a tabela BRAND abaixo. O terminal recarrega
--  sozinho ao salvar (ou use CTRL+SHIFT+R).
-- =============================================================================

local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder and wezterm.config_builder() or {}

-- -----------------------------------------------------------------------------
-- Identidade visual e preferências (variáveis configuráveis)
-- -----------------------------------------------------------------------------
local BRAND = {
  company        = 'Upfly',
  terminal_name  = 'Upfly Code',
  site           = 'https://www.upfly.tec.br',
  support_email  = '[EMAIL_SUPORTE]',

  -- Cores da marca (barra de abas e destaques). O texto usa as cores padrão.
  primary        = '#0080FF', -- azul Upfly (extraído do logo)
  secondary      = '#0A0F1C', -- azul-marinho escuro (barra de título)
  accent         = '#00D4FF', -- ciano de destaque
  tab_inactive   = '#121A2E',
  tab_text       = '#C9D6EA',

  -- Fundo
  background_enabled    = true,
  background_file       = 'background.jpg', -- dentro da pasta branding/
  background_brightness = 0.55,             -- 0 = preto, 1 = imagem original
  background_overlay    = 0.35,             -- véu escuro por cima (legibilidade)

  -- Fonte: nil = padrão (JetBrains Mono, já incluída no motor)
  font           = nil,
  font_size      = nil,

  -- Shell: 'bash' = Git Bash no Windows e bash no macOS/Linux (igual nos 3)
  --        'system' = PowerShell no Windows, shell do usuário no macOS/Linux
  shell          = 'bash',

  show_welcome   = true,  -- linha discreta de boas-vindas ao abrir uma aba

  -- Explorador de arquivos (barra lateral)
  explorer_width   = 0.20, -- fração da largura da janela
  -- Editor para abrir arquivos pela barra lateral: 'auto' = Trae, VS Code ou
  -- Cursor (o primeiro encontrado); ou um comando, ex.: 'code'
  editor           = 'auto',
  explorer_on_open = true, -- abrir a barra lateral ao abrir uma pasta

  -- Pastas onde procurar projetos no "Abrir pasta" (relativas à pasta pessoal)
  project_dirs = {
    'Documents/GitHub', 'Documentos/GitHub', -- padrão do GitHub Desktop
    'projetos', 'Projetos', 'Projects', 'projects',
    'code', 'dev', 'source/repos', 'Desktop', 'Área de Trabalho',
  },
}

-- -----------------------------------------------------------------------------
-- Caminhos e plataforma
-- -----------------------------------------------------------------------------
local is_windows = wezterm.target_triple:find('windows') ~= nil
local is_mac     = wezterm.target_triple:find('apple') ~= nil
local sep        = is_windows and '\\' or '/'
local HOME       = wezterm.home_dir or os.getenv('HOME') or os.getenv('USERPROFILE') or '.'

-- Pasta de instalação = pasta acima de config/
local function base_dir()
  local cfg = wezterm.config_file or ''
  local dir = cfg:match('^(.*)[/\\]config[/\\][^/\\]+$')
  if dir then return dir end
  return wezterm.config_dir or '.'
end
local BASE = base_dir()

local function path(...)
  return table.concat({ BASE, ... }, sep)
end

local function file_exists(p)
  if not p then return false end
  local f = io.open(p, 'r')
  if f then f:close() return true end
  return false
end

local function first_existing(list)
  for _, p in ipairs(list) do
    if file_exists(p) then return p end
  end
  return nil
end

local function slashes(p) return (p:gsub('\\', '/')) end

local function basename(p)
  p = (p or ''):gsub('[/\\]+$', '')
  return p:match('([^/\\]+)$') or p
end

local function is_dir(p)
  if not p or p == '' then return false end
  local ok = pcall(wezterm.read_dir, p)
  return ok
end

-- -----------------------------------------------------------------------------
-- Shell padrão (Git Bash / bash nos 3 sistemas)
-- -----------------------------------------------------------------------------
local function powershell()
  return first_existing({ 'C:\\Program Files\\PowerShell\\7\\pwsh.exe' }) or 'powershell.exe'
end

local function find_bash()
  if is_windows then
    local lad = os.getenv('LOCALAPPDATA') or ''
    return first_existing({
      'C:\\Program Files\\Git\\bin\\bash.exe',
      lad .. '\\Programs\\Git\\bin\\bash.exe',
      path('git', 'bin', 'bash.exe'), -- Git portátil instalado pelo Upfly Code
    })
  end
  return first_existing({
    '/opt/homebrew/bin/bash', '/usr/local/bin/bash', -- bash moderno (Homebrew)
    '/bin/bash', '/usr/bin/bash',
  })
end

local BASH = (BRAND.shell == 'bash') and find_bash() or nil

local function unix_shell()
  return os.getenv('SHELL') or (is_mac and '/bin/zsh' or '/bin/bash')
end

local WELCOME_SH = path('bin', 'upfly-shell.sh')

if BASH then
  if BRAND.show_welcome then
    config.default_prog = { BASH, is_windows and slashes(WELCOME_SH) or WELCOME_SH }
  else
    config.default_prog = { BASH, '-l' }
  end
elseif is_windows then
  if BRAND.show_welcome then
    config.default_prog = {
      powershell(), '-NoLogo', '-NoExit', '-ExecutionPolicy', 'Bypass',
      '-File', path('bin', 'upfly-shell.ps1'),
    }
  else
    config.default_prog = { powershell(), '-NoLogo' }
  end
elseif BRAND.show_welcome then
  config.default_prog = { '/bin/sh', WELCOME_SH }
end

config.set_environment_variables = {
  UPFLY_CODE      = '1',
  UPFLY_CODE_HOME = BASE,
  -- usado só por quem ativar o Starship (ver docs)
  STARSHIP_CONFIG = path('config', 'starship.toml'),
}
if is_windows and BASH then
  -- Claude Code no Windows usa o Git Bash; garante que ele ache o portátil também
  config.set_environment_variables.CLAUDE_CODE_GIT_BASH_PATH = BASH
end
-- Idioma: português do Brasil por padrão (mensagens do Git e do Git Bash).
-- No macOS e no Linux vale o idioma do sistema.
if is_windows and not os.getenv('LANG') then
  config.set_environment_variables.LANG = 'pt_BR.UTF-8'
end

-- -----------------------------------------------------------------------------
-- Diretório atual do painel
-- -----------------------------------------------------------------------------
local function pane_cwd(pane)
  local ok, u = pcall(function() return pane:get_current_working_dir() end)
  if not ok or not u then return nil end
  local p
  if type(u) == 'string' then
    p = u:gsub('^file://[^/]*', '')
  else
    p = u.file_path
  end
  if p and is_windows then p = p:gsub('^/(%a:)', '%1') end
  return p
end

-- -----------------------------------------------------------------------------
-- Integração com o Claude Code
-- -----------------------------------------------------------------------------
local MSG_NO_CLAUDE = 'O Claude Code ainda nao esta instalado. Aperte F1 e escolha Conectar o Claude.'

local function claude_args()
  if BASH then
    return {
      BASH, '-lc',
      'export PATH="$HOME/.local/bin:$PATH"; if command -v claude >/dev/null 2>&1; then claude; else echo "'
        .. MSG_NO_CLAUDE .. '"; fi; exec "$BASH" -l',
    }
  end
  if is_windows then
    return {
      powershell(), '-NoLogo', '-NoExit', '-Command',
      "if (Get-Command claude -ErrorAction SilentlyContinue) { claude } else { Write-Host '"
        .. MSG_NO_CLAUDE .. "' -ForegroundColor Yellow }",
    }
  end
  local sh = unix_shell()
  return {
    sh, '-lc',
    'if command -v claude >/dev/null 2>&1; then claude; else echo "' .. MSG_NO_CLAUDE .. '"; fi; exec "'
      .. sh .. '" -l',
  }
end

local function spawn_claude(where)
  return wezterm.action_callback(function(window, pane)
    local spec = { args = claude_args(), cwd = pane_cwd(pane) }
    if where == 'split' then
      window:perform_action(act.SplitPane {
        direction = 'Right', size = { Percent = 45 }, command = spec,
      }, pane)
    else
      window:perform_action(act.SpawnCommandInNewTab(spec), pane)
    end
  end)
end

-- -----------------------------------------------------------------------------
-- Explorador de arquivos (barra lateral, como no VS Code)
-- -----------------------------------------------------------------------------
local UPFLY_FILES = first_existing({ path('tools', is_windows and 'upfly-files.exe' or 'upfly-files') })

-- Programas que a barra lateral usa para conversar com o terminal ao lado
local function wezterm_cli()
  local dir = wezterm.executable_dir or ''
  return dir .. sep .. (is_windows and 'wezterm.exe' or 'wezterm')
end

local function git_exe()
  if not is_windows then return nil end
  if BASH then
    local root = BASH:match('^(.*)\\bin\\bash%.exe$') or BASH:match('^(.*)\\usr\\bin\\bash%.exe$')
    if root and file_exists(root .. '\\cmd\\git.exe') then return root .. '\\cmd\\git.exe' end
  end
  return nil
end

local function explorer_env()
  local env = {
    UPFLY_WEZTERM_CLI = wezterm_cli(),
    UPFLY_EDITOR = BRAND.editor or 'auto',
    UPFLY_SHELL_KIND = BASH and 'bash' or (is_windows and 'powershell' or 'posix'),
  }
  local g = git_exe()
  if g then env.UPFLY_GIT = g end
  return env
end

local function explorer_args(dir)
  return { UPFLY_FILES, dir }
end

local function is_explorer(p)
  local ok, name = pcall(function() return p:get_foreground_process_name() end)
  if ok and name and name:lower():find('upfly%-files') then return true end
  local ok2, title = pcall(function() return p:get_title() end)
  return ok2 and title and title:lower():find('upfly%-files') ~= nil
end

local function add_explorer(pane, dir)
  if not UPFLY_FILES then return nil end
  local ok, new = pcall(function()
    return pane:split {
      direction = 'Left', size = BRAND.explorer_width, top_level = true,
      cwd = dir, args = explorer_args(dir),
      set_environment_variables = explorer_env(),
    }
  end)
  return ok and new or nil
end

local toggle_explorer = wezterm.action_callback(function(window, pane)
  if not UPFLY_FILES then
    window:toast_notification(BRAND.terminal_name,
      'Explorador de arquivos não instalado. Rode o instalador do Upfly Code de novo.', nil, 5000)
    return
  end
  local tab = pane:tab()
  for _, p in ipairs(tab:panes()) do
    if is_explorer(p) then
      window:perform_action(act.CloseCurrentPane { confirm = false }, p)
      return
    end
  end
  add_explorer(pane, pane_cwd(pane) or HOME)
end)

-- -----------------------------------------------------------------------------
-- Abrir pasta (recentes, projetos, seletor do sistema ou caminho digitado)
-- -----------------------------------------------------------------------------
local RECENT_FILE = path('state', 'recent.txt')
local MAX_RECENT = 15

local function normalize_dir(d)
  if not d then return nil end
  d = d:gsub('^%s+', ''):gsub('%s+$', ''):gsub('^"(.*)"$', '%1')
  if d:sub(1, 1) == '~' then d = HOME .. d:sub(2) end
  if is_windows then
    d = d:gsub('/', '\\')
    d = d:gsub('^\\(%a):', '%1:')           -- /C:/x -> C:\x
    d = d:gsub('^\\(%a)\\', '%1:\\')        -- /c/x  -> c:\x (estilo Git Bash)
  end
  if #d > 3 then d = d:gsub('[/\\]+$', '') end
  return d
end

local function read_recents()
  local list = {}
  local f = io.open(RECENT_FILE, 'r')
  if not f then return list end
  for line in f:lines() do
    if line ~= '' then table.insert(list, line) end
  end
  f:close()
  return list
end

local function add_recent(dir)
  local list = { dir }
  for _, d in ipairs(read_recents()) do
    if d ~= dir and #list < MAX_RECENT then table.insert(list, d) end
  end
  local f = io.open(RECENT_FILE, 'w')
  if not f then return end
  f:write(table.concat(list, '\n'), '\n')
  f:close()
end

local function find_projects()
  local found, seen = {}, {}
  for _, rel in ipairs(BRAND.project_dirs) do
    local root = HOME .. sep .. rel:gsub('/', sep)
    local ok, entries = pcall(wezterm.read_dir, root)
    if ok and entries then
      for _, e in ipairs(entries) do
        local name = basename(e)
        if #found < 60 and not seen[e] and name:sub(1, 1) ~= '.' and is_dir(e) then
          seen[e] = true
          table.insert(found, e)
        end
      end
    end
  end
  return found
end

local function trim(s) return (s or ''):gsub('^%s+', ''):gsub('%s+$', '') end

-- Abre o seletor de pastas nativo do sistema. Retorna o caminho ou nil.
local function native_pick_folder()
  local args
  if is_windows then
    args = { 'powershell.exe', '-NoProfile', '-STA', '-WindowStyle', 'Hidden', '-Command',
      '[Console]::OutputEncoding=[Text.Encoding]::UTF8;'
      .. 'Add-Type -AssemblyName System.Windows.Forms;'
      .. '$f=New-Object System.Windows.Forms.Form -Property @{TopMost=$true};'
      .. '$d=New-Object System.Windows.Forms.FolderBrowserDialog;'
      .. '$d.Description="Abrir pasta no Upfly Code";$d.ShowNewFolderButton=$true;'
      .. 'if($d.ShowDialog($f) -eq "OK"){[Console]::Out.Write($d.SelectedPath)}' }
  elseif is_mac then
    args = { 'osascript', '-e',
      'POSIX path of (choose folder with prompt "Abrir pasta no Upfly Code")' }
  elseif file_exists('/usr/bin/zenity') then
    args = { 'zenity', '--file-selection', '--directory', '--title=Abrir pasta no Upfly Code' }
  elseif file_exists('/usr/bin/kdialog') then
    args = { 'kdialog', '--getexistingdirectory', HOME, '--title', 'Abrir pasta no Upfly Code' }
  else
    return nil, 'sem-seletor'
  end
  local ok, success, stdout = pcall(wezterm.run_child_process, args)
  if not ok or not success then return nil end
  local p = trim(stdout)
  if p == '' then return nil end
  return p
end

local function open_folder(window, pane, dir)
  dir = normalize_dir(dir)
  if not dir or not is_dir(dir) then
    window:toast_notification(BRAND.terminal_name, 'Pasta não encontrada: ' .. tostring(dir), nil, 5000)
    return
  end
  add_recent(dir)
  local tab, main = window:mux_window():spawn_tab { cwd = dir }
  tab:set_title(basename(dir))
  if BRAND.explorer_on_open and add_explorer(main, dir) then
    main:activate()
  end
end

local function prompt_path(window, pane)
  window:perform_action(act.PromptInputLine {
    description = wezterm.format {
      { Foreground = { Color = BRAND.accent } }, { Text = 'Abrir pasta — ' },
      { Attribute = { Intensity = 'Normal' } },
      { Text = 'digite ou cole o caminho e tecle Enter (Esc cancela)' },
    },
    action = wezterm.action_callback(function(w, p, line)
      if line and trim(line) ~= '' then open_folder(w, p, line) end
    end),
  }, pane)
end

local open_folder_picker = wezterm.action_callback(function(window, pane)
  local choices = {
    { id = '__browse__', label = '📂  Procurar pasta no computador...' },
    { id = '__type__',   label = '⌨   Digitar ou colar um caminho...' },
  }
  local seen = {}
  for _, d in ipairs(read_recents()) do
    if is_dir(d) then
      seen[d] = true
      table.insert(choices, { id = d, label = '🕘  ' .. basename(d) .. '   ' .. d })
    end
  end
  for _, d in ipairs(find_projects()) do
    if not seen[d] then
      table.insert(choices, { id = d, label = '📁  ' .. basename(d) .. '   ' .. d })
    end
  end

  window:perform_action(act.InputSelector {
    title = 'Abrir pasta',
    description = 'Enter abre  ·  / pesquisa pelo nome  ·  Esc cancela',
    fuzzy_description = 'Pesquisar pasta: ',
    choices = choices,
    action = wezterm.action_callback(function(w, p, id, label)
      if not id then return end
      if id == '__browse__' then
        local picked, why = native_pick_folder()
        if picked then
          open_folder(w, p, picked)
        elseif why == 'sem-seletor' then
          prompt_path(w, p)
        end
      elseif id == '__type__' then
        prompt_path(w, p)
      else
        open_folder(w, p, id)
      end
    end),
  }, pane)
end)

-- -----------------------------------------------------------------------------
-- Atualizações (GitHub Releases)
--   O repositório fica em config/update-repo.txt (ex.: upfly/upfly-code).
--   Ao abrir e a cada 6 h, o Upfly Code consulta a última release. Se houver
--   versão nova, mostra um aviso com o botão "Atualizar agora", um selo na
--   barra superior e a opção "Atualizar" no menu (F1).
-- -----------------------------------------------------------------------------
local function read_first_line(p)
  local f = io.open(p, 'r')
  if not f then return nil end
  local line = f:read('l')
  f:close()
  return line and trim(line) or nil
end

local CURRENT_VERSION = read_first_line(path('VERSION')) or '0.0.0'
local UPDATE_REPO = read_first_line(path('config', 'update-repo.txt'))
if UPDATE_REPO and (UPDATE_REPO == '' or UPDATE_REPO:find('%[')) then UPDATE_REPO = nil end
local UPDATE_INTERVAL = 6 * 3600

local function version_parts(v)
  local t = {}
  for n in tostring(v):gsub('^v', ''):gmatch('%d+') do table.insert(t, tonumber(n)) end
  return t
end

local function is_newer(candidate, current)
  local a, b = version_parts(candidate), version_parts(current)
  for i = 1, math.max(#a, #b) do
    local x, y = a[i] or 0, b[i] or 0
    if x ~= y then return x > y end
  end
  return false
end

-- Consulta a última release. Retorna { version, url, notes } ou nil.
local function fetch_latest_release()
  if not UPDATE_REPO then return nil end
  local ok, success, stdout = pcall(wezterm.run_child_process, {
    is_windows and 'curl.exe' or 'curl', '-fsSL', '--max-time', '15',
    '-H', 'Accept: application/vnd.github+json', '-H', 'User-Agent: UpflyCode',
    'https://api.github.com/repos/' .. UPDATE_REPO .. '/releases/latest',
  })
  if not ok or not success or not stdout or stdout == '' then return nil end
  local okj, data = pcall(wezterm.json_parse, stdout)
  if not okj or type(data) ~= 'table' or not data.tag_name then return nil end
  return {
    version = (data.tag_name:gsub('^v', '')),
    url = data.html_url,
    notes = data.body or '',
  }
end

local function updater_args()
  if is_windows then
    return { 'powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass',
      '-File', path('bin', 'self-update.ps1') }
  end
  return { '/bin/bash', path('bin', 'self-update.sh') }
end

local function run_update(window, pane)
  window:perform_action(act.SpawnCommandInNewTab { args = updater_args() }, pane)
end

local function show_update_prompt(window, pane, info)
  window:perform_action(act.InputSelector {
    title = 'Atualização do Upfly Code',
    description = 'Nova versão ' .. info.version .. ' disponível (você tem a ' .. CURRENT_VERSION
      .. ').  Enter escolhe · Esc fecha',
    choices = {
      { id = 'now',   label = '⬆   Atualizar agora para a versão ' .. info.version },
      { id = 'notes', label = '📄  Ver o que mudou' },
      { id = 'later', label = '⏰  Lembrar depois' },
    },
    action = wezterm.action_callback(function(w, p, id)
      if id == 'now' then
        run_update(w, p)
      elseif id == 'notes' and info.url then
        wezterm.open_with(info.url)
      end
    end),
  }, pane)
end

local function check_for_updates(opts)
  opts = opts or {}
  local info = fetch_latest_release()
  if info and is_newer(info.version, CURRENT_VERSION) then
    wezterm.GLOBAL.upfly_update = info
  else
    wezterm.GLOBAL.upfly_update = nil
  end
  local win = opts.window
  if not win then
    local all = wezterm.mux.all_windows()
    win = all[1] and all[1]:gui_window()
  end
  if not win then return end
  local found = wezterm.GLOBAL.upfly_update
  if found and (opts.manual or wezterm.GLOBAL.upfly_update_prompted ~= found.version) then
    wezterm.GLOBAL.upfly_update_prompted = found.version
    win:toast_notification(BRAND.terminal_name, 'Nova versão ' .. found.version .. ' disponível.', nil, 6000)
    show_update_prompt(win, win:active_pane(), found)
  elseif opts.manual then
    local msg = UPDATE_REPO and ('Você já está na versão mais recente (' .. CURRENT_VERSION .. ').')
      or 'Repositório de atualizações não configurado (config/update-repo.txt).'
    if UPDATE_REPO and not info then msg = 'Não foi possível consultar o GitHub agora. Tente mais tarde.' end
    win:toast_notification(BRAND.terminal_name, msg, nil, 5000)
  end
end

local function schedule_update_checks(delay)
  if not UPDATE_REPO then return end
  wezterm.time.call_after(delay, function()
    pcall(check_for_updates)
    schedule_update_checks(UPDATE_INTERVAL)
  end)
end

local update_action = wezterm.action_callback(function(window, pane)
  local info = wezterm.GLOBAL.upfly_update
  if info and is_newer(info.version, CURRENT_VERSION) then
    show_update_prompt(window, pane, info)
  else
    check_for_updates { window = window, manual = true }
  end
end)

-- -----------------------------------------------------------------------------
-- Conexão com o Claude (assistente ao abrir)
--   Se o Claude Code não estiver instalado ou a conta não estiver conectada,
--   o Upfly Code oferece "Instalar" / "Entrar com minha conta" ao abrir.
-- -----------------------------------------------------------------------------
local NO_CLAUDE_PROMPT = path('state', 'nao-perguntar-claude')

local function claude_installed()
  local candidates = is_windows
    and { HOME .. '\\.local\\bin\\claude.exe' }
    or { HOME .. '/.local/bin/claude', '/opt/homebrew/bin/claude', '/usr/local/bin/claude', '/usr/bin/claude' }
  if first_existing(candidates) then return true end
  local ok, success
  if BASH then
    ok, success = pcall(wezterm.run_child_process, { BASH, '-lc', 'command -v claude' })
  elseif is_windows then
    ok, success = pcall(wezterm.run_child_process, { 'where.exe', 'claude' })
  else
    ok, success = pcall(wezterm.run_child_process, { unix_shell(), '-lc', 'command -v claude' })
  end
  return ok and success or false
end

local function claude_logged_in()
  if os.getenv('ANTHROPIC_API_KEY') or os.getenv('CLAUDE_CODE_OAUTH_TOKEN') then return true end
  if file_exists(HOME .. sep .. '.claude' .. sep .. '.credentials.json') then return true end
  local f = io.open(HOME .. sep .. '.claude.json', 'r')
  if f then
    local content = f:read('a') or ''
    f:close()
    if content:find('"oauthAccount"', 1, true) then return true end
  end
  return false
end

local function claude_install_args()
  if BASH and is_windows then
    return { BASH, '-lc',
      'echo "Instalando o Claude Code..."; '
      .. 'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "irm https://claude.ai/install.ps1 | iex" && '
      .. 'export PATH="$HOME/.local/bin:$PATH" && echo && echo "Agora entre na sua conta do Claude:" && claude; '
      .. 'exec "$BASH" -l' }
  elseif is_windows then
    return { powershell(), '-NoLogo', '-NoExit', '-Command',
      'irm https://claude.ai/install.ps1 | iex; $env:Path = "$env:USERPROFILE\\.local\\bin;$env:Path"; claude' }
  end
  local sh = BASH or unix_shell()
  return { sh, '-lc',
    'echo "Instalando o Claude Code..."; curl -fsSL https://claude.ai/install.sh | bash && '
    .. 'export PATH="$HOME/.local/bin:$PATH" && echo && echo "Agora entre na sua conta do Claude:" && claude; '
    .. 'exec "' .. sh .. '" -l' }
end

local function claude_status()
  if not claude_installed() then return 'missing' end
  if not claude_logged_in() then return 'logged_out' end
  return 'ok'
end

local function show_claude_prompt(window, pane, status, manual)
  local choices
  if status == 'missing' then
    choices = {
      { id = 'install', label = '⬇   Instalar o Claude Code e entrar na minha conta' },
    }
  elseif status == 'logged_out' then
    choices = {
      { id = 'login', label = '🔑  Entrar com minha conta Claude (abre o navegador)' },
    }
  else
    window:toast_notification(BRAND.terminal_name, 'Claude Code instalado e conectado.', nil, 4000)
    return
  end
  table.insert(choices, { id = 'later', label = '⏭   Agora não' })
  if not manual then
    table.insert(choices, { id = 'never', label = '🔕  Não perguntar de novo' })
  end
  window:perform_action(act.InputSelector {
    title = 'Conectar o Upfly Code ao Claude',
    description = status == 'missing'
      and 'O Claude Code ainda não está instalado neste computador.  Enter escolhe · Esc fecha'
      or 'Falta entrar na sua conta do Claude (Pro, Max, Team ou Enterprise).  Enter escolhe · Esc fecha',
    choices = choices,
    action = wezterm.action_callback(function(w, p, id)
      if id == 'install' then
        w:perform_action(act.SpawnCommandInNewTab { args = claude_install_args() }, p)
      elseif id == 'login' then
        w:perform_action(act.SpawnCommandInNewTab { args = claude_args() }, p)
      elseif id == 'never' then
        local f = io.open(NO_CLAUDE_PROMPT, 'w')
        if f then f:write('1') f:close() end
      end
    end),
  }, pane)
end

local function check_claude_on_start(window)
  local status = claude_status()
  wezterm.GLOBAL.upfly_claude = status
  if status == 'ok' or file_exists(NO_CLAUDE_PROMPT) then return end
  if window then show_claude_prompt(window, window:active_pane(), status, false) end
end

local connect_claude_action = wezterm.action_callback(function(window, pane)
  local status = claude_status()
  wezterm.GLOBAL.upfly_claude = status
  show_claude_prompt(window, pane, status, true)
end)

-- Windows: ícone e nome da Upfly na barra de tarefas (bin\upfly-taskbar.exe)
local function start_taskbar_helper()
  if not is_windows then return end
  local helper = path('bin', 'upfly-taskbar.exe')
  if not file_exists(helper) then return end
  local exe = (wezterm.executable_dir or '') .. '\\UpflyCode.exe'
  if not file_exists(exe) then exe = (wezterm.executable_dir or '') .. '\\wezterm-gui.exe' end
  local relaunch = '"' .. exe .. '" --config-file "' .. (wezterm.config_file or '')
    .. '" start --always-new-process --class UpflyCode'
  pcall(wezterm.background_child_process, { helper, path('branding', 'icon.ico'), relaunch, 'Upfly.UpflyCode' })
end

-- Ao iniciar com uma pasta (ex.: "Abrir no Upfly Code" no menu do Windows,
-- ou `upfly-code <pasta>`), abre já com a barra lateral.
wezterm.on('gui-startup', function(cmd)
  local tab, pane, mux_window = wezterm.mux.spawn_window(cmd or {})
  start_taskbar_helper()
  schedule_update_checks(8)
  wezterm.time.call_after(1.5, function()
    local gw = mux_window and mux_window:gui_window()
    pcall(check_claude_on_start, gw)
  end)
  local cwd = cmd and cmd.cwd and normalize_dir(cmd.cwd)
  if cwd and normalize_dir(HOME) ~= cwd and is_dir(cwd) then
    add_recent(cwd)
    tab:set_title(basename(cwd))
    if BRAND.explorer_on_open and add_explorer(pane, cwd) then pane:activate() end
  end
end)

-- -----------------------------------------------------------------------------
-- Aparência
-- -----------------------------------------------------------------------------
local function background_layers()
  local img = path('branding', BRAND.background_file)
  if not BRAND.background_enabled or not file_exists(img) then
    return nil
  end
  return {
    {
      source = { File = img },
      width = 'Cover', height = 'Cover',
      horizontal_align = 'Center', vertical_align = 'Middle',
      repeat_x = 'NoRepeat', repeat_y = 'NoRepeat',
      hsb = { brightness = BRAND.background_brightness, saturation = 1.0, hue = 1.0 },
      attachment = 'Fixed',
    },
    {
      source = { Color = '#03050B' },
      width = '100%', height = '100%',
      opacity = BRAND.background_overlay,
    },
  }
end

config.background = background_layers()

if BRAND.font then config.font = wezterm.font(BRAND.font) end
if BRAND.font_size then config.font_size = BRAND.font_size end

config.initial_cols = 140
config.initial_rows = 36
config.window_padding = { left = 10, right = 10, top = 8, bottom = 6 }
config.scrollback_lines = 20000
config.audible_bell = 'Disabled'
config.visual_bell = {
  fade_in_duration_ms = 75, fade_out_duration_ms = 150,
  target = 'CursorColor',
}
-- O aviso de fechar do motor é em inglês; o Upfly Code usa o seu (Ctrl+Shift+W).
config.window_close_confirmation = 'NeverPrompt'
config.hide_tab_bar_if_only_one_tab = false
config.use_fancy_tab_bar = true
config.tab_max_width = 32
-- painel inativo levemente apagado, para destacar onde está o foco
config.inactive_pane_hsb = { saturation = 0.9, brightness = 0.75 }

config.window_frame = {
  active_titlebar_bg   = BRAND.secondary,
  inactive_titlebar_bg = BRAND.secondary,
}

config.colors = {
  split = '#1B2742',
  tab_bar = {
    background = BRAND.secondary,
    active_tab = { bg_color = BRAND.primary, fg_color = '#FFFFFF', intensity = 'Bold' },
    inactive_tab = { bg_color = BRAND.tab_inactive, fg_color = BRAND.tab_text },
    inactive_tab_hover = { bg_color = '#1B2742', fg_color = '#FFFFFF' },
    new_tab = { bg_color = BRAND.secondary, fg_color = BRAND.tab_text },
    new_tab_hover = { bg_color = BRAND.primary, fg_color = '#FFFFFF' },
  },
  -- O demais (cores do texto, cursor, paleta ANSI) fica no padrão.
}

-- Nomes de shell que não precisam aparecer no título (é só o "prompt")
local SHELL_NAMES = {
  ['powershell.exe'] = true, ['pwsh.exe'] = true, ['cmd.exe'] = true,
  ['powershell'] = true, ['pwsh'] = true, ['bash'] = true, ['zsh'] = true,
  ['fish'] = true, ['sh'] = true, ['bash.exe'] = true, ['wsl.exe'] = true,
  ['mintty.exe'] = true, ['administrador: windows powershell'] = true,
  ['windows powershell'] = true,
}

local function friendly_title(raw)
  raw = raw or ''
  local rawl = raw:lower()
  if rawl:find('^mingw') or rawl:find('^msys') then return nil end -- título do Git Bash
  if rawl:find('wezterm') or rawl:find('upflycode') then return nil end -- título padrão do motor
  local base = raw:match('([^/\\]+)$') or raw
  local lower = base:lower()
  if raw == '' or SHELL_NAMES[lower] or SHELL_NAMES[rawl] then
    return nil
  end
  if lower:find('^claude') then return 'Claude Code' end
  if lower:find('^upfly%-files') then return 'Arquivos' end
  return raw
end

-- Título da janela: "Upfly Code" ou "Upfly Code — <programa em execução>"
wezterm.on('format-window-title', function(tab, pane, tabs, panes, cfg)
  local ok, t = pcall(friendly_title, tab.active_pane.title)
  if not ok or not t then return BRAND.terminal_name end
  return BRAND.terminal_name .. ' — ' .. t
end)

-- Título das abas: nome dado ao abrir a pasta, programa em execução ou pasta atual
local function tab_title(tab, max_width)
  if tab.tab_title and #tab.tab_title > 0 then return tab.tab_title end
  local t = friendly_title(tab.active_pane.title)
  if not t then
    local cwd = tab.active_pane.current_working_dir
    if cwd then
      local p = type(cwd) == 'string' and cwd:gsub('^file://[^/]*', '') or cwd.file_path
      if p and p ~= '' and p ~= '/' then
        t = basename(p)
        if normalize_dir(p) == normalize_dir(HOME) then t = 'Início' end
      end
    end
  end
  return t or BRAND.terminal_name
end

wezterm.on('format-tab-title', function(tab, tabs, panes, cfg, hover, max_width)
  local ok, t = pcall(tab_title, tab, max_width)
  if not ok or not t or t == '' then t = BRAND.terminal_name end
  return ' ' .. wezterm.truncate_right(t, math.max(4, (max_width or 20) - 2)) .. ' '
end)

-- Status no canto direito da barra de abas
wezterm.on('update-status', function(window, pane)
  local leader = window:leader_is_active() and '  ⌨ Atalho: aperte a próxima tecla ' or ''
  local upd = wezterm.GLOBAL.upfly_update
  if upd and not is_newer(upd.version, CURRENT_VERSION) then
    wezterm.GLOBAL.upfly_update = nil -- já atualizado
    upd = nil
  end
  local badge = upd and (' ⬆ Nova versão ' .. upd.version .. ': aperte F1 ') or ''
  local cs = wezterm.GLOBAL.upfly_claude
  local claude_badge = (cs == 'missing' or cs == 'logged_out') and ' ● Conectar o Claude: aperte F1 ' or ''
  window:set_right_status(wezterm.format {
    { Foreground = { Color = '#FFC857' } }, { Text = leader },
    { Background = { Color = upd and '#FFC857' or BRAND.secondary } },
    { Foreground = { Color = '#0A0F1C' } }, { Text = badge },
    { Background = { Color = BRAND.secondary } },
    { Foreground = { Color = '#FF9F5A' } }, { Text = claude_badge },
    { Background = { Color = BRAND.secondary } },
    { Foreground = { Color = BRAND.tab_text } }, { Text = '  ☰ Menu: F1  ' },
    { Foreground = { Color = BRAND.accent } }, { Text = '▲ ' },
    { Foreground = { Color = BRAND.tab_text } },
    { Text = BRAND.terminal_name .. '  ' .. wezterm.strftime('%H:%M') .. '  ' },
  })
end)

-- Aviso quando uma aba em segundo plano (ex.: Claude Code) toca o sino
wezterm.on('bell', function(window, pane)
  if not window:is_focused() then
    window:toast_notification(BRAND.terminal_name,
      'Uma aba precisa da sua atenção: ' .. (pane:get_title() or ''), nil, 5000)
  end
end)

-- Liga/desliga o fundo
wezterm.on('upfly-toggle-background', function(window, pane)
  local o = window:get_config_overrides() or {}
  if o.background then
    o.background = nil
  else
    o.background = { { source = { Color = '#05070F' }, width = '100%', height = '100%' } }
  end
  window:set_config_overrides(o)
end)

-- -----------------------------------------------------------------------------
-- Fechar com aviso em português
--   Só pergunta se algum programa (ex.: Claude Code) ainda estiver rodando.
-- -----------------------------------------------------------------------------
local function busy_program(p)
  local ok, name = pcall(function() return p:get_foreground_process_name() end)
  if not ok or not name or name == '' then return nil end
  local base = (name:match('([^/\\]+)$') or name):lower()
  if SHELL_NAMES[base] or base:find('^upfly%-files') or base:find('^wezterm') then return nil end
  if base:find('^claude') or base:find('^node') then return 'o Claude Code' end
  return base:gsub('%.exe$', '')
end

local function confirm_close(window, pane, what)
  local panes = {}
  if what == 'tab' then
    for _, p in ipairs(pane:tab():panes()) do table.insert(panes, p) end
  else
    panes = { pane }
  end
  local running
  for _, p in ipairs(panes) do running = running or busy_program(p) end
  local close = what == 'tab' and act.CloseCurrentTab { confirm = false }
    or act.CloseCurrentPane { confirm = false }
  if not running then
    window:perform_action(close, pane)
    return
  end
  window:perform_action(act.InputSelector {
    title = what == 'tab' and 'Fechar esta aba?' or 'Fechar este painel?',
    description = 'Ainda tem ' .. running .. ' rodando aqui. Ele será encerrado.',
    choices = {
      { id = 'no',  label = 'Não, continuar aqui' },
      { id = 'yes', label = 'Sim, fechar' },
    },
    action = wezterm.action_callback(function(w, p, id)
      if id == 'yes' then w:perform_action(close, p) end
    end),
  }, pane)
end

local close_tab  = wezterm.action_callback(function(w, p) confirm_close(w, p, 'tab') end)
local close_pane = wezterm.action_callback(function(w, p) confirm_close(w, p, 'pane') end)

-- -----------------------------------------------------------------------------
-- Nova aba com... (substitui o lançador do motor, que é em inglês)
-- -----------------------------------------------------------------------------
local launch_menu = {
  { label = 'Claude Code', args = claude_args() },
}
if BASH then
  table.insert(launch_menu, { label = is_windows and 'Git Bash' or 'Bash', args = { BASH, '-l' } })
end
if is_windows then
  table.insert(launch_menu, { label = 'PowerShell', args = { powershell(), '-NoLogo' } })
  table.insert(launch_menu, { label = 'Prompt de Comando (CMD)', args = { 'cmd.exe' } })
else
  table.insert(launch_menu, { label = 'Shell do sistema (' .. unix_shell() .. ')', args = { unix_shell(), '-l' } })
end
config.launch_menu = launch_menu

local new_tab_with = wezterm.action_callback(function(window, pane)
  local choices = {}
  for i, item in ipairs(launch_menu) do
    table.insert(choices, { id = tostring(i), label = item.label })
  end
  window:perform_action(act.InputSelector {
    title = 'Abrir nova aba com…',
    description = 'Enter abre  ·  Esc cancela',
    choices = choices,
    action = wezterm.action_callback(function(w, p, id)
      local item = id and launch_menu[tonumber(id)]
      if item then
        w:perform_action(act.SpawnCommandInNewTab { args = item.args, cwd = pane_cwd(p) }, p)
      end
    end),
  }, pane)
end)

-- -----------------------------------------------------------------------------
-- Copiar e colar como em qualquer programa
--   Ctrl+C copia quando há texto selecionado; sem seleção, interrompe o
--   programa (como sempre no terminal). Ctrl+V cola.
-- -----------------------------------------------------------------------------
local smart_copy = wezterm.action_callback(function(window, pane)
  local sel = window:get_selection_text_for_pane(pane)
  if sel and sel ~= '' then
    window:perform_action(act.CopyTo 'Clipboard', pane)
    window:perform_action(act.ClearSelection, pane)
  else
    window:perform_action(act.SendKey { key = 'c', mods = 'CTRL' }, pane)
  end
end)

-- -----------------------------------------------------------------------------
-- Menu do Upfly Code (F1, Ctrl+Shift+P ou botão direito do mouse)
--   Tudo o que o terminal faz, em português, com busca por nome.
-- -----------------------------------------------------------------------------
local MOD = is_mac and 'Cmd' or 'Ctrl'

local function menu_items(window, pane)
  local items = {}
  local function add(id, label, key, run)
    table.insert(items, { id = id, label = label, key = key, run = run })
  end
  local sel = window:get_selection_text_for_pane(pane)
  if sel and sel ~= '' then
    add('copy', 'Copiar texto selecionado', MOD .. '+C', function(w, p)
      w:perform_action(act.CopyTo 'Clipboard', p)
      w:perform_action(act.ClearSelection, p)
    end)
  end
  local cs = wezterm.GLOBAL.upfly_claude
  if cs == 'missing' or cs == 'logged_out' then
    add('claude-connect', '● Conectar o Claude (falta fazer)', nil, function(w, p)
      w:perform_action(connect_claude_action, p)
    end)
  end
  local upd = wezterm.GLOBAL.upfly_update
  if upd and is_newer(upd.version, CURRENT_VERSION) then
    add('update-now', '⬆ Atualizar para a versão ' .. upd.version, nil, function(w, p)
      run_update(w, p)
    end)
  end
  add('paste', 'Colar', MOD .. '+V', function(w, p) w:perform_action(act.PasteFrom 'Clipboard', p) end)
  if not is_mac then
    -- o Claude Code lê imagens da área de transferência com o Ctrl+V "puro"
    add('paste-image', 'Colar imagem no Claude', 'Ctrl+Shift+V', function(w, p)
      w:perform_action(act.SendKey { key = 'v', mods = 'CTRL' }, p)
    end)
  end
  add('open', 'Abrir pasta de projeto', 'Ctrl+Shift+O', function(w, p) w:perform_action(open_folder_picker, p) end)
  add('files', 'Mostrar ou esconder os arquivos (barra lateral)', 'Ctrl+Shift+E', function(w, p)
    w:perform_action(toggle_explorer, p)
  end)
  add('claude-side', 'Abrir o Claude ao lado', 'Ctrl+Shift+A', function(w, p)
    w:perform_action(spawn_claude('split'), p)
  end)
  add('claude-tab', 'Abrir o Claude numa aba nova', nil, function(w, p)
    w:perform_action(spawn_claude('tab'), p)
  end)
  add('newtab', 'Nova aba', 'Ctrl+Shift+T', function(w, p) w:perform_action(act.SpawnTab 'CurrentPaneDomain', p) end)
  add('newtab-with', 'Nova aba com… (Bash, PowerShell, Claude)', nil, function(w, p)
    w:perform_action(new_tab_with, p)
  end)
  add('split-right', 'Dividir a tela: novo terminal à direita', nil, function(w, p)
    w:perform_action(act.SplitHorizontal { domain = 'CurrentPaneDomain' }, p)
  end)
  add('split-down', 'Dividir a tela: novo terminal embaixo', nil, function(w, p)
    w:perform_action(act.SplitVertical { domain = 'CurrentPaneDomain' }, p)
  end)
  add('zoom', 'Ampliar ou voltar o painel atual', nil, function(w, p) w:perform_action(act.TogglePaneZoomState, p) end)
  add('close-pane', 'Fechar este painel', nil, function(w, p) confirm_close(w, p, 'pane') end)
  add('close-tab', 'Fechar esta aba', 'Ctrl+Shift+W', function(w, p) confirm_close(w, p, 'tab') end)
  add('search', 'Procurar texto no terminal', 'Ctrl+Shift+F', function(w, p)
    w:perform_action(act.Search 'CurrentSelectionOrEmptyString', p)
  end)
  add('clear', 'Limpar a tela', 'Ctrl+Shift+K', function(w, p)
    w:perform_action(act.ClearScrollback 'ScrollbackAndViewport', p)
    w:perform_action(act.SendKey { key = 'l', mods = 'CTRL' }, p)
  end)
  add('font-up', 'Aumentar a letra', 'Ctrl+=', function(w, p) w:perform_action(act.IncreaseFontSize, p) end)
  add('font-down', 'Diminuir a letra', 'Ctrl+-', function(w, p) w:perform_action(act.DecreaseFontSize, p) end)
  add('font-reset', 'Tamanho normal da letra', 'Ctrl+0', function(w, p) w:perform_action(act.ResetFontSize, p) end)
  add('fullscreen', 'Tela cheia', 'F11', function(w, p) w:perform_action(act.ToggleFullScreen, p) end)
  add('background', 'Ligar ou desligar a imagem de fundo', nil, function(w, p)
    w:perform_action(act.EmitEvent 'upfly-toggle-background', p)
  end)
  if not (cs == 'missing' or cs == 'logged_out') then
    add('claude-account', 'Conta do Claude (verificar conexão)', nil, function(w, p)
      w:perform_action(connect_claude_action, p)
    end)
  end
  add('update', 'Procurar atualização do Upfly Code', nil, function(w, p) w:perform_action(update_action, p) end)
  add('new-window', 'Nova janela', 'Ctrl+Shift+N', function(w, p) w:perform_action(act.SpawnWindow, p) end)
  return items
end

local function pad(s, n)
  local len = utf8 and utf8.len(s) or #s
  if not len then len = #s end
  if len >= n then return s .. '  ' end
  return s .. string.rep(' ', n - len)
end

local show_menu = wezterm.action_callback(function(window, pane)
  local items = menu_items(window, pane)
  local by_id, choices = {}, {}
  for _, it in ipairs(items) do
    by_id[it.id] = it
    local label = it.key and (pad(it.label, 52) .. it.key) or it.label
    table.insert(choices, { id = it.id, label = label })
  end
  window:perform_action(act.InputSelector {
    title = BRAND.terminal_name .. ': o que você quer fazer?',
    fuzzy = true,
    fuzzy_description = 'Digite para procurar  (↑ ↓ escolhe · Enter confirma · Esc fecha): ',
    choices = choices,
    action = wezterm.action_callback(function(w, p, id)
      local it = id and by_id[id]
      if it then it.run(w, p) end
    end),
  }, pane)
end)

-- -----------------------------------------------------------------------------
-- Atalhos
--   F1 ou Ctrl+Shift+P: menu com tudo, em português
--   Ctrl+Shift+O abrir pasta · Ctrl+Shift+E arquivos · Ctrl+Shift+A Claude
--   Ctrl+C copia (com texto selecionado) · Ctrl+V cola
--   Atalhos antigos com Ctrl+Espaço continuam funcionando.
-- -----------------------------------------------------------------------------
config.leader = { key = 'Space', mods = 'CTRL', timeout_milliseconds = 1500 }

config.keys = {
  -- Menu
  { key = 'F1', mods = 'NONE', action = show_menu },
  { key = 'p', mods = 'CTRL|SHIFT', action = show_menu },
  { key = 'P', mods = 'CTRL|SHIFT', action = show_menu },

  -- Copiar e colar
  { key = 'c', mods = 'CTRL', action = smart_copy },
  { key = 'v', mods = 'CTRL', action = act.PasteFrom 'Clipboard' },
  -- imagem no Claude Code: manda o Ctrl+V original para ele
  { key = 'v', mods = 'CTRL|SHIFT', action = act.SendKey { key = 'v', mods = 'CTRL' } },
  { key = 'V', mods = 'CTRL|SHIFT', action = act.SendKey { key = 'v', mods = 'CTRL' } },

  -- Pastas, arquivos e Claude
  { key = 'o', mods = 'CTRL|SHIFT', action = open_folder_picker },
  { key = 'O', mods = 'CTRL|SHIFT', action = open_folder_picker },
  { key = 'e', mods = 'CTRL|SHIFT', action = toggle_explorer },
  { key = 'E', mods = 'CTRL|SHIFT', action = toggle_explorer },
  { key = 'a', mods = 'CTRL|SHIFT', action = spawn_claude('split') },
  { key = 'A', mods = 'CTRL|SHIFT', action = spawn_claude('split') },

  -- Fechar com aviso em português
  { key = 'w', mods = 'CTRL|SHIFT', action = close_tab },
  { key = 'W', mods = 'CTRL|SHIFT', action = close_tab },
  { key = 'k', mods = 'CTRL|SHIFT', action = act.Multiple {
      act.ClearScrollback 'ScrollbackAndViewport', act.SendKey { key = 'l', mods = 'CTRL' } } },
  { key = 'K', mods = 'CTRL|SHIFT', action = act.Multiple {
      act.ClearScrollback 'ScrollbackAndViewport', act.SendKey { key = 'l', mods = 'CTRL' } } },
  { key = 'F11', mods = 'NONE', action = act.ToggleFullScreen },

  -- Telas do motor que só existem em inglês: desligadas
  { key = 'l', mods = 'CTRL|SHIFT', action = act.DisableDefaultAssignment },
  { key = 'L', mods = 'CTRL|SHIFT', action = act.DisableDefaultAssignment },
  { key = 'u', mods = 'CTRL|SHIFT', action = act.DisableDefaultAssignment },
  { key = 'U', mods = 'CTRL|SHIFT', action = act.DisableDefaultAssignment },
  { key = 'x', mods = 'CTRL|SHIFT', action = act.DisableDefaultAssignment },
  { key = 'X', mods = 'CTRL|SHIFT', action = act.DisableDefaultAssignment },

  -- Atalhos com Ctrl+Espaço (para quem já se acostumou)
  { key = 'c', mods = 'LEADER', action = spawn_claude('tab') },
  { key = 'v', mods = 'LEADER', action = spawn_claude('split') },
  { key = 'o', mods = 'LEADER', action = open_folder_picker },
  { key = 'e', mods = 'LEADER', action = toggle_explorer },
  { key = '\\', mods = 'LEADER', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = '-',  mods = 'LEADER', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
  { key = 'x',  mods = 'LEADER', action = close_pane },
  { key = 'z',  mods = 'LEADER', action = act.TogglePaneZoomState },
  { key = 'LeftArrow',  mods = 'LEADER', action = act.ActivatePaneDirection 'Left' },
  { key = 'RightArrow', mods = 'LEADER', action = act.ActivatePaneDirection 'Right' },
  { key = 'UpArrow',    mods = 'LEADER', action = act.ActivatePaneDirection 'Up' },
  { key = 'DownArrow',  mods = 'LEADER', action = act.ActivatePaneDirection 'Down' },
  { key = 't', mods = 'LEADER', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'l', mods = 'LEADER', action = new_tab_with },
  { key = 'b', mods = 'LEADER', action = act.EmitEvent 'upfly-toggle-background' },
  { key = 'u', mods = 'LEADER', action = update_action },
  { key = 'k', mods = 'LEADER', action = connect_claude_action },
  -- Envia CTRL+Espaço de verdade ao apertar duas vezes
  { key = 'Space', mods = 'LEADER|CTRL', action = act.SendKey { key = 'Space', mods = 'CTRL' } },
}

if is_mac then
  -- No Mac, Cmd+C/Cmd+V já copiam e colam; Ctrl+C volta a interromper.
  config.keys[4] = { key = 'c', mods = 'CMD', action = act.CopyTo 'Clipboard' }
  config.keys[5] = { key = 'v', mods = 'CMD', action = act.PasteFrom 'Clipboard' }
end

-- Botão direito do mouse abre o menu (na barra lateral, ela tem o seu próprio)
config.mouse_bindings = {
  { event = { Down = { streak = 1, button = 'Right' } }, mods = 'NONE', action = show_menu },
  -- Ctrl+clique abre links
  { event = { Up = { streak = 1, button = 'Left' } }, mods = 'CTRL', action = act.OpenLinkAtMouseCursor },
}

return config
