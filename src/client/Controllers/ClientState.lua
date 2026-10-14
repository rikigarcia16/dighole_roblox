--!strict
-- Client-side mirror of the server state. Read-only: the server is the authority.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local ClientState = {}

ClientState.data = nil :: any
ClientState.changed = Signal.new()

function ClientState.energy(): (number, number)
	local player = Players.LocalPlayer
	return (player:GetAttribute("Energy") :: number?) or 0, (player:GetAttribute("MaxEnergy") :: number?) or 1
end

function ClientState.start()
	Remotes.event("State").OnClientEvent:Connect(function(snapshot)
		ClientState.data = snapshot
		ClientState.changed:Fire(snapshot)
	end)
	task.spawn(function()
		for _ = 1, 20 do
			if ClientState.data then
				return
			end
			local ok, snapshot = pcall(function()
				return Remotes.func("GetState"):InvokeServer()
			end)
			if ok and snapshot and not ClientState.data then
				ClientState.data = snapshot
				ClientState.changed:Fire(snapshot)
				return
			end
			task.wait(1)
		end
	end)
end

return ClientState
