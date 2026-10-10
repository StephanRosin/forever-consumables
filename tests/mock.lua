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
    function w:SetDontSavePosition(v) self._dontSave = v end
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
        if type(rel) == "table" and rel._protected then self._protected = true end  -- anchored to a protected frame
    end
    function w:GetPoint() local a = self._point; if a then return a[1], a[2], a[3], a[4], a[5] end end
    function w:ClearAllPoints() guard(self, "ClearAllPoints"); self._point = nil end
    function w:SetAllPoints(rel)
        self._allPoints = rel or true
        if type(rel) == "table" and rel._protected then self._protected = true end
    end
    function w:SetAttribute(k, v) guard(self, "SetAttribute"); self._attrs[k] = v end
    function w:GetAttribute(k) return self._attrs[k] end
    function w:SetFrameRef(k, f) self._refs[k] = f end
    function w:GetFrameRef(k) return self._refs[k] end
    function w:RegisterEvent(e) self._events[e] = true end
    function w:UnregisterEvent(e) self._events[e] = nil end
    function w:RegisterForClicks(...) self._clicks = { ... } end
    function w:RegisterForDrag(...) self._drag = { ... } end
    function w:Enable() guard(self, "Enable"); self._enabled = true end
    function w:Disable() guard(self, "Disable"); self._enabled = false end
    function w:SetEnabled(v) guard(self, "SetEnabled"); self._enabled = v and true or false end
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
    -- Real client: REGEN_DISABLED fires before lockdown starts, REGEN_ENABLED after it ends.
    if on then
        M.Fire("PLAYER_REGEN_DISABLED")
        M.combat = true
    else
        M.combat = false
        M.Fire("PLAYER_REGEN_ENABLED")
    end
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
