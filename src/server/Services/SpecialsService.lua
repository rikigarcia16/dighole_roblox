--!strict
-- Everything placed underground besides terrain: cave decoration, treasure chests, geodes and the
-- story landmarks. Objects are created when their sector is generated and stay hidden inside sealed
-- rock until the player digs into the connected cave system ("revealed"); only then are their
-- prompts enabled, so nothing can be opened through solid rock.
--
-- Reward safety: chests and geodes have stable ids from the cave layout (Logic/Caves); opened ids
-- are saved in the plot owner's profile (plot.openedChests) and marked before paying. Landmark
-- rewards are paid once per reader through profile.clues.

local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Resources = require(ReplicatedStorage.Shared.Config.Resources)
local Story = require(ReplicatedStorage.Shared.Config.Story)
local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Grid = require(ReplicatedStorage.Shared.Util.Grid)
local Caves = require(script.Parent.Parent.Logic.Caves)
local FossilBeds = require(script.Parent.Parent.Logic.FossilBeds)
local Collection = require(script.Parent.Parent.Logic.Collection)
local Fossils = require(ReplicatedStorage.Shared.Config.Fossils)
local OreGeneration = require(script.Parent.Parent.Logic.OreGeneration)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local TerrainChunkService = require(script.Parent.TerrainChunkService)
local InventoryService = require(script.Parent.InventoryService)
local StateService = require(script.Parent.StateService)
local FxService = require(script.Parent.FxService)
local CaveProps = require(script.Parent.CaveProps)

local SpecialsService = {}

local CELL = GameConfig.CellSize
local INTERACT_DISTANCE = 14
local SECTOR = Caves.SectorHeight

-- Chest coins by zone index (before a ±20% roll).
local CHEST_COINS = { 40, 120, 380, 950, 2600, 6500, 14000 }

type Special = {
	kind: "chest" | "landmark" | "geode" | "fossil",
	key: string,
	model: Model,
	prompt: ProximityPrompt,
	revealed: boolean,
	opened: boolean,
	depth: number,
	noteId: string?,
	system: string?, -- key of the cave system that reveals it
	speciesId: string?, -- fossils
}

type PlotState = {
	folder: Folder,
	sectors: { [number]: boolean }, -- sectors already decorated
	revealedSystems: { [string]: boolean },
	specials: { [string]: Special },
	bySystem: { [string]: { Special } },
	opened: { [string]: boolean },
}

local states: { [any]: PlotState } = {}

-- Hooks for structure services (AnomalyService) so this file does not grow with every structure.
local sectorBuiltHooks: { (any, Caves.Sector, Folder) -> () } = {}
local systemRevealedHooks: { (any, number, number, Player?) -> () } = {}

-- Called once per plot sector after its decoration exists: (plot, sector, folder).
function SpecialsService.onSectorBuilt(callback: (any, Caves.Sector, Folder) -> ())
	table.insert(sectorBuiltHooks, callback)
end

-- Called when a cave system is revealed: (plot, sectorIndex, system, player). `player` is nil when
-- the reveal comes from rebuilding a saved plot (no notification should be shown then).
function SpecialsService.onSystemRevealed(callback: (any, number, number, Player?) -> ())
	table.insert(systemRevealedHooks, callback)
end

local function fireHooks(list: { any }, ...: any)
	for _, callback in list do
		local ok, err = pcall(callback, ...)
		if not ok then
			warn("[SpecialsService] hook failed:", err)
		end
	end
end

local NEIGHBORS = { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } }

local part = CaveProps.part
local light = CaveProps.light

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

local function revealSystem(
	state: PlotState,
	key: string,
	plot: any,
	sectorIndex: number,
	system: number,
	player: Player?
): boolean
	if state.revealedSystems[key] then
		return false
	end
	state.revealedSystems[key] = true
	local list = state.bySystem[key]
	if list then
		for _, special in list do
			reveal(special)
		end
	end
	fireHooks(systemRevealedHooks, plot, sectorIndex, system, player)
	return true
end

