-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 Exchange Walker Live contributors
-- Offline behavioral checks for Exchange Walker Live 3.1.4.
-- Run: lua5.1 exchange-walker-live-test.lua f2ce-api.lua exchange-walker-live.lua

local adapter_source = assert(arg[1], "path to f2ce-api.lua is required")
local runtime_source = assert(arg[2], "path to exchange-walker-live.lua is required")
local passed, failed = 0, 0

local function check(condition, message)
  if condition then passed = passed + 1 return end
  failed = failed + 1
  io.stderr:write("FAIL: " .. tostring(message) .. "\n")
end

local sent = {}
local timers, timer_order = {}, {}
local triggers, aliases, handlers = {}, {}, {}
local next_id = 0

local function new_id()
  next_id = next_id + 1
  return next_id
end

function cecho(_) end
function send(command, _echo) sent[#sent + 1] = command end
function tempTimer(delay, callback)
  local id = new_id()
  timers[id] = { delay = delay, callback = callback, active = true }
  timer_order[#timer_order + 1] = id
  return id
end
function killTimer(id) if timers[id] then timers[id].active = false end end
local function run_next_timer()
  while #timer_order > 0 do
    local id = table.remove(timer_order, 1)
    local timer = timers[id]
    if timer and timer.active then
      timer.active = false
      timer.callback()
      return true
    end
  end
  return false
end

function tempRegexTrigger(pattern, callback)
  local id = new_id()
  triggers[id] = { pattern = pattern, callback = callback, active = true }
  return id
end
function killTrigger(id) if triggers[id] then triggers[id].active = false end end
function tempAlias(pattern, callback)
  local id = new_id()
  aliases[id] = { pattern = pattern, callback = callback, active = true }
  return id
end
function killAlias(id) if aliases[id] then aliases[id].active = false end end
function registerAnonymousEventHandler(name, callback)
  local id = new_id()
  handlers[id] = { name = name, callback = callback, active = true }
  return id
end
function killAnonymousEventHandler(id) if handlers[id] then handlers[id].active = false end end
local function raise_event(name)
  for _, handler in pairs(handlers) do
    if handler.active and handler.name == name then handler.callback() end
  end
end

local function new_widget()
  local widget = { lines = {}, visible = false, deleted = false }
  function widget:setStyleSheet(value) self.style = value end
  function widget:setClickCallback(callback) self.callback = callback end
  function widget:setToolTip(value) self.tooltip = value end
  function widget:echo(value) self.text = value end
  function widget:cecho(value) self.lines[#self.lines + 1] = value end
  function widget:show() self.visible = true end
  function widget:hide() self.visible = false end
  function widget:delete() self.deleted = true end
  function widget:setColor(...) self.color = { ... } end
  function widget:enableAutoWrap() self.auto_wrap = true end
  function widget:clear() self.lines = {} end
  return widget
end

Geyser = {
  Label = { new = function(_, _parent) return new_widget() end },
  MiniConsole = { new = function(_, _parent) return new_widget() end },
}

local mux_content = {}
local pane = {
  id = "pane_2", name = "LeftTop", _activeTabId = "who",
  _tabs = {
    { id = "who", name = "Who", _activeContent = "fed2_who" },
    { id = "exchange", name = "Exchange", _activeContent = "fed2_exchange" },
  },
  _hiddenTabs = {},
}
function pane:addTab(name, _position)
  local target = {
    id = "tab_" .. tostring(#self._tabs + 1), name = name, pane = self,
    content = {}, contentBg = new_widget(),
  }
  self._tabs[#self._tabs + 1] = target
  self._activeTabId = target.id -- model Mux addTab selecting the new tab internally
  return target
end
function pane:activateTab(id) self._activeTabId = id end

Mux = {}
function Mux.registerContent(content_id, definition) mux_content[content_id] = definition end
function Mux.getPane(id) if id == "pane_2" then return pane end end
function Mux._applyContent(target, content_id, _force)
  target._activeContent = content_id
  mux_content[content_id].apply(target)
end

F2T_VERSION = "3.2.5"
gmcp = {
  room = { info = {
    id = "location:1:2", mapId = 1, system = "Serenity",
    area = "Holland", num = 2, owner = "Ersella",
  } },
  char = { vitals = { name = "Ersella" } },
}

local exchange_rows = {
  { name = "Alloys", stock_current = 500, stock_min = 100,
    stock_max = 900, spread = 20, net = 15 },
  { name = "Meats", stock_current = 0, stock_min = 100,
    stock_max = 200, spread = 20, net = -1 },
  { name = "Clinics", stock_current = 200, stock_min = 0,
    stock_max = 0, spread = 6, net = 0 },
  { name = "Gold", stock_current = 10000, stock_min = 100,
    stock_max = 900, spread = 20, net = 50 },
  { name = "NanoFabrics", stock_current = -225, stock_min = 0,
    stock_max = 800, spread = 20, net = -5 },
}
exchange_rows._expected_count = 5
local use_raw_exchange = false
local raw_exchange_buffer = {
  "Alloys: value 151ig/ton Spread: 20% Stock: current 500/min 100/max 900",
  "Efficiency: 267% Net: 15",
  "Meats: value 300ig/ton Spread: 20% Stock: current 0/min 100/max 200 Efficiency: 187%",
  " Net: -1",
  "Clinics: value 500ig/ton Spread: 6% Stock: current 200/min 0/max 0 Efficiency: 100% Net: 0",
  "Gold: value 900ig/ton Spread: 20% Stock: current 10000/min 100/max 900 Efficiency:",
  " 262% Net: 50",
  "NanoFabrics: value 700ig/ton Spread: 20% Stock: current -225/min 0/max 800 Efficiency: 100%",
  " Net: -5",
}
local production_rows = {
  Alloys = { production = 20, consumption = 5 },
  Meats = { production = 2, consumption = 3 },
  Clinics = { production = 4, consumption = 4 },
  Gold = { production = 60, consumption = 10 },
  NanoFabrics = { production = 1, consumption = 6 },
}

f2t_po = { phase = "idle", callback = nil }
local reset_calls = 0
function f2t_po_reset()
  reset_calls = reset_calls + 1
  f2t_po.phase, f2t_po.callback = "idle", nil
end
function f2t_po_parse_exchange_buffer(_buffer)
  return {} -- Reproduces the incomplete F2CE 3.2.5 wrapped-line parser.
end
local original_exchange_parser = f2t_po_parse_exchange_buffer
function f2t_po_capture_exchange(_, callback)
  if f2t_po.phase ~= "idle" then return false end
  send("display exchange", false)
  f2t_po.phase, f2t_po.callback = "capturing_exchange", callback
  f2t_po_reset()
  local data = exchange_rows
  if use_raw_exchange then
    line = "5 commodities, 2 deficits, 3 surpluses"
    data = f2t_po_parse_exchange_buffer(raw_exchange_buffer)
  end
  callback(data)
  return true
end
function f2t_po_capture_production(_, callback)
  if f2t_po.phase ~= "idle" then return false end
  send("display production", false)
  f2t_po.phase, f2t_po.callback = "capturing_production", callback
  f2t_po_reset()
  callback(production_rows)
  return true
end

ExchangeWalkerLive = {}
dofile(adapter_source)
dofile(runtime_source)
local EW = ExchangeWalkerLive

check(EW.VERSION == "3.1.4-live", "version must be 3.1.4-live")
check(EW.enabled == false, "fresh load must default OFF")
check(#sent == 0, "loading must send no gameplay command")
check(type(EW.public) == "table" and EW.public.contract == "ExchangeWalkerLive/1.0",
  "public API contract must be available")
check(rawget(_G, "FedHaulerLive") == nil, "standalone runtime must not require FedHaulerLive")
check(type(mux_content.exchange_walker_live) == "table", "Mux content must register")
check(pane._tabs[3] and pane._tabs[3].name == "Stockpiles",
  "installation must automatically place the Stockpiles tab")
local stockpile_tab = pane._tabs[3]
check(type(EW.ui.instances[stockpile_tab]) == "table"
    and stockpile_tab._activeContent == "exchange_walker_live",
  "automatic placement must build the Stockpiles display")
check(pane._activeTabId == "who",
  "automatic placement must restore the previously active F2CE tab")
check(EW.ui.mount(false, false) == true and #pane._tabs == 3
    and pane._activeTabId == "who",
  "idempotent background mount must not duplicate or activate the tab")

EW.preview()
EW.apply()
check(#sent == 0, "preview/apply while OFF must send nothing")

local saved_version = F2T_VERSION
F2T_VERSION = "3.1.9"
check(EW.on() == false and EW.enabled == false, "stale F2CE must fail closed")
F2T_VERSION = saved_version
check(EW.on() == true and EW.enabled == true, "validated F2CE must arm")
check(#sent == 0, "arming must send nothing")
use_raw_exchange = true
EW.preview()
check(f2t_po_parse_exchange_buffer == original_exchange_parser,
  "Exchange Walker must restore the original F2CE parser after capture")
run_next_timer()
check(EW.plan ~= nil and #EW.plan.rows == 5,
  "mixed one-line and wrapped exchange rows must produce a complete plan")
check(EW.plan.rows[5].commodity == "NanoFabrics" and EW.plan.rows[5].current == -225,
  "mixed-wrap parser must preserve a real negative stock deficit")
use_raw_exchange = false

local saved_alloys = production_rows.Alloys
production_rows.Alloys = nil
EW.preview()
run_next_timer()
check(EW.plan == nil, "missing production row must reject the preview")
check(sent[#sent - 1] == "display exchange" and sent[#sent] == "display production",
  "failed preview may send only the two F2CE display commands")
production_rows.Alloys = saved_alloys

production_rows.Orphan = { production = 1, consumption = 0 }
EW.preview()
run_next_timer()
check(EW.plan == nil, "production commodity missing from exchange must reject the preview")
production_rows.Orphan = nil

exchange_rows._expected_count = 67
EW.preview()
run_next_timer()
check(EW.plan == nil, "parsed row count below the exchange summary must reject the preview")
check(#sent >= 2 and sent[#sent - 1] == "display exchange" and sent[#sent] == "display production",
  "partial-capture rejection may send only the two read-only display commands")
exchange_rows._expected_count = 5

local saved_spread = exchange_rows[1].spread
exchange_rows[1].spread = 5
EW.preview()
run_next_timer()
check(EW.plan == nil, "invalid exchange spread must reject the preview")
exchange_rows[1].spread = saved_spread

local saved_minimum = exchange_rows[1].stock_min
exchange_rows[1].stock_min = -1
EW.preview()
run_next_timer()
check(EW.plan == nil, "negative configured minimum must reject the preview")
exchange_rows[1].stock_min = saved_minimum

EW.preview()
check(sent[#sent] == "display exchange", "preview must start with display exchange")
run_next_timer()
check(sent[#sent] == "display production", "preview must follow with display production")
check(EW.plan ~= nil and #EW.plan.rows == 5, "complete capture must create a five-row plan")
check(#EW.plan.actions == 11, "policy fixture must create eleven exact changes")
check(EW.plan.rows[1].commodity == "Gold", "rows must sort by recomputed net production")
check(EW.plan.rows[1].target_min == 10000 and EW.plan.rows[1].target_max == 20000,
  "stock at 10000 must target 10000/20000")
check(EW.plan.rows[1].target_spread == 40, "positive producer must target 40 percent spread")
check(EW.plan.rows[5].commodity == "NanoFabrics" and EW.plan.rows[5].current == -225,
  "negative current stock deficit must remain valid live data")
check(EW.plan.rows[5].target_min == 0 and EW.plan.rows[5].target_max == 0,
  "negative-stock deficit producer must target zero limits")
check(EW.plan.rows[5].target_spread == 6, "negative producer must target 6 percent spread")
check(pane._activeTabId == "who", "preview must preserve the active F2CE tab")
EW.ui.show()
check(pane._activeTabId == pane._tabs[3].id, "explicit display must reveal the Stockpiles tab")

local action_start = #sent + 1
check(EW.apply() == true and EW.applying == true, "explicit apply must start")
check(#sent == action_start, "apply must initially send exactly one mutation")
check(sent[action_start] == "set stockpile min 10000 Gold", "reserve minimum command must be first")

local function confirmation_callback(kind)
  for _, trigger in pairs(triggers) do
    if trigger.active then
      if kind == "min" and trigger.pattern:find("Min stock") then return trigger.callback end
      if kind == "max" and trigger.pattern:find("Max stock") then return trigger.callback end
      if kind == "spread" and trigger.pattern:find("Price spread") then return trigger.callback end
    end
  end
end

while EW.applying do
  local pending = EW.pending_confirmation
  check(type(pending) == "table", "every dispatched mutation must await confirmation")
  if not pending then break end
  matches = { "confirmation", pending.action.commodity, tostring(pending.value) }
  confirmation_callback(pending.action.kind)()
  run_next_timer()
end

local expected_actions = {
  "set stockpile min 10000 Gold", "set stockpile max 20000 Gold", "set spread 40 Gold",
  "set stockpile min 500 Alloys", "set stockpile max 1500 Alloys", "set spread 40 Alloys",
  "set stockpile min 0 Meats", "set stockpile max 0 Meats", "set spread 6 Meats",
}
for index, expected in ipairs(expected_actions) do
  check(sent[action_start + index - 1] == expected, "unexpected action order at " .. tostring(index))
end
check(EW.applying == false, "apply must finish after all confirmations")
check(EW.plan.applied == true, "applied plan must be single-use")
local sent_after_apply = #sent
EW.apply()
check(#sent == sent_after_apply, "applied plan must never replay")

EW.preview()
run_next_timer()
local mismatch_start = #sent
EW.apply()
local pending = EW.pending_confirmation
matches = { "confirmation", pending.action.commodity, tostring(pending.value + 1) }
confirmation_callback(pending.action.kind)()
check(EW.applying == false, "mismatched acknowledgement must stop apply")
check(#sent == mismatch_start + 1, "mismatch must prevent later mutation commands")

EW.on()
raise_event("sysConnectionEvent")
check(EW.enabled == false and EW.plan == nil, "reconnect must reset OFF and clear the plan")

EW.on()
local old_trigger_ids = {}
for _, id in ipairs(EW.runtime.trigger_ids) do old_trigger_ids[#old_trigger_ids + 1] = id end
EW.shutdown()
for _, id in ipairs(old_trigger_ids) do
  check(triggers[id].active == false, "shutdown must remove old trigger " .. tostring(id))
end
ExchangeWalkerLive = {}
dofile(adapter_source)
dofile(runtime_source)
EW = ExchangeWalkerLive
check(EW.enabled == false, "reload must return to OFF")
local active_trigger_count = 0
for _, trigger in pairs(triggers) do if trigger.active then active_trigger_count = active_trigger_count + 1 end end
check(active_trigger_count == 3, "reload must leave exactly three active confirmation triggers")
check(#pane._tabs == 3, "reload must not duplicate the Stockpiles Mux tab")
check(type(EW.ui.instances[stockpile_tab]) == "table", "reload must rebuild saved Mux content")
check(EW.ui.show() == true and pane._activeTabId == stockpile_tab.id,
  "saved Content Library placement must remain usable after reload")
check(EW.public.capabilities().capture.available == true, "API capability report must expose capture")

print(string.format("RESULT %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
