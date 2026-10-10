# Forever Consumables 1.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A new WoW: Forever addon: a movable, collapsible bar with one secure button per consumable category; an arrow (or right click) picks the item, a left click uses it; everything about the bar is configurable in a Forever-Unit-Frames-style options window.

**Architecture:** Pure logic modules (Settings, Classify, Bags, Choice, Visibility, Layout) are tested in isolation against a lean Lua 5.1 mock of the WoW API. One UI module (Bar.lua) owns every secure frame and changes protected state only out of combat (deferred through `ns.AfterCombat`); collapsing runs as a secure click snippet so it also works in combat. The options window is copied from Forever Square Minimap (`Options/Style.lua`, `Options/Widgets.lua`, `OptionsPanel.lua`) and described by `Options.lua`.

**Tech Stack:** Lua 5.1 (as in the game), WoW: Forever client (Interface 16001, modern API: `C_Container`, `C_Item`, `C_Spell`, `MenuUtil`, secure templates), bash tooling (`install`, `tools/package`, `tests/run`).

## Global Constraints

- Repo: `~/Dokumente/ForeverConsumables`, remote `git@github.com:StephanRosin/forever-consumables.git`, branch `main`. Spec: `docs/specs/2026-10-10-forever-consumables-design.md`.
- Addon folder and TOC name: `ForeverConsumables`; title "Forever Consumables"; `## Interface: 16001`; `## Version: 1.0.0`.
- SavedVariables: `ForeverConsumablesProfiles` (account: profiles, language), `ForeverConsumablesChar` (character: active profile, `choice[cat]`, `collapsed`, probe output).
- Category keys and default order, exactly: `food, drink, healing, mana, potions, flasks, elixirs, protection, scrolls, bandages`.
- Secure frames (holder, bar, item buttons, toggle): attributes, points, size, show/hide only out of combat (`InCombatLockdown()` false) — except inside the toggle's secure `_onclick` snippet and the state driver.
- Item buttons: `SecureActionButtonTemplate`, `RegisterForClicks("AnyUp", "AnyDown")`, `type = "item"`, `item = "item:<id>"`. In right-click mode `*type2 = ""` (not `type2`), and `PostClick` acts only when `not down` and `not IsModifierKeyDown()`.
- Never `hooksecurefunc` on frame methods (Forever hides hooked frame methods from Blizzard's code); use `HookScript` or own scripts.
- Strings only through `ns.L`; four locales `enUS, deDE, esES, frFR` with the same keys (tested).
- Tests: `tests/run` runs every `tests/run_*.lua` with `lua5.1`, each in its own process. Run the single file you work on while working; the full `tests/run` at the end of each task.
- Code comments in English, plain sentences, matching the sibling Forever addons. Commits end with:
  ```
  Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01PSwcrtAz5yXQ5Kj9VjMsMo
  ```
- No credentials anywhere in the repo.

## File Structure

| File | Responsibility |
|---|---|
| `ForeverConsumables.toc` | load order, SavedVariables, compartment functions |
| `Locales/enUS.lua` + `deDE`, `esES`, `frFR` | strings; enUS defines `ns.L` and `ns.SetActiveLocale` |
| `Locale.lua` | language choice (copy of FSM) |
| `Core.lua` | `ns.On` event bus, `ns.AfterCombat`, `ns.Print`, `ns.GetAddOnMetadata`, slash command |
| `Profiles.lua` | profiles (copy of FSM) + `ns.CharDB()` |
| `Settings.lua` | setting definitions, defaults, validation, `Get/Set/OnChange`, category order, export/import codec |
| `Data/Items.lua` | curated item ID lists per category, conjured and buff-food sets |
| `Classify.lua` | item ID → categories; buff food; conjured |
| `Probe.lua` | `/fcon scan`, `/fcon ids` — dump client data into `ForeverConsumablesChar` |
| `Bags.lua` | scan bags → entries per category |
| `Choice.lua` | best item, resolve chosen vs automatic, per-character choice store |
| `Visibility.lua` | state driver string, environment (instance/taxi), alpha |
| `Layout.lua` | pure geometry of toggle, bar and button cells |
| `Bar.lua` | the secure frames, refresh/display, collapse, mover, events |
| `Picker.lua` | the pick menu and the button tooltip |
| `Options/Style.lua`, `Options/Widgets.lua`, `OptionsPanel.lua` | options window (copied from FSM) |
| `Media.lua` | font list (`ns.Media.Fonts()`), used by Style and Bar |
| `Options.lua` | the option pages |
| `MinimapButton.lua` | minimap button + addon compartment functions (copied from FSM) |
| `install`, `tools/package` | copy to AddOns / build zip (copied from FSM) |
| `tests/mock.lua`, `tests/run`, `tests/run_*.lua` | mock and tests |

---

### Task 1: Scaffold — TOC, core, locales, profiles, tooling, mock

**Files:**
- Create: `ForeverConsumables.toc`, `Core.lua`, `Locale.lua`, `Profiles.lua`, `Locales/enUS.lua`, `Locales/deDE.lua`, `Locales/esES.lua`, `Locales/frFR.lua`, `install`, `tools/package`, `tests/run`, `tests/mock.lua`, `tests/run_core.lua`, `.gitignore`

**Interfaces:**
- Produces: `ns.On(event, fn)`, `ns.AfterCombat(key, fn)`, `ns.Print(msg)`, `ns.GetAddOnMetadata(field)`, `ns.Slash[sub] = fn(rest)` (sub-commands table; empty sub opens options via `ns.Slash[""]`), `ns.DB()`, `ns.AccountDB()`, `ns.CharDB()`, `ns.ActiveProfile()`, `ns.ProfileList()`, `ns.SwitchProfile(name)`, `ns.DeleteProfile(name)`, `ns.AskProfileName()`, `ns.AskDeleteProfile()`, `ns.L`, `ns.Locale` (`Setting/Set/OnChange/CHOICES`).
- Mock API (`tests/mock.lua` returns `M`): `M.LoadAddon()` (loads every file of the TOC in order with `ADDON, ns`; returns `ns`), `M.check(label, got, want)`, `M.done()` (prints and exits), `M.Fire(event, ...)`, `M.Click(frame, mouse, down)`, `M.flush()` (runs `C_Timer` callbacks), `M.combat` (bool), `M.items`, `M.bags`, `M.level`, `M.drivers`, `M.menu`, `M.instance`, `M.taxi`, `M.byName`.

- [ ] **Step 1: TOC and `.gitignore`**

`ForeverConsumables.toc`:
```
## Interface: 16001
## Title: Forever Consumables
## Notes: A small bar for food, drink, potions, flasks, elixirs, scrolls and bandages.
## Notes-deDE: Eine kleine Leiste für Essen, Trinken, Tränke, Fläschchen, Elixiere, Schriftrollen und Verbände.
## Notes-esES: Una pequeña barra para comida, bebida, pociones, frascos, elixires, pergaminos y vendas.
## Notes-esMX: Una pequeña barra para comida, bebida, pociones, frascos, elixires, pergaminos y vendas.
## Notes-frFR: Une petite barre pour nourriture, boissons, potions, flacons, élixirs, parchemins et bandages.
## Version: 1.0.0
## IconTexture: Interface\Icons\INV_Potion_54
## AddonCompartmentFunc: ForeverConsumables_OnAddonCompartmentClick
## AddonCompartmentFuncOnEnter: ForeverConsumables_OnAddonCompartmentEnter
## AddonCompartmentFuncOnLeave: ForeverConsumables_OnAddonCompartmentLeave
## SavedVariables: ForeverConsumablesProfiles
## SavedVariablesPerCharacter: ForeverConsumablesChar

Locales\enUS.lua
Locales\deDE.lua
Locales\esES.lua
Locales\frFR.lua
Locale.lua
Core.lua
Profiles.lua
```
Later tasks append their files to this list (each task says where).

`.gitignore`:
```
dist/
.superpowers/
```

- [ ] **Step 2: Locales**

`Locales/enUS.lua` — copy the header of `~/Dokumente/ForeverSquareMinimap/Locales/enUS.lua` lines 1–25 (the `ns.Locales`, `ns.L` metatable and `ns.SetActiveLocale`) verbatim, then these strings (Task 1's; later tasks add theirs to all four files):
```lua
L.ADDON_NAME = "Forever Consumables"
L.MSG_LAST_PROFILE = "The last profile cannot be deleted."
L.LANGUAGE_AUTO = "Game language"
L.OPT_LANGUAGE = "Language"
L.POPUP_PROFILE_NAME = "Name of the new profile:"
L.POPUP_PROFILE_DELETE = "Really delete the profile \"%s\"?"
L.OPEN_OPTIONS = "Open options"
L.BUTTON_CLICK = "Click: options"
L.BUTTON_DRAG = "Drag: move the button"
L.INHERITED = "inherited"
L.RESET_OVERRIDE = "Reset"
L.SLASH_HELP = "/fcon — options · /fcon scan — record bag items · /fcon ids — check the item lists"
```
`deDE.lua`, `esES.lua`, `frFR.lua` start with
```lua
local _, ns = ...

local L = {}
ns.Locales.deDE = L   -- esES / frFR respectively
```
and translate every key:
- deDE: "Forever Consumables", "Das letzte Profil kann nicht gelöscht werden.", "Spielsprache", "Sprache", "Name des neuen Profils:", "Profil \"%s\" wirklich löschen?", "Optionen öffnen", "Klick: Optionen", "Ziehen: Knopf verschieben", "geerbt", "Zurücksetzen", "/fcon — Optionen · /fcon scan — Taschen erfassen · /fcon ids — Itemlisten prüfen"
- esES: "Forever Consumables", "El último perfil no se puede borrar.", "Idioma del juego", "Idioma", "Nombre del nuevo perfil:", "¿Borrar de verdad el perfil \"%s\"?", "Abrir opciones", "Clic: opciones", "Arrastrar: mover el botón", "heredado", "Restablecer", "/fcon — opciones · /fcon scan — registrar las bolsas · /fcon ids — comprobar las listas"
- frFR: "Forever Consumables", "Le dernier profil ne peut pas être supprimé.", "Langue du jeu", "Langue", "Nom du nouveau profil :", "Vraiment supprimer le profil \"%s\" ?", "Ouvrir les options", "Clic : options", "Glisser : déplacer le bouton", "hérité", "Réinitialiser", "/fcon — options · /fcon scan — relever les sacs · /fcon ids — vérifier les listes"

- [ ] **Step 3: `Locale.lua` and `Profiles.lua` from FSM**

```bash
cd ~/Dokumente/ForeverConsumables
cp ~/Dokumente/ForeverSquareMinimap/Locale.lua Locale.lua
cp ~/Dokumente/ForeverSquareMinimap/Profiles.lua Profiles.lua
sed -i 's/ForeverSquareMinimapProfiles/ForeverConsumablesProfiles/g; s/ForeverSquareMinimapChar/ForeverConsumablesChar/g; s/FOREVERSQUAREMINIMAP_/FOREVERCONSUMABLES_/g' Locale.lua Profiles.lua
```
Then edit `Profiles.lua`:
- Header comment: replace the FSM description ("map size, map position, the button column and the FPS/latency display") with "the bar's layout and look; the chosen items and the collapsed state are per character (ns.CharDB)".
- Replace the body of `local function applyLook()` with:
  ```lua
  local function applyLook()
      if ns.Settings and ns.Settings.Changed then ns.Settings.Changed(nil) end
  end
  ```
- After `function ns.AccountDB()` add:
  ```lua
  -- This character's own values: the chosen item per category, whether the
  -- bar is collapsed, the probe's output.
  function ns.CharDB()
      Init()
      return ForeverConsumablesChar
  end
  ```
Check with `grep -n "Square\|Minimap" Locale.lua Profiles.lua` — no hits may remain.

- [ ] **Step 4: `Core.lua`**

```lua
--[[---------------------------------------------------------------------------
Core.lua -- the event bus, work deferred until combat ends, chat output and
the slash command.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
ns.ADDON = ADDON

local handlers = {}
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(handlers[event]) do fn(...) end
end)

-- Several modules listen to the same event; each gets it in the order it
-- registered.
function ns.On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        events:RegisterEvent(event)
    end
    table.insert(handlers[event], fn)
end

-- Runs fn now, or once when combat ends. Protected frames cannot change in
-- combat; the latest fn per key wins, so repeated requests run once.
local pending = {}
function ns.AfterCombat(key, fn)
    if not InCombatLockdown() then
        pending[key] = nil
        fn()
        return
    end
    pending[key] = fn
end

ns.On("PLAYER_REGEN_ENABLED", function()
    local run = pending
    pending = {}
    for _, fn in pairs(run) do fn() end
end)

function ns.GetAddOnMetadata(field)
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return get and get(ADDON, field)
end

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff4fc3f7" .. ns.L.ADDON_NAME .. ":|r " .. tostring(msg))
end

-- Sub-commands: other files add theirs; "" opens the options.
ns.Slash = {}
SLASH_FOREVERCONSUMABLES1 = "/fcon"
SLASH_FOREVERCONSUMABLES2 = "/foreverconsumables"
SlashCmdList.FOREVERCONSUMABLES = function(msg)
    local sub, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    sub = (sub or ""):lower()
    local fn = ns.Slash[sub]
    if fn then fn(rest) else ns.Print(ns.L.SLASH_HELP) end
end
```
Append `Core.lua` already listed in the TOC (Step 1).

- [ ] **Step 5: `install`, `tools/package`, `tests/run`**

```bash
cp ~/Dokumente/ForeverSquareMinimap/install install
mkdir -p tools && cp ~/Dokumente/ForeverSquareMinimap/tools/package tools/package
sed -i 's/ForeverSquareMinimap/ForeverConsumables/g' install tools/package
chmod +x install tools/package
```
`tests/run`:
```bash
#!/usr/bin/env bash
# Runs the tests with Lua 5.1, as in the game; each file in its own process.
#   tests/run            all files
#   tests/run classify   only tests/run_classify.lua
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
ROOT="$(cd "$HERE/.." && pwd)"
status=0
for t in run_*.lua; do
    if [ -n "${1:-}" ] && [ "$t" != "run_$1.lua" ]; then continue; fi
    lua5.1 -e "ADDONDIR='$ROOT'" "$t" || status=1
done
exit $status
```
`chmod +x tests/run`.

- [ ] **Step 6: `tests/mock.lua`**

A lean mock; later tasks extend it where they need more. Write it in full:
```lua
-- A mock of the WoW API, just enough for Forever Consumables. Lua 5.1, as in the game.
local M = { frames = {}, byName = {}, chat = {}, timers = {}, drivers = {}, menu = nil,
            items = {}, bags = {}, level = 60, combat = false, instance = false, taxi = false,
            dead = false, cooldowns = {}, spells = {}, popups = {}, used = {} }
local pass, fail = 0, 0

function M.check(label, got, want)
    if got == want then
        pass = pass + 1
    else
        fail = fail + 1
        print(("  FAIL %-50s -> %s   (want: %s)"):format(label, tostring(got), tostring(want)))
    end
end

function M.done()
    print(("%d passed, %d failed"):format(pass, fail))
    os.exit(fail == 0 and 0 or 1)
end

-- Widgets: unknown CamelCase methods are no-ops; anything else is data.
local widget = {}
widget.__index = function(t, k)
    if type(k) ~= "string" or not k:match("^%u") then return nil end
    local f = function() end
    rawset(t, k, f)
    return f
end

-- Protected frames refuse changes in combat, except from a secure snippet.
local function guard(self, what)
    if self._protected and M.combat and not M.secureRun then
        error(("protected %s:%s in combat"):format(tostring(self._name), what), 3)
    end
end

local function newWidget(name, template)
    local w = setmetatable({ _name = name, _scripts = {}, _events = {}, _attrs = {}, _refs = {},
                             _w = 10, _h = 10, _shown = true, _alpha = 1, _scale = 1, _enabled = true }, widget)
    w._protected = template ~= nil and template:find("Secure") ~= nil
    function w:GetName() return self._name end
    function w:SetScript(s, fn) self._scripts[s] = fn end
    function w:GetScript(s) return self._scripts[s] end
    function w:HookScript(s, fn)
        local old = self._scripts[s]
        self._scripts[s] = function(...) if old then old(...) end fn(...) end
    end
    function w:SetSize(a, b) guard(self, "SetSize"); self._w, self._h = a, b end
    function w:SetWidth(a) guard(self, "SetWidth"); self._w = a end
    function w:SetHeight(b) guard(self, "SetHeight"); self._h = b end
    function w:GetWidth() return self._w end
    function w:GetHeight() return self._h end
    function w:Show() guard(self, "Show"); self._shown = true end
    function w:Hide() guard(self, "Hide"); self._shown = false end
    function w:SetShown(v) if v then self:Show() else self:Hide() end end
    function w:IsShown() return self._shown end
    function w:IsVisible()
        local f = self
        while f do if not f._shown then return false end f = f._parent end
        return true
    end
    function w:SetAlpha(v) self._alpha = v end
    function w:GetAlpha() return self._alpha end
    function w:SetScale(v) guard(self, "SetScale"); self._scale = v end
    function w:GetScale() return self._scale end
    function w:GetEffectiveScale() return self._scale end
    function w:SetPoint(p, rel, p2, x, y)
        guard(self, "SetPoint")
        if type(rel) == "number" then x, y, rel, p2 = rel, p2, nil, nil end
        self._point = { p, rel, p2, x, y }
    end
    function w:GetPoint() local a = self._point; if a then return a[1], a[2], a[3], a[4], a[5] end end
    function w:ClearAllPoints() guard(self, "ClearAllPoints"); self._point = nil end
    function w:SetAllPoints(rel) self._allPoints = rel or true end
    function w:SetAttribute(k, v) guard(self, "SetAttribute"); self._attrs[k] = v end
    function w:GetAttribute(k) return self._attrs[k] end
    function w:SetFrameRef(k, f) self._refs[k] = f end
    function w:GetFrameRef(k) return self._refs[k] end
    function w:RegisterEvent(e) self._events[e] = true end
    function w:UnregisterEvent(e) self._events[e] = nil end
    function w:RegisterForClicks(...) self._clicks = { ... } end
    function w:RegisterForDrag(...) self._drag = { ... } end
    function w:Enable() self._enabled = true end
    function w:Disable() self._enabled = false end
    function w:SetEnabled(v) self._enabled = v and true or false end
    function w:IsEnabled() return self._enabled end
    function w:SetParent(p) self._parent = p end
    function w:GetParent() return self._parent end
    function w:SetText(t) self._text = t end
    function w:GetText() return self._text end
    function w:SetMovable(v) self._movable = v end
    function w:EnableMouse(v) self._mouse = v end
    function w:IsMouseOver() return self._mouseOver or false end
    function w:CreateTexture()
        local t = newWidget()
        t._parent = self
        function t:SetTexture(f) self._texture = f end
        function t:GetTexture() return self._texture end
        function t:SetColorTexture(r, g, b, a) self._color = { r, g, b, a } end
        function t:SetVertexColor(r, g, b, a) self._vertex = { r, g, b, a } end
        function t:SetDesaturated(v) self._desaturated = v and true or false end
        function t:IsDesaturated() return self._desaturated or false end
        function t:SetTexCoord(...) self._coords = { ... } end
        return t
    end
    function w:CreateFontString()
        local fs = newWidget()
        fs._parent = self
        fs._font = { "Fonts\\FRIZQT__.TTF", 12, "" }
        function fs:SetFont(path, size, flags) self._font = { path, size, flags } end
        function fs:GetFont() return self._font[1], self._font[2], self._font[3] end
        function fs:SetTextColor(r, g, b, a) self._textColor = { r, g, b, a } end
        function fs:GetStringWidth() return #tostring(self._text or "") * 6 end
        function fs:GetStringHeight() return self._font[2] end
        return fs
    end
    function w:SetCooldown(start, duration) self._cooldown = { start, duration } end
    function w:Clear() self._cooldown = nil end
    return w
end
M.newWidget = newWidget

function CreateFrame(kind, name, parent, template)
    local f = newWidget(name, template)
    f._kind, f._template = kind, template
    f._parent = parent
    table.insert(M.frames, f)
    if name then M.byName[name] = f; _G[name] = f end
    return f
end

function M.Fire(event, ...)
    for _, f in ipairs(M.frames) do
        local h = f._events[event] and f:GetScript("OnEvent")
        if h then h(f, event, ...) end
    end
end

function M.flush()
    local run = M.timers
    M.timers = {}
    for _, fn in ipairs(run) do fn() end
end

-- A click as the client does it: secure handler snippets (_onclick) run in
-- a restricted environment that may change protected frames; secure action
-- buttons "use" their item (recorded in M.used) unless the button's type is
-- the no-op "". Then PostClick.
function M.Click(f, mouse, down)
    mouse = mouse or "LeftButton"
    local snippet = f:GetAttribute("_onclick")
    if snippet then
        local fn = assert(loadstring("local self, button, down = ...\n" .. snippet))
        M.secureRun = true
        fn(f, mouse, down)
        M.secureRun = false
    elseif f._template and f._template:find("SecureActionButtonTemplate") and not down then
        local suffix = mouse == "RightButton" and "2" or "1"
        local kind = f:GetAttribute("*type" .. suffix)
        if kind == nil then kind = f:GetAttribute("type" .. suffix) end
        if kind == nil then kind = f:GetAttribute("type") end
        if kind == "item" then M.used[#M.used + 1] = f:GetAttribute("item") end
    end
    local post = f:GetScript("PostClick")
    if post then post(f, mouse, down) end
end

function InCombatLockdown() return M.combat end
function M.setCombat(on)
    M.combat = on
    M.Fire(on and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
end

function RegisterStateDriver(f, state, driver)
    if M.combat then error("RegisterStateDriver in combat", 2) end
    M.drivers[f] = M.drivers[f] or {}
    M.drivers[f][state] = driver
end
function UnregisterStateDriver(f, state) if M.drivers[f] then M.drivers[f][state] = nil end end

function IsModifierKeyDown() return M.modifier or false end
function GetLocale() return M.locale or "enUS" end
function UnitLevel() return M.level end
function UnitOnTaxi() return M.taxi end
function UnitIsDeadOrGhost() return M.dead end
function IsInInstance()
    if M.instance then return true, M.instance end
    return false, "none"
end
function GetTime() return M.now or 1000 end
NUM_BAG_SLOTS = 4

C_Timer = { After = function(_, fn) table.insert(M.timers, fn) end }

-- Items: M.items[id] = { name, icon, classID, subclassID, spell, spellID,
-- minLevel, itemLevel, desc }; M.bags[id] = count, laid out bag 0 slot 1..n.
local function slots()
    local list = {}
    for id, count in pairs(M.bags) do if count > 0 then list[#list + 1] = id end end
    table.sort(list)
    return list
end
C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and #slots() or 0 end,
    GetContainerItemInfo = function(bag, slot)
        local id = bag == 0 and slots()[slot]
        if not id then return nil end
        local it = M.items[id] or {}
        return { itemID = id, stackCount = M.bags[id], iconFileID = it.icon, itemName = it.name }
    end,
    GetItemCooldown = function(id)
        local c = M.cooldowns[id]
        if c then return c[1], c[2], 1 end
        return 0, 0, 1
    end,
}
C_Item = {
    GetItemInfoInstant = function(id)
        local it = M.items[id]
        if not it then return nil end
        return id, "Consumable", "", "", it.icon, it.classID or 0, it.subclassID or 0
    end,
    GetItemInfo = function(id)
        local it = M.items[id]
        if not it then return nil end
        return it.name, "item:" .. id, 1, it.itemLevel or 1, it.minLevel or 0, "Consumable", "", 20, "",
            it.icon, 0, it.classID or 0, it.subclassID or 0
    end,
    GetItemSpell = function(id)
        local it = M.items[id]
        if it and it.spell then return it.spell, it.spellID end
    end,
    GetItemCount = function(id) return M.bags[id] or 0 end,
    RequestLoadItemDataByID = function() end,
}
-- Spell names by ID in the client's language (M.spells[id] = name).
C_Spell = {
    GetSpellName = function(id) return M.spells[id] end,
    GetSpellDescription = function(id)
        for _, it in pairs(M.items) do if it.spellID == id then return it.desc or "" end end
        return ""
    end,
}
C_AddOns = { GetAddOnMetadata = function(_, field) if field == "Version" then return "1.0.0" end end }

-- Blizzard's menu: the generator runs at once against a recording root.
local function newDescription(text, kind)
    local d = { text = text, kind = kind, enabled = true, children = {} }
    function d:SetEnabled(v) self.enabled = v end
    function d:AddInitializer() end
    function d:SetTooltip() end
    return d
end
local function newRoot()
    local root = newDescription(nil, "root")
    function root:CreateTitle(text) local d = newDescription(text, "title"); table.insert(self.children, d); return d end
    function root:CreateDivider() table.insert(self.children, newDescription(nil, "divider")) end
    function root:CreateButton(text, onClick)
        local d = newDescription(text, "button"); d.onClick = onClick; table.insert(self.children, d); return d
    end
    function root:CreateRadio(text, isSelected, setSelected, data)
        local d = newDescription(text, "radio")
        d.isSelected, d.setSelected, d.data = isSelected, setSelected, data
        table.insert(self.children, d)
        return d
    end
    function root:CreateCheckbox(text, isSelected, setSelected, data)
        local d = newDescription(text, "checkbox")
        d.isSelected, d.setSelected, d.data = isSelected, setSelected, data
        table.insert(self.children, d)
        return d
    end
    return root
end
MenuUtil = {
    CreateContextMenu = function(owner, generator)
        local root = newRoot()
        generator(owner, root)
        M.menu = { owner = owner, root = root }
        return M.menu
    end,
}

UIParent = newWidget("UIParent")
UIParent._w, UIParent._h = 1920, 1080
function UIParent:GetLeft() return 0 end
function UIParent:GetBottom() return 0 end
Minimap = newWidget("Minimap")
GameTooltip = newWidget("GameTooltip")
function GameTooltip:SetOwner(o) self._owner = o; self._lines = {} end
function GameTooltip:SetItemByID(id) self._item = id; self._lines = { (M.items[id] or {}).name } end
function GameTooltip:SetText(t) self._lines = { t } end
function GameTooltip:AddLine(t) self._lines = self._lines or {}; table.insert(self._lines, t) end
function GameTooltip:IsOwned(o) return self._owner == o end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) table.insert(M.chat, m) end }
SlashCmdList = {}
StaticPopupDialogs = {}
function StaticPopup_Show(which, a, b, data)
    M.popups[#M.popups + 1] = { which = which, arg = a, data = data }
end
UISpecialFrames = {}

-- Loads every file of the TOC, in order, as the client would.
function M.LoadAddon()
    local ns = {}
    local root = ADDONDIR
    for line in io.lines(root .. "/ForeverConsumables.toc") do
        line = line:gsub("\r", "")
        if line ~= "" and not line:match("^#") then
            assert(loadfile(root .. "/" .. line:gsub("\\", "/")))("ForeverConsumables", ns)
        end
    end
    M.ns = ns
    return ns
end

return M
```

- [ ] **Step 7: `tests/run_core.lua` (the failing test first)**

```lua
-- Core: event bus, deferred work, slash command, locales, profiles.
local M = dofile("mock.lua")
print("Core, locales, profiles")
local ns = M.LoadAddon()

-- AfterCombat runs at once out of combat, once after combat in it.
local runs = 0
ns.AfterCombat("x", function() runs = runs + 1 end)
M.check("out of combat: at once", runs, 1)
M.setCombat(true)
ns.AfterCombat("x", function() runs = runs + 1 end)
ns.AfterCombat("x", function() runs = runs + 10 end)
M.check("in combat: waits", runs, 1)
M.setCombat(false)
M.check("after combat: the latest once", runs, 11)

-- Slash: unknown sub prints the help.
SlashCmdList.FOREVERCONSUMABLES("nonsense")
M.check("help printed", M.chat[#M.chat]:find("/fcon", 1, true) ~= nil, true)

-- Every language has the same keys as English.
local function keys(t) local k = {} for key in pairs(t) do k[#k + 1] = key end table.sort(k) return table.concat(k, ",") end
local en = keys(ns.Locales.enUS)
for _, code in ipairs({ "deDE", "esES", "frFR" }) do
    M.check("same keys: " .. code, keys(ns.Locales[code]), en)
end

-- Profiles: a character starts on Default; CharDB is its own.
M.Fire("ADDON_LOADED", "ForeverConsumables")
M.check("default profile", ns.ActiveProfile(), "Default")
ns.DB().size = 40
ns.SwitchProfile("Raid")
M.check("save as copies", ns.DB().size, 40)
M.check("char db", type(ns.CharDB()), "table")

M.done()
```

- [ ] **Step 8: Run, fix until green**

Run: `tests/run core`
Expected first: failures only where the copy needs adjusting; then `N passed, 0 failed`. Extend the mock where a copied file calls something missing (keep the "unknown CamelCase = no-op" rule).

- [ ] **Step 9: Commit**

```bash
git add -A && git commit -m "Scaffold: TOC, core, locales, profiles, tooling, mock"
```

---

### Task 2: Settings, category order, export/import

**Files:**
- Create: `Settings.lua`, `tests/run_settings.lua`
- Modify: `ForeverConsumables.toc` (append `Settings.lua` after `Profiles.lua`), all four locales

**Interfaces:**
- Consumes: `ns.DB()`, `ns.L`.
- Produces: `Settings.CATEGORIES` (array), `Settings.POINTS` (array), `Settings.Def(key)` → def table, `Settings.Get(key)`, `Settings.Set(key, value)` → bool (false when invalid), `Settings.OnChange(fn)` (fn(key|nil)), `Settings.Changed(key)` (fires listeners; `nil` = everything), `Settings.Order()` → array of category keys, `Settings.Position(cat)` → 1-based index, `Settings.MoveTo(cat, index)`, `Settings.Export()` → string, `Settings.Import(str)` → `true` or `false, errorKey`.

- [ ] **Step 1: Failing test `tests/run_settings.lua`**

```lua
-- Settings: defaults, validation, order, export/import.
local M = dofile("mock.lua")
print("Settings")
local ns = M.LoadAddon()
local S = ns.Settings

M.check("default size", S.Get("size"), 36)
M.check("default mode", S.Get("visMode"), "ALWAYS")
M.check("default category on", S.Get("show_food"), true)
M.check("default colour alpha", S.Get("backgroundColor")[4], 0.5)

local changed
S.OnChange(function(key) changed = key end)
M.check("set valid", S.Set("size", 40), true)
M.check("stored", S.Get("size"), 40)
M.check("listener", changed, "size")
M.check("clamped high", (S.Set("size", 999) and S.Get("size")), 64)
M.check("rounded", (S.Set("size", 30.6) and S.Get("size")), 31)
M.check("wrong type refused", S.Set("size", "big"), false)
M.check("enum refused", S.Set("visMode", "SOMETIMES"), false)
M.check("enum kept", S.Get("visMode"), "ALWAYS")
M.check("colour refused", S.Set("borderColor", { 1, 2 }), false)

-- Order: default, moving, unknown and missing keys.
M.check("default order", table.concat(S.Order(), ","),
    "food,drink,healing,mana,potions,flasks,elixirs,protection,scrolls,bandages")
S.MoveTo("bandages", 1)
M.check("moved to front", S.Order()[1], "bandages")
M.check("position", S.Position("food"), 2)
ns.DB().order = "mana,junk,mana,food"
M.check("cleaned order", table.concat(S.Order(), ","),
    "mana,food,drink,healing,potions,flasks,elixirs,protection,scrolls,bandages")

-- Export / import round trip.
S.Set("visMode", "COMBAT")
S.Set("borderColor", { 1, 0, 0, 1 })
S.Set("countFont", "Arial; Narrow=1")
local text = S.Export()
M.check("export prefix", text:sub(1, 4), "FC1;")
ns.SwitchProfile("Other")
S.Set("visMode", "NEVER")
M.check("import ok", (S.Import(text)), true)
M.check("import mode", S.Get("visMode"), "COMBAT")
M.check("import colour", S.Get("borderColor")[1], 1)
M.check("import text escaped", S.Get("countFont"), "Arial; Narrow=1")
M.check("import order", S.Order()[1], "mana")
local ok, err = S.Import("garbage")
M.check("bad import refused", ok, false)
M.check("bad import reason", err, "IMPORT_FORMAT")
M.check("bad import keeps profile", S.Get("visMode"), "COMBAT")
M.check("unknown keys skipped", (S.Import("FC1;nosuch=1;size=50")), true)
M.check("known key after unknown", S.Get("size"), 50)

M.done()
```

- [ ] **Step 2: Run, see it fail** — `tests/run settings` → error "attempt to index nil (Settings)".

- [ ] **Step 3: `Settings.lua`**

```lua
--[[---------------------------------------------------------------------------
Settings.lua -- every setting of the bar: its type, default and limits, read
and written through the active profile (Profiles.lua). Invalid values are
refused, numbers clamped and rounded. Also the order of the categories and
the profile as text for export and import.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...

local Settings = {}
ns.Settings = Settings

Settings.CATEGORIES = { "food", "drink", "healing", "mana", "potions", "flasks", "elixirs", "protection",
    "scrolls", "bandages" }
Settings.POINTS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }

local DEFS = {
    -- The bar
    { key = "orientation", type = "enum", values = { "HORIZONTAL", "VERTICAL" }, default = "HORIZONTAL" },
    { key = "perRow", type = "int", min = 1, max = 10, default = 10 },
    { key = "size", type = "int", min = 20, max = 64, default = 36 },
    { key = "spacing", type = "int", min = 0, max = 20, default = 4 },
    { key = "scale", type = "int", min = 50, max = 200, default = 100 },
    { key = "borderShow", type = "bool", default = true },
    { key = "borderSize", type = "int", min = 1, max = 4, default = 1 },
    { key = "borderColor", type = "color", default = { 0, 0, 0, 1 } },
    { key = "backgroundShow", type = "bool", default = true },
    { key = "backgroundColor", type = "color", default = { 0, 0, 0, 0.5 } },
    { key = "point", type = "enum", values = Settings.POINTS, default = "CENTER" },
    { key = "x", type = "int", min = -2000, max = 2000, default = 0 },
    { key = "y", type = "int", min = -2000, max = 2000, default = -200 },
    { key = "locked", type = "bool", default = true },
    -- Visibility
    { key = "visMode", type = "enum", values = { "ALWAYS", "COMBAT", "NOCOMBAT", "NEVER" }, default = "ALWAYS" },
    { key = "visInstance", type = "bool", default = false },
    { key = "visGroup", type = "bool", default = false },
    { key = "visHideDead", type = "bool", default = true },
    { key = "visHideTaxi", type = "bool", default = true },
    { key = "alphaCombat", type = "int", min = 0, max = 100, default = 100 },
    { key = "alphaNoCombat", type = "int", min = 0, max = 100, default = 100 },
    { key = "fadeMouseover", type = "bool", default = false },
    -- Display
    { key = "countFont", type = "text", default = "DEFAULT" },
    { key = "countSize", type = "int", min = 6, max = 24, default = 12 },
    { key = "countOutline", type = "enum", values = { "NONE", "OUTLINE", "THICKOUTLINE" }, default = "OUTLINE" },
    { key = "countColor", type = "color", default = { 1, 1, 1, 1 } },
    { key = "countPoint", type = "enum", values = Settings.POINTS, default = "BOTTOMRIGHT" },
    { key = "countX", type = "int", min = -30, max = 30, default = -2 },
    { key = "countY", type = "int", min = -30, max = 30, default = 2 },
    { key = "arrowMode", type = "enum", values = { "RIGHT", "BELOW", "RIGHTCLICK" }, default = "RIGHT" },
    { key = "tooltip", type = "bool", default = true },
    -- Categories
    { key = "hideEmpty", type = "bool", default = true },
    { key = "order", type = "text", default = table.concat(Settings.CATEGORIES, ",") },
    -- Minimap button
    { key = "minimapShow", type = "bool", default = true },
    { key = "minimapAngle", type = "int", min = 0, max = 359, default = 225 },
}
for _, cat in ipairs(Settings.CATEGORIES) do
    DEFS[#DEFS + 1] = { key = "show_" .. cat, type = "bool", default = true }
end

local byKey = {}
for _, def in ipairs(DEFS) do byKey[def.key] = def end

function Settings.Def(key) return byKey[key] end
function Settings.All() return DEFS end

local function copy(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, x in pairs(v) do c[k] = x end
    return c
end

-- The value to store, or nil when v is not one of def's values.
local function validate(def, v)
    local t = def.type
    if t == "int" then
        if type(v) ~= "number" or v ~= v then return nil end
        v = math.floor(v + 0.5)
        return math.max(def.min, math.min(def.max, v))
    elseif t == "bool" then
        if type(v) == "boolean" then return v end
    elseif t == "enum" then
        for _, name in ipairs(def.values) do if name == v then return v end end
    elseif t == "color" then
        if type(v) ~= "table" or #v ~= 4 then return nil end
        for i = 1, 4 do
            if type(v[i]) ~= "number" or v[i] < 0 or v[i] > 1 then return nil end
        end
        return { v[1], v[2], v[3], v[4] }
    elseif t == "text" then
        if type(v) == "string" then return v end
    end
    return nil
end
Settings.Validate = validate

function Settings.Get(key)
    local def = byKey[key]
    if not def then return nil end
    local v = ns.DB()[key]
    if v ~= nil and validate(def, v) ~= nil then return copy(v) end
    return copy(def.default)
end

local listeners = {}
function Settings.OnChange(fn) listeners[#listeners + 1] = fn end

function Settings.Changed(key)
    for _, fn in ipairs(listeners) do fn(key) end
end

function Settings.Set(key, value)
    local def = byKey[key]
    local v = def and validate(def, value)
    if v == nil then return false end
    ns.DB()[key] = v
    Settings.Changed(key)
    return true
end

-- Category order -----------------------------------------------------------

-- The stored order without unknown or repeated keys; categories it lacks
-- follow in their default order, so an older profile gains new ones.
function Settings.Order()
    local list, seen = {}, {}
    local known = {}
    for _, cat in ipairs(Settings.CATEGORIES) do known[cat] = true end
    for cat in tostring(Settings.Get("order")):gmatch("[^,]+") do
        if known[cat] and not seen[cat] then list[#list + 1] = cat; seen[cat] = true end
    end
    for _, cat in ipairs(Settings.CATEGORIES) do
        if not seen[cat] then list[#list + 1] = cat end
    end
    return list
end

function Settings.Position(cat)
    for i, c in ipairs(Settings.Order()) do if c == cat then return i end end
end

function Settings.MoveTo(cat, index)
    local list = Settings.Order()
    local from = Settings.Position(cat)
    if not from then return end
    index = math.max(1, math.min(#list, math.floor(index)))
    table.remove(list, from)
    table.insert(list, index, cat)
    Settings.Set("order", table.concat(list, ","))
end

-- Export / import -----------------------------------------------------------
-- "FC1;key=value;..." with only the values the profile holds. Text escapes
-- %, ; and = as %XX.

local FORMAT = "FC1"

local function escape(s)
    return (s:gsub("[%%;=]", function(c) return ("%%%02X"):format(c:byte()) end))
end
local function unescape(s)
    return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end
local function hex(c) return ("%02x"):format(math.floor(c * 255 + 0.5)) end

local function encode(def, v)
    local t = def.type
    if t == "int" then return ("%d"):format(v) end
    if t == "bool" then return v and "1" or "0" end
    if t == "enum" then return v end
    if t == "color" then return "#" .. hex(v[1]) .. hex(v[2]) .. hex(v[3]) .. hex(v[4]) end
    return escape(v)
end

local function decode(def, raw)
    local t = def.type
    if t == "int" then return raw:match("^%-?%d+$") and tonumber(raw) end
    if t == "bool" then
        if raw == "1" then return true elseif raw == "0" then return false end
        return nil
    end
    if t == "enum" then return raw end
    if t == "color" then
        local r, g, b, a = raw:match("^#(%x%x)(%x%x)(%x%x)(%x%x)$")
        if not r then return nil end
        return { tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255, tonumber(a, 16) / 255 }
    end
    return unescape(raw)
end

function Settings.Export()
    local db, parts = ns.DB(), {}
    for _, def in ipairs(DEFS) do
        local v = db[def.key]
        if v ~= nil and validate(def, v) ~= nil then
            parts[#parts + 1] = def.key .. "=" .. encode(def, v)
        end
    end
    table.sort(parts)
    table.insert(parts, 1, FORMAT)
    return table.concat(parts, ";")
end

-- Replaces the active profile's values with the string's. Unknown keys
-- (a newer version's) are skipped; a string that is not ours changes
-- nothing.
function Settings.Import(str)
    if type(str) ~= "string" then return false, "IMPORT_FORMAT" end
    str = str:gsub("^%s+", ""):gsub("%s+$", "")
    if str:sub(1, #FORMAT + 1) ~= FORMAT .. ";" and str ~= FORMAT then return false, "IMPORT_FORMAT" end
    local values = {}
    for entry in str:sub(#FORMAT + 2):gmatch("[^;]+") do
        local key, raw = entry:match("^([%w_]+)=(.*)$")
        local def = key and byKey[key]
        local v = def and decode(def, raw)
        v = v ~= nil and validate(def, v) or nil
        if v ~= nil then values[key] = v end
    end
    local db = ns.DB()
    for k in pairs(db) do db[k] = nil end
    for k, v in pairs(values) do db[k] = v end
    Settings.Changed(nil)
    return true
end
```
Add the locale key `IMPORT_FORMAT` to all four locales: en "This is not a Forever Consumables profile.", de "Das ist kein Forever-Consumables-Profil.", es "Esto no es un perfil de Forever Consumables.", fr "Ceci n'est pas un profil Forever Consumables.". Append `Settings.lua` to the TOC after `Profiles.lua`.

- [ ] **Step 4: Run** `tests/run settings` → `0 failed`; `tests/run` all green.

- [ ] **Step 5: Commit** `git add -A && git commit -m "Settings: definitions, validation, category order, export/import"`

---

### Task 3: Item lists, classification, probe

**Files:**
- Create: `Data/Items.lua`, `Classify.lua`, `Probe.lua`, `tests/run_classify.lua`
- Modify: TOC (append `Data\Items.lua`, `Classify.lua`, `Probe.lua` after `Settings.lua`), locales

**Interfaces:**
- Consumes: `ns.Settings.CATEGORIES`, `ns.Slash`, `ns.CharDB()`, `ns.Print`.
- Produces: `ns.Items.LISTS[cat]` (array of IDs), `ns.Items.CATEGORY[id]` → array of cats, `ns.Items.CONJURED[id]`, `ns.Items.BUFF_FOOD[id]`; `Classify.Of(id)` → array of cats (possibly empty), `Classify.IsBuffFood(id)` → bool, `Classify.IsConjured(id)` → bool, `Classify.SPELLS` (reference spell IDs), `Classify.Reset()`.

- [ ] **Step 1: Failing test `tests/run_classify.lua`**

```lua
-- Which category an item belongs to.
local M = dofile("mock.lua")
print("Classification")
-- Reference spells in the client's language.
M.spells = { [433] = "Food", [430] = "Drink", [167152] = "Refreshment", [441] = "Healing Potion",
    [437] = "Restore Mana", [746] = "First Aid", [19705] = "Well Fed" }
M.items = {
    [4599] = { name = "Cured Ham Steak", spell = "Food", spellID = 1131 },
    [8766] = { name = "Morning Glory Dew", spell = "Drink", spellID = 1137 },
    [90001] = { name = "Mage Biscuit", spell = "Refreshment", spellID = 900 },
    [13446] = { name = "Major Healing Potion", subclassID = 1, spell = "Healing Potion" },
    [90002] = { name = "Unknown Healing Draught", spell = "Healing Potion" },
    [90003] = { name = "Unknown Mana Draught", spell = "Restore Mana" },
    [90004] = { name = "Frenzy Potion", subclassID = 1, spell = "Frenzy" },
    [90005] = { name = "Some Elixir", subclassID = 2, spell = "Strength" },
    [90006] = { name = "Some Flask", subclassID = 3 },
    [90007] = { name = "Some Scroll", subclassID = 4 },
    [90008] = { name = "Some Bandage", spell = "First Aid" },
    [90009] = { name = "Hearthstone", classID = 15 },
    [90010] = { name = "Unused Consumable", subclassID = 0, spell = "Something" },
    [12451] = { name = "Juju Power", subclassID = 0, spell = "Juju Power" },
    [18253] = { name = "Major Rejuvenation Potion", subclassID = 1, spell = "Rejuvenation" },
    [21023] = { name = "Dirge's Chops", spell = "Food", spellID = 9001 },
    [90011] = { name = "Spicy Thing", spell = "Food", spellID = 9002, desc = "If you spend 10 seconds eating you will become well fed." },
    [5350] = { name = "Conjured Water", spell = "Drink" },
}
local ns = M.LoadAddon()
local C = ns.Classify
local function of(id) return table.concat(C.Of(id), ",") end

M.check("food by spell", of(4599), "food")
M.check("drink by spell", of(8766), "drink")
M.check("refreshment in both", of(90001), "food,drink")
M.check("healing potion by spell", of(90002), "healing")
M.check("mana potion by spell", of(90003), "mana")
M.check("listed healing potion", of(13446), "healing")
M.check("other potion -> potions", of(90004), "potions")
M.check("elixir by subclass", of(90005), "elixirs")
M.check("flask by subclass", of(90006), "flasks")
M.check("scroll by subclass", of(90007), "scrolls")
M.check("bandage by spell", of(90008), "bandages")
M.check("not a consumable", of(90009), "")
M.check("leftover not shown", of(90010), "")
M.check("listed juju -> elixirs", of(12451), "elixirs")
M.check("rejuvenation in both", of(18253), "healing,mana")
M.check("buff food listed", C.IsBuffFood(21023), true)
M.check("buff food by description", C.IsBuffFood(90011), true)
M.check("plain food is not buff food", C.IsBuffFood(4599), false)
M.check("conjured listed", C.IsConjured(5350), true)
M.check("not conjured", C.IsConjured(8766), false)

-- Every category key used in the lists is a real category.
local known = {}
for _, cat in ipairs(ns.Settings.CATEGORIES) do known[cat] = true end
local bad = 0
for cat in pairs(ns.Items.LISTS) do if not known[cat] then bad = bad + 1 end end
M.check("list keys are categories", bad, 0)

-- The probe stores the bag items with their data.
M.bags = { [4599] = 5, [13446] = 3 }
SlashCmdList.FOREVERCONSUMABLES("scan")
local scan = ns.CharDB().scan
M.check("scan stored", scan and #scan, 2)
M.check("scan has categories", scan[2].cats, "healing")
SlashCmdList.FOREVERCONSUMABLES("ids")
M.flush()
M.check("ids checked: known", ns.CharDB().ids[13446], "Major Healing Potion")
M.check("ids checked: unknown", ns.CharDB().ids[13510], false)

M.done()
```

- [ ] **Step 2: Run, see it fail** — `tests/run classify`.

- [ ] **Step 3: `Data/Items.lua`**

These IDs are best knowledge of Classic Era data; Task 4 checks every one in the client (`/fcon ids`) and removes or fixes those that are wrong.
```lua
--[[---------------------------------------------------------------------------
Data/Items.lua -- items sorted by hand: those the use spell and the item
subclass cannot place (runes, gems, healthstones, Juju, Zanza, the Blasted
Lands buffs, protection and combat potions). Checked in the client with
/fcon ids. An item may stand in two lists (Major Rejuvenation Potion).
-----------------------------------------------------------------------------]]

local ADDON, ns = ...

local Items = {}
ns.Items = Items

Items.LISTS = {
    healing = {
        118, 858, 929, 1710, 3928, 13446,           -- Minor .. Major Healing Potion
        5512, 19004, 19005, 5511, 19006, 19007, 5509, 19008, 19009, 5510, 19010, 19011, 9421, 19012, 19013, -- healthstones
        11951,                                      -- Whipper Root Tuber (Felwood)
        18253, 9144,                                -- Major Rejuvenation, Wildvine Potion
    },
    mana = {
        2455, 3385, 3827, 6149, 13443, 13444,       -- Minor .. Major Mana Potion
        5514, 5513, 8007, 8008,                     -- Mana Agate, Jade, Citrine, Ruby
        11952,                                      -- Night Dragon's Breath (Felwood)
        20520, 12662,                               -- Dark Rune, Demonic Rune
        18253, 9144,
    },
    potions = {
        5631, 5633, 13442,                          -- Rage, Great Rage, Mighty Rage Potion
        2459, 3823, 9172,                           -- Swiftness, Lesser Invisibility, Invisibility
        3387, 9036,                                 -- Limited Invulnerability, Magic Resistance
        7676,                                       -- Thistle Tea
        12190,                                      -- Dreamless Sleep Potion
    },
    flasks = { 13510, 13511, 13512, 13513, 13506 }, -- Titans, Distilled Wisdom, Supreme Power, Chromatic Resistance, Petrification
    elixirs = {
        12450, 12451, 12455, 12457, 12458, 12459, 12460, -- Juju Flurry, Power, Ember, Chill, Guile, Escape, Might
        20079, 20080, 20081,                        -- Spirit of Zanza, Sheen of Zanza, Swiftness of Zanza
        8410, 8411, 8412, 8423, 8424,               -- R.O.I.D.S., Lung Juice, Ground Scorpok Assay, Cerebral Cortex, Gizzard Gum
        12820,                                      -- Winterfall Firewater
        13452, 9206, 9187, 8949, 3390, 2457,        -- Mongoose, Giants, Greater/-/Lesser/Minor Agility
        9179, 9264, 13454, 9155, 21546, 6373, 17708, -- Greater Intellect, Shadow Power, Greater Arcane, Arcane, Greater Firepower, Firepower, Frost Power
        3825, 13445, 8951, 3389, 5997,              -- Fortitude, Superior/Greater/-/Minor Defense
        13453, 20007, 20004, 3826, 3388, 3382,      -- Brute Force, Mageblood, Major/Mighty/Strong/Weak Troll's Blood
        9088, 9224, 9154, 9233, 6662, 5996, 18294,  -- Gift of Arthas, Demonslaying, Detect Undead, Detect Demon, Giant Growth, Water Breathing, Greater Water Breathing
        2454, 3391, 3383, 2458, 8529,               -- Lion's Strength, Ogre's Strength, Wisdom, Minor Fortitude, Noggenfogger
    },
    protection = {
        6049, 13457, 6050, 13456, 6052, 13458, 6048, 13459, 13461, 6051, -- Fire, Frost, Nature, Shadow (+Greater), Greater Arcane, Holy
        5634, 20008, 9030, 13462, 13455,            -- Free Action, Living Action, Restorative, Purification, Greater Stoneshield
    },
    scrolls = {
        3012, 1477, 4425, 10309, 955, 2290, 4419, 10308, 3013, 1478, 4421, 10305,
        1181, 1712, 4424, 10306, 1180, 1711, 4422, 10307, 954, 2289, 4426, 10310,
    },
    bandages = { 1251, 2581, 3530, 3531, 6450, 6451, 8544, 8545, 14529, 14530 },
}

-- Conjured items go first: they vanish when you log out long enough.
Items.CONJURED = {}
for _, id in ipairs({
    5350, 2288, 2136, 3772, 8077, 8078, 8079,       -- Conjured Water .. Crystal Water
    5349, 1113, 1114, 1487, 8075, 8076,             -- Conjured Muffin .. Cinnamon Roll
    5514, 5513, 8007, 8008,                         -- mana gems
    5512, 19004, 19005, 5511, 19006, 19007, 5509, 19008, 19009, 5510, 19010, 19011, 9421, 19012, 19013,
}) do Items.CONJURED[id] = true end

-- Buff food the automatic choice never takes.
Items.BUFF_FOOD = {}
for _, id in ipairs({
    21023, 20452, 13928, 13931, 18254, 12218, 21072, 21217, 18045, 12216, 12215, 6888, 2680, 13929, 13927,
}) do Items.BUFF_FOOD[id] = true end

Items.CATEGORY = {}
for cat, ids in pairs(Items.LISTS) do
    for _, id in ipairs(ids) do
        local cats = Items.CATEGORY[id] or {}
        cats[#cats + 1] = cat
        Items.CATEGORY[id] = cats
    end
end
-- Two lists: the category order decides the order of the result.
local rank = {}
for i, cat in ipairs(ns.Settings.CATEGORIES) do rank[cat] = i end
for _, cats in pairs(Items.CATEGORY) do
    table.sort(cats, function(a, b) return rank[a] < rank[b] end)
end
```

- [ ] **Step 4: `Classify.lua`**

```lua
--[[---------------------------------------------------------------------------
Classify.lua -- an item's categories. Many Classic consumables carry the
subclass "Consumable" (0), so the subclass alone cannot sort them. In order:
the hand-made lists (Data/Items.lua), the use spell's name compared with
reference spells in the client's language (Food, Drink, Refreshment,
Healing Potion, Restore Mana, First Aid), then the subclass. Any other
potion goes to "potions", so new potions show without a list update.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local Items = ns.Items

local Classify = {}
ns.Classify = Classify

Classify.SPELLS = { food = 433, drink = 430, refreshment = 167152, healingPotion = 441, restoreMana = 437,
    firstAid = 746, wellFed = 19705 }

-- Retail-style consumable subclasses (Forever's data uses them for part of
-- the items).
local SUBCLASS = { [1] = "potions", [2] = "elixirs", [3] = "flasks", [4] = "scrolls", [5] = "food", [7] = "bandages" }

local names, cache = nil, {}

local function Names()
    if not names then
        names = {}
        for key, id in pairs(Classify.SPELLS) do
            names[key] = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or nil
        end
    end
    return names
end

function Classify.Reset() names, cache = nil, {} end

local BY_SPELL = {
    { "refreshment", { "food", "drink" } },
    { "food", { "food" } },
    { "drink", { "drink" } },
    { "healingPotion", { "healing" } },
    { "restoreMana", { "mana" } },
    { "firstAid", { "bandages" } },
}

local function copy(t) local c = {} for i, v in ipairs(t) do c[i] = v end return c end

local function compute(id)
    if Items.CATEGORY[id] then return copy(Items.CATEGORY[id]), true end
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(id)
    if classID ~= 0 then return {}, classID ~= nil end
    local spell = C_Item.GetItemSpell(id)
    if spell then
        local n = Names()
        for _, rule in ipairs(BY_SPELL) do
            if n[rule[1]] and spell == n[rule[1]] then return copy(rule[2]), true end
        end
    end
    local cat = SUBCLASS[subclassID]
    if cat then return { cat }, true end
    return {}, spell ~= nil
end

-- Cached once the client knows the item well enough to decide.
function Classify.Of(id)
    if cache[id] then return copy(cache[id]) end
    local cats, sure = compute(id)
    if sure then cache[id] = cats end
    return copy(cats)
end

function Classify.IsConjured(id) return Items.CONJURED[id] == true end

-- Listed, or its use spell's text names the "Well Fed" buff.
function Classify.IsBuffFood(id)
    if Items.BUFF_FOOD[id] then return true end
    local _, spellID = C_Item.GetItemSpell(id)
    local wellFed = Names().wellFed
    if not spellID or not wellFed then return false end
    local desc = C_Spell.GetSpellDescription(spellID)
    return type(desc) == "string" and desc:lower():find(wellFed:lower(), 1, true) ~= nil
end
```

- [ ] **Step 5: `Probe.lua`**

```lua
--[[---------------------------------------------------------------------------
Probe.lua -- records what the client says about items, for checking the
lists and the classification: /fcon scan (every item in the bags) and
/fcon ids (every listed ID: its name, or false). Written to
ForeverConsumablesChar; /reload saves it to the WTF folder.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...

local function bagItems()
    local seen, list = {}, {}
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and not seen[info.itemID] then
                seen[info.itemID] = true
                list[#list + 1] = info.itemID
            end
        end
    end
    table.sort(list)
    return list
end

ns.Slash.scan = function()
    local out = {}
    for _, id in ipairs(bagItems()) do
        local name, _, _, itemLevel, minLevel, _, _, _, _, _, _, classID, subclassID = C_Item.GetItemInfo(id)
        local spell, spellID = C_Item.GetItemSpell(id)
        out[#out + 1] = { id = id, name = name, classID = classID, subclassID = subclassID, spell = spell,
            spellID = spellID, itemLevel = itemLevel, minLevel = minLevel,
            cats = table.concat(ns.Classify.Of(id), ","), buffFood = ns.Classify.IsBuffFood(id) }
    end
    local spells = {}
    for key, id in pairs(ns.Classify.SPELLS) do spells[key] = C_Spell.GetSpellName(id) or false end
    local db = ns.CharDB()
    db.scan, db.scanSpells = out, spells
    ns.Print(("scan: %d items recorded, /reload to save"):format(#out))
end

ns.Slash.ids = function()
    local ids = {}
    for _, list in pairs(ns.Items.LISTS) do
        for _, id in ipairs(list) do ids[id] = true end
    end
    for id in pairs(ns.Items.BUFF_FOOD) do ids[id] = true end
    for id in pairs(ns.Items.CONJURED) do ids[id] = true end
    for id in pairs(ids) do C_Item.RequestLoadItemDataByID(id) end
    -- Names arrive asynchronously; read them a moment later.
    C_Timer.After(3, function()
        local result, missing = {}, 0
        for id in pairs(ids) do
            local name = C_Item.GetItemInfo(id)
            result[id] = name or false
            if not name then missing = missing + 1 end
        end
        ns.CharDB().ids = result
        ns.Print(("ids: %d missing, /reload to save"):format(missing))
    end)
end
```
Append to the TOC after `Settings.lua`: `Data\Items.lua`, `Classify.lua`, `Probe.lua`.

- [ ] **Step 6: Run** `tests/run classify` → green; `tests/run` all green.

- [ ] **Step 7: Commit** `git add -A && git commit -m "Item lists, classification and the probe commands"`

---

### Task 4: Check the item data in the client (controller with the user)

Not for a subagent: needs the running game. The controller does it.

- [ ] **Step 1:** `./install "$HOME/Games/Battlenet/drive_c/Program Files (x86)/World of Warcraft/_classic_beta_/Interface/AddOns"`
- [ ] **Step 2:** Ask the user to start WoW (never send the launcher's start command twice), log in with a character carrying consumables, type `/fcon ids`, wait 3 seconds, `/fcon scan`, then `/reload`. (No movement, no casting during automated steps.)
- [ ] **Step 3:** Read the character's `ForeverConsumables.lua` SavedVariables file. For every `ids[id] = false`: find the right ID (wowhead classic/`wowapi`, or the scan) or remove it from `Data/Items.lua`. Compare `scanSpells` with the expected English/German names. In `scan`, check: subclass values the client uses for potions/elixirs/flasks/food, items with empty `cats` that should have one, wrong categories. Fix `Data/Items.lua` / `Classify.lua` (keep tests in step, add a case per fix).
- [ ] **Step 4:** `tests/run`; commit `git commit -am "Item data checked in the client"`.

---

### Task 5: Bags and the automatic choice

**Files:**
- Create: `Bags.lua`, `Choice.lua`, `tests/run_choice.lua`
- Modify: TOC (append `Bags.lua`, `Choice.lua` after `Probe.lua`)

**Interfaces:**
- Consumes: `Classify.Of`, `Classify.IsConjured`, `Classify.IsBuffFood`, `Settings.CATEGORIES`, `ns.CharDB()`.
- Produces: `Bags.Scan()` → `{ [cat] = { entry... } }` (every category key present, list sorted by name); entry = `{ id, name, icon, count, minLevel, itemLevel, conjured, buffFood }`. `Choice.Best(list, level)` → entry|nil; `Choice.Resolve(list, chosenID, level)` → entry|nil, `isChosen` bool; `Choice.Get(cat)` → itemID|nil; `Choice.Set(cat, itemID|nil)`.

- [ ] **Step 1: Failing test `tests/run_choice.lua`**

```lua
-- Bag scan and the automatic choice.
local M = dofile("mock.lua")
print("Bags and choice")
M.spells = { [433] = "Food", [430] = "Drink", [441] = "Healing Potion" }
M.items = {
    [118] = { name = "Minor Healing Potion", spell = "Healing Potion", minLevel = 1, itemLevel = 5, icon = 1 },
    [929] = { name = "Healing Potion", spell = "Healing Potion", minLevel = 12, itemLevel = 22, icon = 2 },
    [13446] = { name = "Major Healing Potion", spell = "Healing Potion", minLevel = 45, itemLevel = 55, icon = 3 },
    [5512] = { name = "Minor Healthstone", minLevel = 0, itemLevel = 1, icon = 4 },
    [4599] = { name = "Cured Ham Steak", spell = "Food", minLevel = 35, itemLevel = 45, icon = 5 },
    [21023] = { name = "Dirge's Chops", spell = "Food", minLevel = 55, itemLevel = 65, icon = 6 },
    [8079] = { name = "Conjured Crystal Water", spell = "Drink", minLevel = 55, itemLevel = 65, icon = 7 },
    [8766] = { name = "Morning Glory Dew", spell = "Drink", minLevel = 45, itemLevel = 55, icon = 8 },
}
-- The healthstone stays out of the bags here: conjured, it would win every healing pick.
M.bags = { [118] = 4, [929] = 2, [13446] = 1, [4599] = 10, [21023] = 3, [8079] = 20, [8766] = 5 }
local ns = M.LoadAddon()
local B, C = ns.Bags, ns.Choice

M.level = 30
local scan = B.Scan()
M.check("every category present", scan.flasks ~= nil and #scan.flasks, 0)
M.check("healing entries", #scan.healing, 3)
M.check("sorted by name", scan.healing[1].name, "Healing Potion")
M.check("count", scan.food[1].count, 10)
M.check("conjured flag", scan.drink[1].conjured, true)
M.check("buff food flag", scan.food[2].buffFood, true)

M.check("best: highest usable level", C.Best(scan.healing, 30).id, 929)
M.level = 60
scan = B.Scan()
M.check("best at 60", C.Best(scan.healing, 60).id, 13446)
M.check("conjured first", C.Best(scan.drink, 60).id, 8079)
M.check("buff food never automatic", C.Best(scan.food, 60).id, 4599)
M.check("only buff food: none", C.Best({ scan.food[2] }, 60), nil)

-- A chosen item while in the bags; automatic otherwise.
local e, chosen = C.Resolve(scan.healing, 118, 60)
M.check("chosen used", e.id, 118)
M.check("chosen flag", chosen, true)
e, chosen = C.Resolve(scan.healing, 99999, 60)
M.check("gone: automatic", e.id, 13446)
M.check("gone: not chosen", chosen, false)

C.Set("healing", 118)
M.check("stored per character", ns.CharDB().choice.healing, 118)
M.check("get", C.Get("healing"), 118)
C.Set("healing", nil)
M.check("back to automatic", C.Get("healing"), nil)

M.done()
```

- [ ] **Step 2: Run, see it fail** — `tests/run choice`.

- [ ] **Step 3: `Bags.lua`**

```lua
--[[---------------------------------------------------------------------------
Bags.lua -- the consumables in the bags, per category. One entry per item
ID with its total count over all bags; an item of two categories stands in
both lists.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...

local Bags = {}
ns.Bags = Bags

local function newEntry(id, info)
    local name, _, _, itemLevel, minLevel = C_Item.GetItemInfo(id)
    return {
        id = id,
        name = name or info.itemName or ("item:" .. id),
        icon = info.iconFileID,
        count = C_Item.GetItemCount(id) or 0,
        minLevel = minLevel or 0,
        itemLevel = itemLevel or 0,
        conjured = ns.Classify.IsConjured(id),
        buffFood = ns.Classify.IsBuffFood(id),
    }
end

function Bags.Scan()
    local byCat, seen = {}, {}
    for _, cat in ipairs(ns.Settings.CATEGORIES) do byCat[cat] = {} end
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            if id and not seen[id] then
                seen[id] = true
                local cats = ns.Classify.Of(id)
                if #cats > 0 then
                    local entry = newEntry(id, info)
                    for _, cat in ipairs(cats) do table.insert(byCat[cat], entry) end
                end
            end
        end
    end
    for _, list in pairs(byCat) do
        table.sort(list, function(a, b) return a.name < b.name end)
    end
    return byCat
end
```

- [ ] **Step 4: `Choice.lua`**

```lua
--[[---------------------------------------------------------------------------
Choice.lua -- which item a category's button uses. By hand (stored per
character) while that item is in the bags, otherwise the best one: usable at
your level, conjured first, then the higher required level, then the higher
item level. Buff food is never chosen automatically.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...

local Choice = {}
ns.Choice = Choice

local function better(a, b)
    if a.conjured ~= b.conjured then return a.conjured end
    if a.minLevel ~= b.minLevel then return a.minLevel > b.minLevel end
    if a.itemLevel ~= b.itemLevel then return a.itemLevel > b.itemLevel end
    return a.id > b.id
end

function Choice.Best(list, level)
    local best
    for _, e in ipairs(list) do
        if not e.buffFood and (e.minLevel or 0) <= level and (not best or better(e, best)) then best = e end
    end
    return best
end

function Choice.Resolve(list, chosenID, level)
    if chosenID then
        for _, e in ipairs(list) do
            if e.id == chosenID then return e, true end
        end
    end
    return Choice.Best(list, level), false
end

function Choice.Get(cat)
    local choice = ns.CharDB().choice
    return choice and choice[cat]
end

-- nil: automatic.
function Choice.Set(cat, id)
    local db = ns.CharDB()
    db.choice = db.choice or {}
    db.choice[cat] = id
end
```
Append `Bags.lua`, `Choice.lua` to the TOC after `Probe.lua`.

- [ ] **Step 5: Run** `tests/run choice`, then `tests/run` → green.

- [ ] **Step 6: Commit** `git add -A && git commit -m "Bag scan and the automatic choice"`

---

### Task 6: Visibility rules and layout geometry

**Files:**
- Create: `Visibility.lua`, `Layout.lua`, `tests/run_layout.lua`
- Modify: TOC (append `Visibility.lua`, `Layout.lua` after `Choice.lua`)

**Interfaces:**
- Consumes: a getter `get(key)` (normally `ns.Settings.Get`).
- Produces: `Visibility.Driver(get, env)` → string; `Visibility.Env()` → `{ inInstance, onTaxi }`; `Visibility.Alpha(get, inCombat, mouseOver)` → 0..1. `Layout.ARROW` (12), `Layout.TOGGLE` (14), `Layout.PAD` (3); `Layout.Compute(o)` with `o = { count, perRow, size, spacing, orientation, arrowMode }` → `{ cells = { {x=,y=}... }, barWidth, barHeight, barX, barY, width, height, arrow = "RIGHT"|"BELOW"|nil }` — all relative to the holder's TOPLEFT (y negative downwards); the toggle sits at (0, 0).

- [ ] **Step 1: Failing test `tests/run_layout.lua`**

```lua
-- The state driver, alpha and the geometry.
local M = dofile("mock.lua")
print("Visibility and layout")
local ns = M.LoadAddon()
local V, Lay = ns.Visibility, ns.Layout

local values
local function get(key) return values[key] end
local function base()
    values = { visMode = "ALWAYS", visInstance = false, visGroup = false, visHideDead = false, visHideTaxi = false,
        alphaCombat = 100, alphaNoCombat = 40, fadeMouseover = true }
end
local env = { inInstance = false, onTaxi = false }

base(); M.check("always", V.Driver(get, env), "show")
values.visMode = "COMBAT"; M.check("combat", V.Driver(get, env), "[combat] show; hide")
values.visMode = "NOCOMBAT"; M.check("no combat", V.Driver(get, env), "[combat] hide; show")
values.visMode = "NEVER"; M.check("never", V.Driver(get, env), "hide")
base(); values.visHideDead = true; values.visGroup = true
M.check("dead and group", V.Driver(get, env), "[dead] hide; [nogroup] hide; show")
base(); values.visInstance = true
M.check("instance only, outside", V.Driver(get, env), "hide")
M.check("instance only, inside", V.Driver(get, { inInstance = true, onTaxi = false }), "show")
base(); values.visHideTaxi = true
M.check("taxi hides", V.Driver(get, { inInstance = false, onTaxi = true }), "hide")

M.instance = "raid"; M.taxi = true
local e = V.Env()
M.check("env instance", e.inInstance, true)
M.check("env taxi", e.onTaxi, true)
M.instance = "pvp"
M.check("battleground is no instance", V.Env().inInstance, false)

base()
M.check("alpha out of combat", V.Alpha(get, false, false), 0.4)
M.check("alpha in combat", V.Alpha(get, true, false), 1)
M.check("alpha under the mouse", V.Alpha(get, false, true), 1)
values.fadeMouseover = false
M.check("no mouseover fade", V.Alpha(get, false, true), 0.4)

-- Geometry: 3 buttons of 30, spacing 4, arrow right (12), horizontal.
local g = Lay.Compute({ count = 3, perRow = 10, size = 30, spacing = 4, orientation = "HORIZONTAL", arrowMode = "RIGHT" })
-- cell width 42; bar = 3 + 42*3 + 4*2 + 3 = 140; bar starts after the toggle + spacing
M.check("bar width", g.barWidth, 140)
M.check("bar height", g.barHeight, 36)
M.check("bar x", g.barX, 18)
M.check("cell 2 x", g.cells[2].x, 3 + 42 + 4)
M.check("cell 2 y", g.cells[2].y, -3)
M.check("total width", g.width, 158)
M.check("arrow", g.arrow, "RIGHT")

-- Two per row, arrow below, horizontal: 2 columns, 2 rows.
g = Lay.Compute({ count = 3, perRow = 2, size = 30, spacing = 4, orientation = "HORIZONTAL", arrowMode = "BELOW" })
M.check("rows: height", g.barHeight, 3 + 42 * 2 + 4 + 3)
M.check("rows: cell 3", g.cells[3].x .. "," .. g.cells[3].y, "3,-49")

-- Vertical: toggle on top, columns grow sideways.
g = Lay.Compute({ count = 3, perRow = 2, size = 30, spacing = 4, orientation = "VERTICAL", arrowMode = "RIGHTCLICK" })
M.check("vertical: bar y", g.barY, -18)
M.check("vertical: cell 2", g.cells[2].x .. "," .. g.cells[2].y, "3,-37")
M.check("vertical: cell 3", g.cells[3].x .. "," .. g.cells[3].y, "37,-3")
M.check("right click: no arrow", g.arrow, nil)

g = Lay.Compute({ count = 0, perRow = 10, size = 30, spacing = 4, orientation = "HORIZONTAL", arrowMode = "RIGHT" })
M.check("empty bar", g.barWidth, 0)
M.check("empty: just the toggle", g.width, 14)

M.done()
```

- [ ] **Step 2: Run, see it fail** — `tests/run layout`.

- [ ] **Step 3: `Visibility.lua`**

```lua
--[[---------------------------------------------------------------------------
Visibility.lua -- when the bar shows. The state driver handles what macro
conditions can say ([combat], [dead], [nogroup]) and so works in combat.
Instance and taxi have no condition: they are decided here and the driver
is rebuilt when they change (always out of combat in practice).
-----------------------------------------------------------------------------]]

local ADDON, ns = ...

local Visibility = {}
ns.Visibility = Visibility

local BASE = { ALWAYS = "show", COMBAT = "[combat] show; hide", NOCOMBAT = "[combat] hide; show", NEVER = "hide" }

function Visibility.Driver(get, env)
    local mode = get("visMode")
    if mode == "NEVER" then return "hide" end
    if get("visInstance") and not env.inInstance then return "hide" end
    if get("visHideTaxi") and env.onTaxi then return "hide" end
    local parts = {}
    if get("visHideDead") then parts[#parts + 1] = "[dead] hide" end
    if get("visGroup") then parts[#parts + 1] = "[nogroup] hide" end
    parts[#parts + 1] = BASE[mode] or "show"
    return table.concat(parts, "; ")
end

-- Dungeons and raids count; battlegrounds and arenas do not.
function Visibility.Env()
    local inside, kind = IsInInstance()
    return {
        inInstance = (inside and (kind == "party" or kind == "raid")) and true or false,
        onTaxi = UnitOnTaxi("player") and true or false,
    }
end

function Visibility.Alpha(get, inCombat, mouseOver)
    if mouseOver and get("fadeMouseover") then return 1 end
    return (inCombat and get("alphaCombat") or get("alphaNoCombat")) / 100
end
```

- [ ] **Step 4: `Layout.lua`**

```lua
--[[---------------------------------------------------------------------------
Layout.lua -- where the toggle, the bar and each button go, from the
settings alone (no frames), relative to the holder's top left corner.
The toggle sits at the start: left of the bar when it runs horizontally,
above it when vertically. A cell is the button plus its arrow (right or
below); perRow counts cells along the bar's direction.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...

local Layout = { ARROW = 12, TOGGLE = 14, PAD = 3 }
ns.Layout = Layout

function Layout.Compute(o)
    local arrow = (o.arrowMode == "RIGHT" or o.arrowMode == "BELOW") and o.arrowMode or nil
    local cw = o.size + (arrow == "RIGHT" and Layout.ARROW or 0)
    local ch = o.size + (arrow == "BELOW" and Layout.ARROW or 0)
    local horizontal = o.orientation ~= "VERTICAL"
    local along = math.min(o.count, o.perRow)
    local across = o.count > 0 and math.ceil(o.count / o.perRow) or 0
    local cols, rows = along, across
    if not horizontal then cols, rows = across, along end

    local g = { cells = {}, arrow = arrow }
    for i = 1, o.count do
        local a, b = (i - 1) % o.perRow, math.floor((i - 1) / o.perRow)
        local col, row = a, b
        if not horizontal then col, row = b, a end
        g.cells[i] = { x = Layout.PAD + col * (cw + o.spacing), y = -(Layout.PAD + row * (ch + o.spacing)) }
    end
    if o.count > 0 then
        g.barWidth = 2 * Layout.PAD + cols * cw + (cols - 1) * o.spacing
        g.barHeight = 2 * Layout.PAD + rows * ch + (rows - 1) * o.spacing
    else
        g.barWidth, g.barHeight = 0, 0
    end
    local gap = Layout.TOGGLE + o.spacing
    if horizontal then
        g.barX, g.barY = gap, 0
        g.width = o.count > 0 and gap + g.barWidth or Layout.TOGGLE
        g.height = math.max(Layout.TOGGLE, g.barHeight)
    else
        g.barX, g.barY = 0, -gap
        g.width = math.max(Layout.TOGGLE, g.barWidth)
        g.height = o.count > 0 and gap + g.barHeight or Layout.TOGGLE
    end
    return g
end
```
Append `Visibility.lua`, `Layout.lua` to the TOC after `Choice.lua`.

- [ ] **Step 5: Run** `tests/run layout` → green (check the expected numbers by hand if one differs: the test comments show the arithmetic). Then `tests/run`.

- [ ] **Step 6: Commit** `git add -A && git commit -m "Visibility driver, alpha and layout geometry"`

---

### Task 7: The bar — secure frames, refresh, collapse, mover

**Files:**
- Create: `Media.lua`, `Bar.lua`, `tests/run_bar.lua`
- Modify: TOC (append `Media.lua` after `Locale.lua`; `Bar.lua` after `Layout.lua`), locales

**Interfaces:**
- Consumes: everything above.
- Produces: `ns.Media.FONTS`, `ns.Media.Fonts()` → list `{ key, path }` (first `{ key = "DEFAULT" }`), `ns.Media.FontPath(key)`; `Bar.ICONS[cat]` (category texture), `Bar.Create()`, `Bar.Refresh()` (out of combat: full; in combat: display only + remembers), `Bar.UpdateDisplay()`, `Bar.ApplyVisibility()`, `Bar.ApplyAlpha()`, `Bar.ListOf(cat)` → entries of the last scan, `Bar.ButtonOf(cat)` → the secure button, `Bar.holder`, `Bar.toggle`, `Bar.bar`; each button has `button.cat`, `button.entry`, `button.arrow`, `button.icon`, `button.count`, `button.cooldown`. Hook point for Task 8: `Bar.onPick` (function(owner, cat)) and `Bar.onEnter` (function(button)) — set by Picker.lua.

- [ ] **Step 1: Failing test `tests/run_bar.lua`**

```lua
-- The bar's frames: refresh, combat, collapse, visibility, mover.
local M = dofile("mock.lua")
print("Bar")
M.spells = { [433] = "Food", [430] = "Drink", [441] = "Healing Potion" }
M.items = {
    [929] = { name = "Healing Potion", spell = "Healing Potion", minLevel = 12, itemLevel = 22, icon = 2 },
    [13446] = { name = "Major Healing Potion", spell = "Healing Potion", minLevel = 45, itemLevel = 55, icon = 3 },
    [4599] = { name = "Cured Ham Steak", spell = "Food", minLevel = 35, itemLevel = 45, icon = 5 },
    [8766] = { name = "Morning Glory Dew", spell = "Drink", minLevel = 45, itemLevel = 55, icon = 8 },
}
M.bags = { [929] = 2, [13446] = 1, [4599] = 10, [8766] = 5 }
local ns = M.LoadAddon()
local Bar, S = ns.Bar, ns.Settings
M.Fire("ADDON_LOADED", "ForeverConsumables")
M.Fire("PLAYER_LOGIN")
M.flush()

local function shown(cat) local b = Bar.ButtonOf(cat); return b ~= nil and b:IsShown() end
M.check("food shown", shown("food"), true)
M.check("drink shown", shown("drink"), true)
M.check("healing shown", shown("healing"), true)
M.check("empty flasks hidden", shown("flasks"), false)
local heal = Bar.ButtonOf("healing")
M.check("item attribute", heal:GetAttribute("item"), "item:13446")
M.check("type item", heal:GetAttribute("type"), "item")
M.check("count text", heal.count:GetText(), "1")
M.check("icon", heal.icon:GetTexture(), 3)
M.check("order: food first", select(4, Bar.ButtonOf("food"):GetPoint()), 3)

M.Click(heal, "LeftButton", true)
M.Click(heal, "LeftButton", false)
M.check("left click uses once", #M.used, 1)
M.check("used the potion", M.used[1], "item:13446")

-- Empty categories kept when asked.
S.Set("hideEmpty", false)
M.check("empty flasks kept", shown("flasks"), true)
M.check("empty: category icon", Bar.ButtonOf("flasks").icon:GetTexture(), Bar.ICONS.flasks)
M.check("empty: greyed", Bar.ButtonOf("flasks").icon:IsDesaturated(), true)
S.Set("hideEmpty", true)
S.Set("show_drink", false)
M.check("switched off", shown("drink"), false)
S.Set("show_drink", true)

-- In combat: nothing protected changes; the last potion is used up.
M.setCombat(true)
M.bags[13446] = 0
M.Fire("BAG_UPDATE_DELAYED")
M.check("combat: button stays", heal:IsShown(), true)
M.check("combat: attribute unchanged", heal:GetAttribute("item"), "item:13446")
M.check("combat: greyed", heal.icon:IsDesaturated(), true)
M.check("combat: count 0", heal.count:GetText(), "0")
M.check("combat: arrow disabled", heal.arrow:IsEnabled(), false)
M.setCombat(false)
M.check("after combat: next best", heal:GetAttribute("item"), "item:929")
M.check("after combat: arrow enabled", heal.arrow:IsEnabled(), true)

-- Settings changed in combat apply after it.
M.setCombat(true)
S.Set("size", 40)
M.check("combat: size waits", heal:GetWidth(), 36)
M.setCombat(false)
M.check("after combat: size", heal:GetWidth(), 40)

-- Collapse: also in combat, saved per character.
local toggle = Bar.toggle
M.setCombat(true)
M.Click(toggle, "LeftButton")
M.check("collapsed in combat", Bar.bar:IsShown(), false)
M.check("saved", ns.CharDB().collapsed, true)
M.Click(toggle, "LeftButton")
M.check("opened again", Bar.bar:IsShown(), true)
M.check("saved open", ns.CharDB().collapsed, false)
M.setCombat(false)
M.Click(toggle, "LeftButton")
M.Fire("BAG_UPDATE_DELAYED")
M.check("refresh keeps it collapsed", Bar.bar:IsShown(), false)
M.Click(toggle, "LeftButton")

-- Visibility driver.
S.Set("visMode", "COMBAT")
M.check("driver", M.drivers[Bar.holder].visibility, "[dead] hide; [combat] show; hide")
S.Set("visInstance", true)
M.check("instance only, outside", M.drivers[Bar.holder].visibility, "hide")
M.instance = "party"
M.Fire("PLAYER_ENTERING_WORLD")
M.flush()
M.check("instance only, inside", M.drivers[Bar.holder].visibility, "[dead] hide; [combat] show; hide")
S.Set("visInstance", false); S.Set("visMode", "ALWAYS")

-- Alpha follows combat.
S.Set("alphaNoCombat", 50)
M.check("alpha out of combat", Bar.holder:GetAlpha(), 0.5)
M.setCombat(true)
M.check("alpha in combat", Bar.holder:GetAlpha(), 1)
M.setCombat(false)

-- Position and the mover.
S.Set("point", "TOPLEFT"); S.Set("x", 100); S.Set("y", -50)
local p, rel, p2, x, y = Bar.holder:GetPoint()
M.check("point", p .. ":" .. p2 .. ":" .. x .. ":" .. y, "TOPLEFT:TOPLEFT:100:-50")
S.Set("locked", false)
M.check("mover shown", Bar.mover:IsShown(), true)
S.Set("locked", true)
M.check("mover hidden", Bar.mover:IsShown(), false)

M.done()
```

- [ ] **Step 2: Run, see it fail** — `tests/run bar`.

- [ ] **Step 3: `Media.lua`** (the font list FSM's `Infos.FONTS`/`FontList` had)

```lua
--[[---------------------------------------------------------------------------
Media.lua -- the fonts to choose from: the game's four and any that
LibSharedMedia knows. "DEFAULT" is the game's normal font.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...

local Media = ns.Media or {}
ns.Media = Media

Media.FONTS = {
    { key = "DEFAULT" },
    { key = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { key = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
    { key = "Skurri", path = "Fonts\\SKURRI.TTF" },
    { key = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
}

function Media.Fonts()
    local list, seen = {}, {}
    for _, f in ipairs(Media.FONTS) do list[#list + 1] = f; seen[f.key] = true end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local names = LSM:List("font") or {}
        table.sort(names)
        for _, name in ipairs(names) do
            if not seen[name] then list[#list + 1] = { key = name, path = LSM:Fetch("font", name) } end
        end
    end
    return list
end

function Media.FontPath(key)
    for _, f in ipairs(Media.Fonts()) do
        if f.key == key and f.path then return f.path end
    end
    return "Fonts\\FRIZQT__.TTF"
end
```
Mock: add `LibStub = nil` is already the default (not defined) — fine.

- [ ] **Step 4: `Bar.lua`**

```lua
--[[---------------------------------------------------------------------------
Bar.lua -- the frames. A holder (moved, scaled, shown by the state driver)
carries the toggle and the bar; the bar carries one secure item button per
category, each with an arrow beside it for choosing.

Protected things (attributes, points, sizes, show/hide) change only out of
combat: Refresh in combat only updates icons, counts and cooldowns and
remembers to run fully when combat ends. Collapsing is a secure click
snippet on the toggle, so it works in combat too; PostClick saves it.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local L = ns.L
local S = ns.Settings

local Bar = {}
ns.Bar = Bar

Bar.ICONS = {
    food = "Interface\\Icons\\INV_Misc_Food_14", drink = "Interface\\Icons\\INV_Drink_07",
    healing = "Interface\\Icons\\INV_Potion_54", mana = "Interface\\Icons\\INV_Potion_76",
    potions = "Interface\\Icons\\INV_Potion_41", flasks = "Interface\\Icons\\INV_Potion_62",
    elixirs = "Interface\\Icons\\INV_Potion_32", protection = "Interface\\Icons\\INV_Potion_16",
    scrolls = "Interface\\Icons\\INV_Scroll_03", bandages = "Interface\\Icons\\INV_Misc_Bandage_15",
}
local TOGGLE_OPEN = "Interface\\Buttons\\UI-MinusButton-Up"
local TOGGLE_CLOSED = "Interface\\Buttons\\UI-PlusButton-Up"
local ARROW = "Interface\\ChatFrame\\ChatFrameExpandArrow"

local buttons = {}      -- cat -> button
local lastScan = {}     -- cat -> entries
local dirty = false

local COLLAPSE = [[
    local bar = self:GetFrameRef("bar")
    if self:GetAttribute("collapsed") then
        self:SetAttribute("collapsed", false)
        if self:GetAttribute("hasItems") then bar:Show() end
    else
        self:SetAttribute("collapsed", true)
        bar:Hide()
    end
]]

local function collapsed() return ns.CharDB().collapsed == true end

local function paintToggle()
    Bar.toggle.icon:SetTexture(collapsed() and TOGGLE_CLOSED or TOGGLE_OPEN)
end

local function newButton(cat)
    local b = CreateFrame("Button", "ForeverConsumablesButton_" .. cat, Bar.bar, "SecureActionButtonTemplate")
    b.cat = cat
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "item")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints(b)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cooldown:SetAllPoints(b)
    b.count = b:CreateFontString(nil, "OVERLAY")
    b.arrow = CreateFrame("Button", nil, Bar.bar)
    b.arrow.icon = b.arrow:CreateTexture(nil, "ARTWORK")
    b.arrow.icon:SetAllPoints(b.arrow)
    b.arrow.icon:SetTexture(ARROW)
    b.arrow:SetScript("OnClick", function(self)
        if not InCombatLockdown() and Bar.onPick then Bar.onPick(self, cat) end
    end)
    b:SetScript("PostClick", function(self, mouse, down)
        if down or mouse ~= "RightButton" or IsModifierKeyDown() then return end
        if S.Get("arrowMode") == "RIGHTCLICK" and not InCombatLockdown() and Bar.onPick then Bar.onPick(self, cat) end
    end)
    b:SetScript("OnEnter", function(self) if Bar.onEnter then Bar.onEnter(self) end end)
    b:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    buttons[cat] = b
    return b
end

function Bar.Create()
    if Bar.holder then return end
    local holder = CreateFrame("Frame", "ForeverConsumablesHolder", UIParent, "SecureHandlerStateTemplate")
    holder:SetMovable(true)
    holder:SetClampedToScreen(true)
    Bar.holder = holder

    local bar = CreateFrame("Frame", "ForeverConsumablesBar", holder, "SecureHandlerBaseTemplate")
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    bar.border = {}
    for i = 1, 4 do bar.border[i] = bar:CreateTexture(nil, "BORDER") end
    Bar.bar = bar

    local toggle = CreateFrame("Button", "ForeverConsumablesToggle", holder, "SecureHandlerClickTemplate")
    toggle:SetSize(ns.Layout.TOGGLE, ns.Layout.TOGGLE)
    toggle:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    toggle.icon = toggle:CreateTexture(nil, "ARTWORK")
    toggle.icon:SetAllPoints(toggle)
    toggle:RegisterForClicks("AnyUp")
    toggle:SetFrameRef("bar", bar)
    toggle:SetAttribute("_onclick", COLLAPSE)
    toggle:SetAttribute("collapsed", collapsed())
    toggle:SetScript("PostClick", function(self)
        ns.CharDB().collapsed = self:GetAttribute("collapsed") and true or false
        paintToggle()
    end)
    toggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.ADDON_NAME)
        GameTooltip:AddLine(collapsed() and L.TIP_EXPAND or L.TIP_COLLAPSE)
        GameTooltip:Show()
    end)
    toggle:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    Bar.toggle = toggle

    -- The mover: a green cover while unlocked.
    local mover = CreateFrame("Frame", "ForeverConsumablesMover", holder)
    mover:SetAllPoints(holder)
    mover:SetFrameStrata("DIALOG")
    mover.tex = mover:CreateTexture(nil, "OVERLAY")
    mover.tex:SetAllPoints(mover)
    mover.tex:SetColorTexture(0.2, 0.8, 0.3, 0.35)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetScript("OnDragStart", function() if not InCombatLockdown() then holder:StartMoving() end end)
    mover:SetScript("OnDragStop", function()
        holder:StopMovingOrSizing()
        Bar.SavePosition()
    end)
    mover:Hide()
    Bar.mover = mover

    for _, cat in ipairs(S.CATEGORIES) do newButton(cat) end
    holder:SetScript("OnUpdate", function(self, elapsed)
        if not S.Get("fadeMouseover") then return end
        self.since = (self.since or 0) + elapsed
        if self.since < 0.1 then return end
        self.since = 0
        Bar.ApplyAlpha()
    end)
end

-- The holder's offset from its point on the screen, in its own scale.
function Bar.SavePosition()
    local holder, point = Bar.holder, S.Get("point")
    local left, bottom = holder:GetLeft(), holder:GetBottom()
    if not left then return end
    local w, h = holder:GetWidth(), holder:GetHeight()
    local s = holder:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local function coord(p, lo, size)
        if p:find(lo == "x" and "LEFT" or "BOTTOM") then return 0 end
        if p:find(lo == "x" and "RIGHT" or "TOP") then return 1 end
        return 0.5
    end
    local fx, fy = coord(point, "x"), coord(point, "y")
    local x = (left + w * fx) - UIParent:GetWidth() * fx / s
    local y = (bottom + h * fy) - UIParent:GetHeight() * fy / s
    S.Set("x", math.floor(x + 0.5))
    S.Set("y", math.floor(y + 0.5))
end

local function applyBorder()
    local bar, size, c = Bar.bar, S.Get("borderSize"), S.Get("borderColor")
    local edges = bar.border
    local show = S.Get("borderShow")
    local spec = {
        { "TOPLEFT", "TOPRIGHT", nil, size }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, size },
        { "TOPLEFT", "BOTTOMLEFT", size, nil }, { "TOPRIGHT", "BOTTOMRIGHT", size, nil },
    }
    for i, e in ipairs(edges) do
        e:ClearAllPoints()
        e:SetPoint(spec[i][1], bar, spec[i][1])
        e:SetPoint(spec[i][2], bar, spec[i][2])
        if spec[i][3] then e:SetWidth(spec[i][3]) else e:SetHeight(spec[i][4]) end
        e:SetColorTexture(c[1], c[2], c[3], c[4])
        e:SetShown(show)
    end
    local bg = S.Get("backgroundColor")
    bar.bg:SetColorTexture(bg[1], bg[2], bg[3], bg[4])
    bar.bg:SetShown(S.Get("backgroundShow"))
end

local function applyCountFont(b)
    local flags = S.Get("countOutline")
    b.count:SetFont(ns.Media.FontPath(S.Get("countFont")), S.Get("countSize"), flags == "NONE" and "" or flags)
    local c = S.Get("countColor")
    b.count:SetTextColor(c[1], c[2], c[3], c[4])
    b.count:ClearAllPoints()
    local p = S.Get("countPoint")
    b.count:SetPoint(p, b, p, S.Get("countX"), S.Get("countY"))
end

function Bar.ApplyVisibility()
    if not Bar.holder then return end
    ns.AfterCombat("visibility", function()
        RegisterStateDriver(Bar.holder, "visibility", ns.Visibility.Driver(S.Get, ns.Visibility.Env()))
    end)
end

function Bar.ApplyAlpha()
    if not Bar.holder then return end
    local over = Bar.holder:IsMouseOver()
    Bar.holder:SetAlpha(ns.Visibility.Alpha(S.Get, InCombatLockdown(), over))
end

-- Icons, counts, cooldowns, greying, arrows: allowed in combat.
function Bar.UpdateDisplay()
    local combat = InCombatLockdown()
    for cat, b in pairs(buttons) do
        if b:IsShown() then
            local e = b.entry
            if e then
                local count = C_Item.GetItemCount(e.id) or 0
                b.icon:SetTexture(e.icon)
                b.icon:SetDesaturated(count == 0)
                b.count:SetText(tostring(count))
                local start, duration = C_Container.GetItemCooldown(e.id)
                if duration and duration > 0 then b.cooldown:SetCooldown(start, duration) else b.cooldown:Clear() end
            else
                b.icon:SetTexture(Bar.ICONS[cat])
                b.icon:SetDesaturated(true)
                b.count:SetText("")
                b.cooldown:Clear()
            end
            b.arrow:SetEnabled(not combat)
            b.arrow.icon:SetDesaturated(combat)
        end
    end
end

function Bar.Refresh()
    if not Bar.holder then return end
    if InCombatLockdown() then
        dirty = true
        Bar.UpdateDisplay()
        return
    end
    dirty = false
    lastScan = ns.Bags.Scan()
    local level = UnitLevel("player") or 1
    local visible = {}
    for _, cat in ipairs(S.Order()) do
        local list = lastScan[cat]
        if S.Get("show_" .. cat) and (#list > 0 or not S.Get("hideEmpty")) then
            visible[#visible + 1] = cat
        end
    end

    local arrowMode = S.Get("arrowMode")
    local g = ns.Layout.Compute({ count = #visible, perRow = S.Get("perRow"), size = S.Get("size"),
        spacing = S.Get("spacing"), orientation = S.Get("orientation"), arrowMode = arrowMode })
    local size = S.Get("size")
    local shownCat = {}
    for i, cat in ipairs(visible) do
        local b = buttons[cat]
        shownCat[cat] = true
        b.entry = ns.Choice.Resolve(lastScan[cat], ns.Choice.Get(cat), level)
        b:SetAttribute("item", b.entry and ("item:" .. b.entry.id) or nil)
        b:SetAttribute("*type2", arrowMode == "RIGHTCLICK" and "" or nil)
        b:SetSize(size, size)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", Bar.bar, "TOPLEFT", g.cells[i].x, g.cells[i].y)
        b:Show()
        applyCountFont(b)
        b.arrow:ClearAllPoints()
        if g.arrow == "RIGHT" then
            b.arrow:SetSize(ns.Layout.ARROW, size)
            b.arrow:SetPoint("LEFT", b, "RIGHT", 0, 0)
            b.arrow.icon:SetTexCoord(0, 1, 0, 1)
        elseif g.arrow == "BELOW" then
            b.arrow:SetSize(size, ns.Layout.ARROW)
            b.arrow:SetPoint("TOP", b, "BOTTOM", 0, 0)
            b.arrow.icon:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
        end
        b.arrow:SetShown(g.arrow ~= nil)
    end
    for cat, b in pairs(buttons) do
        if not shownCat[cat] then
            b.entry = nil
            b:Hide()
            b.arrow:Hide()
        end
    end

    local holder, bar = Bar.holder, Bar.bar
    holder:SetScale(S.Get("scale") / 100)
    holder:SetSize(g.width, g.height)
    holder:ClearAllPoints()
    holder:SetPoint(S.Get("point"), UIParent, S.Get("point"), S.Get("x"), S.Get("y"))
    bar:SetSize(math.max(1, g.barWidth), math.max(1, g.barHeight))
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", holder, "TOPLEFT", g.barX, g.barY)
    Bar.toggle:SetAttribute("hasItems", #visible > 0)
    Bar.toggle:SetAttribute("collapsed", collapsed())
    bar:SetShown(#visible > 0 and not collapsed())
    paintToggle()
    applyBorder()
    Bar.mover:SetShown(not S.Get("locked"))
    Bar.UpdateDisplay()
    Bar.ApplyAlpha()
end

function Bar.ListOf(cat) return lastScan[cat] or {} end
function Bar.ButtonOf(cat) return buttons[cat] end

-- Events ------------------------------------------------------------------------

ns.On("PLAYER_LOGIN", function()
    Bar.Create()
    Bar.Refresh()
    Bar.ApplyVisibility()
end)
ns.On("BAG_UPDATE_DELAYED", Bar.Refresh)
ns.On("PLAYER_LEVEL_UP", function() C_Timer.After(0.5, Bar.Refresh) end)
ns.On("BAG_UPDATE_COOLDOWN", Bar.UpdateDisplay)
ns.On("PLAYER_REGEN_DISABLED", function()
    Bar.UpdateDisplay()
    Bar.ApplyAlpha()
end)
ns.On("PLAYER_REGEN_ENABLED", function()
    if dirty then Bar.Refresh() else Bar.UpdateDisplay() end
    Bar.ApplyAlpha()
end)
-- Instance and taxi: the driver is rebuilt a moment after they change.
local function later() C_Timer.After(0.2, Bar.ApplyVisibility) end
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_CONTROL_LOST",
    "PLAYER_CONTROL_GAINED" }) do
    ns.On(event, later)
end

local VISIBILITY = { visMode = true, visInstance = true, visGroup = true, visHideDead = true, visHideTaxi = true }
local ALPHA = { alphaCombat = true, alphaNoCombat = true, fadeMouseover = true }
S.OnChange(function(key)
    if not Bar.holder then return end
    if key == nil or VISIBILITY[key] then Bar.ApplyVisibility() end
    if key ~= nil and ALPHA[key] then Bar.ApplyAlpha(); return end
    if key == nil or not VISIBILITY[key] then ns.AfterCombat("refresh", Bar.Refresh) end
end)
```
Notes for the implementer:
- The mock lacks `SetClampedToScreen`, `StartMoving`, `StopMovingOrSizing`, `GetLeft`, `GetBottom`, `SetFrameStrata` — CamelCase no-ops are fine; `GetLeft` returning nil makes `SavePosition` return early in tests (only the in-game check covers dragging).
- `M.Fire("PLAYER_LOGIN")` must reach `ns.On` handlers: Core's event frame is a mock frame with `_events` — `M.Fire` delivers it.
- The "order: food first" check reads `x` of `GetPoint()` (4th value) = `Layout.PAD` = 3.
- In Settings.Set during combat, `Bar.Refresh` is deferred by `ns.AfterCombat("refresh", …)`; `ApplyVisibility` by its own key.
Add locale keys `TIP_COLLAPSE` ("Click: collapse the bar" / "Klick: Leiste zuklappen" / "Clic: plegar la barra" / "Clic : replier la barre") and `TIP_EXPAND` ("Click: open the bar" / "Klick: Leiste aufklappen" / "Clic: desplegar la barra" / "Clic : déplier la barre").
Append `Media.lua` after `Locale.lua` and `Bar.lua` after `Layout.lua` in the TOC.

- [ ] **Step 5: Run** `tests/run bar` until green; then `tests/run`.

- [ ] **Step 6: Commit** `git add -A && git commit -m "The bar: secure buttons, refresh, collapse, visibility, mover"`

---

### Task 8: Pick menu and tooltip

**Files:**
- Create: `Picker.lua`, `tests/run_picker.lua`
- Modify: TOC (append `Picker.lua` after `Bar.lua`), locales

**Interfaces:**
- Consumes: `Bar.onPick`, `Bar.onEnter`, `Bar.ListOf`, `Bar.Refresh`, `Choice.Get/Set`, `Settings.Get`.
- Produces: `Picker.Open(owner, cat)`, `Picker.Tooltip(button)`; locale keys `CAT_<CAT>` for each category (upper case: `CAT_FOOD` …), `PICK_AUTO`, `TIP_USE`, `TIP_PICK_ARROW`, `TIP_PICK_RIGHT`.

- [ ] **Step 1: Failing test `tests/run_picker.lua`**

```lua
-- Choosing an item and the tooltip.
local M = dofile("mock.lua")
print("Picker")
M.spells = { [441] = "Healing Potion" }
M.items = {
    [929] = { name = "Healing Potion", spell = "Healing Potion", minLevel = 12, itemLevel = 22, icon = 2 },
    [13446] = { name = "Major Healing Potion", spell = "Healing Potion", minLevel = 45, itemLevel = 55, icon = 3 },
}
M.bags = { [929] = 2, [13446] = 1 }
local ns = M.LoadAddon()
M.Fire("ADDON_LOADED", "ForeverConsumables")
M.Fire("PLAYER_LOGIN")
local Bar, S = ns.Bar, ns.Settings
local heal = Bar.ButtonOf("healing")

heal.arrow:GetScript("OnClick")(heal.arrow)
local root = M.menu.root
M.check("title", root.children[1].text, "Healing")
M.check("automatic first", root.children[2].text, "Automatic (best)")
M.check("automatic selected", root.children[2].isSelected(), true)
M.check("two items", #root.children, 4)
M.check("item text has count", root.children[3].text:find("Healing Potion (2)", 1, true) ~= nil, true)
root.children[3].setSelected()
M.check("chosen stored", ns.Choice.Get("healing"), 929)
M.check("button follows", heal:GetAttribute("item"), "item:929")
M.menu = nil
heal.arrow:GetScript("OnClick")(heal.arrow)
M.check("chosen selected", M.menu.root.children[3].isSelected(), true)
M.check("automatic not selected", M.menu.root.children[2].isSelected(), false)
M.menu.root.children[2].setSelected()
M.check("back to automatic", heal:GetAttribute("item"), "item:13446")

-- No menu in combat.
M.menu = nil
M.setCombat(true)
heal.arrow:GetScript("OnClick")(heal.arrow)
M.check("combat: no menu", M.menu, nil)
M.setCombat(false)

-- Right-click mode: right click picks, never uses; modifiers do nothing.
S.Set("arrowMode", "RIGHTCLICK")
M.check("arrow hidden", heal.arrow:IsShown(), false)
M.check("no-op type2", heal:GetAttribute("*type2"), "")
M.used = {}
M.Click(heal, "RightButton", true)
M.Click(heal, "RightButton", false)
M.check("right click: not used", #M.used, 0)
M.check("right click: menu", M.menu ~= nil, true)
M.menu = nil
M.modifier = true
M.Click(heal, "RightButton", false)
M.check("shift right: no menu", M.menu, nil)
M.modifier = false
S.Set("arrowMode", "RIGHT")
M.check("type2 cleared", heal:GetAttribute("*type2"), nil)

-- Tooltip.
heal:GetScript("OnEnter")(heal)
M.check("tooltip item", GameTooltip._item, 13446)
M.check("tooltip hint", GameTooltip._lines[#GameTooltip._lines], "Arrow: choose")
S.Set("tooltip", false)
GameTooltip._item = nil
heal:GetScript("OnEnter")(heal)
M.check("tooltip off", GameTooltip._item, nil)

M.done()
```

- [ ] **Step 2: Run, see it fail** — `tests/run picker`.

- [ ] **Step 3: `Picker.lua`**

```lua
--[[---------------------------------------------------------------------------
Picker.lua -- the list behind a button's arrow (or its right click):
"Automatic (best)" and every item of the category in the bags with its
count. Out of combat only, as choosing changes a secure button. Also the
buttons' tooltip.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local L = ns.L
local S, Choice, Bar = ns.Settings, ns.Choice, ns.Bar

local Picker = {}
ns.Picker = Picker

local function catLabel(cat) return L["CAT_" .. cat:upper()] end

local function choose(cat, id)
    Choice.Set(cat, id)
    Bar.Refresh()
end

function Picker.Open(owner, cat)
    if InCombatLockdown() then return end
    local list = Bar.ListOf(cat)
    local function chosenHere()
        local id = Choice.Get(cat)
        for _, e in ipairs(list) do if e.id == id then return id end end
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(catLabel(cat))
        root:CreateRadio(L.PICK_AUTO, function() return chosenHere() == nil end, function() choose(cat, nil) end)
        for _, e in ipairs(list) do
            local text = ("|T%s:16|t %s (%d)"):format(tostring(e.icon), e.name, C_Item.GetItemCount(e.id) or 0)
            root:CreateRadio(text, function() return chosenHere() == e.id end, function() choose(cat, e.id) end)
        end
    end)
end

function Picker.Tooltip(button)
    if not S.Get("tooltip") then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if button.entry then
        GameTooltip:SetItemByID(button.entry.id)
    else
        GameTooltip:SetText(catLabel(button.cat))
    end
    GameTooltip:AddLine(L.TIP_USE, 1, 1, 1)
    GameTooltip:AddLine(S.Get("arrowMode") == "RIGHTCLICK" and L.TIP_PICK_RIGHT or L.TIP_PICK_ARROW, 1, 1, 1)
    GameTooltip:Show()
end

Bar.onPick = Picker.Open
Bar.onEnter = Picker.Tooltip
```
Locale keys (en / de / es / fr):
- `CAT_FOOD` Food / Essen / Comida / Nourriture
- `CAT_DRINK` Drink / Trinken / Bebida / Boisson
- `CAT_HEALING` Healing / Heilung / Curación / Soins
- `CAT_MANA` Mana / Mana / Maná / Mana
- `CAT_POTIONS` Potions / Tränke / Pociones / Potions
- `CAT_FLASKS` Flasks / Fläschchen / Frascos / Flacons
- `CAT_ELIXIRS` Elixirs / Elixiere / Elixires / Élixirs
- `CAT_PROTECTION` Protection / Schutz / Protección / Protection
- `CAT_SCROLLS` Scrolls / Schriftrollen / Pergaminos / Parchemins
- `CAT_BANDAGES` Bandages / Verbände / Vendas / Bandages
- `PICK_AUTO` Automatic (best) / Automatisch (bester) / Automático (el mejor) / Automatique (le meilleur)
- `TIP_USE` Left-click: use / Linksklick: benutzen / Clic izquierdo: usar / Clic gauche : utiliser
- `TIP_PICK_ARROW` Arrow: choose / Pfeil: auswählen / Flecha: elegir / Flèche : choisir
- `TIP_PICK_RIGHT` Right-click: choose / Rechtsklick: auswählen / Clic derecho: elegir / Clic droit : choisir

- [ ] **Step 4: Run** `tests/run picker`, then `tests/run`.

- [ ] **Step 5: Commit** `git add -A && git commit -m "Pick menu and tooltip"`

---

### Task 9: Options window, minimap button, compartment

**Files:**
- Create (copied): `Options/Style.lua`, `Options/Widgets.lua`, `OptionsPanel.lua`, `MinimapButton.lua`
- Create: `Options.lua`, `tests/run_options.lua`
- Modify: TOC (append `Options\Style.lua`, `Options\Widgets.lua`, `OptionsPanel.lua`, `Options.lua`, `MinimapButton.lua` after `Picker.lua`), locales

**Interfaces:**
- Consumes: `Settings.*`, `ns.Media`, profiles, `ns.Locale`, `ns.Slash`.
- Produces: `ns.Window` (`Open/Toggle/Refresh/IsShown/OnHide`), `ns.BuildOptions(spec)`, `ns.RefreshOptions()`, `ns.OptionsSpec()` (the page list, for tests), `ns.MinimapButton`, globals `ForeverConsumables_OnAddonCompartmentClick/Enter/Leave`, `ns.Slash[""]` (toggle options).

- [ ] **Step 1: Copy the FSM window**

```bash
mkdir -p Options
cp ~/Dokumente/ForeverSquareMinimap/Options/Style.lua Options/Style.lua
cp ~/Dokumente/ForeverSquareMinimap/Options/Widgets.lua Options/Widgets.lua
cp ~/Dokumente/ForeverSquareMinimap/OptionsPanel.lua OptionsPanel.lua
cp ~/Dokumente/ForeverSquareMinimap/MinimapButton.lua MinimapButton.lua
sed -i 's/ForeverSquareMinimap/ForeverConsumables/g; s/Forever Square Minimap/Forever Consumables/g' Options/Style.lua Options/Widgets.lua OptionsPanel.lua MinimapButton.lua
```
Then:
- `Options/Style.lua`: replace the `ns.Media.FontPath` block (the one reading `ns.Infos.FontList`) with nothing — `Media.lua` (loaded earlier) defines `ns.Media.FontPath`. Keep `ns.Media = ns.Media or {}` out; the rest unchanged.
- `MinimapButton.lua`: header comment → "a button on the map's edge that opens the options; dragged along the edge; switched off in the options." Replace `Button.Get/Set` with:
  ```lua
  -- Settings: minimapShow and minimapAngle (Settings.lua).
  function Button.Get(field)
      return ns.Settings.Get(field == "show" and "minimapShow" or "minimapAngle")
  end
  function Button.Set(field, value)
      ns.Settings.Set(field == "show" and "minimapShow" or "minimapAngle", value)
      Button.Place()
  end
  ```
  Set `Button.ICON = "Interface\\Icons\\INV_Potion_54"`. Remove any `ns.Compartment` use (FSM hides its own button when it collects icons — not here; `SetShown(Button.Get("show"))`). Replace the `Minimap:HookScript("OnSizeChanged", …)` line comment accordingly (keep the hook). Make sure `Button.Create()` runs at `PLAYER_LOGIN` (FSM called it from `SquareMinimap.lua`): add at the end
  ```lua
  ns.On("PLAYER_LOGIN", Button.Create)
  ```
- `OptionsPanel.lua`: no logic changes; check `grep -n "Infos\|api\." OptionsPanel.lua Options/*.lua MinimapButton.lua` has no hits left.
- Add to `Core.lua`'s neighbours — in `Options.lua` (below): `ns.Slash[""] = function() ns.Window.Toggle() end`.

- [ ] **Step 2: Failing test `tests/run_options.lua`**

```lua
-- The option pages: every setting has a row; rows read and write settings.
local M = dofile("mock.lua")
print("Options")
local ns = M.LoadAddon()
M.Fire("ADDON_LOADED", "ForeverConsumables")
M.Fire("PLAYER_LOGIN")
local S = ns.Settings
local spec = ns.OptionsSpec()

-- Rows by label key.
local rows, tabs = {}, {}
for _, opt in ipairs(spec) do
    if opt.type == "tab" then tabs[#tabs + 1] = opt.label end
    if opt.label then rows[opt.label] = rows[opt.label] or opt end
end
M.check("tabs", table.concat(tabs, ","), "TAB_GENERAL,TAB_BAR,TAB_VISIBILITY,TAB_DISPLAY,TAB_CATEGORIES")

-- Every setting is reachable (keys covered by some row's settingKey).
local covered = {}
for _, opt in ipairs(spec) do if opt.settingKey then covered[opt.settingKey] = true end end
local missing = {}
for _, def in ipairs(S.All()) do
    if not covered[def.key] and def.key ~= "minimapAngle" then
        missing[#missing + 1] = def.key
    end
end
M.check("every setting has a row", table.concat(missing, ","), "")

-- A row writes through Settings.
rows.OPT_SIZE.set(48)
M.check("size via options", S.Get("size"), 48)
M.check("size row reads", rows.OPT_SIZE.get(), 48)
rows.OPT_VIS_MODE.set("NOCOMBAT")
M.check("mode via options", S.Get("visMode"), "NOCOMBAT")

-- Category position rows move categories.
local pos
for _, opt in ipairs(spec) do if opt.settingKey == "order" and opt.cat == "scrolls" then pos = opt end end
pos.set(1)
M.check("moved by position row", S.Order()[1], "scrolls")
M.check("position row reads", pos.get(), 1)

-- Every label key exists in English.
local bad = {}
for _, opt in ipairs(spec) do
    if type(opt.label) == "string" and not ns.Locales.enUS[opt.label] then bad[#bad + 1] = opt.label end
end
M.check("labels translated", table.concat(bad, ","), "")

-- Slash opens the window.
SlashCmdList.FOREVERCONSUMABLES("")
M.check("window open", ns.Window.IsShown(), true)

M.done()
```
(`order` is covered by the per-category position rows with `settingKey = "order"`; `minimapAngle` is set by dragging the minimap button.)

- [ ] **Step 3: `Options.lua`**

Every row that maps to one setting carries `settingKey` and gets its `get`/`set` from a helper:
```lua
--[[---------------------------------------------------------------------------
Options.lua -- the option pages (OptionsPanel.lua builds them): General,
Bar, Visibility, Display, Categories. Every row writes through Settings.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local L = ns.L
local S = ns.Settings

local function add(page, items) for _, item in ipairs(items) do page[#page + 1] = item end end

-- A row bound to one setting.
local function bind(key, row)
    row.settingKey = key
    row.get = row.get or function() return S.Get(key) end
    row.set = row.set or function(v) S.Set(key, v) end
    return row
end
local function check(key, label) return bind(key, { type = "check", label = label }) end
local function slider(key, label, unit, step)
    local def = S.Def(key)
    return bind(key, { label = label, min = def.min, max = def.max, step = step or 1, unit = unit })
end
local function select(key, label, prefix)
    return bind(key, { type = "select", label = label, choices = function()
        local list = {}
        for _, v in ipairs(S.Def(key).values) do list[#list + 1] = { value = v, label = L[prefix .. v] } end
        return list
    end })
end
local function color(key, label) return bind(key, { type = "color", label = label }) end

local function generalTab()
    return {
        { type = "tab", label = "TAB_GENERAL" },
        { type = "select", label = "OPT_LANGUAGE",
          choices = function()
              local list = { { value = "AUTO", label = L.LANGUAGE_AUTO } }
              for _, c in ipairs(ns.Locale.CHOICES) do list[#list + 1] = c end
              return list
          end,
          get = function() return ns.Locale.Setting() end, set = function(v) ns.Locale.Set(v) end },
        { type = "header", label = "OPT_MINIMAP" },
        check("minimapShow", "OPT_MINIMAP_SHOW"),
        { type = "header", label = "OPT_PROFILE" },
        { type = "select", label = "OPT_PROFILE_ACTIVE",
          choices = function()
              local list = {}
              for _, name in ipairs(ns.ProfileList()) do list[#list + 1] = { label = name, value = name } end
              return list
          end,
          get = function() return ns.ActiveProfile() end,
          set = function(name) ns.SwitchProfile(name); ns.RefreshOptions() end },
        { type = "buttons", buttons = {
            { label = "OPT_PROFILE_SAVE_AS", width = 150, onClick = function() ns.AskProfileName() end },
            { label = "OPT_PROFILE_DELETE", width = 100, onClick = function() ns.AskDeleteProfile() end },
        } },
        { type = "buttons", buttons = {
            { label = "OPT_EXPORT", width = 120, onClick = function() ns.ShowExport() end },
            { label = "OPT_IMPORT", width = 120, onClick = function() ns.AskImport() end },
        } },
    }
end

local function barTab()
    return {
        { type = "tab", label = "TAB_BAR" },
        { type = "header", label = "OPT_LAYOUT" },
        select("orientation", "OPT_ORIENTATION", "ORIENT_"),
        slider("perRow", "OPT_PER_ROW"),
        slider("size", "OPT_SIZE", "px"),
        slider("spacing", "OPT_SPACING", "px"),
        slider("scale", "OPT_SCALE", "%", 5),
        { type = "header", label = "OPT_POSITION" },
        check("locked", "OPT_LOCKED"),
        select("point", "OPT_POINT", "POINT_"),
        slider("x", "OPT_X", "px"),
        slider("y", "OPT_Y", "px"),
        { type = "header", label = "OPT_BORDER" },
        check("borderShow", "OPT_BORDER_SHOW"),
        slider("borderSize", "OPT_BORDER_SIZE", "px"),
        color("borderColor", "OPT_BORDER_COLOR"),
        check("backgroundShow", "OPT_BACKGROUND_SHOW"),
        color("backgroundColor", "OPT_BACKGROUND_COLOR"),
    }
end

local function visibilityTab()
    return {
        { type = "tab", label = "TAB_VISIBILITY" },
        { type = "header", label = "OPT_WHEN" },
        select("visMode", "OPT_VIS_MODE", "VIS_"),
        check("visInstance", "OPT_VIS_INSTANCE"),
        check("visGroup", "OPT_VIS_GROUP"),
        check("visHideDead", "OPT_VIS_DEAD"),
        check("visHideTaxi", "OPT_VIS_TAXI"),
        { type = "header", label = "OPT_OPACITY" },
        slider("alphaNoCombat", "OPT_ALPHA_NOCOMBAT", "%", 5),
        slider("alphaCombat", "OPT_ALPHA_COMBAT", "%", 5),
        check("fadeMouseover", "OPT_FADE_MOUSEOVER"),
    }
end

local function displayTab()
    return {
        { type = "tab", label = "TAB_DISPLAY" },
        { type = "header", label = "OPT_COUNT" },
        bind("countFont", { type = "select", label = "OPT_FONT", choices = function()
            local list = {}
            for _, f in ipairs(ns.Media.Fonts()) do
                list[#list + 1] = { value = f.key, label = f.key == "DEFAULT" and L.FONT_DEFAULT or f.key, font = f.key }
            end
            return list
        end }),
        slider("countSize", "OPT_FONT_SIZE", "px"),
        select("countOutline", "OPT_OUTLINE", "OUTLINE_"),
        color("countColor", "OPT_COUNT_COLOR"),
        select("countPoint", "OPT_COUNT_POINT", "POINT_"),
        slider("countX", "OPT_X", "px"),
        slider("countY", "OPT_Y", "px"),
        { type = "header", label = "OPT_CHOOSING" },
        select("arrowMode", "OPT_ARROW", "ARROW_"),
        check("tooltip", "OPT_TOOLTIP"),
    }
end

local function categoriesTab()
    local items = {
        { type = "tab", label = "TAB_CATEGORIES" },
        { type = "header", label = "OPT_CATEGORIES" },
        check("hideEmpty", "OPT_HIDE_EMPTY"),
    }
    for _, cat in ipairs(S.CATEGORIES) do
        local up = cat:upper()
        add(items, {
            { type = "header", label = "CAT_" .. up },
            check("show_" .. cat, "OPT_CAT_SHOW"),
            { label = "OPT_CAT_POSITION", min = 1, max = #S.CATEGORIES, step = 1, settingKey = "order", cat = cat,
              get = function() return S.Position(cat) end,
              set = function(v) S.MoveTo(cat, v); ns.RefreshOptions() end },
        })
    end
    return items
end

local spec
function ns.OptionsSpec()
    if not spec then
        spec = { title = L.ADDON_NAME }
        for _, tab in ipairs({ generalTab, barTab, visibilityTab, displayTab, categoriesTab }) do add(spec, tab()) end
    end
    return spec
end

ns.On("PLAYER_LOGIN", function() ns.BuildOptions(ns.OptionsSpec()) end)
ns.Slash[""] = function() ns.Window.Toggle() end

-- Export and import through Blizzard's text popups.
if StaticPopupDialogs then
    StaticPopupDialogs.FOREVERCONSUMABLES_EXPORT = {
        text = "", button1 = OKAY or "OK", hasEditBox = 1, editBoxWidth = 350,
        OnShow = function(dialog)
            local box = dialog.GetEditBox and dialog:GetEditBox()
            if box then box:SetText(S.Export()); box:HighlightText(); box:SetFocus() end
        end,
        EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }
    StaticPopupDialogs.FOREVERCONSUMABLES_IMPORT = {
        text = "", button1 = ACCEPT or "Accept", button2 = CANCEL or "Cancel", hasEditBox = 1, editBoxWidth = 350,
        OnAccept = function(dialog)
            local box = dialog.GetEditBox and dialog:GetEditBox()
            local ok, err = S.Import(box and box:GetText())
            if not ok then ns.Print(L[err]) end
            ns.RefreshOptions()
        end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }
end
function ns.ShowExport()
    StaticPopupDialogs.FOREVERCONSUMABLES_EXPORT.text = L.POPUP_EXPORT
    StaticPopup_Show("FOREVERCONSUMABLES_EXPORT")
end
function ns.AskImport()
    StaticPopupDialogs.FOREVERCONSUMABLES_IMPORT.text = L.POPUP_IMPORT
    StaticPopup_Show("FOREVERCONSUMABLES_IMPORT")
end
```
Locale keys for all four files (en / de / es / fr):
- Tabs: `TAB_GENERAL` General / Allgemein / General / Général; `TAB_BAR` Bar / Leiste / Barra / Barre; `TAB_VISIBILITY` Visibility / Sichtbarkeit / Visibilidad / Visibilité; `TAB_DISPLAY` Display / Anzeige / Visualización / Affichage; `TAB_CATEGORIES` Categories / Kategorien / Categorías / Catégories
- General: `OPT_MINIMAP` Minimap button / Minimap-Knopf / Botón del minimapa / Bouton de la minicarte; `OPT_MINIMAP_SHOW` Show / Anzeigen / Mostrar / Afficher; `OPT_PROFILE` Profile / Profil / Perfil / Profil; `OPT_PROFILE_ACTIVE` Active profile / Aktives Profil / Perfil activo / Profil actif; `OPT_PROFILE_SAVE_AS` Save as... / Speichern als... / Guardar como... / Enregistrer sous...; `OPT_PROFILE_DELETE` Delete / Löschen / Borrar / Supprimer; `OPT_EXPORT` Export / Exportieren / Exportar / Exporter; `OPT_IMPORT` Import / Importieren / Importar / Importer; `POPUP_EXPORT` Copy this text (Ctrl+C): / Diesen Text kopieren (Strg+C): / Copia este texto (Ctrl+C): / Copiez ce texte (Ctrl+C) :; `POPUP_IMPORT` Paste a profile text: / Profiltext einfügen: / Pega el texto de un perfil: / Collez le texte d'un profil :
- Bar: `OPT_LAYOUT` Layout / Anordnung / Disposición / Disposition; `OPT_ORIENTATION` Direction / Richtung / Dirección / Direction; `ORIENT_HORIZONTAL` Horizontal / Waagrecht / Horizontal / Horizontale; `ORIENT_VERTICAL` Vertical / Senkrecht / Vertical / Verticale; `OPT_PER_ROW` Buttons per row / Knöpfe pro Reihe / Botones por fila / Boutons par rangée; `OPT_SIZE` Button size / Knopfgröße / Tamaño de botón / Taille des boutons; `OPT_SPACING` Spacing / Abstand / Espaciado / Espacement; `OPT_SCALE` Scale / Skalierung / Escala / Échelle; `OPT_POSITION` Position / Position / Posición / Position; `OPT_LOCKED` Locked / Gesperrt / Bloqueada / Verrouillée; `OPT_POINT` Anchor point / Ankerpunkt / Punto de anclaje / Point d'ancrage; `OPT_X` Horizontal offset / Waagrechter Versatz / Desplazamiento horizontal / Décalage horizontal; `OPT_Y` Vertical offset / Senkrechter Versatz / Desplazamiento vertical / Décalage vertical; `OPT_BORDER` Border and background / Rahmen und Hintergrund / Borde y fondo / Bordure et fond; `OPT_BORDER_SHOW` Show border / Rahmen anzeigen / Mostrar borde / Afficher la bordure; `OPT_BORDER_SIZE` Border size / Rahmenstärke / Grosor del borde / Épaisseur de la bordure; `OPT_BORDER_COLOR` Border colour / Rahmenfarbe / Color del borde / Couleur de la bordure; `OPT_BACKGROUND_SHOW` Show background / Hintergrund anzeigen / Mostrar fondo / Afficher le fond; `OPT_BACKGROUND_COLOR` Background colour / Hintergrundfarbe / Color de fondo / Couleur du fond
- Points: `POINT_TOPLEFT` … `POINT_BOTTOMRIGHT` — copy the nine lines from each FSM locale file (`grep '^L.POINT_' ~/Dokumente/ForeverSquareMinimap/Locales/<code>.lua`).
- Visibility: `OPT_WHEN` When to show / Wann anzeigen / Cuándo mostrar / Quand afficher; `OPT_VIS_MODE` Show / Anzeigen / Mostrar / Afficher; `VIS_ALWAYS` Always / Immer / Siempre / Toujours; `VIS_COMBAT` In combat only / Nur im Kampf / Solo en combate / Seulement en combat; `VIS_NOCOMBAT` Out of combat only / Nur außerhalb des Kampfs / Solo fuera de combate / Seulement hors combat; `VIS_NEVER` Never / Nie / Nunca / Jamais; `OPT_VIS_INSTANCE` Only in dungeons and raids / Nur in Dungeons und Raids / Solo en mazmorras y bandas / Seulement en donjon et raid; `OPT_VIS_GROUP` Only in a group / Nur in einer Gruppe / Solo en grupo / Seulement en groupe; `OPT_VIS_DEAD` Hide while dead / Ausblenden, wenn tot / Ocultar al estar muerto / Masquer si mort; `OPT_VIS_TAXI` Hide on a flight path / Auf dem Flugweg ausblenden / Ocultar en ruta de vuelo / Masquer en vol; `OPT_OPACITY` Opacity / Deckkraft / Opacidad / Opacité; `OPT_ALPHA_NOCOMBAT` Out of combat / Außerhalb des Kampfs / Fuera de combate / Hors combat; `OPT_ALPHA_COMBAT` In combat / Im Kampf / En combate / En combat; `OPT_FADE_MOUSEOVER` Fully visible under the mouse / Unter der Maus voll sichtbar / Totalmente visible bajo el ratón / Entièrement visible sous la souris
- Display: `OPT_COUNT` Count / Anzahl / Cantidad / Quantité; `OPT_FONT` Font / Schrift / Fuente / Police; `FONT_DEFAULT` Game font / Spielschrift / Fuente del juego / Police du jeu; `OPT_FONT_SIZE` Size / Größe / Tamaño / Taille; `OPT_OUTLINE` Outline / Kontur / Contorno / Contour; `OUTLINE_NONE` None / Keine / Ninguno / Aucun; `OUTLINE_OUTLINE` Thin / Dünn / Fino / Fin; `OUTLINE_THICKOUTLINE` Thick / Dick / Grueso / Épais; `OPT_COUNT_COLOR` Colour / Farbe / Color / Couleur; `OPT_COUNT_POINT` Point on the button / Punkt am Knopf / Punto en el botón / Point sur le bouton; `OPT_CHOOSING` Choosing / Auswählen / Elegir / Choisir; `OPT_ARROW` Choose with / Auswählen mit / Elegir con / Choisir avec; `ARROW_RIGHT` Arrow beside / Pfeil daneben / Flecha al lado / Flèche à côté; `ARROW_BELOW` Arrow below / Pfeil darunter / Flecha debajo / Flèche dessous; `ARROW_RIGHTCLICK` Right click / Rechtsklick / Clic derecho / Clic droit; `OPT_TOOLTIP` Show tooltips / Tooltips anzeigen / Mostrar descripciones / Afficher les infobulles
- Categories: `OPT_CATEGORIES` Categories / Kategorien / Categorías / Catégories; `OPT_HIDE_EMPTY` Hide empty categories / Leere Kategorien ausblenden / Ocultar categorías vacías / Masquer les catégories vides; `OPT_CAT_SHOW` Show / Anzeigen / Mostrar / Afficher; `OPT_CAT_POSITION` Position on the bar / Platz in der Leiste / Posición en la barra / Place dans la barre

Append to the TOC after `Picker.lua`: `Options\Style.lua`, `Options\Widgets.lua`, `OptionsPanel.lua`, `Options.lua`, `MinimapButton.lua`.

- [ ] **Step 4: Run** `tests/run options` — extend `tests/mock.lua` for what the copied window needs at build time (it mirrors FSM's mock: `SetColorTexture`, `SetHighlightTexture`, `EnableMouseWheel`, `SetScrollChild`, `GetVerticalScrollRange`, `SetVerticalScroll`, `CreateFontString(_, _, template)` etc. — CamelCase no-ops cover most; return values where the code does arithmetic, e.g. `GetVerticalScrollRange` → 0). Then `tests/run`.

- [ ] **Step 5: Commit** `git add -A && git commit -m "Options window, minimap button, addon compartment"`

---

### Task 10: In-game check (controller with the user)

Not for a subagent.

- [ ] **Step 1:** `tests/run` (full) green; `./install …/_classic_beta_/Interface/AddOns`.
- [ ] **Step 2:** User `/reload`s. Check with the user (screenshot of only the bar region — private chats are on screen): bar shows, counts right, left click eats/drinks/uses (the user does this, not the automation), arrow menu lists items, choosing works, empty categories hidden, collapse/expand in and out of combat, each visibility mode, unlock + drag + position saved, options window pages, export/import, minimap button and compartment entry, no Lua errors.
- [ ] **Step 3:** Fix what turns up (each fix with a test), `tests/run`, reinstall, recheck. Commit.

---

### Task 11: Documentation, release preparation

- [ ] **Step 1:** `README.md` (what it is, install, `/fcon`, categories, settings overview, tests) and `docs/curseforge/description.md` (English, like FSM's).
- [ ] **Step 2:** `tools/release`: copy from FSM, `sed -i 's/ForeverSquareMinimap/ForeverConsumables/g; s/Forever Square Minimap/Forever Consumables/g'`. The CurseForge project ID goes into the TOC as `## X-Curse-Project-ID:` once the user has created the project (ask; do not create it). Do not upload without the user's go.
- [ ] **Step 3:** Project documentation page (version, structure, pitfalls).
- [ ] **Step 4:** Notes for future work sessions.
- [ ] **Step 5:** `git push origin main`.
