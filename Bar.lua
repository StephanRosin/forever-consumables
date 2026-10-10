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

local GREY = { 0.5, 0.5, 0.5, 1 }   -- count text at zero
local buttons = {}      -- cat -> button
local lastScan = {}     -- cat -> entries
local dirty = false
-- In combat for display purposes. PLAYER_REGEN_DISABLED fires before
-- InCombatLockdown() turns true, so alpha and arrows follow this flag;
-- InCombatLockdown() alone decides whether protected calls are allowed.
local inCombat = InCombatLockdown() and true or false

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
    holder:SetDontSavePosition(true)   -- we place it ourselves from the saved x/y
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
        ns.AfterCombat("drag", function()
            holder:StopMovingOrSizing()
            Bar.SavePosition()
        end)
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
    local function coord(p, lo)
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
    Bar.holder:SetAlpha(ns.Visibility.Alpha(S.Get, inCombat, over))
end

-- Icons, counts, cooldowns, greying, arrows: allowed in combat.
-- The arrows are implicitly protected (anchored to the secure buttons): SetEnabled
-- only when not locked down, i.e. at combat start (explicit inCombat) and after it.
function Bar.UpdateDisplay()
    local combat = inCombat
    local locked = InCombatLockdown()
    for cat, b in pairs(buttons) do
        if b:IsShown() then
            local e = b.entry
            if e then
                local count = C_Item.GetItemCount(e.id) or 0
                b.icon:SetTexture(e.icon)
                b.icon:SetDesaturated(count == 0)
                b.count:SetText(tostring(count))
                local c = count == 0 and GREY or S.Get("countColor")
                b.count:SetTextColor(c[1], c[2], c[3], c[4])
                local start, duration = C_Container.GetItemCooldown(e.id)
                if duration and duration > 0 then b.cooldown:SetCooldown(start, duration) else b.cooldown:Clear() end
            else
                b.icon:SetTexture(Bar.ICONS[cat])
                b.icon:SetDesaturated(true)
                b.count:SetText("")
                b.cooldown:Clear()
            end
            if not locked then b.arrow:SetEnabled(not combat) end
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
    ns.AfterCombat("create", function()
        Bar.Create()
        Bar.Refresh()
        Bar.ApplyVisibility()
    end)
end)
ns.On("BAG_UPDATE_DELAYED", Bar.Refresh)
ns.On("PLAYER_LEVEL_UP", function() C_Timer.After(0.5, Bar.Refresh) end)
ns.On("BAG_UPDATE_COOLDOWN", function() Bar.UpdateDisplay() end)
ns.On("PLAYER_REGEN_DISABLED", function()
    inCombat = true
    Bar.UpdateDisplay()
    Bar.ApplyAlpha()
end)
ns.On("PLAYER_REGEN_ENABLED", function()
    inCombat = false
    if dirty then Bar.Refresh() else Bar.UpdateDisplay() end
    Bar.ApplyAlpha()
end)
-- Item data that was not cached at login arrives later: rescan, at most
-- one pending rescan at a time.
local infoPending = false
ns.On("GET_ITEM_INFO_RECEIVED", function()
    if infoPending then return end
    infoPending = true
    C_Timer.After(0.5, function()
        infoPending = false
        Bar.Refresh()
    end)
end)
-- Instance and taxi: the driver is rebuilt a moment after they change.
local function later() C_Timer.After(0.2, Bar.ApplyVisibility) end
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_CONTROL_LOST",
    "PLAYER_CONTROL_GAINED" }) do
    ns.On(event, later)
end

local VISIBILITY = { visMode = true, visInstance = true, visGroup = true, visHideDead = true, visHideTaxi = true }
local MINIMAP = { minimapShow = true, minimapAngle = true }
local ALPHA = { alphaCombat = true, alphaNoCombat = true, fadeMouseover = true }
S.OnChange(function(key)
    if not Bar.holder or MINIMAP[key] then return end
    if key == nil or VISIBILITY[key] then Bar.ApplyVisibility() end
    if key ~= nil and ALPHA[key] then Bar.ApplyAlpha(); return end
    if key == nil or not VISIBILITY[key] then ns.AfterCombat("refresh", Bar.Refresh) end
end)
