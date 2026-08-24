-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 Exchange Walker Live contributors
-------------------------------------------------------------------------------
-- Exchange Walker Live for Mudlet
-- Version 3.0.0-live
--
-- Updated from Exchange Walker 2.0 for the Federation 2 public live server.
-- This add-on deliberately reuses the live-tested F2CE Tools planet-owner
-- capture/parser functions instead of registering competing output triggers.
--
-- Safety model:
--   * OFF is the default after loading.
--   * ON only enables capture; it sends no gameplay command by itself.
--   * `ew preview` gathers current exchange/production data and displays a plan.
--   * `ew apply` sends that exact plan once. It never retries commands.
--   * Plans expire after two minutes and are invalidated by room changes.
--   * Turning OFF cancels capture and any commands not yet sent.
--
-- Intended policy retained from version 2.0:
--   * Net production <= 0: target minimum and maximum stockpile are zero.
--   * Net production > 0 and stock < 10,000 tons: target minimum is current
--     stock and target maximum is 1,000 tons above current stock.
--   * Net production > 0 and stock >= 10,000 tons: leave settings unchanged.
-------------------------------------------------------------------------------

ExchangeWalkerLive = ExchangeWalkerLive or {}
local EW = ExchangeWalkerLive

EW.VERSION = "3.0.0-live"
EW.enabled = EW.enabled == true
EW.busy = false
EW.applying = false
EW.plan = nil
EW.plan_max_age_seconds = 120
EW.command_spacing_seconds = 0.20
EW.pending_confirmations = EW.pending_confirmations or {}

local function notice(color, message)
  cecho(string.format("\n<%s>[Exchange Walker]<reset> %s\n", color, message))
end

local function normalized(value)
  return string.lower(tostring(value or ""))
end

local function current_room_identity()
  local info = gmcp and gmcp.room and gmcp.room.info or nil
  if type(info) ~= "table" then
    return nil
  end

  return table.concat({
    tostring(info.id or ""),
    tostring(info.mapId or ""),
    tostring(info.system or ""),
    tostring(info.area or ""),
    tostring(info.num or ""),
  }, "|")
end

local function current_planet_name()
  local info = gmcp and gmcp.room and gmcp.room.info or nil
  if type(info) ~= "table" then
    return "Current planet"
  end
  return tostring(info.area or info.name or "Current planet")
end

local function ownership_is_confirmed()
  local info = gmcp and gmcp.room and gmcp.room.info or nil
  local vitals = gmcp and gmcp.char and gmcp.char.vitals or nil
  local owner = type(info) == "table" and info.owner or nil
  local player = type(vitals) == "table" and vitals.name or nil

  return type(owner) == "string" and owner ~= ""
    and type(player) == "string" and player ~= ""
    and normalized(owner) == normalized(player), owner, player
end

local function f2ce_tools_available()
  return type(f2t_po_capture_exchange) == "function"
    and type(f2t_po_capture_production) == "function"
    and type(f2t_po_reset) == "function"
end

local function cancel_timer(field)
  if EW[field] then
    killTimer(EW[field])
    EW[field] = nil
  end
end

local function update_button()
  if not EW.button then
    return
  end

  local enabled = EW.enabled
  local background = enabled and "#166534" or "#7f1d1d"
  local hover = enabled and "#15803d" or "#991b1b"
  EW.button:setStyleSheet(string.format([[
    QLabel {
      background-color: %s;
      color: white;
      border: 1px solid #d1d5db;
      border-radius: 4px;
      padding: 3px;
      font-weight: bold;
    }
    QLabel:hover { background-color: %s; }
  ]], background, hover))
  EW.button:echo(string.format(
    "<center>Exchange Walker: %s</center>", enabled and "ON" or "OFF"))
end

