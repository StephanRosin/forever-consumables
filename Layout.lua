--[[---------------------------------------------------------------------------
Layout.lua -- where the toggle, the bar and each button go, from the
settings alone (no frames), relative to the holder's top left corner.
The toggle sits at the start: left of the bar when it runs horizontally,
above it when vertically, mirrored by growX = "LEFT" / growY = "UP" so it
stays next to the first button. A cell is the button plus its arrow (right or
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
        if o.growX == "LEFT" then col = cols - 1 - col end
        if o.growY == "UP" then row = rows - 1 - row end
        g.cells[i] = { x = Layout.PAD + col * (cw + o.spacing), y = -(Layout.PAD + row * (ch + o.spacing)) }
    end
    if o.count > 0 then
        g.barWidth = 2 * Layout.PAD + cols * cw + (cols - 1) * o.spacing
        g.barHeight = 2 * Layout.PAD + rows * ch + (rows - 1) * o.spacing
    else
        g.barWidth, g.barHeight = 0, 0
    end
    local gap = Layout.TOGGLE + o.spacing
    local left, up = o.growX == "LEFT", o.growY == "UP"
    if horizontal then
        g.barX, g.barY = left and 0 or gap, 0
        g.width = o.count > 0 and gap + g.barWidth or Layout.TOGGLE
        g.height = math.max(Layout.TOGGLE, g.barHeight)
    else
        g.barX, g.barY = 0, up and 0 or -gap
        g.width = math.max(Layout.TOGGLE, g.barWidth)
        g.height = o.count > 0 and gap + g.barHeight or Layout.TOGGLE
    end
    g.toggleX = left and g.width - Layout.TOGGLE or 0
    g.toggleY = up and -(g.height - Layout.TOGGLE) or 0
    return g
end
