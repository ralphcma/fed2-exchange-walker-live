-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 Exchange Walker Live contributors
-- Offline behavioral checks for exchange-walker-live.lua.
-- Run with: lua5.1 exchange-walker-live-test.lua exchange-walker-live.lua

local source = assert(arg[1], "path to exchange-walker-live.lua is required")
local sent = {}
local timers = {}
local next_id = 0

function cecho(_) end
function send(command, _echo)
  table.insert(sent, command)
end
function killTimer(_) end
function killTrigger(_) end
function killAlias(_) end
function tempRegexTrigger(_, _callback)
  next_id = next_id + 1
  return next_id
end
function tempAlias(_, _callback)
  next_id = next_id + 1
  return next_id
end
function tempTimer(_, callback)
  next_id = next_id + 1
  table.insert(timers, callback)
  return next_id
end

local function drain_timers()
  while #timers > 0 do
    local callback = table.remove(timers, 1)
    callback()
  end
end

local button = {}
function button:setFontSize(_) end
function button:setClickCallback(callback) self.callback = callback end
function button:setToolTip(_) end
function button:setStyleSheet(_) end
function button:echo(_) end
function button:show() self.visible = true end
Geyser = {Label = {new = function(_) return button end}}

gmcp = {
  room = {info = {
    id = "location:1:2", mapId = 1, system = "Serenity",
    area = "Holland", num = 2, owner = "Ersella",
  }},
  char = {vitals = {name = "Ersella"}},
}

local exchange_rows = {
  {name = "Alloys", stock_current = 500, stock_min = 100,
   stock_max = 900, net = 15},
  {name = "Meats", stock_current = 0, stock_min = 100,
   stock_max = 200, net = -1},
  {name = "Clinics", stock_current = 200, stock_min = 0,
   stock_max = 0, net = 0},
  {name = "Gold", stock_current = 10000, stock_min = 100,
   stock_max = 900, net = 50},
}
local production_rows = {
  Alloys = {production = 20, consumption = 5},
  Meats = {production = 2, consumption = 3},
  Clinics = {production = 4, consumption = 4},
  Gold = {production = 60, consumption = 10},
}

function f2t_po_capture_exchange(_, callback)
  callback(exchange_rows)
  return true
end
function f2t_po_capture_production(_, callback)
  callback(production_rows)
  return true
end
function f2t_po_reset() end

dofile(source)
assert(ExchangeWalkerLive.enabled == false, "walker must load OFF")
assert(button.visible == true, "toggle button must be visible")

exchange_walker_on()
assert(ExchangeWalkerLive.enabled == true, "walker must enable")
assert(#sent == 0, "enabling must not send commands")

fetch_and_process_data()
drain_timers()
assert(#sent == 0, "preview must not send commands")
assert(ExchangeWalkerLive.plan ~= nil, "preview must create a plan")
assert(#ExchangeWalkerLive.plan.actions == 4,
       "expected two Alloys and two Meats changes")

exchange_walker_apply()
drain_timers()
assert(#sent == 4, "apply must send each planned change once")
assert(sent[1] == "set stockpile min 500 Alloys")
assert(sent[2] == "set stockpile max 1500 Alloys")
assert(sent[3] == "set stockpile min 0 Meats")
assert(sent[4] == "set stockpile max 0 Meats")

exchange_walker_apply()
drain_timers()
assert(#sent == 4, "an applied plan must never replay")

exchange_walker_off()
assert(ExchangeWalkerLive.enabled == false, "walker must disable")
assert(ExchangeWalkerLive.plan == nil, "OFF must clear the plan")

print("Exchange Walker Live offline checks passed")
