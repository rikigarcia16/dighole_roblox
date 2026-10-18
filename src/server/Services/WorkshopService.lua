--!strict
-- E.'s workshop (Config/Anomalies.Rooms.workshop): built with its sector, revealed when a doorway
-- opens, and one interaction: hang your shovel on the eighth hook. The seven old shovels swing, the
-- ledger turns a page and shows, in E.'s hand, the exact number of blocks you had dug, under E.'s
-- 3 912. From then on the battery holds half as much again (EnergyService).
--
-- State lives in the plot owner's profile (anomalies.workshop), so it survives leaving. Only the
-- owner can hang a shovel in their own workshop.

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Anomalies = require(ReplicatedStorage.Shared.Config.Anomalies)
local ToolModels = require(ReplicatedStorage.Shared.Util.ToolModels)
local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local Caves = require(script.Parent.Parent.Logic.Caves)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)
local SpecialsService = require(script.Parent.SpecialsService)
local FxService = require(script.Parent.FxService)
local EnergyService = require(script.Parent.EnergyService)
local WorkshopRoomBuilder = require(script.Parent.WorkshopRoomBuilder)

local WorkshopService = {}

local INTERACT_DISTANCE = 12
local ANIMATION_SECONDS = 2.6

type Workshop = {
	plot: any,
	room: WorkshopRoomBuilder.Room,
	revealed: boolean,
	busy: boolean,
	hungModel: Model?,
}

local workshops: { [any]: Workshop } = {}

local function ownerProfile(plot: any): any?
	return plot.owner and PlayerDataService.get(plot.owner)
end

-- "3912" -> "3 912", the way E. writes numbers in the ledger
local function spaced(n: number): string
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", ""))
end

local function ledgerLines(profile: any, ownerName: string): string
	local workshop = profile.anomalies.workshop
	local lines = { ownerName .. " — " .. spaced(workshop.hungCount) }
	local gap = workshop.hungCount - Anomalies.WorkshopEBlocks
	if gap > 0 then
		table.insert(lines, "(+" .. spaced(gap) .. ")")
	else
		table.insert(lines, "(" .. spaced(-gap) .. ")")
	end
	local counter = profile.anomalies.counter
	if counter.solved then
		table.insert(lines, "◇ " .. spaced(counter.solvedCount))
	end
	return table.concat(lines, "\n")
end

-- The player's own tool, hanging head down from the eighth hook.
local function hangTool(workshop: Workshop, toolId: string, fadeIn: boolean): Model?
	if not Tools.get(toolId) then
		return nil
	end
	local model = ToolModels.buildModel(toolId)
	model.Name = "HungTool"
	local hook = workshop.room.hook
	model:PivotTo(CFrame.new(hook.Position + Vector3.new(0, -0.9, 0.35)) * CFrame.Angles(math.rad(-90), 0, 0))
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			if fadeIn then
				local target = d.Transparency
				d.Transparency = 1
				TweenService:Create(d, TweenInfo.new(0.8), { Transparency = target }):Play()
			end
		end
	end
	model.Parent = workshop.room.model
	return model
end

