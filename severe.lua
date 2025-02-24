--[[
    Optimized Lock's Npc Aimbot | Version 1.02
    Original by: Lock the hobo
]]

if not _G.settings then
	print("No settings found! Loading default settings")

	_G.settings = {
		["Aimbot"] = {
			["enabled"] = true,
			["jitter_fix"] = true,
			["max_distance"] = 200,
			["closes_to_crosshair"] = true,
			["aimbot_offset"] = {
				["x"] = 0,
				["y"] = 0,
			},

			["show_fov"] = true, -- false > off | true > on
			["fov_size"] = 220,
			["fov_color"] = { 255, 255, 255 },

			["smoothness"] = 1,
			["sensitivity"] = 1,

			["target_dot"] = true, -- false > off | true > on
			["target_dot_size"] = 5,
			["target_dot_color"] = { 255, 0, 0 },
		},

		["Esp"] = {
			["enabled"] = true, -- false > off | true > on

			["tracer"] = false, -- false > off | true > on
			["tracer_color"] = { 100, 100, 255 },
			["tracer_offset"] = {
				["y"] = -5,
			},

			["stick"] = false, -- false > off | true > on
			["stick_color"] = { 255, 255, 255 },
			["stick_offset"] = {
				["y"] = -2,
			},

			["name"] = true,
			["name_custom_text"] = "",
			["name_color"] = { 255, 255, 255 },
			["name_offset"] = {
				["x"] = 20,
				["y"] = -7,
			},

			["distance"] = true, -- false > off | true > on
			["distance_behind_text"] = "m",
			["distance_color"] = { 100, 100, 100 },
			["distance_offset"] = {
				["x"] = 20,
				["y"] = 5,
			},

			["head_dot"] = true, -- false > off | true > on
			["head_dot_size"] = 4,
			["head_dot_color"] = { 255, 255, 255 },
		},

		["Npc Path"] = { -- the path from game to the folder/model where the npc is located
			[1] = { "Workspace" },
		},
		["In Npc Path"] = { "Head" }, -- the path from the npc model to the target part
	}
end

-- CORE SETTINGS
local REFRESH_RATE = 1 / 1000

-- Idk if this help
local sqrt = math.sqrt
local floor = math.floor
local pairs = pairs
local drawingnew = Drawing.new
local drawingclear = Drawing.clear
local getchildren = getchildren
local getposition = getposition
local worldtoscreenpoint = worldtoscreenpoint
local findservice = findservice
local findfirstchild = findfirstchild
local time = time
local spawn = spawn
local wait = wait
local mousemoverel = mousemoverel

local Workspace = findservice(Game, "Workspace")
local Camera = findfirstchild(Workspace, "Camera")

local debugCheck = _G.cust_func or false
local screenDimensions = getscreendimensions()
local centerOfScreen = { screenDimensions.x / 2, screenDimensions.y / 2 }

local cachedNpcs = {}
local cachedPaths = {}

local function calculateDistance(p1, p2)
	local px, py, pz = p2.x - p1.x, p2.y - p1.y, p2.z - p1.z
	return sqrt(px * px + py * py + pz * pz)
end

local function Draw(drawingType, properties)
	local drawing = drawingnew(drawingType)
	for key, value in pairs(properties) do
		drawing[key] = value
	end
	return drawing
end

local fovCircle = Draw("Circle", {
	Color = settings.Aimbot.fov_color,
	Radius = settings.Aimbot.fov_size,
	Position = centerOfScreen,
	Thickness = 1,
	Visible = settings.Aimbot.show_fov,
})

local targetDot = Draw("Circle", {
	Visible = false,
	Color = settings.Aimbot.target_dot_color,
	Thickness = 1,
	Radius = settings.Aimbot.target_dot_size,
})

