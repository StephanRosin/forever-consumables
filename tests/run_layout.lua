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
M.check("dead and group", V.Driver(get, env), "[@player,dead] hide; [nogroup] hide; show")
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

-- Growth mirrored: 3 cells of 30, two per row, horizontal, left and up.
g = Lay.Compute({ count = 3, perRow = 2, size = 30, spacing = 4, orientation = "HORIZONTAL", arrowMode = "RIGHTCLICK",
    growX = "LEFT", growY = "UP" })
M.check("left/up: first cell right, bottom", g.cells[1].x .. "," .. g.cells[1].y, "37,-37")
M.check("left/up: second cell left of it", g.cells[2].x .. "," .. g.cells[2].y, "3,-37")
M.check("left/up: next row above", g.cells[3].x .. "," .. g.cells[3].y, "37,-3")
M.check("left: bar starts at the left edge", g.barX, 0)
M.check("left/up: toggle at the start corner", g.toggleX .. "," .. g.toggleY, (g.width - 14) .. "," .. -(g.height - 14))
g = Lay.Compute({ count = 3, perRow = 2, size = 30, spacing = 4, orientation = "VERTICAL", arrowMode = "RIGHTCLICK",
    growY = "UP" })
M.check("vertical up: bar at the top, toggle below", g.barY .. "," .. g.toggleY, "0," .. -(g.height - 14))
M.check("vertical up: first cell at the bottom", g.cells[1].y, -37)
g = Lay.Compute({ count = 3, perRow = 2, size = 30, spacing = 4, orientation = "HORIZONTAL", arrowMode = "RIGHTCLICK" })
M.check("default: toggle top left", g.toggleX .. "," .. g.toggleY, "0,0")

-- No collapse button: no room for it, the bar starts at the edge.
g = Lay.Compute({ count = 3, perRow = 10, size = 30, spacing = 4, orientation = "HORIZONTAL", arrowMode = "RIGHT", toggle = false })
M.check("no toggle: bar x", g.barX, 0)
M.check("no toggle: width is the bar", g.width, g.barWidth)
g = Lay.Compute({ count = 3, perRow = 1, size = 30, spacing = 4, orientation = "VERTICAL", arrowMode = "RIGHTCLICK", toggle = false })
M.check("no toggle, vertical: bar y", g.barY, 0)

M.done()