-- Has the player dug a cell next to any cell of this system? (used when rebuilding a saved plot)
local function systemExposed(plot: any, sector: Caves.Sector, system: number): boolean
	local N = GameConfig.PlotDigCells
	for i, v in sector.grid do
		if v == system then
			local local0 = i - 1
			local x, z = local0 % N, (local0 // N) % N
			local d = sector.top + local0 // (N * N)
			for _, n in NEIGHBORS do
				if plot.dug[Grid.key(x + n[1], d + n[2], z + n[3])] then
					return true
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
		sectors = {},
		revealedSystems = {},
		specials = {},
		bySystem = {},
		opened = {},
	}
	if ownerProfile then
		for _, key in ownerProfile.plot.openedChests do
			state.opened[key] = true
		end
	end
	states[plot] = state
	return state
end

-- Colour of the crystals inside a geode, by depth.
local function geodeColor(depth: number): Color3
	local zone = Zones.at(depth)
	if zone.index <= 2 then
		return Color3.fromRGB(170, 110, 240)
	elseif zone.index == 3 then
		return Color3.fromRGB(110, 190, 255)
	end
	return zone.accent
end

local function register(state: PlotState, special: Special)
	state.specials[special.key] = special
	if special.system then
		local list = state.bySystem[special.system]
		if not list then
			list = {}
			state.bySystem[special.system] = list
		end
		table.insert(list, special)
	end
end

local function buildSector(plot: any, state: PlotState, sector: Caves.Sector)
	CaveProps.decorate(plot, sector, state.folder)
	fireHooks(sectorBuiltHooks, plot, sector, state.folder)
	for _, spot in sector.spots do
		local systemKey = Caves.systemKey(sector.index, spot.system)
		if not state.opened[spot.id] then
			local model, prompt
			if spot.kind == "chest" then
				model = CaveProps.chest(plot, spot, state.folder)
				prompt = makePrompt(model.PrimaryPart :: BasePart, "Chest", "Cofre", "Abrir")
				CollectionService:AddTag(model, "THNE_Chest")
			else
				model = CaveProps.geode(plot, spot, geodeColor(spot.d), state.folder)
				prompt = makePrompt(model.PrimaryPart :: BasePart, "Geode", "Geoda", "Abrir")
				prompt.HoldDuration = 1.2
				CollectionService:AddTag(model, "THNE_Geode")
			end
			register(state, {
				kind = spot.kind,
				key = spot.id,
				model = model,
				prompt = prompt,
				revealed = false,
				opened = false,
				depth = spot.d,
				noteId = nil,
				system = systemKey,
			})
		end
	end
	-- Systems the player already opened in an earlier session.
	for system in sector.systems do
		if systemExposed(plot, sector, system) then
			revealSystem(state, Caves.systemKey(sector.index, system), plot, sector.index, system, nil)
		end
	end
end

