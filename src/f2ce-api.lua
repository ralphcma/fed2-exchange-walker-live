-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 Exchange Walker Live contributors
--
-- Exchange Walker Live compatibility boundary for F2CE Tools and Muxlet.
-- Feature code must use this facade rather than binding directly to F2CE globals
-- or Mux workspace internals.  Upstream compatibility changes belong here.

local EW = rawget(_G, "ExchangeWalkerLive")
if type(EW) ~= "table" then return end

local api = {
  VERSION = "1.0.0",
  CONTRACT = "ExchangeWalkerLive.F2CE/1.0",
  VALIDATED_F2CE_VERSION = "3.2.5",
  bindings = {},
  capture = { lease = nil, callback = nil, kind = nil },
  core = {},
  display = {},
}
EW.f2ce = api

api.bindings.functions = {
  capture_exchange = "f2t_po_capture_exchange",
  capture_production = "f2t_po_capture_production",
  capture_reset = "f2t_po_reset",
}

local function global_function(key)
  local name = api.bindings.functions[key]
  local value = name and rawget(_G, name) or nil
  return type(value) == "function" and value or nil, name
end

local function version_tuple(value)
  local major, minor, patch = tostring(value or ""):match("^(%d+)%.(%d+)%.(%d+)")
  if not major then return nil end
  return { tonumber(major), tonumber(minor), tonumber(patch) }
end

function api.core.version()
  local version = rawget(_G, "F2T_VERSION")
  if type(version) == "string" then return version end
  if type(getPackageInfo) == "function" then
    local ok, info = pcall(getPackageInfo, "f2ce-tools")
    if ok and type(info) == "table" and type(info.version) == "string" then
      return info.version
    end
  end
  return nil
end

function api.core.versionAtLeast(actual, minimum)
  local left, right = version_tuple(actual), version_tuple(minimum)
  if not left or not right then return false end
  for index = 1, 3 do
    if left[index] ~= right[index] then return left[index] > right[index] end
  end
  return true
end

function api.core.captureAvailable()
  for _, key in ipairs({ "capture_exchange", "capture_production", "capture_reset" }) do
    local fn, name = global_function(key)
    if not fn then return false, "F2CE capability is missing: " .. tostring(name) end
  end
  return true
end

function api.core.gmcpReady()
  local data = rawget(_G, "gmcp")
  if type(data) ~= "table" then return false, "GMCP is unavailable" end
  if type(data.room) ~= "table" or type(data.room.info) ~= "table" then
    return false, "gmcp.room.info has not populated"
  end
  if type(data.char) ~= "table" or type(data.char.vitals) ~= "table" then
    return false, "gmcp.char.vitals has not populated"
  end
  return true
end

function api.core.check(options)
  options = type(options) == "table" and options or {}
  local version = api.core.version()
  if not version then
    return false, "F2CE Tools is missing or did not expose its installed version"
  end
  local minimum = tostring(options.minimum_version or api.VALIDATED_F2CE_VERSION)
  if not api.core.versionAtLeast(version, minimum) then
    return false, string.format(
      "F2CE Tools %s is stale; version %s or newer is required", version, minimum)
  end
  local ok, reason = api.core.captureAvailable()
  if not ok then return false, reason end
  if options.gmcp then
    ok, reason = api.core.gmcpReady()
    if not ok then return false, reason end
  end
  return true
end

function api.core.ownership()
  local data = rawget(_G, "gmcp")
  local info = type(data) == "table" and type(data.room) == "table" and data.room.info or nil
  local vitals = type(data) == "table" and type(data.char) == "table" and data.char.vitals or nil
  local owner = type(info) == "table" and info.owner or nil
  local player = type(vitals) == "table" and vitals.name or nil
  local owned = type(owner) == "string" and owner ~= ""
    and type(player) == "string" and player ~= ""
    and string.lower(owner) == string.lower(player)
  return owned, owner, player
end

function api.core.capabilities()
  local capture_ok, capture_reason = api.core.captureAvailable()
  local mux = rawget(_G, "Mux")
  return {
    contract = api.CONTRACT,
    adapter_version = api.VERSION,
    f2ce_version = api.core.version(),
    validated_f2ce_version = api.VALIDATED_F2CE_VERSION,
    capture = { available = capture_ok, reason = capture_reason },
    display = {
      registration = type(mux) == "table" and type(mux.registerContent) == "function",
      workspace_mount = type(mux) == "table" and type(mux.registerContent) == "function"
        and type(mux.getPane) == "function" and type(mux._applyContent) == "function",
    },
  }
end

local function clear_capture_lease(lease)
  if lease == nil or api.capture.lease == lease then
    api.capture.lease = nil
    api.capture.callback = nil
    api.capture.kind = nil
  end
end

local function start_capture(kind, callback)
  if type(callback) ~= "function" then return false, "capture callback is required" end
  if api.capture.lease ~= nil then
    return false, "Exchange Walker already owns an F2CE capture"
  end
  local fn, name = global_function(kind == "exchange" and "capture_exchange" or "capture_production")
  if not fn then return false, "F2CE capability is missing: " .. tostring(name) end

  local lease = {}
  local wrapped
  wrapped = function(data)
    clear_capture_lease(lease)
    callback(data)
  end
  api.capture.lease = lease
  api.capture.callback = wrapped
  api.capture.kind = kind

  local ok, started, reason = pcall(fn, nil, wrapped)
  if not ok then
    clear_capture_lease(lease)
    return false, tostring(started)
  end
  if started == false then
    clear_capture_lease(lease)
    return false, tostring(reason or ("F2CE " .. kind .. " capture is busy"))
  end
  return true