local function getInstanceFromPath(StartingInstance, pathTable, IGNORE_FIRST_INDEX)
	if not StartingInstance then
		return false
	end

	local CurrentInstance = StartingInstance
	local startIndex = IGNORE_FIRST_INDEX and 2 or 1

	for i = startIndex, #pathTable do
		CurrentInstance = findfirstchild(CurrentInstance, pathTable[i])
		if not CurrentInstance then
			return false
		end
	end

	return CurrentInstance
end

local function getNpcPart(npc)
	for _, pathTable in pairs(settings["In Npc Path"]) do
		local npcPart = getInstanceFromPath(npc, pathTable)
		if npcPart then
			return npcPart
		end
	end
	return nil
end

local espFunctions = {
	name = {
		init = function(cachedData)
			return Draw("Text", {
				Text = settings.Esp.name_custom_text ~= "" and settings.Esp.name_custom_text or cachedData.name,
				Color = settings.Esp.name_color,
				Outline = true,
				Center = false,
				Font = 1,
				Size = 10,
				Visible = settings.Esp.name,
			})
		end,

		update = function(drawing, cachedData)
			if not settings.Esp.name then
				drawing.Visible = false
				return
			end

			local offset = settings.Esp.name_offset
			local screenPos = cachedData.screenPos

			drawing.Position = { screenPos.x + offset.x, screenPos.y + offset.y }
			drawing.Visible = cachedData.onScreen
		end,
	},

	headdot = {
		init = function(cachedData)
			return Draw("Circle", {
				Color = settings.Esp.head_dot_color,
				Radius = settings.Esp.head_dot_size,
				Thickness = 1,
				Visible = settings.Esp.head_dot,
			})
		end,

		update = function(drawing, cachedData)
			if not settings.Esp.head_dot then
				drawing.Visible = false
				return
			end

			local screenPos = cachedData.screenPos
			drawing.Position = { screenPos.x, screenPos.y }
			drawing.Radius = settings.Esp.head_dot_size * 100 / cachedData.distance
			drawing.Visible = cachedData.onScreen
		end,
	},

	stick = {
		init = function(cachedData)
			return Draw("Line", {
				Color = settings.Esp.stick_color,
				Thickness = 1,
				Visible = settings.Esp.stick,
			})
		end,

		update = function(drawing, cachedData)
			if not settings.Esp.stick then
				drawing.Visible = false
				return
			end

			local screenPos = cachedData.screenPos
			local bottomScreenPos, bottomOnScreen = worldtoscreenpoint({
				cachedData.position.x,
				cachedData.position.y + settings.Esp.stick_offset.y,
				cachedData.position.z,
			})

			drawing.To = { screenPos.x, screenPos.y }
			drawing.From = { bottomScreenPos.x, bottomScreenPos.y }
			drawing.Visible = cachedData.onScreen and bottomOnScreen
		end,
	},

	tracer = {
		init = function(cachedData)
			return Draw("Line", {
				Color = settings.Esp.tracer_color,
				Thickness = 1,
				Visible = settings.Esp.tracer,
			})
		end,

		update = function(drawing, cachedData)
			if not settings.Esp.tracer then
				drawing.Visible = false
				return
			end

			local screenPos = cachedData.screenPos
			drawing.To = { screenPos.x, screenPos.y }
			drawing.From = centerOfScreen
			drawing.Visible = cachedData.onScreen
		end,
	},

	distance = {
		init = function(cachedData)
			return Draw("Text", {
				Text = cachedData.name .. settings.Esp.distance_behind_text,
				Color = settings.Esp.distance_color,
				Outline = true,
				Center = false,
				Font = 1,
				Size = 10,
				Visible = settings.Esp.distance,
			})
		end,

		update = function(drawing, cachedData)
			if not settings.Esp.distance then
				drawing.Visible = false
				return
			end

			local screenPos = cachedData.screenPos
			local offset = settings.Esp.distance_offset
			drawing.Position = { screenPos.x + offset.x, screenPos.y + offset.y }
			drawing.Text = floor(cachedData.distance) .. settings.Esp.distance_behind_text
			drawing.Visible = cachedData.onScreen
		end,
	},
}

