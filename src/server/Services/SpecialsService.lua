--!strict
-- Everything placed underground besides terrain: cave props (per zone style), treasure chests and
-- the story landmarks. Objects are created when their chunk is generated and stay hidden inside
-- sealed air pockets until the player digs into them ("revealed"); only then are their prompts
-- enabled, so nothing can be opened through solid rock.
--
-- Reward safety: chests are keyed by cave and the opened keys are saved in the plot owner's
-- profile; landmark rewards are paid once per reader through profile.clues.

local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Resources = require(ReplicatedStorage.Shared.Config.Resources)
local Story = require(ReplicatedStorage.Shared.Config.Story)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Grid = require(ReplicatedStorage.Shared.Util.Grid)
local Hash = require(ReplicatedStorage.Shared.Util.Hash)
local OreGeneration = require(script.Parent.Parent.Logic.OreGeneration)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local TerrainChunkService = require(script.Parent.TerrainChunkService)
local InventoryService = require(script.Parent.InventoryService)
local StateService = require(script.Parent.StateService)
local FxService = require(script.Parent.FxService)

local SpecialsService = {}

local CELL = GameConfig.CellSize
local INTERACT_DISTANCE = 14

-- Chest coins by zone index (before a ±20% roll).
local CHEST_COINS = { 40, 120, 380, 950, 2600, 6500, 14000 }

type Special = {
	kind: "chest" | "landmark",
	key: string,
	model: Model,
	prompt: ProximityPrompt,
	revealed: boolean,
	opened: boolean,
	depth: number,
	noteId: string?,
}

type PlotState = {
	folder: Folder,
	caves: { [string]: OreGeneration.Cave },
	revealedCaves: { [string]: boolean },
	specials: { [string]: Special },
	openedChests: { [string]: boolean },
}

local states: { [any]: PlotState } = {}

local NEIGHBORS = { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } }

-- Building helpers -------------------------------------------------------------------------------

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.Shape = shape or Enum.PartType.Block
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function light(parent: Instance, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
end

local function makePrompt(parent: BasePart, action: string, objectText: string, actionText: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt:SetAttribute("Action", action)
	prompt.Parent = parent
	return prompt
end

local function floorOf(plot: any, cave: OreGeneration.Cave, cx: number, cz: number): Vector3?
	local top = cave.by * 8
	for d = top + 7, top, -1 do
		local found = OreGeneration.caveAt(plot.seed, cx, d, cz)
		if found and found.key == cave.key then
			local center = Grid.cellCenter(plot.originX, plot.originZ, cx, d, cz)
			return center - Vector3.new(0, CELL / 2, 0)
		end
	end
	return nil
end

local function ceilingOf(plot: any, cave: OreGeneration.Cave, cx: number, cz: number): Vector3?
	local top = cave.by * 8
	for d = top, top + 7 do
		local found = OreGeneration.caveAt(plot.seed, cx, d, cz)
		if found and found.key == cave.key then
			local center = Grid.cellCenter(plot.originX, plot.originZ, cx, d, cz)
			return center + Vector3.new(0, CELL / 2, 0)
		end
	end
	return nil
end

-- Cave props, one style per zone. Kept to a handful of parts per cave.
local function decorateCave(plot: any, cave: OreGeneration.Cave, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Cave_" .. cave.key
	local ccx, ccz = math.floor(cave.cx), math.floor(cave.cz)
	local floor = floorOf(plot, cave, ccx, ccz)
	if not floor then
		return
	end
	local rng = Random.new(Hash.int(plot.seed, cave.bx, cave.by, cave.bz, 7))

	if cave.zoneId == "forgotten_mines" then
		-- Old mine supports: two posts, a crossbeam and a hanging lantern.
		local ceiling = ceilingOf(plot, cave, ccx, ccz)
		local height = if ceiling then math.max(4, ceiling.Y - floor.Y) else 7
		local wood = Color3.fromRGB(110, 78, 50)
		for _, side in { -1, 1 } do
			part(
				model,
				"Support",
				Vector3.new(0.8, height, 0.8),
				CFrame.new(floor + Vector3.new(side * 3.2, height / 2, 0)),
				wood,
				Enum.Material.WoodPlanks
			)
		end
		part(
			model,
			"Beam",
			Vector3.new(7.4, 0.8, 0.9),
			CFrame.new(floor + Vector3.new(0, height - 0.4, 0)),
			wood,
			Enum.Material.WoodPlanks
		)
		local lantern = part(
			model,
			"Lantern",
			Vector3.new(0.7, 0.9, 0.7),
			CFrame.new(floor + Vector3.new(1.2, height - 1.6, 0)),
			Color3.fromRGB(255, 190, 90),
			Enum.Material.Neon
		)
		light(lantern, Color3.fromRGB(255, 180, 90), 18, 1.4)
		if rng:NextNumber() < 0.6 then
			part(
				model,
				"OldPlank",
				Vector3.new(3.6, 0.3, 0.9),
				CFrame.new(floor + Vector3.new(-1, 0.2, 2)) * CFrame.Angles(0, rng:NextNumber() * 3, 0.2),
				wood,
				Enum.Material.Wood
			)
		end
	elseif cave.zoneId == "ancient_caverns" then
		local stone = Color3.fromRGB(206, 184, 140)
		part(
			model,
			"Column",
			Vector3.new(1.8, 6, 1.8),
			CFrame.new(floor + Vector3.new(2.5, 3, 1)),
			stone,
			Enum.Material.Sandstone
		)
		local glyph = part(
			model,
			"Glyph",
			Vector3.new(0.1, 1.2, 1.2),
			CFrame.new(floor + Vector3.new(1.55, 3.5, 1)),
			Color3.fromRGB(80, 230, 255),
			Enum.Material.Neon
		)
		glyph.CanCollide = false
		light(glyph, Color3.fromRGB(80, 230, 255), 12, 1)
	else
		-- Crystal clusters (crystal caves, volcanic, abyss and core use the zone accent colour).
		local zone = Zones.at(cave.by * 8)
		local color = if cave.zoneId == "crystal_caves"
			then (if rng:NextNumber() < 0.5 then Color3.fromRGB(110, 170, 255) else Color3.fromRGB(180, 110, 255))
			else zone.accent
		for i = 1, 4 do
			local height = 1.5 + rng:NextNumber() * 2.5
			local offset = Vector3.new(rng:NextNumber() * 5 - 2.5, height / 2 - 0.3, rng:NextNumber() * 5 - 2.5)
			local shard = part(
				model,
				"Crystal",
				Vector3.new(0.7, height, 0.7),
				CFrame.new(floor + offset)
					* CFrame.Angles(rng:NextNumber() * 0.6 - 0.3, rng:NextNumber() * 3, rng:NextNumber() * 0.6 - 0.3),
				color,
				Enum.Material.Neon
			)
			shard.CanCollide = false
			shard.Transparency = 0.15
			if i == 1 then
				light(shard, color, 16, 1.2)
			end
		end
	end

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CastShadow = false
		end
	end
	model.Parent = parent
end

local function buildChest(plot: any, cave: OreGeneration.Cave, parent: Instance): Special?
	local chest = cave.chest
	if not chest then
		return nil
	end
	local center = Grid.cellCenter(plot.originX, plot.originZ, chest.cx, chest.d, chest.cz)
	local floorY = center.Y - CELL / 2
	local model = Instance.new("Model")
	model.Name = "Chest_" .. cave.key
	local wood = Color3.fromRGB(130, 84, 46)
	local gold = Color3.fromRGB(240, 190, 60)
	local base = part(
		model,
		"Base",
		Vector3.new(2.6, 1.4, 1.7),
		CFrame.new(center.X, floorY + 0.7, center.Z),
		wood,
		Enum.Material.WoodPlanks
	)
	part(
		model,
		"Band",
		Vector3.new(2.7, 0.25, 1.8),
		CFrame.new(center.X, floorY + 1.1, center.Z),
		gold,
		Enum.Material.Metal
	)
	part(
		model,
		"Lid",
		Vector3.new(2.6, 0.7, 1.7),
		CFrame.new(center.X, floorY + 1.75, center.Z),
		wood,
		Enum.Material.WoodPlanks
	)
	part(
		model,
		"Lock",
		Vector3.new(0.4, 0.5, 0.2),
		CFrame.new(center.X, floorY + 1.35, center.Z - 0.9),
		gold,
		Enum.Material.Metal
	)
	model.PrimaryPart = base
	local prompt = makePrompt(base, "Chest", "Cofre", "Abrir")
	prompt:SetAttribute("CaveKey", cave.key)
	model.Parent = parent
	CollectionService:AddTag(model, "THNE_Chest")
	return {
		kind = "chest",
		key = cave.key,
		model = model,
		prompt = prompt,
		revealed = false,
		opened = false,
		depth = chest.d,
		noteId = nil,
	}
end

local function buildLandmark(plot: any, landmark: OreGeneration.Landmark, parent: Instance): Special
	local center = Grid.cellCenter(plot.originX, plot.originZ, landmark.cx, landmark.d, landmark.cz)
	local floorY = center.Y - CELL / 2
	local model = Instance.new("Model")
	model.Name = "Landmark_" .. landmark.id
	local main: Part
	if landmark.id == "miner_box" then
		local wood = Color3.fromRGB(122, 86, 52)
		main = part(
			model,
			"Crate",
			Vector3.new(2.4, 1.8, 1.8),
			CFrame.new(center.X, floorY + 0.9, center.Z) * CFrame.Angles(0, 0.3, 0),
			wood,
			Enum.Material.WoodPlanks
		)
		part(
			model,
			"Strap",
			Vector3.new(2.5, 0.25, 1.9),
			CFrame.new(center.X, floorY + 1.3, center.Z) * CFrame.Angles(0, 0.3, 0),
			Color3.fromRGB(70, 60, 50),
			Enum.Material.Metal
		)
		local lamp = part(
			model,
			"OldLamp",
			Vector3.new(0.5, 0.7, 0.5),
			CFrame.new(center.X + 0.6, floorY + 2.15, center.Z),
			Color3.fromRGB(255, 200, 120),
			Enum.Material.Neon
		)
		light(lamp, Color3.fromRGB(255, 190, 110), 12, 1.2)
	else
		main = part(
			model,
			"Tablet",
			Vector3.new(2.8, 3.2, 0.6),
			CFrame.new(center.X, floorY + 1.6, center.Z),
			Color3.fromRGB(70, 74, 86),
			Enum.Material.Slate
		)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 0
		gui.Brightness = 2
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.Parent = main
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Text = "◇ ᚦ ◈\nᛟ ◬ ᚨ\n◇ ◇ ◇"
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(90, 230, 255)
		text.Font = Enum.Font.Arcade
		text.Parent = gui
		light(main, Color3.fromRGB(90, 230, 255), 14, 1.4)
	end
	model.PrimaryPart = main
	model:SetAttribute("Kind", "landmark")
	model:SetAttribute("NoteId", landmark.id)
	local prompt = makePrompt(main, "Landmark", "Hallazgo", "Examinar")
	prompt:SetAttribute("NoteId", landmark.id)
	model.Parent = parent
	CollectionService:AddTag(model, "THNE_Landmark")
	return {
		kind = "landmark",
		key = landmark.id,
		model = model,
		prompt = prompt,
		revealed = false,
		opened = false,
		depth = landmark.d,
		noteId = landmark.id,
	}
end

-- Reveal logic -----------------------------------------------------------------------------------

local function reveal(special: Special)
	if special.revealed then
		return
	end
	special.revealed = true
	special.prompt.Enabled = not special.opened
	special.model:SetAttribute("Revealed", true)
end

-- Has the player dug a cell next to any cell of this cave?
local function caveExposed(plot: any, cave: OreGeneration.Cave): boolean
	local x0, d0, z0 = cave.bx * 8, cave.by * 8, cave.bz * 8
	for cx = x0, x0 + 7 do
		for d = d0, d0 + 7 do
			for cz = z0, z0 + 7 do
				if plot.dug[Grid.key(cx, d, cz)] then
					for _, n in NEIGHBORS do
						local found = OreGeneration.caveAt(plot.seed, cx + n[1], d + n[2], cz + n[3])
						if found and found.key == cave.key then
							return true
						end
					end
				end
			end
		end
	end
	return false
end

local function landmarkExposed(plot: any, landmark: OreGeneration.Landmark): boolean
	for _, n in NEIGHBORS do
		if plot.dug[Grid.key(landmark.cx + n[1], landmark.d + n[2], landmark.cz + n[3])] then
			return true
		end
	end
	return false
end

local function stateFor(plot: any): PlotState?
	local existing = states[plot]
	if existing then
		return existing
	end
	if not plot.owner or not plot.folder then
		return nil
	end
	local ownerProfile = PlayerDataService.get(plot.owner)
	local folder = Instance.new("Folder")
	folder.Name = "Underground"
	folder.Parent = plot.folder
	local state: PlotState = {
		folder = folder,
		caves = {},
		revealedCaves = {},
		specials = {},
		openedChests = {},
	}
	if ownerProfile then
		for _, key in ownerProfile.plot.openedChests do
			state.openedChests[key] = true
		end
	end
	states[plot] = state
	return state
end

local function onChunkGenerated(plot: any, d0: number, d1: number)
	local state = stateFor(plot)
	if not state then
		return
	end
	for _, cave in OreGeneration.cavesInRange(plot.seed, d0, d1) do
		if not state.caves[cave.key] then
			state.caves[cave.key] = cave
			decorateCave(plot, cave, state.folder)
			local chest = if state.openedChests[cave.key] then nil else buildChest(plot, cave, state.folder)
			if chest then
				state.specials["chest:" .. cave.key] = chest
			end
			if caveExposed(plot, cave) then
				state.revealedCaves[cave.key] = true
				if chest then
					reveal(chest)
				end
			end
		end
	end
	for _, landmark in OreGeneration.landmarks(plot.seed) do
		if landmark.d >= d0 and landmark.d <= d1 and not state.specials["landmark:" .. landmark.id] then
			local special = buildLandmark(plot, landmark, state.folder)
			state.specials["landmark:" .. landmark.id] = special
			if landmarkExposed(plot, landmark) then
				reveal(special)
			end
		end
	end
end

-- Called by DiggingService with the cells broken by one hit.
function SpecialsService.onCellsBroken(player: Player, plot: any, broken: { { cx: number, d: number, cz: number } })
	local state = stateFor(plot)
	if not state then
		return
	end
	local profile = PlayerDataService.get(player)
	for _, cell in broken do
		for _, n in NEIGHBORS do
			local cx, d, cz = cell.cx + n[1], cell.d + n[2], cell.cz + n[3]
			if Grid.inDigArea(cx, d, cz) and not plot.dug[Grid.key(cx, d, cz)] then
				local cave = OreGeneration.caveAt(plot.seed, cx, d, cz)
				if cave and not state.revealedCaves[cave.key] then
					state.revealedCaves[cave.key] = true
					local chest = state.specials["chest:" .. cave.key]
					if chest then
						reveal(chest)
					end
					if profile then
						profile.stats.cavesFound += 1
					end
					StateService.notify(
						player,
						"discovery",
						if chest
							then "¡Has abierto una cueva! Algo brilla en el fondo..."
							else "¡Has abierto una cueva!"
					)
					StateService.push(player)
				end
				local landmark = OreGeneration.landmarkAt(plot.seed, cx, d, cz)
				if landmark then
					local special = state.specials["landmark:" .. landmark.id]
					if special and not special.revealed then
						reveal(special)
						StateService.notify(player, "discovery", "Tu herramienta golpea algo que no es roca...")
					end
				end
			end
		end
	end
end

-- Interaction ----------------------------------------------------------------------------------

local function nearModel(player: Player, model: Model): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - model:GetPivot().Position).Magnitude <= INTERACT_DISTANCE
end

local function findSpecial(player: Player, prompt: ProximityPrompt): (any, Special?)
	for _, plot in PlotService.all() do
		local state = states[plot]
		if state and prompt:IsDescendantOf(state.folder) then
			for _, special in state.specials do
				if special.prompt == prompt then
					return plot, special
				end
			end
		end
	end
	return nil, nil
end

local function openChest(player: Player, plot: any, special: Special)
	local state = states[plot]
	if not state or special.opened or not special.revealed then
		return
	end
	if not PlotService.canDig(player, plot) then
		StateService.notify(player, "error", "Este cofre está en la parcela de otro jugador.", "chest_foreign", 3)
		return
	end
	local profile = PlayerDataService.get(player)
	local ownerProfile = plot.owner and PlayerDataService.get(plot.owner)
	if not profile or not ownerProfile then
		return
	end

	special.opened = true
	special.prompt.Enabled = false
	special.model:SetAttribute("Opened", true)
	state.openedChests[special.key] = true
	table.insert(ownerProfile.plot.openedChests, special.key)

	local zone = Zones.at(special.depth)
	local rng = Random.new()
	local coins = math.floor((CHEST_COINS[zone.index] or 100) * (0.8 + rng:NextNumber() * 0.4))
	profile.coins += coins
	profile.stats.coinsEarned += coins
	profile.stats.chestsOpened += 1

	-- A few units of a valuable ore that spawns at this depth.
	local candidates = {}
	for _, ore in Resources.Ores do
		local rule = ore.spawn
		if rule and special.depth >= rule.minDepth and special.depth < rule.maxDepth then
			table.insert(candidates, ore)
		end
	end
	table.sort(candidates, function(a, b)
		return a.value > b.value
	end)
	local bonus = candidates[rng:NextInteger(1, math.min(3, math.max(1, #candidates)))]
	local bonusText = ""
	if bonus then
		local amount = rng:NextInteger(2, 4)
		InventoryService.collect(player, bonus.id, amount, true)
		bonusText = string.format(" y %d × %s", amount, bonus.name)
	end
	StateService.notify(
		player,
		"sell",
		string.format("¡Cofre abierto! +%s monedas%s", Format.number(coins), bonusText)
	)
	StateService.push(player)

	local lid = special.model:FindFirstChild("Lid") :: BasePart?
	if lid then
		local hinge = lid.CFrame * CFrame.new(0, -0.35, 0.85)
		local opened = hinge * CFrame.Angles(math.rad(-100), 0, 0) * CFrame.new(0, 0.35, -0.85)
		TweenService
			:Create(lid, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = opened })
			:Play()
	end
	FxService.broadcast(
		player,
		special.model:GetPivot().Position + Vector3.new(0, 1.5, 0),
		bonus and bonus.id or "coal",
		true,
		nil,
		bonus and bonus.id or nil
	)
end

local function readLandmark(player: Player, special: Special)
	local noteId = special.noteId
	if not noteId or not special.revealed then
		return
	end
	local note = Story.Notes[noteId]
	local profile = PlayerDataService.get(player)
	if not note or not profile then
		return
	end
	if not profile.clues[noteId] then
		profile.clues[noteId] = true
		if note.reward > 0 then
			profile.coins += note.reward
			profile.stats.coinsEarned += note.reward
			StateService.notify(
				player,
				"discovery",
				string.format("Nueva pista: %s · +%s monedas", note.title, Format.number(note.reward))
			)
		else
			StateService.notify(player, "discovery", "Nueva pista: " .. note.title)
		end
		StateService.push(player)
	end
	Remotes.event("ShowNote"):FireClient(player, noteId)
end

function SpecialsService.start()
	TerrainChunkService.onChunkGenerated(onChunkGenerated)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local action = prompt:GetAttribute("Action")
		if action == "Note" then
			-- The house note: free, readable by anyone.
			local noteId = prompt:GetAttribute("NoteId")
			local profile = PlayerDataService.get(player)
			if type(noteId) == "string" and Story.Notes[noteId] and profile then
				if not profile.clues[noteId] then
					profile.clues[noteId] = true
					StateService.push(player)
				end
				Remotes.event("ShowNote"):FireClient(player, noteId)
			end
			return
		end
		if action ~= "Chest" and action ~= "Landmark" then
			return
		end
		local plot, special = findSpecial(player, prompt)
		if not plot or not special or not nearModel(player, special.model) then
			return
		end
		if special.kind == "chest" then
			openChest(player, plot, special)
		else
			readLandmark(player, special)
		end
	end)

	PlotService.onReleased(function(plot)
		local state = states[plot]
		if state then
			state.folder:Destroy()
			states[plot] = nil
		end
	end)
end

return SpecialsService
