-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 Exchange Walker Live contributors
-------------------------------------------------------------------------------
-- Exchange Walker Live for Mudlet
-- Version 3.1.0-live
--
-- Current-planet owner stockpile planner. Capture and workspace integration
-- are delegated through f2ce-api.lua so future F2CE changes stay isolated.
-- Loading and reconnecting always return to OFF. Preview sends only the F2CE
-- display commands; apply is a separate explicit action and advances only after
-- each expected server acknowledgement.
-------------------------------------------------------------------------------

local EW = rawget(_G, "ExchangeWalkerLive")
if type(EW) ~= "table" then return end
if type(EW.f2ce) ~= "table" then
  if type(cecho) == "function" then
    cecho("\n<red>[Exchange Walker]<reset> F2CE compatibility adapter did not load; remaining OFF.\n")
  end
  return
end

EW.VERSION = "3.1.0-live"
EW.API_CONTRACT = "ExchangeWalkerLive/1.0"
EW.MIN_F2CE_VERSION = "3.2.5"
EW.enabled = false
EW.busy = false
EW.applying = false
EW.plan = nil
EW.plan_max_age_seconds = 120
EW.command_spacing_seconds = 0.20
EW.confirmation_timeout_seconds = 6
EW.pending_confirmation = nil
EW.apply_index = nil
EW.runtime = { trigger_ids = {}, handler_ids = {}, alias_id = nil }
EW.events = { subscribers = {}, next_id = 0 }
EW.ui = {
  content_id = "exchange_walker_live",
  preferred_pane_id = "pane_2",
  preferred_pane_name = "LeftTop",
  preferred_tab_name = "Stockpiles",
  registered = false,
  registered_target = nil,
  instances = {},
  instance_counter = 0,
  history = {},
  history_limit = 600,
  shutting_down = false,
}

local function normalized(value)
  return string.lower(tostring(value or ""))
end

local function finite_number(value)
  local number = tonumber(value)
  if number == nil or number ~= number or number == math.huge or number == -math.huge then
    return nil
  end
  return number
end

local function current_room_identity()
  local data = rawget(_G, "gmcp")
  local info = type(data) == "table" and type(data.room) == "table" and data.room.info or nil
  if type(info) ~= "table" then return nil end
  return table.concat({
    tostring(info.id or ""), tostring(info.mapId or ""),
    tostring(info.system or ""), tostring(info.area or ""),
    tostring(info.num or ""),
  }, "|")
end

local function current_planet_name()
  local data = rawget(_G, "gmcp")
  local info = type(data) == "table" and type(data.room) == "table" and data.room.info or nil
  if type(info) ~= "table" then return "Current planet" end
  return tostring(info.area or info.name or "Current planet")
end

local function emit(event_name, payload)
  local listeners = EW.events.subscribers[event_name]
  if type(listeners) ~= "table" then return end
  for _, callback in pairs(listeners) do pcall(callback, payload or {}) end
end

local function main_notice(color, message)
  if type(cecho) == "function" then
    cecho(string.format("\n<%s>[Exchange Walker]<reset> %s\n", color, message))
  end
end

local function console_write(console, markup)
  if type(console) ~= "table" then return false end
  if type(console.cecho) == "function" then return pcall(console.cecho, console, markup .. "\n") end
  if type(console.echo) == "function" then
    local plain = tostring(markup):gsub("<[^>]+>", "")
    return pcall(console.echo, console, plain .. "\n")
  end
  return false
end

