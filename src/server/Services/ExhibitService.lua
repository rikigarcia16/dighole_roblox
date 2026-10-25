--!strict
-- The house display case. Pieces of the story (resources with `keep`: the antique fragment, the
-- relic, the artifact) are not sold with the rest of the backpack. At the case, F exhibits every
-- kept piece not shown yet (one unit each); exhibiting all three completes the "relics" collection
-- (Config/Collections), which pays more than selling them and adds to the journal.
--
-- Shown pieces are saved in profile.collection.exhibit and rebuilt in the case on join, so the
-- house reflects how far the player has gone.
--
-- The house also shows progress derived from the profile (no new saved fields): a map of the seven
-- layers on the back wall, lit as each one is reached, with the depth record; a trophy for each
-- completed collection set on the west wall shelf; and, under the map, the stone of "El fondo" with
-- the times the hole turned round.

local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Collections = require(ReplicatedStorage.Shared.Config.Collections)
local Resources = require(ReplicatedStorage.Shared.Config.Resources)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)

local ExhibitService = {}

local INTERACT_DISTANCE = 12

-- Case slot order: the "relics" set order.
local ORDER: { string } = {}
for _, set in Collections do
	if set.kind == "exhibit" then
		for _, id in set.items or {} do
			table.insert(ORDER, id)
		end
	end
end

local shown: { [any]: Folder } = {}

local function displayModel(resource: Resources.Resource, at: Vector3, parent: Instance)
	local stand = Instance.new("Part")
	stand.Name = "Stand"
	stand.Anchored = true
	stand.Size = Vector3.new(1.4, 0.3, 1.4)
	stand.CFrame = CFrame.new(at - Vector3.new(0, 0.6, 0))
	stand.Color = Color3.fromRGB(60, 46, 34)
	stand.Material = Enum.Material.Wood
	stand.Parent = parent
	local piece = Instance.new("Part")
	piece.Name = resource.id
	piece.Anchored = true
	piece.CanCollide = false
	piece.Size = Vector3.new(0.9, 0.9, 0.9)
	piece.CFrame = CFrame.new(at) * CFrame.Angles(math.rad(20), math.rad(35), 0)
	piece.Color = resource.color
	piece.Material = if resource.rarity == "Unique" or resource.rarity == "Epic"
		then Enum.Material.Neon
		else Enum.Material.Marble
	piece.Parent = parent
	piece:SetAttribute("SpinSpeed", 0.35)
	CollectionService:AddTag(piece, "THNE_Spin") -- turns slowly in the case (AmbientLifeController)
end

local function rebuild(plot: any, profile: any)
	local old = shown[plot]
	if old then
		old:Destroy()
		shown[plot] = nil
	end
	if not plot.folder or not plot.points then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Exhibit"
	for i, id in ORDER do
		local resource = Resources.get(id)
		local slot = plot.points.vitrine[i]
		if resource and slot and profile.collection.exhibit[id] then
			displayModel(resource, slot, folder)
		end
	end
	folder.Parent = plot.folder
	shown[plot] = folder
end

-- Progress in the house ------------------------------------------------------------------------------

type Progress = { folder: Folder, signature: string }
local progress: { [any]: Progress } = {}

local function setDone(profile: any, id: string): boolean
	return profile.quests.completed["set_" .. id] == true
end

local function signatureOf(profile: any): string
	local parts = {}
	for _, zone in Zones.List do
		table.insert(parts, if profile.zonesReached[zone.id] then "1" else "0")
	end
	for _, set in Collections do
		table.insert(parts, if setDone(profile, set.id) then "1" else "0")
	end
	table.insert(parts, tostring(math.floor(profile.stats.maxDepth)))
	local core = profile.anomalies.core
	table.insert(parts, if core.engraved then "E" .. core.loops else "-")
	return table.concat(parts)
end

local function trophyColor(set: any): Color3
	if set.kind == "fossils" then
		return if set.id == "deep_fossils" then Color3.fromRGB(80, 230, 210) else Color3.fromRGB(226, 214, 184)
	end
	local first = set.items and set.items[1]
	local resource = first and Resources.get(first)
	return if resource then resource.color else Color3.fromRGB(255, 210, 120)
end

