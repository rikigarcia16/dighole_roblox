--!strict
-- Replicates each player's authoritative state to their client. Changes are coalesced: any
-- number of `push` calls in the same frame result in one network message.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)
local Inventory = require(script.Parent.Parent.Logic.Inventory)
local ProfileSchema = require(script.Parent.Parent.Logic.ProfileSchema)
local PlayerDataService = require(script.Parent.PlayerDataService)

local StateService = {}

local pending: { [Player]: boolean } = {}
local stateEvent = Remotes.event("State")
local notifyEvent = Remotes.event("Notify")
local lastNotify: { [Player]: { [string]: number } } = {}
local beforePushCallbacks: { (Player) -> () } = {}
local snapshotProviders: { (Player, any, any) -> () } = {}

-- Runs right before a state snapshot is sent (QuestService uses it to complete quests based on
-- the latest state, so rewards are included in the same snapshot).
function StateService.beforePush(callback: (Player) -> ())
	table.insert(beforePushCallbacks, callback)
end

-- Lets other services add fields to the snapshot: provider(player, profile, snapshot).
function StateService.addSnapshotProvider(provider: (Player, any, any) -> ())
	table.insert(snapshotProviders, provider)
end

function StateService.snapshot(player: Player): any?
	local profile = PlayerDataService.get(player)
	if not profile then
		return nil
	end
	local snapshot = {
		coins = profile.coins,
		inventory = profile.inventory,
		used = Inventory.used(profile.inventory),
		capacity = Upgrades.valueAt("backpack", profile.upgrades.backpack),
		tools = profile.tools,
		equippedTool = profile.equippedTool,
		upgrades = profile.upgrades,
		discoveries = profile.discoveries,
		zonesReached = profile.zonesReached,
		maxDepth = profile.stats.maxDepth,
		stats = profile.stats,
		clues = profile.clues,
		collection = profile.collection,
		settings = profile.settings,
		persistent = PlayerDataService.isPersistent(player),
	}
	for _, provider in snapshotProviders do
		provider(player, profile, snapshot)
	end
	return snapshot
end

function StateService.push(player: Player)
	if pending[player] then
		return
	end
	pending[player] = true
	task.defer(function()
		pending[player] = nil
		if player.Parent then
			for _, callback in beforePushCallbacks do
				local ok, err = pcall(callback, player)
				if not ok then
					warn("[StateService] beforePush failed:", err)
				end
			end
			local snapshot = StateService.snapshot(player)
			if snapshot then
				stateEvent:FireClient(player, snapshot)
			end
		end
	end)
end

-- Sends a toast. Identical `key`s are throttled so spammy situations (full backpack while digging)
-- do not flood the screen.
function StateService.notify(player: Player, kind: string, text: string, throttleKey: string?, throttleSeconds: number?)
	if throttleKey then
		local perPlayer = lastNotify[player]
		if not perPlayer then
			perPlayer = {}
			lastNotify[player] = perPlayer
		end
		local now = os.clock()
		if perPlayer[throttleKey] and now - perPlayer[throttleKey] < (throttleSeconds or 2) then
			return
		end
		perPlayer[throttleKey] = now
	end
	notifyEvent:FireClient(player, kind, text)
end

function StateService.start()
	local limiter = RateLimiter.new(GameConfig.RateLimits.GetState.rate, GameConfig.RateLimits.GetState.burst)
	Remotes.func("GetState").OnServerInvoke = function(player: Player)
		if not limiter:allow(player) then
			return nil
		end
		return StateService.snapshot(player)
	end
	-- Preferences: validated by ProfileSchema.applySettings, saved with the profile. Not pushed back
	-- (the client already shows what it asked for), so a slider cannot spam full snapshots.
	local settingsLimiter = RateLimiter.new(2, 6)
	Remotes.event("SaveSettings").OnServerEvent:Connect(function(player, input)
		local profile = PlayerDataService.get(player)
		if profile and settingsLimiter:allow(player) then
			ProfileSchema.applySettings(profile.settings, input)
		end
	end)
	PlayerDataService.onLoaded(function(player)
		StateService.push(player)
		if not PlayerDataService.isPersistent(player) then
			StateService.notify(
				player,
				"warning",
				"El guardado no está disponible en esta sesión: tu progreso no se guardará."
			)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
		lastNotify[player] = nil
		limiter:forget(player)
	end)
end

return StateService