-- Rotates a group of parts about a hinge as a NumberValue is tweened (degrees, about the hinge's Z).
local function swingAbout(parts: { BasePart }, hinge: CFrame, info: TweenInfo, degrees: number)
	local offsets = {}
	for i, p in parts do
		offsets[i] = hinge:ToObjectSpace(p.CFrame)
	end
	local angle = Instance.new("NumberValue")
	angle.Changed:Connect(function(value: number)
		local turn = hinge * CFrame.Angles(0, 0, math.rad(value))
		for i, p in parts do
			if p.Parent then
				p.CFrame = turn * offsets[i]
			end
		end
	end)
	local tween = TweenService:Create(angle, info, { Value = degrees })
	tween.Completed:Connect(function()
		angle:Destroy()
	end)
	tween:Play()
end

local function showLedger(workshop: Workshop, profile: any, ownerName: string)
	workshop.room.ledgerText.Text = ledgerLines(profile, ownerName)
	local page = workshop.room.page
	page.Transparency = 1
	local gui = page:FindFirstChildOfClass("SurfaceGui")
	if gui then
		gui.Enabled = false
	end
end

local function hang(player: Player, workshop: Workshop)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	local state = profile.anomalies.workshop
	if state.hung or workshop.busy then
		return
	end
	workshop.busy = true
	workshop.room.hookPrompt.Enabled = false
	state.found = true
	state.hung = true
	state.hungCount = profile.stats.cellsDug
	state.hungAt = os.time()
	state.toolId = profile.equippedTool
	workshop.room.model:SetAttribute("Hung", true)

	workshop.hungModel = hangTool(workshop, state.toolId, true)
	-- the seven old shovels swing together, as if a door had opened
	for i, shovel in workshop.room.shovels do
		local parts = {}
		for _, d in shovel.model:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
		local info = TweenInfo.new(0.45 + i * 0.02, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true)
		swingAbout(parts, shovel.pivot, info, if i % 2 == 0 then 9 else -9)
	end
	-- the ledger turns a page
	local page = workshop.room.page
	swingAbout(
		{ page },
		workshop.room.pageHinge,
		TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		-175
	)
	FxService.special(player, workshop.room.hook.Position, "counter_lock", nil)

	task.delay(ANIMATION_SECONDS, function()
		workshop.busy = false
		if not workshop.room.model.Parent then
			return
		end
		showLedger(workshop, profile, player.Name)
		EnergyService.refresh(player)
		if player.Parent then
			StateService.notify(player, "discovery", "Nueva entrada en el diario: «La octava pala»")
			StateService.notify(
				player,
				"success",
				string.format(
					"Batería de E.: +%d %% de capacidad.",
					math.floor(Anomalies.WorkshopBatteryBonus * 100 + 0.5)
				)
			)
			StateService.push(player)
		end
	end)
	StateService.push(player)
end

local function build(plot: any, sector: Caves.Sector, folder: Folder)
	if sector.anomalyId ~= "workshop" or workshops[plot] then
		return
	end
	local profile = ownerProfile(plot)
	if not profile then
		return
	end
	local room = WorkshopRoomBuilder.build(plot, folder)
	local workshop: Workshop = { plot = plot, room = room, revealed = false, busy = false, hungModel = nil }
	workshops[plot] = workshop
	local state = profile.anomalies.workshop
	if state.hung then
		room.model:SetAttribute("Hung", true)
		workshop.hungModel = hangTool(workshop, state.toolId, false)
		showLedger(workshop, profile, plot.owner.Name)
	end
end

local function onRevealed(plot: any, sectorIndex: number, system: number, finder: Player?)
	if sectorIndex ~= Anomalies.Rooms.workshop.sector then
		return
	end
	local workshop = workshops[plot]
	local sector = Caves.sector(plot.seed, sectorIndex)
	if not workshop or sector.anomalySystem ~= system or workshop.revealed then
		return
	end
	workshop.revealed = true
	workshop.room.model:SetAttribute("Revealed", true)
	local profile = ownerProfile(plot)
	if profile then
		workshop.room.hookPrompt.Enabled = not profile.anomalies.workshop.hung
		profile.anomalies.workshop.found = true
	end
	if finder then
		local finderProfile = PlayerDataService.get(finder)
		if finderProfile and finder ~= plot.owner then
			finderProfile.anomalies.workshop.found = true
		end
		FxService.special(finder, workshop.room.center + Vector3.new(0, 4, 0), "workshop_found", nil)
		StateService.notify(finder, "discovery", "Nueva entrada en el diario: «El taller de E.»")
		StateService.push(finder)
	end
	if plot.owner and plot.owner ~= finder then
		StateService.push(plot.owner)
	end
end

local function near(player: Player, part: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - part.Position).Magnitude <= INTERACT_DISTANCE
end

function WorkshopService.start()
	SpecialsService.onSectorBuilt(build)
	SpecialsService.onSystemRevealed(onRevealed)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt:GetAttribute("Action") ~= "WorkshopHang" then
			return
		end
		for _, workshop in workshops do
			if prompt:IsDescendantOf(workshop.room.model) then
				if not workshop.revealed or not near(player, workshop.room.hook) then
					return
				end
				if workshop.plot.owner ~= player then
					StateService.notify(player, "info", "Este gancho espera otra pala.", "workshop_foreign", 4)
					return
				end
				hang(player, workshop)
				return
			end
		end
	end)

	PlotService.onReleased(function(plot)
		workshops[plot] = nil -- the model is destroyed with the plot's Underground folder
	end)
end

return WorkshopService