local function getClosestTarget()
	local closestDistance = math.huge
	local closestNpc = nil
	local closestScreenPos = nil

	for _, cachedData in pairs(cachedNpcs) do
		if not cachedData.onScreen then
			continue
		end

		if cachedData.distance > settings.Aimbot.max_distance then
			continue
		end

		local screenPos = cachedData.screenPos

		local dx = screenPos.x - centerOfScreen[1]
		local dy = screenPos.y - centerOfScreen[2]
		local distFromCenter = sqrt(dx * dx + dy * dy)

		if distFromCenter > settings.Aimbot.fov_size then
			continue
		end

		local targetDistance = settings.Aimbot.closes_to_crosshair and distFromCenter or cachedData.distance

		if targetDistance < closestDistance then
			closestDistance = targetDistance
			closestNpc = cachedData
			closestScreenPos = screenPos
		end
	end

	return closestNpc, closestScreenPos
end

local function smoothMove(currentX, currentY, targetX, targetY)
	local smoothness = settings.Aimbot.smoothness

	local dx = (targetX - currentX) / smoothness
	local dy = (targetY - currentY) / smoothness

	return dx, dy
end

local function updateAimbot()
	if not settings.Aimbot.enabled or not isrightpressed() then
		targetDot.Visible = false
		return
	end

	local target, screenPos = getClosestTarget()
	if not target then
		targetDot.Visible = false
		return
	end

	if settings.Aimbot.target_dot then
		targetDot.Position = { screenPos.x, screenPos.y }
		targetDot.Visible = true
	end

	local aimX = screenPos.x + settings.Aimbot.aimbot_offset.x
	local aimY = screenPos.y + settings.Aimbot.aimbot_offset.y
	local moveX, moveY = smoothMove(centerOfScreen[1], centerOfScreen[2], aimX, aimY)

	mousemoverel(moveX, moveY)
end

local function updateCache(npc, cachedData)
	local position = getposition(cachedData.part)
	local screenPos, onScreen = worldtoscreenpoint({ position.x, position.y, position.z })

	cachedData.position = position
	cachedData.distance = calculateDistance(position, getposition(Camera))
	cachedData.screenPos = screenPos
	cachedData.onScreen = onScreen
end

local function cleanupDrawings(cachedData)
	for _, drawing in pairs(cachedData.drawings) do
		drawing:Remove()
	end
end

local function run()
	local currentActive = {}

	for _, Parent in pairs(cachedPaths) do
		for _, npc in pairs(getchildren(Parent)) do
			local cachedData = cachedNpcs[npc]

			if not cachedData then
				local npcPart = getNpcPart(npc)
				if not npcPart then
					continue
				end

				cachedData = {
					name = getname(npc),
					part = npcPart,
					npc = npc,
					position = nil,
					distance = nil,
					screenPos = nil,
					onScreen = nil,
					drawings = {},
				}

				if debugCheck and debugCheck(cachedData) then
					continue
				end

				for funcName, func in pairs(espFunctions) do
					cachedData.drawings[funcName] = func.init(cachedData)
				end

				cachedNpcs[npc] = cachedData
			end

			currentActive[npc] = true

			updateCache(npc, cachedData)

			for funcName, func in pairs(espFunctions) do
				func.update(cachedData.drawings[funcName], cachedData)
			end
		end
	end

	for npc, cachedData in pairs(cachedNpcs) do
		if not currentActive[npc] then
			cleanupDrawings(cachedData)
			cachedNpcs[npc] = nil
		end
	end

	updateAimbot()
end

local function initializePaths()
	for index, pathTable in pairs(settings["Npc Path"]) do
		cachedPaths[index] = getInstanceFromPath(Workspace, pathTable, true)
	end
end

local function initialize()
	initializePaths()

	spawn(function()
		while wait(REFRESH_RATE) do
			run()
		end
	end)
end

initialize()