function EW.ui.append(markup)
  markup = tostring(markup or "")
  EW.ui.history[#EW.ui.history + 1] = markup
  while #EW.ui.history > EW.ui.history_limit do table.remove(EW.ui.history, 1) end
  local routed = false
  for _, instance in pairs(EW.ui.instances) do
    routed = console_write(instance.console, markup) or routed
  end
  return routed
end

function EW.ui.clear()
  EW.ui.history = {}
  for _, instance in pairs(EW.ui.instances) do
    if instance.console and type(instance.console.clear) == "function" then
      pcall(instance.console.clear, instance.console)
    end
  end
end

function EW.ui.replace(lines)
  EW.ui.clear()
  local routed = false
  for _, line_text in ipairs(lines or {}) do routed = EW.ui.append(line_text) or routed end
  if not routed and type(cecho) == "function" then
    cecho("\n" .. table.concat(lines or {}, "\n") .. "\n")
  end
  return routed
end

local function notice(color, message)
  local markup = string.format("<%s>[Exchange Walker]<reset> %s", color, message)
  local routed = EW.ui.append(markup)
  if not routed or color == "red" or color == "yellow" then main_notice(color, message) end
end

local function cancel_timer(field)
  if EW[field] then
    if type(killTimer) == "function" then pcall(killTimer, EW[field]) end
    EW[field] = nil
  end
end

local function state_payload()
  return {
    version = EW.VERSION, api_contract = EW.API_CONTRACT,
    enabled = EW.enabled, busy = EW.busy, applying = EW.applying,
    planet = EW.plan and EW.plan.planet or nil,
    action_count = EW.plan and #EW.plan.actions or 0,
    plan_applied = EW.plan and EW.plan.applied == true or false,
  }
end

local function update_ui()
  local state = EW.enabled and "ON" or "OFF"
  local activity = EW.applying and "APPLYING" or (EW.busy and "CAPTURING" or "IDLE")
  local plan_text = EW.plan and string.format("%d changes", #EW.plan.actions) or "no plan"
  for _, instance in pairs(EW.ui.instances) do
    local controls = instance.controls
    if controls and controls.status and type(controls.status.echo) == "function" then
      pcall(controls.status.echo, controls.status,
        string.format("<center>Exchange Walker %s | %s | %s</center>", state, activity, plan_text))
    end
    if controls and controls.toggle and type(controls.toggle.echo) == "function" then
      pcall(controls.toggle.echo, controls.toggle,
        string.format("<center>%s</center>", EW.enabled and "OFF" or "ON"))
    end
  end
  emit("state.changed", state_payload())
end

local function destroy_widget(widget)
  if type(widget) ~= "table" then return end
  if type(widget.hide) == "function" then pcall(widget.hide, widget) end
  if type(widget.delete) == "function" then pcall(widget.delete, widget) end
end

local function create_label(parent, name, x, y, width, height, text, color, callback, tooltip)
  local label = Geyser.Label:new({ name = name, x = x, y = y, width = width, height = height }, parent)
  if type(label.setStyleSheet) == "function" then
    label:setStyleSheet(string.format([[
      QLabel { background-color: %s; color: white; border: 1px solid #737884;
        padding: 2px; font-weight: bold; }
      QLabel:hover { border: 1px solid white; }
    ]], color))
  end
  if type(label.echo) == "function" then label:echo("<center>" .. text .. "</center>") end
  if callback and type(label.setClickCallback) == "function" then label:setClickCallback(callback) end
  if tooltip and type(label.setToolTip) == "function" then label:setToolTip(tooltip) end
  if type(label.show) == "function" then label:show() end
  return label
end

local function current_ew()
  local value = rawget(_G, "ExchangeWalkerLive")
  return type(value) == "table" and value or nil
end

local function dynamic_call(method)
  return function()
    local current = current_ew()
    if current and type(current[method]) == "function" then return current[method]() end
  end
end

local function build_mux_content(target)
  if target.contentBg and type(target.contentBg.hide) == "function" then
    pcall(target.contentBg.hide, target.contentBg)
  end
  EW.ui.instance_counter = EW.ui.instance_counter + 1
  local prefix = "ExchangeWalkerLiveMux" .. tostring(EW.ui.instance_counter)
  local controls = {}
  controls.status = create_label(target.content, prefix .. "Status", 0, 0, "100%", 24,
    "Exchange Walker OFF | IDLE | no plan", "#252936", nil,
    "Current Exchange Walker lifecycle and preview state.")
  controls.toggle = create_label(target.content, prefix .. "Toggle", "0%", 26, "20%", 26,
    "ON", "#166534", dynamic_call("toggle"), "Arm or disarm Exchange Walker.")
  controls.preview = create_label(target.content, prefix .. "Preview", "20%", 26, "20%", 26,
    "PREVIEW", "#24558a", dynamic_call("preview"),
    "Capture display exchange and display production through F2CE Tools.")
  controls.apply = create_label(target.content, prefix .. "Apply", "40%", 26, "20%", 26,
    "APPLY", "#714018", dynamic_call("apply"), "Apply the reviewed unexpired plan once.")
  controls.cancel = create_label(target.content, prefix .. "Cancel", "60%", 26, "20%", 26,
    "CANCEL", "#7f1d1d", dynamic_call("cancel"), "Cancel capture or unsent changes.")
  controls.clear = create_label(target.content, prefix .. "Clear", "80%", 26, "20%", 26,
    "CLEAR", "#3e4657", function()
      local current = current_ew()
      if current and current.ui then current.ui.clear() end
    end, "Clear Exchange Walker display history.")
  local console = Geyser.MiniConsole:new({
    name = prefix .. "Console", x = 0, y = 54, width = "100%", height = "100%-54px",
    fontSize = 9, scrollBar = true,
  }, target.content)
  if type(console.setColor) == "function" then pcall(console.setColor, console, 18, 18, 26) end
  if type(console.enableAutoWrap) == "function" then pcall(console.enableAutoWrap, console) end
  if type(console.show) == "function" then pcall(console.show, console) end
  EW.ui.instances[target] = { target = target, controls = controls, console = console }
  EW.ui.registered_target = target
  for _, line_text in ipairs(EW.ui.history) do console_write(console, line_text) end
  update_ui()
end

local function destroy_mux_content(target)
  local instance = EW.ui.instances[target]
  if not instance then return end
  if instance.controls then for _, widget in pairs(instance.controls) do destroy_widget(widget) end end
  destroy_widget(instance.console)
  EW.ui.instances[target] = nil
  if EW.ui.registered_target == target then EW.ui.registered_target = nil end
end

function EW.ui.registerMuxContent()
  if not (Geyser and Geyser.Label and Geyser.MiniConsole) then
    return false, "Geyser Label/MiniConsole is unavailable"
  end
  local definition = {
    name = "Exchange Walker",
    description = "Planet-owner production, stockpile, spread, preview, and apply display.",
    group = "Exchange Walker Live", internal = false, singleton = false,
    apply = function(target)
      local ok, reason = pcall(build_mux_content, target)
      if not ok then main_notice("red", "Mux content failed: " .. tostring(reason)) end
    end,
    remove = function(target) destroy_mux_content(target) end,
    resize = function(_target) update_ui() end,
    serialize = function(_target) return {} end,
    restore = function(_target, _data) update_ui() end,
    onReveal = function(_target) update_ui() end,
  }
  local ok, reason = EW.f2ce.display.registerContent(EW.ui.content_id, definition)
  EW.ui.registered = ok == true
  return ok, reason
end

function EW.ui.mount(activate, reapply)
  local ok, target, created = EW.f2ce.display.mountContentTab(EW.ui.content_id, {
    pane_id = EW.ui.preferred_pane_id, pane_name = EW.ui.preferred_pane_name,
    tab_name = EW.ui.preferred_tab_name,
    required_contents = { "fed2_who", "fed2_exchange" },
    activate = activate == true, reapply = reapply == true,
  })
  if ok then EW.ui.registered_target = target end
  return ok, target, created
end

function EW.ui.install()
  local registered, reason = EW.ui.registerMuxContent()
  if not registered then return false, reason end
  return EW.ui.mount(false, next(EW.ui.instances) == nil)
end

function EW.ui.show()
  if not EW.ui.registered then
    local ok = EW.ui.registerMuxContent()
    if not ok then return false end
  end
  local ok, reason = EW.ui.mount(true, next(EW.ui.instances) == nil)
  if not ok then notice("yellow", "Mux display unavailable: " .. tostring(reason)) end
  return ok
end

local function validate_complete_capture(exchange_data, production_data)
  if type(exchange_data) ~= "table" or type(production_data) ~= "table" then
    return nil, "Exchange or production capture is not a valid table."
  end
  local production_by_name = {}
  for name, production in pairs(production_data) do
    if type(name) ~= "string" or name == "" or type(production) ~= "table" then
      return nil, "Production capture contains an invalid commodity row."
    end
    local key = normalized(name)
    if production_by_name[key] ~= nil then
      return nil, string.format("Production capture contains duplicate rows for %s.", name)
    end
    local produced = finite_number(production.production)
    local consumed = finite_number(production.consumption)
    if produced == nil or consumed == nil or produced < 0 or consumed < 0 then
      return nil, string.format("Production capture is invalid for %s.", name)
    end
    production_by_name[key] = { production = produced, consumption = consumed }
  end
  local exchange_names = {}
  for _, exchange in ipairs(exchange_data) do
    if type(exchange) ~= "table" or type(exchange.name) ~= "string" or exchange.name == "" then
      return nil, "Exchange capture contains an invalid commodity row."
    end
    local key = normalized(exchange.name)
    if exchange_names[key] then
      return nil, string.format("Exchange capture contains duplicate rows for %s.", exchange.name)
    end
    exchange_names[key] = true
    if production_by_name[key] == nil then
      return nil, string.format("Production capture is incomplete: missing %s.", exchange.name)
    end
    local current = finite_number(exchange.stock_current)
    local minimum = finite_number(exchange.stock_min)
    local maximum = finite_number(exchange.stock_max)
    local spread = finite_number(exchange.spread)
    if current == nil or minimum == nil or maximum == nil
        or current < 0 or minimum < 0 or maximum < 0 then
      return nil, string.format("Exchange stock capture is invalid for %s.", exchange.name)
    end
    if spread == nil or spread < 6 or spread > 40 then
      return nil, string.format("Exchange spread capture is invalid for %s.", exchange.name)
    end
  end
  return production_by_name, nil
end

local function make_plan(exchange_data, production_data, room_identity)
  local production_by_name, capture_error = validate_complete_capture(exchange_data, production_data)
  if not production_by_name then return nil, capture_error end
  local rows = {}
  for _, exchange in ipairs(exchange_data) do
    local production = production_by_name[normalized(exchange.name)]
    local produced, consumed = production.production, production.consumption
    local net = produced - consumed
    local current = math.floor(tonumber(exchange.stock_current))
    local old_min = math.floor(tonumber(exchange.stock_min))
    local old_max = math.floor(tonumber(exchange.stock_max))
    local old_spread = math.floor(tonumber(exchange.spread))
    local target_min, target_max, target_spread, policy
    if net <= 0 then
      target_min, target_max, target_spread, policy = 0, 0, 6, "deficit/breakeven"
    elseif current < 10000 then
      target_min, target_max = math.max(0, current), math.max(0, current) + 1000
      target_spread, policy = 40, "surplus-growing"
    else
      target_min, target_max, target_spread, policy = 10000, 20000, 40, "surplus-reserve"
    end
    rows[#rows + 1] = {
      commodity = exchange.name, production = produced, consumption = consumed, net = net,
      current = current, old_min = old_min, old_max = old_max,
      target_min = target_min, target_max = target_max,
      old_spread = old_spread, target_spread = target_spread, policy = policy,
    }
  end
  table.sort(rows, function(left, right)
    if left.net == right.net then return normalized(left.commodity) < normalized(right.commodity) end
    return left.net > right.net
  end)
  local actions = {}
  for _, row in ipairs(rows) do
    if row.target_min ~= row.old_min then
      actions[#actions + 1] = { kind = "min", commodity = row.commodity, value = row.target_min,
        command = string.format("set stockpile min %d %s", row.target_min, row.commodity) }
    end
    if row.target_max ~= row.old_max then
      actions[#actions + 1] = { kind = "max", commodity = row.commodity, value = row.target_max,
        command = string.format("set stockpile max %d %s", row.target_max, row.commodity) }
    end
    if row.target_spread ~= row.old_spread then
      actions[#actions + 1] = { kind = "spread", commodity = row.commodity, value = row.target_spread,
        command = string.format("set spread %d %s", row.target_spread, row.commodity) }
    end
  end
  return { created_at = os.time(), room_identity = room_identity,
    planet = current_planet_name(), rows = rows, actions = actions, applied = false }, nil
end

local function compact_name(value, width)
  local text = tostring(value or "")
  if #text > width then return text:sub(1, math.max(1, width - 1)) .. "~" end
  return text
end

local function display_plan(plan)
  local lines = {
    string.format("<green>EXCHANGE + PRODUCTION | %s<reset>", plan.planet),
    "<dim_grey>Production, stock, spread, and limits (old -> new)<reset>",
  }
  for _, row in ipairs(plan.rows) do
    local color = row.net > 0 and "green" or "red"
    lines[#lines + 1] = string.format(
      "<%s>%-17s net %+d | stock %d<reset>",
      color, compact_name(row.commodity, 17), row.net, row.current)
    lines[#lines + 1] = string.format(
      "  prod/cons %d/%d | spread %d -> %d",
      row.production, row.consumption, row.old_spread, row.target_spread)
    lines[#lines + 1] = string.format(
      "  limits %d/%d -> %d/%d",
      row.old_min, row.old_max, row.target_min, row.target_max)
  end
  lines[#lines + 1] = string.format(
    "<cyan>%d commodities | %d reviewed setting changes | plan expires in %d seconds<reset>",
    #plan.rows, #plan.actions, EW.plan_max_age_seconds)
  EW.ui.replace(lines)
  EW.ui.show()
  if #plan.actions == 0 then
    notice("green", "Preview complete: no stockpile or spread changes are needed.")
  else
    notice("yellow", string.format(
      "Preview complete: %d setting changes. Review the Stockpiles tab, then use `ew apply` within two minutes.",
      #plan.actions))
  end
end

local function preview_failed(message)
  EW.f2ce.capture.cancel()
  EW.busy, EW.plan, EW.capture_room_identity = false, nil, nil
  update_ui()
  notice("red", message)
  emit("preview.failed", { reason = message })
  return false
end

function EW.status()
  local state = EW.enabled and "ON" or "OFF"
  local activity = EW.applying and "applying" or (EW.busy and "capturing" or "idle")
  local plan = EW.plan and string.format("%d pending change(s) for %s",
    #EW.plan.actions, EW.plan.planet) or "no preview plan"
  notice("cyan", string.format("v%s is %s; %s; %s.", EW.VERSION, state, activity, plan))
  return state_payload()
end

function EW.on()
  local ok, reason = EW.f2ce.core.check({ minimum_version = EW.MIN_F2CE_VERSION })
  if not ok then
    EW.enabled = false
    update_ui()
    notice("red", tostring(reason) .. "; Exchange Walker remains OFF.")
    return false
  end
  EW.enabled = true
  update_ui()
  notice("green", "ON. Use `ew preview` to inspect proposed stockpile and spread changes.")
  return true
end

function EW.cancel(reason)
  local was_active = EW.busy or EW.applying
  cancel_timer("transition_timer")
  cancel_timer("apply_timer")
  cancel_timer("confirmation_timer")
  local capture_ok, capture_reason = EW.f2ce.capture.cancel()
  EW.busy, EW.applying = false, false
  EW.pending_confirmation, EW.apply_index, EW.capture_room_identity = nil, nil, nil
  update_ui()
  if not capture_ok then notice("yellow", tostring(capture_reason)) end
  if was_active then
    notice("yellow", reason or
      "Cancelled. Already-sent commands cannot be recalled; run a new preview to reconcile.")
  end
  return true
end

function EW.off(reason)
  EW.cancel(reason or "OFF. Capture stopped and unsent changes cancelled.")
  EW.enabled, EW.plan = false, nil
  update_ui()
  notice("red", "OFF. No capture or stockpile/spread operation will be started.")
  return true
end

function EW.toggle()
  if EW.enabled then return EW.off() end
  return EW.on()
end

function EW.preview()
  if not EW.enabled then notice("red", "The walker is OFF. Use `ew on` first.") return false end
  if EW.busy or EW.applying then
    notice("yellow", "A capture or apply operation is already in progress.")
    return false
  end
  local ok, reason = EW.f2ce.core.check({ minimum_version = EW.MIN_F2CE_VERSION, gmcp = true })
  if not ok then return preview_failed(tostring(reason)) end
  local room_identity = current_room_identity()
  if not room_identity then return preview_failed("GMCP room identity is unavailable.") end
  EW.plan, EW.busy, EW.capture_room_identity = nil, true, room_identity
  update_ui()
  notice("cyan", "Gathering current exchange and production data through F2CE Tools...")
  local started, start_reason = EW.f2ce.capture.exchange(function(exchange_data)
    if not EW.enabled then return preview_failed("Capture stopped because the walker was switched OFF.") end
    if current_room_identity() ~= EW.capture_room_identity then
      return preview_failed("Location changed during exchange capture; no plan was created.")
    end
    if type(exchange_data) ~= "table" or #exchange_data == 0 then
      return preview_failed("No live exchange rows were captured; no plan was created.")
    end
    EW.transition_timer = tempTimer(0.15, function()
      EW.transition_timer = nil
      if current_room_identity() ~= EW.capture_room_identity then
        return preview_failed("Location changed before production capture; no plan was created.")
      end
      local production_started, production_reason = EW.f2ce.capture.production(function(production_data)
        EW.busy = false
        if not EW.enabled then
          EW.plan, EW.capture_room_identity = nil, nil
          update_ui()
          notice("yellow", "Capture completed after OFF; results were discarded.")
          return
        end
        if current_room_identity() ~= EW.capture_room_identity then
          return preview_failed("Location changed during production capture; no plan was created.")
        end
        if type(production_data) ~= "table" or next(production_data) == nil then
          return preview_failed("No live production rows were captured; no plan was created.")
        end
        local plan, capture_error = make_plan(exchange_data, production_data, EW.capture_room_identity)
        EW.capture_room_identity = nil
        if not plan then
          return preview_failed(tostring(capture_error) .. " No plan was created; nothing can be applied.")
        end
        EW.plan = plan
        update_ui()
        display_plan(plan)
        emit("plan.ready", plan)
      end)
      if not production_started then
        preview_failed("Production capture could not start: " .. tostring(production_reason))
      end
    end)
  end)
  if not started then return preview_failed("Exchange capture could not start: " .. tostring(start_reason)) end
  return true
end

local function stop_apply(message, color)
  cancel_timer("apply_timer")
  cancel_timer("confirmation_timer")
  EW.applying, EW.pending_confirmation, EW.apply_index = false, nil, nil
  update_ui()
  notice(color or "red", message)
  emit("apply.failed", { reason = message, plan = EW.plan })
  return false
end

local function apply_context_valid()
  if not EW.enabled then return false, "Apply stopped because Exchange Walker is OFF." end
  if not EW.plan then return false, "Apply stopped because the preview plan disappeared." end
  if EW.plan.room_identity ~= current_room_identity() then
    return false, "Apply stopped because the GMCP room identity changed."
  end
  local owned, owner, player = EW.f2ce.core.ownership()
  if not owned then
    return false, string.format(
      "Apply stopped because GMCP ownership is not confirmed (owner=%s, player=%s).",
      tostring(owner or "unknown"), tostring(player or "unknown"))
  end
  return true
end

local send_action
send_action = function(index)
  local valid, reason = apply_context_valid()
  if not valid then return stop_apply(reason) end
  local action = EW.plan.actions[index]
  if not action then
    EW.applying, EW.apply_index, EW.pending_confirmation = false, nil, nil
    update_ui()
    notice("green", string.format(
      "All %d reviewed changes were sent once and confirmed by the server.", #EW.plan.actions))
    emit("apply.completed", { plan = EW.plan })
    return true
  end
  if type(send) ~= "function" then return stop_apply("Mudlet send() is unavailable.") end
  EW.apply_index = index
  EW.pending_confirmation = {
    key = normalized(action.commodity) .. ":" .. action.kind,
    value = action.value, action = action,
  }
  send(action.command, false)
  emit("apply.command_sent", { index = index, action = action })
  EW.confirmation_timer = tempTimer(EW.confirmation_timeout_seconds, function()
    EW.confirmation_timer = nil
    stop_apply(string.format(
      "Timed out waiting for confirmation of `%s`. Remaining changes were not sent; run a new preview.",
      action.command))
  end)
  return true
end

function EW.apply()
  if not EW.enabled then notice("red", "The walker is OFF; nothing was sent.") return false end
  if EW.busy or EW.applying then
    notice("yellow", "A capture or apply operation is already in progress.") return false
  end
  if not EW.plan then notice("red", "No preview plan exists. Run `ew preview` first.") return false end
  if EW.plan.applied then
    notice("red", "This plan was already applied. Run a new preview; commands will not be replayed.")
    return false
  end
  if os.time() - EW.plan.created_at > EW.plan_max_age_seconds then
    EW.plan = nil
    update_ui()
    notice("red", "The preview expired. Run `ew preview` again before applying.")
    return false
  end
  local valid, reason = apply_context_valid()
  if not valid then notice("red", reason) return false end
  if #EW.plan.actions == 0 then notice("green", "The preview contains no changes; nothing was sent.") return true end
  EW.plan.applied, EW.applying = true, true
  update_ui()
  notice("yellow", string.format(
    "Applying %d reviewed changes to %s. Each command waits for confirmation and will not be retried.",
    #EW.plan.actions, EW.plan.planet))
  emit("apply.started", { plan = EW.plan })
  return send_action(1)
end

local function confirmation(kind)
  local commodity = matches and matches[2] or nil
  local reported = matches and matches[3] or nil
  if not commodity or not reported or not EW.applying then return end
  local pending = EW.pending_confirmation
  if type(pending) ~= "table" then return end
  local key = normalized(commodity) .. ":" .. kind
  if key ~= pending.key then return end
  local numeric = tonumber((tostring(reported):gsub(",", "")))
  if numeric ~= pending.value then
    return stop_apply(string.format(
      "%s %s confirmation was %s, expected %d. Remaining changes were not sent; run a new preview.",
      commodity, kind, tostring(reported), pending.value))
  end
  cancel_timer("confirmation_timer")
  local completed_index = EW.apply_index
  EW.pending_confirmation = nil
  notice("green", string.format("%s %s confirmed at %d%s.",
    commodity, kind, pending.value, kind == "spread" and "%" or " tons"))
  emit("apply.confirmed", { index = completed_index, action = pending.action })
  EW.apply_timer = tempTimer(EW.command_spacing_seconds, function()
    EW.apply_timer = nil
    send_action((completed_index or 0) + 1)
  end)
end

local function add_trigger(pattern, callback)
  if type(tempRegexTrigger) ~= "function" then return nil end
  local id = tempRegexTrigger(pattern, callback)
  if id then EW.runtime.trigger_ids[#EW.runtime.trigger_ids + 1] = id end
  return id
end

local function add_handler(event_name, callback)
  if type(registerAnonymousEventHandler) ~= "function" then return nil end
  local id = registerAnonymousEventHandler(event_name, callback)
  if id then EW.runtime.handler_ids[#EW.runtime.handler_ids + 1] = id end
  return id
end

local function api_status()
  local caps = EW.f2ce.core.capabilities()
  notice("cyan", string.format(
    "API %s | F2CE adapter %s | F2CE %s | capture %s | Mux %s | mount %s.",
    EW.API_CONTRACT, tostring(caps.adapter_version), tostring(caps.f2ce_version or "missing"),
    caps.capture.available and "available" or "missing",
    caps.display.registration and "available" or "missing",
    caps.display.workspace_mount and "available" or "missing"))
  return caps
end

local function install_runtime_hooks()
  add_trigger([[^\s*Min stock level for (\w+) on .+ set to ([0-9][0-9,]*(?:\.[0-9]+)?) tons\.$]],
    function() confirmation("min") end)
  add_trigger([[^\s*Max stock level for (\w+) on .+ set to ([0-9][0-9,]*(?:\.[0-9]+)?) tons\.$]],
    function() confirmation("max") end)
  add_trigger([[^\s*Price spread for (\w+) on .+ set to ([0-9]+)%\.$]],
    function() confirmation("spread") end)
  if type(tempAlias) == "function" then
    EW.runtime.alias_id = tempAlias(
      [[^ew(?:\s+(on|off|toggle|preview|apply|cancel|status|display|api|help))?\s*$]], function()
      local command = normalized(matches and matches[2] or "status")
      if command == "on" then EW.on()
      elseif command == "off" then EW.off()
      elseif command == "toggle" then EW.toggle()
      elseif command == "preview" then EW.preview()
      elseif command == "apply" then EW.apply()
      elseif command == "cancel" then EW.cancel()
      elseif command == "status" then EW.status()
      elseif command == "display" then EW.ui.show()
      elseif command == "api" then api_status()
      else
        EW.ui.replace({
          "<cyan>EXCHANGE WALKER LIVE COMMANDS<reset>",
          "<yellow>ew on<reset>       Arm capture and explicit apply",
          "<yellow>ew off<reset>      Disable and cancel pending work",
          "<yellow>ew preview<reset>  Capture exchange + production and show a plan",
          "<yellow>ew apply<reset>    Apply the latest unexpired preview once",
          "<yellow>ew cancel<reset>   Cancel capture or unsent changes",
          "<yellow>ew display<reset>  Open the F2CE Stockpiles Mux tab",
          "<yellow>ew status<reset>   Show current state",
          "<yellow>ew api<reset>      Show F2CE adapter capabilities",
        })
        EW.ui.show()
      end
    end)
  end
  add_handler("muxletReady", function()
    EW.ui.registerMuxContent()
    EW.ui.mount(false, next(EW.ui.instances) == nil)
    update_ui()
  end)
  add_handler("sysDisconnectionEvent", function()
    EW.off("Disconnected. Reconnect requires explicit `ew on`.")
  end)
  add_handler("sysConnectionEvent", function()
    EW.off("Reconnect safety reset. Use `ew on` explicitly.")
  end)
end

function EW.subscribe(event_name, callback)
  if type(event_name) ~= "string" or event_name == "" or type(callback) ~= "function" then
    return nil, "event name and callback are required"
  end
  EW.events.next_id = EW.events.next_id + 1
  EW.events.subscribers[event_name] = EW.events.subscribers[event_name] or {}
  EW.events.subscribers[event_name][EW.events.next_id] = callback
  return EW.events.next_id
end

function EW.unsubscribe(id)
  for _, listeners in pairs(EW.events.subscribers) do
    if listeners[id] then listeners[id] = nil return true end
  end
  return false
end

function EW.shutdown()
  EW.ui.shutting_down = true
  EW.cancel("Exchange Walker runtime shutdown; unsent work cancelled.")
  EW.enabled, EW.plan = false, nil
  for _, id in ipairs(EW.runtime.trigger_ids) do
    if type(killTrigger) == "function" then pcall(killTrigger, id) end
  end
  EW.runtime.trigger_ids = {}
  if EW.runtime.alias_id and type(killAlias) == "function" then pcall(killAlias, EW.runtime.alias_id) end
  EW.runtime.alias_id = nil
  for _, id in ipairs(EW.runtime.handler_ids) do
    if type(killAnonymousEventHandler) == "function" then pcall(killAnonymousEventHandler, id) end
  end
  EW.runtime.handler_ids = {}
  local targets = {}
  for target in pairs(EW.ui.instances) do targets[#targets + 1] = target end
  for _, target in ipairs(targets) do destroy_mux_content(target) end
  update_ui()
end

EW.public = {
  contract = EW.API_CONTRACT, version = EW.VERSION,
  status = EW.status, on = EW.on, off = EW.off,
  preview = EW.preview, apply = EW.apply, cancel = EW.cancel,
  show = EW.ui.show, subscribe = EW.subscribe, unsubscribe = EW.unsubscribe,
  capabilities = api_status,
}

-- Backward-compatible function names from 3.0.x.
exchange_walker_status = EW.status
exchange_walker_on = EW.on
exchange_walker_off = EW.off
exchange_walker_toggle = EW.toggle
exchange_walker_cancel = EW.cancel
exchange_walker_apply = EW.apply
exchange_walker_shutdown = EW.shutdown
fetch_and_process_data = EW.preview

install_runtime_hooks()
local mounted, mount_reason = EW.ui.install()
update_ui()
if not mounted and mount_reason then
  notice("yellow", "F2CE Mux display is not mounted: " .. tostring(mount_reason)
    .. ". Console commands remain available.")
end
notice("cyan", string.format(
  "v%s loaded; default is OFF. Use `ew on`, `ew preview`, then explicit `ew apply`.", EW.VERSION))
