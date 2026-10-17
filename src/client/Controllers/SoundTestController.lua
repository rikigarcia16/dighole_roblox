--!strict
-- Studio-only QA helper: press F7 to play every sound of Config/Sounds one by one, with its key and
-- purpose on screen, so each one can be checked by ear and marked `verified = true`.
-- Does nothing in live servers.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

local SoundTestController = {}

function SoundTestController.start()
	if not RunService:IsStudio() then
		return
	end
	local keys = {}
	for key in Sounds do
		table.insert(keys, key)
	end
	table.sort(keys)
	local running = false

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.F7 or running then
			return
		end
		running = true
		task.spawn(function()
			for index, key in keys do
				local def = Sounds[key]
				local sound = Instance.new("Sound")
				sound.SoundId = def.id
				sound.Volume = def.volume
				sound.PlaybackSpeed = (def.pitchMin + def.pitchMax) / 2
				sound.Parent = SoundService
				-- a file that does not exist never loads: give up after 3 s instead of waiting forever
				local started = os.clock()
				while not sound.IsLoaded and os.clock() - started < 3 do
					task.wait(0.05)
				end
				print(
					string.format(
						"[SoundTest] %d/%d %-20s %s  (%s)  loaded=%s length=%.2fs",
						index,
						#keys,
						key,
						def.id,
						def.purpose,
						tostring(sound.IsLoaded),
						sound.TimeLength
					)
				)
				pcall(function()
					StarterGui:SetCore("SendNotification", { Title = key, Text = def.purpose, Duration = 1.5 })
				end)
				SoundService:PlayLocalSound(sound)
				task.wait(math.clamp(sound.TimeLength, 0.6, 2) + 0.4)
				sound:Destroy()
			end
			print("[SoundTest] done. A length of 0 means the file did not load.")
			running = false
		end)
	end)
end

return SoundTestController
