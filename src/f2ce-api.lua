-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 Exchange Walker Live contributors
--
-- Exchange Walker consumer binding for the independently installed
-- Fed2ModuleAPI.  Compatibility logic, F2CE capture ownership, public Muxlet
-- registration, and typed command construction are centralized there.

local EW = rawget(_G, "ExchangeWalkerLive")
if type(EW) ~= "table" then return end

local function version_at_least(actual, minimum)
  local a, b, c = tostring(actual or ""):match("^(%d+)%.(%d+)%.(%d+)")
  local x, y, z = tostring(minimum or ""):match("^(%d+)%.(%d+)%.(%d+)")
  if not a or not x then return false end
  a, b, c, x, y, z = tonumber(a), tonumber(b), tonumber(c), tonumber(x), tonumber(y), tonumber(z)
  if a ~= x then return a > x end
  if b ~= y then return b > y end
  return c >= z
end

local function load_standalone()
  local fallback_path = EW._standalone_adapter_path
  if not fallback_path and type(getMudletHomeDir) == "function" then
    local ok_home, home = pcall(getMudletHomeDir)
    if ok_home and type(home) == "string" and home ~= "" then
      fallback_path = home .. "/exchange-walker-live/standalone-f2ce-api.lua"
    end
  end
  if not fallback_path then error("standalone F2CE adapter path is unavailable") end
  local fallback_ok, fallback_reason = pcall(dofile, fallback_path)
  if not fallback_ok or type(EW.f2ce) ~= "table" then
    error("standalone F2CE adapter could not load: " .. tostring(fallback_reason))
  end
end

local function installed_shared_api()
  local shared = rawget(_G, "Fed2ModuleAPI")
  if type(shared) == "table" then return shared end
  -- Package execution order is not stable across Mudlet profile rebuilds.
  -- Bootstrap only the independently installed shared API's canonical file;
  -- the contract/version checks below still reject missing or stale installs.
  if type(getMudletHomeDir) == "function" and type(dofile) == "function" then
    local ok_home, home = pcall(getMudletHomeDir)
    if ok_home and type(home) == "string" and home ~= "" then
      pcall(dofile, home .. "/fed2-module-api/src/fed2_module_api.lua")
    end
  end
  return rawget(_G, "Fed2ModuleAPI")
end

local shared = installed_shared_api()
if type(shared) ~= "table" or shared.CONTRACT ~= "Fed2ModuleAPI/1.0"
    or type(shared.registerClient) ~= "function"
    or not version_at_least(shared.VERSION, "1.2.4") then
  load_standalone()
  return
end

local function authorize(operation, payload)
  if EW.enabled ~= true then return false, "Exchange Walker is OFF" end
  if operation == "po.capture" then
    if EW.busy ~= true then return false, "Exchange Walker is not capturing" end
    if tostring(payload.planet or ""):lower() ~= tostring(EW.capture_target or ""):lower() then
      return false, "remote capture target does not match the active Exchange Walker request"
    end
    return true
  end
  if EW.applying ~= true then return false, "Exchange Walker is not applying a reviewed plan" end
  local pending = EW.pending_confirmation
  local action = type(pending) == "table" and pending.action or nil
  if type(action) ~= "table" then return false, "no reviewed Exchange Walker action is pending" end
  if tostring(action.kind) ~= tostring(payload.kind)
      or tostring(action.commodity):lower() ~= tostring(payload.commodity):lower()
      or tonumber(action.value) ~= tonumber(payload.value)
      or tostring(action.planet or ""):lower() ~= tostring(payload.planet or ""):lower() then
    return false, "typed command does not match the reviewed pending action"
  end
  return true
end

local registered, facade = shared.registerClient("ExchangeWalkerLive", {
  capabilities = { "stockpile.min", "stockpile.max", "stockpile.spread", "po.capture" },
  authorize = authorize,
})
if not registered then error(tostring(facade)) end

local shared_core = facade.core
facade.core = setmetatable({}, { __index = shared_core })
facade.core.check = function(options)
  options = type(options) == "table" and options or {}
  local requested = {}
  for _, profile in ipairs(options.profiles or {}) do requested[#requested + 1] = profile end
  requested[#requested + 1] = "capture"
  local copy = {}
  for key, value in pairs(options) do copy[key] = value end
  copy.profiles = requested
  copy.gmcp_options = copy.gmcp_options or { ship = false }
  return shared_core.check(copy)
end

EW.f2ce = facade