local function onChunkGenerated(plot: any, d0: number, d1: number)
	local state = stateFor(plot)
	if not state then
		return
	end
	-- Decorate a sector once its last layer exists, so floor/ceiling scans see real rock.
	for _, sector in Caves.sectorsInRange(plot.seed, d0 - SECTOR, d1) do
		if not state.sectors[sector.index] and plot.generatedDepth >= sector.top + SECTOR then
			state.sectors[sector.index] = true
			buildSector(plot, state, sector)
		end
	end
	for _, bed in FossilBeds.bedsInRange(plot.seed, d0, d1) do
		local key = "fossil:" .. bed.id
		local species = Fossils.get(bed.speciesId)
		if species and not state.specials[key] and not state.opened[bed.id] then
			local model = CaveProps.fossil(plot, bed, species.model, state.folder)
			local prompt = makePrompt(model.PrimaryPart :: BasePart, "Fossil", "Fósil", "Extraer")
			prompt.HoldDuration = 2
			CollectionService:AddTag(model, "THNE_Fossil")
			local special: Special = {
				kind = "fossil",
				key = key,
				model = model,
				prompt = prompt,
				revealed = false,
				opened = false,
				depth = bed.d,
				noteId = nil,
				system = nil,
				speciesId = bed.speciesId,
			}
			register(state, special)
			local second = if bed.alongX then { bed.cx + 1, bed.cz } else { bed.cx, bed.cz + 1 }
			for _, c in { { bed.cx, bed.cz }, second } do
				for _, n in NEIGHBORS do
					if plot.dug[Grid.key(c[1] + n[1], bed.d + n[2], c[2] + n[3])] then
						reveal(special)
					end
				end
			end
		end
	end
	for _, landmark in OreGeneration.landmarks(plot.seed) do
		local key = "landmark:" .. landmark.id
		if landmark.d >= d0 and landmark.d <= d1 and not state.specials[key] then
			local special = buildLandmark(plot, landmark, state.folder)
			special.key = key
			register(state, special)
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
				local system = Caves.cellAt(plot.seed, cx, d, cz)
				if system > 0 then
					local sectorIndex = d // SECTOR
					local key = Caves.systemKey(sectorIndex, system)
					if revealSystem(state, key, plot, sectorIndex, system, player) then
						local sector = Caves.sector(plot.seed, sectorIndex)
						local info = sector.systems[system]
						if info and info.hasCave then
							if profile then
								profile.stats.cavesFound += 1
							end
							local hasChest = false
							local list = state.bySystem[key]
							if list then
								for _, special in list do
									if special.kind == "chest" then
										hasChest = true
									end
								end
							end
							FxService.special(
								player,
								Grid.cellCenter(plot.originX, plot.originZ, cx, d, cz),
								"cave",
								nil
							)
							StateService.notify(
								player,
								"discovery",
								if hasChest
									then "¡Has abierto una cueva! Algo brilla en la oscuridad..."
									else "¡Has abierto una cueva!"
							)
						elseif info and not info.counter then -- the Counter is presented by AnomalyService
							StateService.notify(player, "discovery", "La roca suena hueca... ¡una geoda!")
						end
						StateService.push(player)
					end
				end
				local bed = FossilBeds.bedAt(plot.seed, cx, d, cz)
				if bed then
					local special = state.specials["fossil:" .. bed.id]
					if special and not special.revealed then
						reveal(special)
						StateService.notify(player, "discovery", "Algo con forma de hueso asoma en la roca...")
					end
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

-- Marks a chest/geode as opened before any reward is paid (so a failure can never pay twice).
local function claimOpen(player: Player, plot: any, special: Special): (any?, PlotState?)
	local state = states[plot]
	if not state or special.opened or not special.revealed then
		return nil, nil
	end
	if not PlotService.canDig(player, plot) then
		StateService.notify(player, "error", "Esto está en la parcela de otro jugador.", "special_foreign", 3)
		return nil, nil
	end
	local profile = PlayerDataService.get(player)
	local ownerProfile = plot.owner and PlayerDataService.get(plot.owner)
	if not profile or not ownerProfile then
		return nil, nil
	end
	special.opened = true
	special.prompt.Enabled = false
	special.model:SetAttribute("Opened", true)
	state.opened[special.key] = true
	table.insert(ownerProfile.plot.openedChests, special.key)
	return profile, state
end

local function openChest(player: Player, plot: any, special: Special)
	local profile = claimOpen(player, plot, special)
	if not profile then
		return
	end

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
	FxService.special(
		player,
		special.model:GetPivot().Position + Vector3.new(0, 1.5, 0),
		"chest",
		bonus and bonus.id or nil
	)
end