function exchange_walker_status()
  local state = EW.enabled and "ON" or "OFF"
  local activity = EW.applying and "applying"
    or (EW.busy and "capturing" or "idle")
  local plan = EW.plan and string.format(
    "%d pending setting change(s) for %s",
    #EW.plan.actions, EW.plan.planet) or "no preview plan"
  notice("cyan", string.format(
    "v%s is %s; %s; %s.", EW.VERSION, state, activity, plan))
end

function exchange_walker_on()
  EW.enabled = true
  update_button()
  notice("green", "ON. Use `ew preview` to inspect proposed changes.")
end

function exchange_walker_cancel(reason)
  local was_active = EW.busy or EW.applying
  cancel_timer("transition_timer")
  cancel_timer("apply_timer")

  if EW.busy and f2ce_tools_available() then
    f2t_po_reset()
  end

  EW.busy = false
  EW.applying = false
  EW.pending_confirmations = {}

  if was_active then
    notice("yellow", reason or
      "Cancelled. Some already-sent live commands may have completed; run a new preview.")
  end
end

function exchange_walker_off()
  exchange_walker_cancel(
    "OFF. Capture stopped and unsent commands cancelled. Run a new preview before the next apply.")
  EW.enabled = false
  EW.plan = nil
  update_button()
  notice("red", "OFF. No capture or stockpile commands will be started.")
end

function exchange_walker_toggle()
  if EW.enabled then
    exchange_walker_off()
  else
    exchange_walker_on()
  end
end

local function sorted_exchange_rows(exchange_data)
  local rows = {}
  for _, row in ipairs(exchange_data or {}) do
    if type(row) == "table" and type(row.name) == "string" then
      table.insert(rows, row)
    end
  end
  table.sort(rows, function(left, right)
    local left_net = tonumber(left.net) or 0
    local right_net = tonumber(right.net) or 0
    if left_net == right_net then
      return normalized(left.name) < normalized(right.name)
    end
    return left_net > right_net
  end)
  return rows
end

local function make_plan(exchange_data, production_data)
  local actions = {}
  local rows = {}

  for _, exchange in ipairs(sorted_exchange_rows(exchange_data)) do
    local production = production_data[exchange.name] or {}
    local produced = tonumber(production.production) or 0
    local consumed = tonumber(production.consumption) or 0
    local net = produced - consumed
    local current = tonumber(exchange.stock_current) or 0
    local old_min = tonumber(exchange.stock_min) or 0
    local old_max = tonumber(exchange.stock_max) or 0
    local target_min = old_min
    local target_max = old_max
    local policy = "unchanged"

    if net <= 0 then
      target_min = 0
      target_max = 0
      policy = "deficit/breakeven"
    elseif current < 10000 then
      target_min = math.max(0, math.floor(current))
      target_max = target_min + 1000
      policy = "surplus"
    else
      policy = "sufficient"
    end

    if target_min ~= old_min then
      table.insert(actions, {
        kind = "min", commodity = exchange.name, value = target_min,
        command = string.format("set stockpile min %d %s", target_min, exchange.name),
      })
    end
    if target_max ~= old_max then
      table.insert(actions, {
        kind = "max", commodity = exchange.name, value = target_max,
        command = string.format("set stockpile max %d %s", target_max, exchange.name),
      })
    end

    table.insert(rows, {
      commodity = exchange.name,
      production = produced,
      consumption = consumed,
      net = net,
      current = current,
      old_min = old_min,
      old_max = old_max,
      target_min = target_min,
      target_max = target_max,
      policy = policy,
    })
  end

  return {
    created_at = os.time(),
    room_identity = current_room_identity(),
    planet = current_planet_name(),
    rows = rows,
    actions = actions,
    applied = false,
  }
end

local function display_plan(plan)
  cecho(string.format(
    "\n<green>Exchange Walker live preview — %s<reset>\n", plan.planet))
  cecho("<cyan>-----------------------------------------------------------------------------------------------<reset>\n")
  cecho(string.format(
    "<cyan>|<reset> %-16s <cyan>|<reset> %6s <cyan>|<reset> %7s <cyan>|<reset> %7s <cyan>|<reset> %11s <cyan>|<reset> %11s <cyan>|<reset>\n",
    "Commodity", "Net", "Stock", "Policy", "Old min/max", "New min/max"))
  cecho("<cyan>|---------------------------------------------------------------------------------------------|<reset>\n")

  for _, row in ipairs(plan.rows) do
    local color = row.net > 0 and "green" or "red"
    cecho(string.format(
      "<cyan>|<reset> <yellow>%-16s<reset> <cyan>|<reset> <%s>%6d<reset> <cyan>|<reset> %7d <cyan>|<reset> %-7s <cyan>|<reset> %5d/%-5d <cyan>|<reset> %5d/%-5d <cyan>|<reset>\n",
      row.commodity, color, row.net, row.current, row.policy,
      row.old_min, row.old_max, row.target_min, row.target_max))
  end

  cecho("<cyan>-----------------------------------------------------------------------------------------------<reset>\n")
  if #plan.actions == 0 then
    notice("green", "Preview complete: no stockpile setting changes are needed.")
  else
    notice("yellow", string.format(
      "Preview complete: %d setting change(s). Review the table, then use `ew apply` within two minutes.",
      #plan.actions))
  end
end

local function preview_failed(message)
  EW.busy = false
  EW.plan = nil
  notice("red", message)
end

function fetch_and_process_data()
  if not EW.enabled then
    notice("red", "The walker is OFF. Click the toggle or use `ew on` first.")
    return
  end
  if EW.busy or EW.applying then
    notice("yellow", "A capture or apply operation is already in progress.")
    return
  end
  if not f2ce_tools_available() then
    notice("red", "F2CE Tools planet-owner capture functions are unavailable. Enable/update f2ce-tools first.")
    return
  end

  EW.plan = nil
  EW.busy = true
  notice("cyan", "Gathering current live exchange and production data...")

  local started = f2t_po_capture_exchange(nil, function(exchange_data)
    if not EW.enabled then
      preview_failed("Capture stopped because the walker was switched OFF.")
      return
    end
    if type(exchange_data) ~= "table" or #exchange_data == 0 then
      preview_failed("No live exchange rows were captured; no plan was created.")
      return
    end

    EW.transition_timer = tempTimer(0.15, function()
      EW.transition_timer = nil
      local production_started = f2t_po_capture_production(nil, function(production_data)
        EW.busy = false
        if not EW.enabled then
          EW.plan = nil
          notice("yellow", "Capture completed after the walker was switched OFF; results discarded.")
          return
        end
        if type(production_data) ~= "table" or next(production_data) == nil then
          preview_failed("No live production rows were captured; no plan was created.")
          return
        end

        EW.plan = make_plan(exchange_data, production_data)
        display_plan(EW.plan)
      end)

      if not production_started then
        preview_failed("Production capture could not start; no plan was created.")
      end
    end)
  end)

  if not started then
    preview_failed("Exchange capture could not start; another F2CE Tools capture may be active.")
  end
end

function exchange_walker_apply()
  if not EW.enabled then
    notice("red", "The walker is OFF; nothing was sent.")
    return
  end
  if EW.busy or EW.applying then
    notice("yellow", "A capture or apply operation is already in progress.")
    return
  end
  if not EW.plan then
    notice("red", "No preview plan exists. Run `ew preview` first.")
    return
  end
  if EW.plan.applied then
    notice("red", "This plan was already applied. Run a new preview; commands will not be replayed.")
    return
  end
  if os.time() - EW.plan.created_at > EW.plan_max_age_seconds then
    EW.plan = nil
    notice("red", "The preview expired. Run `ew preview` again before applying.")
    return
  end
  if EW.plan.room_identity ~= current_room_identity() then
    EW.plan = nil
    notice("red", "Your location changed after the preview. The plan was discarded.")
    return
  end

  local owned, owner, player = ownership_is_confirmed()
  if not owned then
    notice("red", string.format(
      "GMCP does not confirm that this planet belongs to the active character (owner=%s, player=%s). Nothing was sent.",
      tostring(owner or "unknown"), tostring(player or "unknown")))
    return
  end
  if #EW.plan.actions == 0 then
    notice("green", "The preview contains no changes; nothing was sent.")
    return
  end

  EW.plan.applied = true -- Mark before the first mutation: never replay this plan.
  EW.applying = true
  EW.pending_confirmations = {}
  local actions = EW.plan.actions

  local function send_next(index)
    if not EW.enabled then
      EW.applying = false
      notice("yellow", "Apply stopped because the walker was switched OFF. Run a new preview to reconcile partial changes.")
      return
    end
    local action = actions[index]
    if not action then
      EW.applying = false
      EW.apply_timer = nil
      notice("green", string.format(
        "All %d planned command(s) were sent once. Server confirmations remain visible below.",
        #actions))
      return
    end

    local key = normalized(action.commodity) .. ":" .. action.kind
    EW.pending_confirmations[key] = action.value
    send(action.command, false)
    EW.apply_timer = tempTimer(EW.command_spacing_seconds, function()
      EW.apply_timer = nil
      send_next(index + 1)
    end)
  end

  notice("yellow", string.format(
    "Applying %d reviewed setting change(s) to %s. Commands will not be retried.",
    #actions, EW.plan.planet))
  send_next(1)
end

local function confirmation(kind)
  local commodity = matches and matches[2] or nil
  local reported = matches and matches[3] or nil
  if not commodity or not reported then
    return
  end

  local key = normalized(commodity) .. ":" .. kind
  local expected = EW.pending_confirmations[key]
  if expected == nil then
    return
  end

  local numeric = tonumber((reported:gsub(",", "")))
  if numeric == expected then
    EW.pending_confirmations[key] = nil
    notice("green", string.format(
      "%s stockpile %s confirmed at %d tons.", commodity, kind, expected))
  else
    notice("red", string.format(
      "%s stockpile %s confirmation was %s, expected %d. Run a new preview.",
      commodity, kind, reported, expected))
  end
end

local function install_runtime_hooks()
  if EW.min_confirmation_trigger then
    killTrigger(EW.min_confirmation_trigger)
  end
  if EW.max_confirmation_trigger then
    killTrigger(EW.max_confirmation_trigger)
  end
  if EW.alias then
    killAlias(EW.alias)
  end

  EW.min_confirmation_trigger = tempRegexTrigger(
    [[^\s*Min stock level for (\w+) on .+ set to ([0-9][0-9,]*(?:\.[0-9]+)?) tons\.$]],
    function() confirmation("min") end)
  EW.max_confirmation_trigger = tempRegexTrigger(
    [[^\s*Max stock level for (\w+) on .+ set to ([0-9][0-9,]*(?:\.[0-9]+)?) tons\.$]],
    function() confirmation("max") end)

  EW.alias = tempAlias([[^ew(?:\s+(on|off|toggle|preview|apply|cancel|status|help))?\s*$]], function()
    local command = normalized(matches and matches[2] or "status")
    if command == "on" then exchange_walker_on()
    elseif command == "off" then exchange_walker_off()
    elseif command == "toggle" then exchange_walker_toggle()
    elseif command == "preview" then fetch_and_process_data()
    elseif command == "apply" then exchange_walker_apply()
    elseif command == "cancel" then exchange_walker_cancel()
    elseif command == "status" then exchange_walker_status()
    else
      cecho([[
<cyan>Exchange Walker Live commands<reset>
  <yellow>ew on<reset>       Enable capture/preview
  <yellow>ew off<reset>      Disable and cancel pending work
  <yellow>ew preview<reset>  Read current live exchange/production data
  <yellow>ew apply<reset>    Apply the latest unexpired preview once
  <yellow>ew cancel<reset>   Cancel capture or unsent commands
  <yellow>ew status<reset>   Show current state
]])
    end
  end)
end

local function create_toggle_button()
  if not Geyser or not Geyser.Label then
    notice("yellow", "Geyser is unavailable; use `ew on` and `ew off` instead of the button.")
    return
  end

  if not EW.button then
    EW.button = Geyser.Label:new({
      name = "ExchangeWalkerLiveToggle",
      x = "84%", y = 0,
      width = "16%", height = 28,
    })
    EW.button:setFontSize(9)
    EW.button:setClickCallback(function()
      exchange_walker_toggle()
    end)
    if EW.button.setToolTip then
      EW.button:setToolTip(
        "Enable or disable Exchange Walker capture. The button never applies stockpile changes.")
    end
  end

  update_button()
  EW.button:show()
end

install_runtime_hooks()
create_toggle_button()
update_button()

notice("cyan", string.format(
  "v%s loaded for the public live server; default is %s. Use `ew help`.",
  EW.VERSION, EW.enabled and "ON" or "OFF"))
