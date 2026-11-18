-- rex-tab-status: prefix each Rex tab's label with an emoji for the most urgent program status in it.
-- Programs report status with OSC 7501 (Claude Code does). Idle tabs get no prefix.
-- https://github.com/mvwi/rex-tab-status
--
-- This file runs three ways (install.sh sets up the first two):
--   init.lua does require("tab-status"): defines the "Toggle Tab Seen" action (tab_seen_toggle).
--   rex do tab-status.lua --all: listens for events and relabels tabs. launchd keeps it running.
--   TAB_STATUS_CLEAN=1 rex do tab-status.lua: removes every prefix, for uninstall.
--
-- A tab with the default label ("Window 0ab0edc4") shows its terminal's live title in the app.
-- Setting any label hides that title, so for such tabs we prefix the title instead, and
-- restore the default label (empty string) once the status goes away.
--
-- "done" means finished and not yet seen. A done record counts as seen once you switch to
-- its tab, or if it arrives while its tab is already showing. Toggle Tab Seen flips it.

-- Change these to taste, then run: rex config reload, and restart the listener (see README).
local glyph = { error = "❌", working = "⏳", done = "✅" }
local blocked_glyph = { permission = "✋", question = "❓", auth = "🔑" }

local rank = { blocked = 4, error = 3, working = 2, done = 1 }

local state_dir = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/rex"
local seen_path = state_dir .. "/tab-status.json"

-- Seen state, shared by the script and the cmd+u action through a file:
-- { [window_id] = { seen = "2026-11-18T07:09:57", unread = true?, from_title = true? } }
local function load_seen()
  local f = io.open(seen_path)
  if not f then return {} end
  local ok, t = pcall(rex.json.decode, f:read("*a"))
  f:close()
  return ok and type(t) == "table" and t or {}
end

local function save_seen(t)
  local tmp = seen_path .. ".tmp"
  local f = io.open(tmp, "w")
  if not f then return end
  f:write(rex.json.encode(t))
  f:close()
  os.rename(tmp, seen_path)
end

-- shortcut: compares local wall-clock strings, so a DST change can misjudge one hour of records; compare epoch seconds if that matters.
local function now() return os.date("%Y-%m-%dT%H:%M:%S") end