local function openGeode(player: Player, plot: any, special: Special)
	-- The shell is as hard as the rock around it: the tool must be able to break that rock.
	local zone = Zones.at(special.depth)
	local profile = PlayerDataService.get(player)
	local tool = profile and Tools.get(profile.equippedTool)
	local required = 1
	for _, rule in zone.base do
		local rock = Resources.get(rule.id)
		if rock then
			required = math.max(required, rock.requiredPower)
		end
	end
	if not tool or tool.power < required then
		StateService.notify(
			player,
			"error",
			string.format("La corteza es demasiado dura: necesitas potencia %d.", required),
			"geode_hard",
			3
		)
		return
	end
	local opener = claimOpen(player, plot, special)
	if not opener then
		return
	end

	-- Contents: the geode itself (collection item) and crystals that form at this depth.
	local rng = Random.new()
	InventoryService.collect(player, "geode", 1, true)
	local candidates = {}
	for _, ore in Resources.Ores do
		local rule = ore.spawn
		if rule and special.depth >= rule.minDepth and special.depth < rule.maxDepth and ore.rarity ~= "Common" then
			table.insert(candidates, ore)
		end
	end
	local crystal = candidates[rng:NextInteger(1, math.max(1, #candidates))] or Resources.get("copper")
	local amount = rng:NextInteger(3, 6)
	if crystal then
		InventoryService.collect(player, crystal.id, amount, true)
	end
	opener.stats.geodesOpened += 1
	StateService.notify(
		player,
		"find",
		string.format("¡Geoda abierta! Dentro había %d × %s", amount, if crystal then crystal.name else "cristal")
	)
	StateService.push(player)

	-- Crack the shell: lumps fly apart and fade, the crystals light up.
	local center = special.model:GetPivot().Position
	for _, child in special.model:GetChildren() do
		if child:IsA("BasePart") and (child.Name == "Lump" or child.Name == "Shell" or child.Name == "Seam") then
			local piece = child :: BasePart
			piece.CanCollide = false
			local away = (piece.Position - center)
			local offset = if away.Magnitude > 0.1 then away.Unit * 3 else Vector3.new(0, 3, 0)
			TweenService:Create(piece, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = piece.Position + offset,
				Transparency = 1,
			}):Play()
		end
	end
	local interior = special.model:FindFirstChild("Interior")
	if interior then
		for _, crystalPart in interior:GetChildren() do
			if crystalPart:IsA("BasePart") then
				TweenService:Create(crystalPart, TweenInfo.new(0.6), { Transparency = 0.05 }):Play()
			end
		end
		light(special.model.PrimaryPart or special.model, geodeColor(special.depth), 18, 1.6)
	end
	FxService.special(player, center, "geode", crystal and crystal.id or nil)
end

local function extractFossil(player: Player, plot: any, special: Special)
	local speciesId = special.speciesId
	local species = speciesId and Fossils.get(speciesId)
	if not species then
		return
	end
	local opener = claimOpen(player, plot, special)
	if not opener then
		return
	end
	opener.stats.fossilsExtracted += 1
	local result = Collection.registerFossil(opener, species.id, special.depth)
	if result and result.isNew then
		StateService.notify(
			player,
			"find",
			string.format("Nuevo fósil registrado: %s · +%s monedas", species.name, Format.number(result.reward))
		)
	elseif result and result.fragment then
		InventoryService.collect(player, "fossil", 1, true)
		StateService.notify(player, "find", species.name .. " (repetido): obtienes un Fragmento fósil")
	end
	StateService.push(player)
	Remotes.event("FossilFound"):FireClient(player, species.id, result ~= nil and result.isNew, special.depth)

	-- The bones lift out of the rock and fade.
	for _, child in special.model:GetDescendants() do
		if child:IsA("BasePart") then
			local piece = child :: BasePart
			TweenService:Create(piece, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = piece.Position + Vector3.new(0, 1.5, 0),
				Transparency = 1,
			}):Play()
		end
	end
	local model = special.model
	task.delay(1.3, function()
		model:Destroy()
	end)
	FxService.special(player, model:GetPivot().Position, "fossil", "fossil")
end

-- Reads a story note: first time pays its reward and records the clue. Used by landmarks and by
-- structures such as the Counter's tablet.
function SpecialsService.readNote(player: Player, noteId: string)
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

local function readLandmark(player: Player, special: Special)
	if special.noteId and special.revealed then
		SpecialsService.readNote(player, special.noteId)
	end
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
		if action ~= "Chest" and action ~= "Landmark" and action ~= "Geode" and action ~= "Fossil" then
			return
		end
		local plot, special = findSpecial(player, prompt)
		if not plot or not special or not nearModel(player, special.model) then
			return
		end
		if special.kind == "chest" then
			openChest(player, plot, special)
		elseif special.kind == "geode" then
			openGeode(player, plot, special)
		elseif special.kind == "fossil" then
			extractFossil(player, plot, special)
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