local function newPart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function buildLayerMap(plot: any, profile: any, folder: Folder)
	local board = newPart(
		"LayerMap",
		Vector3.new(11, 9.4, 0.2),
		plot.points.layerMap,
		Color3.fromRGB(58, 44, 32),
		Enum.Material.Wood,
		folder
	)
	board.CanCollide = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.4
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Text = "EL AGUJERO"
	title.TextColor3 = Color3.fromRGB(245, 226, 190)
	title.Font = Enum.Font.SpecialElite
	title.TextScaled = true
	title.Parent = gui
	local rows = #Zones.List
	local anyReached = false
	for i, zone in Zones.List do
		local reached = profile.zonesReached[zone.id] == true
		anyReached = anyReached or reached
		local row = Instance.new("Frame")
		row.BorderSizePixel = 0
		row.Position = UDim2.new(0, 16, 0, 44 + (i - 1) * 40)
		row.Size = UDim2.new(1, -32, 0, 36)
		row.BackgroundColor3 = if reached
			then zone.accent:Lerp(Color3.new(0, 0, 0), 0.35)
			else Color3.fromRGB(28, 24, 20)
		row.Parent = gui
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(10, 0)
		label.Size = UDim2.new(1, -20, 1, 0)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Font = Enum.Font.SpecialElite
		label.TextScaled = true
		label.TextColor3 = if reached then Color3.fromRGB(250, 240, 220) else Color3.fromRGB(90, 80, 70)
		label.Text = if reached
			then string.format(
				"%s · %d–%s m",
				zone.name,
				zone.minDepth,
				if i == rows then "…" else tostring(zone.maxDepth)
			)
			else string.format("???  · %d m", zone.minDepth)
		label.Parent = row
	end
	if anyReached then
		local marker = Instance.new("TextLabel")
		marker.BackgroundTransparency = 1
		marker.Position = UDim2.new(0, 16, 0, 44 + rows * 40)
		marker.Size = UDim2.new(1, -32, 0, 32)
		marker.Font = Enum.Font.SpecialElite
		marker.TextScaled = true
		marker.TextColor3 = Color3.fromRGB(255, 205, 90)
		marker.Text = "Récord: " .. Format.depth(profile.stats.maxDepth)
		marker.Parent = gui
	end
end

local function buildTrophies(plot: any, profile: any, folder: Folder)
	local slot = 0
	for _, set in Collections do
		if setDone(profile, set.id) then
			slot += 1
			local at = plot.points.trophies[slot]
			if not at then
				break
			end
			newPart(
				"TrophyBase",
				Vector3.new(1, 0.5, 1),
				CFrame.new(at + Vector3.new(0, 0.25, 0)),
				Color3.fromRGB(40, 32, 26),
				Enum.Material.Marble,
				folder
			)
			local piece = newPart(
				"Trophy_" .. set.id,
				Vector3.new(0.7, 1.1, 0.7),
				CFrame.new(at + Vector3.new(0, 1.15, 0)),
				trophyColor(set),
				Enum.Material.Neon,
				folder
			)
			piece.CanCollide = false
			piece:SetAttribute("SpinSpeed", 0.25)
			CollectionService:AddTag(piece, "THNE_Spin")
			local gui = Instance.new("BillboardGui")
			-- narrow and staggered: the shelf slots are only 2.2 studs apart
			gui.Size = UDim2.fromOffset(110, 34)
			gui.StudsOffsetWorldSpace = Vector3.new(0, if slot % 2 == 0 then 1.9 else 1.1, 0)
			gui.MaxDistance = 18
			gui.LightInfluence = 0
			gui.Parent = piece
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Text = set.name
			label.TextScaled = true
			label.TextWrapped = true
			label.Font = Enum.Font.GothamBold
			label.TextColor3 = Color3.fromRGB(255, 236, 200)
			label.TextStrokeTransparency = 0.4
			label.Parent = gui
		end
	end
end