end

function api.capture.exchange(callback)
  return start_capture("exchange", callback)
end

function api.capture.production(callback)
  return start_capture("production", callback)
end

function api.capture.cancel()
  local lease = api.capture.lease
  if lease == nil then return true end

  -- Do not reset F2CE's global capture if another client replaced our callback.
  local state = rawget(_G, "f2t_po")
  if type(state) == "table" and state.callback ~= nil
      and state.callback ~= api.capture.callback then
    clear_capture_lease(lease)
    return false, "F2CE capture ownership changed; the foreign capture was not reset"
  end

  local reset, name = global_function("capture_reset")
  if not reset then
    clear_capture_lease(lease)
    return false, "F2CE capability is missing: " .. tostring(name)
  end
  local ok, reason = pcall(reset)
  clear_capture_lease(lease)
  if not ok then return false, tostring(reason) end
  return true
end

function api.display.available()
  local mux = rawget(_G, "Mux")
  return type(mux) == "table" and type(mux.registerContent) == "function"
end

function api.display.workspaceMountAvailable()
  local mux = rawget(_G, "Mux")
  return api.display.available()
    and type(mux.getPane) == "function"
    and type(mux._applyContent) == "function"
end

function api.display.registerContent(content_id, definition)
  if not api.display.available() then return false, "Mux.registerContent is unavailable" end
  local mux = rawget(_G, "Mux")
  local ok, reason = pcall(mux.registerContent, content_id, definition)
  if not ok then return false, tostring(reason) end
  return true
end

local function mux_tabs(pane)
  local result = {}
  for _, bucket in ipairs({ pane and pane._tabs, pane and pane._hiddenTabs }) do
    if type(bucket) == "table" then
      for _, tab in ipairs(bucket) do result[#result + 1] = tab end
    end
  end
  return result
end

function api.display.mountContentTab(content_id, options)
  options = type(options) == "table" and options or {}
  if not api.display.workspaceMountAvailable() then
    return false, "Mux workspace mount capability is unavailable"
  end

  local mux = rawget(_G, "Mux")
  local pane_id = tostring(options.pane_id or "")
  local expected_name = tostring(options.pane_name or "")
  local ok, pane = pcall(mux.getPane, pane_id)
  if not ok or type(pane) ~= "table" then
    return false, "F2CE workspace pane is unavailable: " .. pane_id
  end
  if expected_name ~= "" and tostring(pane.name or "") ~= expected_name then
    return false, string.format("F2CE workspace topology changed: %s is '%s', expected '%s'",
      pane_id, tostring(pane.name or ""), expected_name)
  end
  if type(pane.addTab) ~= "function" or type(pane.activateTab) ~= "function" then
    return false, "F2CE workspace pane does not expose tab placement operations"
  end

  local previous_active_tab = pane._activeTabId
  local tabs = mux_tabs(pane)
  for _, required_content in ipairs(options.required_contents or {}) do
    local found = false
    for _, tab in ipairs(tabs) do
      if tab._activeContent == required_content then found = true break end
    end
    if not found then
      return false, "F2CE workspace topology changed; missing expected content "
        .. tostring(required_content)
    end
  end

  local tab_name = tostring(options.tab_name or content_id)
  local target
  for _, tab in ipairs(tabs) do
    if tab._activeContent == content_id then target = tab break end
    if tostring(tab.name or "") == tab_name then
      return false, "F2CE workspace tab name is already in use: " .. tab_name
    end
  end

  local created = false
  if not target then
    local added_ok, added = pcall(pane.addTab, pane, tab_name, options.position)
    if not added_ok or type(added) ~= "table" then
      return false, "Mux could not add the Exchange Walker workspace tab"
    end
    target, created = added, true
  end

  target.closeable = options.closeable ~= false
  target.movable = options.movable ~= false
  target.renamable = false
  target.propertiesButton = false
  target.contentable = false

  if target._activeContent ~= content_id or options.reapply == true then
    local applied_ok, applied_reason = pcall(mux._applyContent, target, content_id, true)
    if not applied_ok then
      return false, "Mux content application failed: " .. tostring(applied_reason)
    end
    if target._activeContent ~= content_id then
      return false, "Mux did not confirm the requested workspace content"
    end
  end

  if options.activate == true then
    local activated_ok, activated_reason = pcall(pane.activateTab, pane, target.id)
    if not activated_ok then
      return false, "Mux tab activation failed: " .. tostring(activated_reason)
    end
  elseif previous_active_tab ~= nil and pane._activeTabId ~= previous_active_tab then
    local restored_ok, restored_reason = pcall(pane.activateTab, pane, previous_active_tab)
    if not restored_ok then
      return false, "Mux active-tab restoration failed: " .. tostring(restored_reason)
    end
  end
  return true, target, created
end
