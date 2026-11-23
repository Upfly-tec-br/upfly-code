-- Testa config/wezterm.lua com um módulo "wezterm" simulado, para as
-- três plataformas. Uso: lua5.4 tests/config_test.lua <raiz do projeto>
local root = arg[1] or '.'
local failures = 0

local function check(cond, msg)
  if cond then
    print('  ok   ' .. msg)
  else
    print('  FALHA ' .. msg)
    failures = failures + 1
  end
end

-- Pasta temporária com projetos falsos (para "Abrir pasta")
local TMP = os.tmpname(); os.remove(TMP); os.execute('mkdir -p ' .. TMP .. '/Documents/GitHub/app-um '
  .. TMP .. '/Documents/GitHub/app-dois ' .. TMP .. '/projetos/site ' .. TMP .. '/install/state '
  .. TMP .. '/install/config')
do
  local f = io.open(TMP .. '/install/VERSION', 'w'); f:write('1.2.0\n'); f:close()
  f = io.open(TMP .. '/install/config/update-repo.txt', 'w'); f:write('upfly/upfly-code\n'); f:close()
end
local RELEASE_TAG = 'v1.3.0'

local function make_mock(triple, config_file, fake_files)
  local events = {}
  local act = setmetatable({}, {
    __index = function(_, name)
      return setmetatable({ _name = name }, {
        __call = function(self, a, b) return { action = name, args = a, b = b } end,
      })
    end,
  })
  local mock
  mock = {
    target_triple = triple,
    config_file = config_file,
    config_dir = root .. '/config',
    home_dir = TMP,
    action = act,
    config_builder = function() return {} end,
    on = function(name, fn) events[name] = fn end,
    action_callback = function(fn) return { callback = fn } end,
    format = function(t) return 'formatted' end,
    strftime = function(f) return '12:00' end,
    font = function(name) return { family = name } end,
    truncate_right = function(s, n) return s:sub(1, n) end,
    read_dir = function(p)
      p = p:gsub('\\', '/')
      local h = io.popen('ls -1A "' .. p .. '" 2>/dev/null && test -d "' .. p .. '" && echo __OK__')
      local out = h:read('a'); h:close()
      if not out:find('__OK__') then error('not a dir: ' .. p) end
      local list = {}
      for name in out:gmatch('[^\n]+') do
        if name ~= '__OK__' then table.insert(list, p .. '/' .. name) end
      end
      return list
    end,
    executable_dir = triple:find('windows') and 'C:\\Upfly\\terminal' or '/opt/wezterm',
    background_child_process = function(args) mock._bg = args end,
    run_child_process = function(args)
      local joined = table.concat(args, ' ')
      if joined:find('command -v claude', 1, true) or args[1] == 'where.exe' then
        return mock._claude_on_path or false, '', ''
      end
      if args[1]:find('curl') then
        mock._curl_url = args[#args]
        return true, '{"tag_name":"' .. RELEASE_TAG .. '","html_url":"https://github.com/upfly/upfly-code/releases/tag/'
          .. RELEASE_TAG .. '","body":"novidades"}', ''
      end
      return true, TMP .. '/projetos/site\n', ''
    end,
    json_parse = function(sx)
      return { tag_name = sx:match('"tag_name":"([^"]+)"'), html_url = sx:match('"html_url":"([^"]+)"'),
               body = sx:match('"body":"([^"]*)"') }
    end,
    GLOBAL = {},
    open_with = function(u) mock._opened = u end,
    time = { call_after = function(sec, fn) mock._timers = mock._timers or {}; table.insert(mock._timers, { sec, fn }) end },
    _events = events,
  }
  mock.mux = {
    all_windows = function() return mock._mux_windows or {} end,
    spawn_window = function(cmd)
      mock._startup_cmd = cmd
      local pane = mock._new_pane('/home')
      local tab = { set_title = function(_, t) mock._startup_title = t end }
      return tab, pane, { gui_window = function() return mock._gw end }
    end,
  }
  return mock
end

local function load_for(triple, label, opts)
  opts = opts or {}
  print(label .. ' (' .. triple .. ')')
  local win = triple:find('windows') ~= nil
  local mac = triple:find('apple') ~= nil
  local base = win and (TMP .. '\\install') or (TMP .. '/install')
  local sep = win and '\\' or '/'
  local cfg_path = base .. sep .. 'config' .. sep .. 'wezterm.lua'

  -- io.open simulado: arquivos "existentes" + sistema real com \ -> /
  local real_open = io.open
  local fake = opts.fake_files or {}
  io.open = function(p, m)
    if (m or 'r') == 'r' and fake[p] then
      return { close = function() end, lines = function() return function() return nil end end }
    end
    local q = p:gsub('\\', '/')
    -- arquivos da instalação vêm do projeto
    q = q:gsub('^' .. TMP:gsub('%p', '%%%0') .. '/install/branding', root .. '/branding')
    q = q:gsub('^' .. TMP:gsub('%p', '%%%0') .. '/install/tools/upfly%-files', root .. '/tools/upfly-files/main.go')
    return real_open(q, m)
  end

  local mock = make_mock(triple, cfg_path)
  local splits, spawned_tabs = {}, {}
  function mock._new_pane(cwd)
    local pane = {}
    pane.get_current_working_dir = function() return { file_path = cwd } end
    pane.split = function(self, spec) table.insert(splits, spec); return { activate = function() end } end
    pane.activate = function() end
    pane.get_foreground_process_name = function() return opts.proc or 'bash' end
    pane.get_title = function() return 'bash' end
    pane.tab = function() return { panes = function() return { pane } end } end
    return pane
  end
  package.loaded['wezterm'] = mock
  local chunk = assert(loadfile(root .. '/config/wezterm.lua'))
  local ok, config = pcall(chunk)
  check(ok, 'configuração carrega sem erro' .. (ok and '' or (': ' .. tostring(config))))
  if not ok then io.open = real_open return end

  check(type(config.default_prog) == 'table', 'default_prog definido')
  check(config.leader and config.leader.key == 'Space', 'LEADER = CTRL+Espaço')
  check(type(config.launch_menu) == 'table' and config.launch_menu[1].label == 'Claude Code',
    'menu de lançamento com Claude Code')
  check(config.colors.tab_bar.active_tab.bg_color == '#0080FF', 'cor da aba ativa = azul Upfly')
  local bg = config.background
  check(type(bg) == 'table' and bg[1].source.File:find('background.jpg', 1, true) ~= nil, 'fundo configurado')

  -- shell padrão
  if opts.expect_bash then
    check(config.default_prog[1] == opts.expect_bash, 'shell padrão é bash: ' .. tostring(config.default_prog[1]))
    check(config.default_prog[2]:find('upfly-shell.sh', 1, true), 'boas-vindas via upfly-shell.sh')
    if win then
      check(not config.default_prog[2]:find('\\', 1, true), 'caminho do script com / para o Git Bash')
      check(config.set_environment_variables.CLAUDE_CODE_GIT_BASH_PATH == opts.expect_bash,
        'Claude Code aponta para o Git Bash')
    end
    check(config.launch_menu[1].args[1] == opts.expect_bash, 'Claude Code roda no bash')
  else
    check(config.default_prog[1]:lower():find('powershell') ~= nil, 'sem Git Bash: cai para o PowerShell')
  end

  -- atalhos novos
  local function find_key(key, mods)
    for _, k in ipairs(config.keys) do if k.key == key and k.mods == mods then return k end end
  end
  check(find_key('o', 'CTRL|SHIFT') ~= nil, 'Ctrl+Shift+O abre pasta')
  check(find_key('e', 'CTRL|SHIFT') ~= nil, 'Ctrl+Shift+E mostra arquivos')
  check(find_key('u', 'LEADER') ~= nil, 'Ctrl+Espaço, U atualiza')

  local ev = mock._events
  for _, name in ipairs({ 'format-window-title', 'format-tab-title', 'update-status', 'bell',
                          'upfly-toggle-background', 'gui-startup' }) do
    check(type(ev[name]) == 'function', 'evento ' .. name)
  end
  check(ev['format-window-title']({ active_pane = { title = 'bash.exe' } }) == 'Upfly Code', 'título sem bash.exe')
  check(ev['format-window-title']({ active_pane = { title = 'MINGW64:/c/Users/dev' } }) == 'Upfly Code',
    'título sem MINGW64')
  check(ev['format-window-title']({ active_pane = { title = 'claude' } }) == 'Upfly Code — Claude Code',
    'título com Claude Code')
  check(ev['format-window-title']({ active_pane = { title = 'wezterm' } }) == 'Upfly Code', 'título nunca mostra "wezterm"')
  local tt = ev['format-tab-title']({ tab_title = '', active_pane = { title = 'wezterm',
    current_working_dir = { file_path = '/home/x/meu-projeto' } } }, {}, {}, {}, false, 30)
  check(tt == ' meu-projeto ', 'aba mostra a pasta, nunca "wezterm": ' .. tostring(tt))
  tt = ev['format-tab-title']({ tab_title = '', active_pane = { title = 'wezterm' } }, {}, {}, {}, false, 30)
  check(tt == ' Upfly Code ', 'aba sem pasta mostra "Upfly Code": ' .. tostring(tt))

  -- janela falsa
  local last_action, toast
  local window = {
    get_config_overrides = function() return nil end,
    set_config_overrides = function() end,
    leader_is_active = function() return false end,
    set_right_status = function() end,
    is_focused = function() return false end,
    toast_notification = function(_, t, m) toast = m end,
    perform_action = function(_, a) last_action = a end,
    mux_window = function()
      return { spawn_tab = function(_, spec)
        table.insert(spawned_tabs, spec)
        local tab = { set_title = function(_, t) spec._title = t end }
        return tab, mock._new_pane(spec.cwd), {}
      end }
    end,
  }
  local pane = mock._new_pane(TMP .. '/projetos/site')

  -- Abrir pasta: lista
  find_key('o', 'CTRL|SHIFT').action.callback(window, pane)
  check(last_action and last_action.action == 'InputSelector', 'Ctrl+Shift+O mostra o seletor de pastas')
  local choices = last_action.args.choices
  local labels = {}
  for _, c in ipairs(choices) do labels[#labels + 1] = c.label end
  local all = table.concat(labels, '|')
  check(choices[1].id == '__browse__', 'primeira opção: procurar pasta no computador')
  check(all:find('app-um', 1, true) and all:find('site', 1, true), 'lista projetos de Documents/GitHub e projetos')

  -- Abrir pasta: escolhe o projeto
  if not win then
    local sel = last_action.args.action.callback
    sel(window, pane, TMP .. '/Documents/GitHub/app-um', 'app-um')
    local spec = spawned_tabs[#spawned_tabs]
    check(spec and spec.cwd == TMP .. '/Documents/GitHub/app-um', 'abre nova aba na pasta escolhida')
    check(spec and spec._title == 'app-um', 'aba recebe o nome da pasta')
    local sp = splits[#splits]
    check(sp and sp.direction == 'Left' and sp.args[1]:find('upfly-files', 1, true), 'abre a barra lateral à esquerda')
    check(sp.set_environment_variables and sp.set_environment_variables.UPFLY_WEZTERM_CLI == '/opt/wezterm/wezterm',
      'barra lateral sabe falar com o terminal ao lado')
    -- recentes
    local f = real_open(TMP .. '/install/state/recent.txt', 'r')
    local rec = f and f:read('a') or ''
    if f then f:close() end
    check(rec:find('app-um', 1, true), 'pasta salva nos recentes')
    -- seletor nativo
    sel(window, pane, '__browse__', 'x')
    spec = spawned_tabs[#spawned_tabs]
    check(spec and spec.cwd == TMP .. '/projetos/site', 'seletor do sistema abre a pasta escolhida')
    -- pasta inexistente
    sel(window, pane, TMP .. '/nao-existe', 'x')
    check(toast and toast:find('não encontrada'), 'aviso para pasta inexistente')

    -- barra lateral: abre e fecha
    local n = #splits
    find_key('e', 'CTRL|SHIFT').action.callback(window, pane)
    check(#splits == n + 1, 'Ctrl+Shift+E abre a barra lateral')
    local explorer_pane = mock._new_pane('/x')
    explorer_pane.get_foreground_process_name = function() return '/install/tools/upfly-files' end
    local pane2 = mock._new_pane('/x')
    pane2.tab = function() return { panes = function() return { explorer_pane, pane2 } end } end
    find_key('e', 'CTRL|SHIFT').action.callback(window, pane2)
    check(last_action.action == 'CloseCurrentPane', 'Ctrl+Shift+E de novo fecha a barra lateral')

    -- iniciar com pasta (menu de contexto / upfly-code <pasta>)
    n = #splits
    ev['gui-startup']({ cwd = TMP .. '/projetos/site' })
    check(#splits == n + 1 and mock._startup_title == 'site', 'iniciar com pasta já abre a barra lateral')
    n = #splits
    ev['gui-startup']({ cwd = TMP })
    check(#splits == n, 'iniciar na pasta pessoal não abre barra lateral')
  end

  -- Menu em português (F1, Ctrl+Shift+P, botão direito)
  window.get_selection_text_for_pane = function() return '' end
  check(find_key('F1', 'NONE') ~= nil and find_key('p', 'CTRL|SHIFT') ~= nil, 'F1 e Ctrl+Shift+P abrem o menu')
  local rb = config.mouse_bindings and config.mouse_bindings[1]
  check(rb and rb.event.Down.button == 'Right' and rb.action == find_key('F1', 'NONE').action,
    'botão direito abre o menu')
  find_key('F1', 'NONE').action.callback(window, pane)
  local menu = last_action
  check(menu.action == 'InputSelector' and menu.args.title:find('o que você quer fazer', 1, true),
    'menu em português')
  local ids, mlabels = {}, {}
  for _, c in ipairs(menu.args.choices) do ids[c.id] = c; mlabels[#mlabels + 1] = c.label end
  check(ids.open and ids.files and ids['claude-side'] and ids.paste and ids['close-tab'] and ids.update,
    'menu tem abrir pasta, arquivos, Claude, colar, fechar e atualizar')
  check(not table.concat(mlabels, ' '):lower():find('wezterm'), 'menu nunca fala em "wezterm"')
  check(menu.args.fuzzy == true, 'menu aceita digitar para procurar')
  menu.args.action.callback(window, pane, 'paste')
  check(last_action.action == 'PasteFrom', 'menu: Colar')
  window.get_selection_text_for_pane = function() return 'texto' end
  find_key('F1', 'NONE').action.callback(window, pane)
  check(last_action.args.choices[1].id == 'copy', 'com texto selecionado, "Copiar" vem primeiro')
  -- Ctrl+C copia com seleção e interrompe sem seleção
  local acts = {}
  local cw = setmetatable({ perform_action = function(_, a) table.insert(acts, a) end }, { __index = window })
  local ck = find_key(mac and 'c' or 'c', mac and 'CMD' or 'CTRL')
  check(ck ~= nil, 'atalho de copiar')
  if not mac then
    ck.action.callback(cw, pane)
    check(acts[1] and acts[1].action == 'CopyTo', 'Ctrl+C com seleção copia')
    acts = {}
    cw.get_selection_text_for_pane = function() return '' end
    ck.action.callback(cw, pane)
    check(acts[1] and acts[1].action == 'SendKey', 'Ctrl+C sem seleção interrompe o programa')
  end
  window.get_selection_text_for_pane = function() return '' end
  -- Fechar aba: aviso em português só com programa rodando
  check(config.window_close_confirmation == 'NeverPrompt', 'sem o aviso em inglês do motor')
  find_key('w', 'CTRL|SHIFT').action.callback(window, pane)
  check(last_action.action == 'CloseCurrentTab', 'Ctrl+Shift+W fecha direto quando só há o shell')
  local busy = mock._new_pane('/x')
  busy.get_foreground_process_name = function() return '/home/x/.local/bin/claude' end
  find_key('w', 'CTRL|SHIFT').action.callback(window, busy)
  check(last_action.action == 'InputSelector' and last_action.args.title == 'Fechar esta aba?'
    and last_action.args.description:find('Claude Code', 1, true), 'com o Claude rodando, pergunta em português')
  -- Telas do motor em inglês desligadas
  check(find_key('l', 'CTRL|SHIFT') and find_key('l', 'CTRL|SHIFT').action.action == nil
    and find_key('l', 'CTRL|SHIFT').action._name == 'DisableDefaultAssignment', 'tela de depuração (inglês) desligada')
  -- Nova aba com...
  find_key('l', 'LEADER').action.callback(window, pane)
  check(last_action.action == 'InputSelector' and last_action.args.title == 'Abrir nova aba com…',
    'lançador em português')

  -- Atualizações
  mock._timers = {}
  ev['gui-startup']({})
  local upd_timer
  for _, t in ipairs(mock._timers) do if t[1] == 8 then upd_timer = t end end
  check(upd_timer ~= nil, 'verifica atualização 8 s após abrir')
  if win then
    check(mock._bg == nil, 'helper da barra de tarefas só roda quando instalado')
  end
  local prompts = {}
  local gw = setmetatable({
    active_pane = function() return pane end,
    perform_action = function(_, a) last_action = a; table.insert(prompts, a) end,
  }, { __index = window })
  mock._mux_windows = { { gui_window = function() return gw end } }
  mock._gw = gw
  local n0 = #mock._timers
  upd_timer[2]()
  check(mock._curl_url == 'https://api.github.com/repos/upfly/upfly-code/releases/latest', 'consulta a release no GitHub')
  check(mock.GLOBAL.upfly_update and mock.GLOBAL.upfly_update.version == '1.3.0', 'detecta versão nova 1.3.0 > 1.2.0')
  check(#mock._timers == n0 + 1 and mock._timers[#mock._timers][1] == 6 * 3600, 'agenda nova verificação em 6 h')
  local pr = prompts[#prompts]
  check(pr and pr.action == 'InputSelector' and pr.args.title == 'Atualização do Upfly Code', 'mostra o aviso com botões')
  check(pr.args.choices[1].id == 'now' and pr.args.choices[1].label:find('Atualizar agora'), 'botão "Atualizar agora"')
  pr.args.action.callback(gw, pane, 'now')
  local sp = prompts[#prompts]
  local script = sp.args and sp.args.args and sp.args.args[#sp.args.args] or ''
  check(sp.action == 'SpawnCommandInNewTab' and script:find('self-update', 1, true), 'Atualizar agora roda o atualizador')
  pr.args.action.callback(gw, pane, 'notes')
  check(mock._opened and mock._opened:find('releases/tag/v1.3.0', 1, true), 'Ver o que mudou abre a release')
  local n = #prompts
  mock._timers[#mock._timers][2]()
  check(#prompts == n, 'não repete o aviso da mesma versão')
  -- selo na barra
  local status
  local sw = setmetatable({ set_right_status = function(_, x) status = x end }, { __index = window })
  ev['update-status'](sw, pane)
  check(status ~= nil, 'barra superior mostra o selo de atualização')
  -- sem versão nova
  n = #prompts
  find_key('u', 'LEADER').action.callback(gw, pane)
  check(#prompts == n + 1 and prompts[#prompts].action == 'InputSelector', 'Ctrl+Espaço, U reabre o aviso pendente')
  RELEASE_TAG = 'v1.2.0'
  mock.GLOBAL.upfly_update = nil
  find_key('u', 'LEADER').action.callback(gw, pane)
  check(mock.GLOBAL.upfly_update == nil and toast and toast:find('mais recente'), 'Ctrl+Espaço, U: já está atualizado')
  RELEASE_TAG = 'v1.3.0'

  -- Conexão com o Claude
  local home = TMP
  local function claude_timer()
    mock._timers = {}
    ev['gui-startup']({})
    for _, t in ipairs(mock._timers) do if t[1] == 1.5 then return t end end
  end
  mock._claude_on_path = false
  os.execute('rm -rf "' .. home .. '/.claude" "' .. home .. '/.claude.json" "' .. home .. '/.local"')
  n = #prompts
  local ct = claude_timer()
  check(ct ~= nil, 'verifica o Claude ao abrir')
  ct[2]()
  local cp = prompts[#prompts]
  check(#prompts == n + 1 and cp.args.title == 'Conectar o Upfly Code ao Claude' and cp.args.choices[1].id == 'install',
    'sem Claude: oferece instalar e entrar')
  check(mock.GLOBAL.upfly_claude == 'missing', 'selo "Conectar Claude" na barra')
  cp.args.action.callback(gw, pane, 'install')
  local ia = prompts[#prompts]
  local cmdline = table.concat(ia.args.args, ' ')
  check(ia.action == 'SpawnCommandInNewTab' and cmdline:find('claude.ai/install', 1, true), 'instala pelo instalador oficial')
  mock._claude_on_path = true
  n = #prompts
  claude_timer()[2]()
  cp = prompts[#prompts]
  check(#prompts == n + 1 and cp.args.choices[1].id == 'login', 'instalado sem conta: oferece entrar')
  cp.args.action.callback(gw, pane, 'login')
  check(prompts[#prompts].action == 'SpawnCommandInNewTab', 'entrar abre o Claude Code (login no navegador)')
  os.execute('mkdir -p "' .. home .. '/.claude" && echo {} > "' .. home .. '/.claude/.credentials.json"')
  n = #prompts
  claude_timer()[2]()
  check(#prompts == n and mock.GLOBAL.upfly_claude == 'ok', 'conectado: não pergunta nada')
  os.execute('rm -rf "' .. home .. '/.claude"')
  n = #prompts
  claude_timer()[2]()
  cp = prompts[#prompts]
  cp.args.action.callback(gw, pane, 'never')
  n = #prompts
  claude_timer()[2]()
  check(#prompts == n, '"Não perguntar de novo" é respeitado')
  os.remove(TMP .. '/install/state/nao-perguntar-claude')

  io.open = real_open
end

load_for('x86_64-unknown-linux-gnu', 'Linux', { expect_bash = '/bin/bash',
  fake_files = { ['/usr/bin/zenity'] = true } })
load_for('aarch64-apple-darwin', 'macOS', { expect_bash = '/bin/bash' })
load_for('x86_64-pc-windows-msvc', 'Windows com Git', {
  expect_bash = 'C:\\Program Files\\Git\\bin\\bash.exe',
  fake_files = { ['C:\\Program Files\\Git\\bin\\bash.exe'] = true },
})
load_for('x86_64-pc-windows-msvc', 'Windows sem Git', {})

os.execute('rm -rf ' .. TMP)
if failures > 0 then
  print(failures .. ' falha(s)')
  os.exit(1)
end
print('Configuração OK')
