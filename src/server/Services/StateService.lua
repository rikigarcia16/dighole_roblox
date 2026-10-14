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
local PlayerDataService = require(script.Parent.PlayerDataService)

local StateService = {}

local pending: { [Player]: boolean } = {}
local stateEvent = Remotes.event("State")
local notifyEvent = Remotes.event("Notify")
local lastNotify: { [Player]: { [string]: number } } = {}

function StateService.snapshot(player: Player): any?
	local profile = PlayerDataService.get(player)
	if not profile then
		return nil
	end
	return {
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
		persistent = PlayerDataService.isPersistent(player),
	}
end

function StateService.push(player: Player)
	if pending[player] then
		return
	end
	pending[player] = true
	task.defer(function()
		pending[player] = nil
		if player.Parent then
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
