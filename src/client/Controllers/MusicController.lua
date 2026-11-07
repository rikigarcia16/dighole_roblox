--!strict
-- One quiet track per zone (Config/Music), crossfaded as the player goes up and down. Tracks are
-- created on first use and kept (at most seven); only the current one plays. Muted from ⚙
-- (settings.music), which UIController applies through setEnabled.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Music = require(ReplicatedStorage.Shared.Config.Music)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Grid = require(ReplicatedStorage.Shared.Util.Grid)

local MusicController = {}

local FADE = 2.5
local CHECK_SECONDS = 1

local player = Players.LocalPlayer
local sounds: { [string]: Sound } = {}
local current: string? = nil
local enabled = true

local function soundFor(zoneId: string): Sound?
	local track = Music[zoneId]
	if not track then
		return nil
	end
	local sound = sounds[zoneId]
	if not sound then
		local s = Instance.new("Sound")
		s.Name = "Music_" .. zoneId
		s.SoundId = track.id
		s.Looped = true
		s.Volume = 0
		s.Parent = SoundService
		sounds[zoneId] = s
		sound = s
	end
	return sound
end

local function fadeTo(sound: Sound, volume: number, stopAfter: boolean)
	local tween = TweenService:Create(sound, TweenInfo.new(FADE, Enum.EasingStyle.Sine), { Volume = volume })
	if stopAfter then
		tween.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and sound.Volume <= 0.001 then
				sound:Pause()
			end
		end)
	end
	tween:Play()
end

local function switchTo(zoneId: string?)
	if zoneId == current then
		return
	end
	if current and sounds[current] then
		fadeTo(sounds[current], 0, true)
	end
	current = zoneId
	if not enabled or not zoneId then
		return
	end
	local sound = soundFor(zoneId)
	if sound then
		if not sound.IsPlaying then
			sound:Resume()
			if not sound.IsPlaying then
				sound:Play()
			end
		end
		fadeTo(sound, Music[zoneId].volume, false)
	end
end

function MusicController.setEnabled(on: boolean)
	if on == enabled then
		return
	end
	enabled = on
	local zoneId = current
	current = nil
	if on then
		switchTo(zoneId)
	else
		for _, sound in sounds do
			fadeTo(sound, 0, true)
		end
		current = zoneId
	end
end

function MusicController.start()
	task.spawn(function()
		while true do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local depth = math.max(0, Grid.depthMetersFromY(root.Position.Y - 3))
				switchTo(Zones.at(depth).id)
			end
			task.wait(CHECK_SECONDS)
		end
	end)
end

return MusicController