-- The bottom: once the player's number is on the wall of "El fondo", a black polished stone with a
-- crack of white light stands on a pedestal beside the layer map, with the times the hole turned round.
local function buildCoreTrophy(plot: any, profile: any, folder: Folder)
	local core = profile.anomalies.core
	if not core.engraved then
		return
	end
	local map = plot.points.layerMap :: CFrame
	-- beside the map, between it and the display case (the table with the note stands in front of it)
	local base = map.Position + map.RightVector * 7.5 + map.LookVector * 1.4 - Vector3.new(0, 5.3, 0)
	newPart(
		"CorePedestal",
		Vector3.new(1.6, 1.2, 1.6),
		CFrame.new(base + Vector3.new(0, 0.6, 0)),
		Color3.fromRGB(40, 32, 26),
		Enum.Material.Marble,
		folder
	)
	local stone = newPart(
		"Trophy_core",
		Vector3.new(1, 1.4, 1),
		CFrame.new(base + Vector3.new(0, 2, 0)),
		Color3.fromRGB(22, 22, 26),
		Enum.Material.Marble,
		folder
	)
	stone.CanCollide = false
	stone.Reflectance = 0.15 -- still, unlike the set trophies: the bottom does not turn
	local crack = newPart(
		"CoreCrack",
		Vector3.new(0.08, 1.2, 1.02),
		stone.CFrame * CFrame.Angles(0, 0, math.rad(12)),
		Color3.fromRGB(214, 236, 255),
		Enum.Material.Neon,
		folder
	)
	crack.CanCollide = false
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0)
	gui.MaxDistance = 22
	gui.LightInfluence = 0
	gui.Parent = stone
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = if core.loops > 0 then string.format("El fondo\nVueltas: %d", core.loops) else "El fondo"
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(214, 236, 255)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
end

-- Rebuilds the layer map and the trophies when something they show has changed.
local function refreshProgress(plot: any, profile: any)
	if not plot.folder or not plot.points or not plot.points.layerMap then
		return
	end
	local signature = signatureOf(profile)
	local current = progress[plot]
	if current and current.signature == signature and current.folder.Parent then
		return
	end
	if current then
		current.folder:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Progress"
	buildLayerMap(plot, profile, folder)
	buildTrophies(plot, profile, folder)
	buildCoreTrophy(plot, profile, folder)
	folder.Parent = plot.folder
	progress[plot] = { folder = folder, signature = signature }
end

local function near(player: Player, part: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - part.Position).Magnitude <= INTERACT_DISTANCE
end

-- Exhibits every kept piece the player carries that is not in the case yet. Returns how many.
function ExhibitService.exhibit(player: Player): number
	local profile = PlayerDataService.get(player)
	local plot = PlotService.get(player)
	if not profile or not plot then
		return 0
	end
	local added = {}
	for _, id in ORDER do
		local count = profile.inventory[id] or 0
		if count > 0 and not profile.collection.exhibit[id] then
			profile.inventory[id] = if count > 1 then count - 1 else nil
			profile.collection.exhibit[id] = true
			local resource = Resources.get(id)
			table.insert(added, if resource then resource.name else id)
		end
	end
	if #added == 0 then
		local missing = 0
		for _, id in ORDER do
			if not profile.collection.exhibit[id] then
				missing += 1
			end
		end
		StateService.notify(
			player,
			"info",
			if missing == 0
				then "La vitrina está completa."
				else "No llevas nada nuevo que exponer. Faltan " .. missing .. " pieza(s): búscalas bajo tierra.",
			"exhibit_none",
			4
		)
		return 0
	end
	rebuild(plot, profile)
	StateService.notify(player, "discovery", "Expuesto en la vitrina: " .. table.concat(added, ", "))
	StateService.push(player)
	return #added
end

function ExhibitService.start()
	PlotService.onReady(function(player, plot)
		local profile = PlayerDataService.get(player)
		if profile then
			rebuild(plot, profile)
			refreshProgress(plot, profile)
		end
	end)
	-- every state push may follow a new layer, a completed set or a deeper record
	StateService.beforePush(function(player)
		local plot = PlotService.get(player)
		local profile = PlayerDataService.get(player)
		if plot and profile then
			refreshProgress(plot, profile)
		end
	end)
	PlotService.onReleased(function(plot)
		progress[plot] = nil -- its folder goes with the plot folder
		local old = shown[plot]
		if old then
			old:Destroy()
			shown[plot] = nil
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt:GetAttribute("Action") ~= "Exhibit" then
			return
		end
		local plot = PlotService.get(player)
		local cabinet = prompt.Parent
		-- only your own house's case
		if
			not plot
			or not plot.folder
			or not cabinet
			or not cabinet:IsA("BasePart")
			or not cabinet:IsDescendantOf(plot.folder)
			or not near(player, cabinet :: BasePart)
		then
			return
		end
		ExhibitService.exhibit(player)
	end)
end

return ExhibitService