local function strip(label)
  for _, set in ipairs({ glyph, blocked_glyph }) do
    for _, e in pairs(set) do
      if label:find(e .. " ", 1, true) == 1 then return label:sub(#e + 2) end
    end
  end
  return label
end

local function is_default(label)
  return label == "" or label:match("^Window %x+$") ~= nil
end

local function method(session_id, block_id, name)
  return rex.call("block.method", { session_id = session_id, block_id = block_id, method = name })
end

local function terminals(w)
  local out = {}
  for _, layer in ipairs(w.layers or {}) do
    for _, b in ipairs(layer.blocks or {}) do
      if b.creator_name == "com.superlogical.terminal" then out[#out + 1] = b.block_id end
    end
  end
  return out
end

-- The tab's most urgent record, with done records already marked seen left out.
local function worst(session_id, w, entry)
  local best
  for _, block_id in ipairs(terminals(w)) do
    local res = method(session_id, block_id, "program_status")
    for _, r in ipairs(res and res.records or {}) do
      local counts = rank[r.state] ~= nil
      if r.state == "done" and not entry.unread then
        counts = (r.updated_at or ""):sub(1, 19) > (entry.seen or "")
      end
      if counts and (not best or rank[r.state] > rank[best.state]) then best = r end
    end
  end
  return best
end

local function relabel(session_id, w, active_window_id)
  local seen = load_seen()
  local entry = seen[w.window_id] or {}
  -- You're looking at this tab, so whatever it finished is seen, unless you marked it unread.
  -- shortcut: "looking" means the session's active tab, even when the app shows another session; use the client's selected session once Rex exposes it.
  if w.window_id == active_window_id and not entry.unread then entry.seen = now() end

  local best = worst(session_id, w, entry)
  local current = w.label or ""
  local base = strip(current)
  local t = w.focused_block_id and method(session_id, w.focused_block_id, "title")
  local title = t and t.title or ""
  -- The title check covers a restart that lost from_title while the label still mirrors the title.
  local derived = entry.from_title or is_default(base) or (title ~= "" and base == title)

  local label
  if not best then
    label = derived and "" or base
    entry.from_title = nil
  else
    local e = best.state == "blocked" and (blocked_glyph[best.kind] or blocked_glyph.permission) or glyph[best.state]
    if derived then
      if title == "" then title = is_default(base) and "" or base end
      label = title == "" and e or (e .. " " .. title)
      entry.from_title = true
    else
      label = e .. " " .. base
    end
  end

  seen[w.window_id] = next(entry) and entry or nil
  save_seen(seen)

  -- The server swaps "" for the default label, so compare against that too.
  if label ~= current and not (label == "" and is_default(current)) then
    rex.session.set_window_label{ session_id = session_id, window_id = w.window_id, label = label }
  end
end

local function window_of(view, block_id)
  for _, w in ipairs(view and view.windows or {}) do
    for _, id in ipairs(terminals(w)) do
      if id == block_id then return w end
    end
  end
end

-- A script only gets views of sessions its stream is attached to, so attach on a miss.
local function view_of(session_id)
  local view = rex.session.view{ session_id = session_id }
  if view then return view end
  rex.call("session.attach", { session_id = session_id })
  return rex.session.view{ session_id = session_id }
end

local function sweep(session_id)
  local view = view_of(session_id)
  for _, w in ipairs(view and view.windows or {}) do relabel(session_id, w, view.active_window_id) end
end

local function sessions()
  local list = rex.call("session.list", {})
  return list and list.sessions or {}
end

if rex.after and os.getenv("TAB_STATUS_CLEAN") then
  -- Uninstall: put every prefixed label back the way it would be without us.
  local seen = load_seen()
  for _, s in ipairs(sessions()) do
    local view = view_of(s.session_id)
    for _, w in ipairs(view and view.windows or {}) do
      local current = w.label or ""
      local base = strip(current)
      if base ~= current then
        local t = w.focused_block_id and method(s.session_id, w.focused_block_id, "title")
        local derived = (seen[w.window_id] or {}).from_title or is_default(base) or (t and t.title == base)
        rex.session.set_window_label{ session_id = s.session_id, window_id = w.window_id, label = derived and "" or base }
      end
    end
  end
elseif rex.after then
  -- Running under `rex do`: follow events.
  local function on_block(ctx)
    local view = view_of(ctx.session_id)
    local w = window_of(view, ctx.block_id)
    if w then relabel(ctx.session_id, w, view.active_window_id) end
  end
  rex.on("terminal.program_status_changed", on_block)
  rex.on("terminal.program_status_removed", on_block)
  rex.on("terminal.title_changed", on_block)

  rex.on("active_window_changed", function(ctx, ev)
    local seen = load_seen()
    local entry = seen[ev.window_id] or {}
    entry.unread, entry.seen = nil, now()
    seen[ev.window_id] = entry
    save_seen(seen)
    sweep(ctx.session_id)
  end)

  rex.on("window_closed", function(ctx, ev)
    local seen = load_seen()
    seen[ev.window_id] = nil
    save_seen(seen)
  end)

  for _, s in ipairs(sessions()) do sweep(s.session_id) end
else
  -- Loaded from init.lua: the toggle action. install.sh binds it to a key in init.lua.
  rex.action{
    name  = "tab_seen_toggle",
    title = "Toggle Tab Seen",
    description = "Mark the current tab's finished work as seen, or as unseen again.",
    keywords = "read unread done status",
    run   = function(ctx)
      local view = view_of(ctx.session_id)
      local w = ctx.block_id and window_of(view, ctx.block_id)
      if not w then return end
      local seen = load_seen()
      local entry = seen[w.window_id] or {}
      local showing = worst(ctx.session_id, w, entry)
      if showing and showing.state == "done" then
        entry.unread, entry.seen = nil, now()
      else
        entry.unread = true
      end
      seen[w.window_id] = entry
      save_seen(seen)
      relabel(ctx.session_id, w, view.active_window_id)
    end,
  }
end
