-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 Exchange Walker Live contributors
--
-- Exchange Walker consumer binding for the independently installed
-- Fed2ModuleAPI.  Compatibility logic, F2CE capture ownership, public Muxlet
-- registration, and typed command construction are centralized there.

local EW = rawget(_G, "ExchangeWalkerLive")
if type(EW) ~= "table" then return end

local shared = rawget(_G, "Fed2ModuleAPI")
if type(shared) ~= "table" or shared.CONTRACT ~= "Fed2ModuleAPI/1.0"
    or type(shared.registerClient) ~= "function" then
  error("Fed2 Module API 1.x is missing; install/reload fed2-module-api before Exchange Walker Live")
end

local function authorize(operation, payload)
  if EW.enabled ~= true then return false, "Exchange Walker is OFF" end
  if EW.applying ~= true then return false, "Exchange Walker is not applying a reviewed plan" end
  local pending = EW.pending_confirmation
  local action = type(pending) == "table" and pending.action or nil
  if type(action) ~= "table" then return false, "no reviewed Exchange Walker action is pending" end
  if tostring(action.kind) ~= tostring(payload.kind)
      or tostring(action.commodity):lower() ~= tostring(payload.commodity):lower()
      or tonumber(action.value) ~= tonumber(payload.value) then
    return false, "typed command does not match the reviewed pending action"
  end
  return true
end

local registered, facade = shared.registerClient("ExchangeWalkerLive", {
  capabilities = { "stockpile.min", "stockpile.max", "stockpile.spread" },
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
