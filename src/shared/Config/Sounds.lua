--!strict
-- Sound ids. Only built-in `rbxasset://` sounds shipped with the Roblox client are used so the
-- project does not depend on third-party audio. Replace them with your own uploaded audio for release.
-- `pitch` ranges are randomised per play so repeated hits do not sound identical.

export type SoundDef = { id: string, volume: number, pitchMin: number, pitchMax: number }

local Sounds: { [string]: SoundDef } = {
	dig_soil = { id = "rbxasset://sounds/action_footsteps_plastic.mp3", volume = 0.7, pitchMin = 0.55, pitchMax = 0.7 },
	dig_rock = { id = "rbxasset://sounds/collide.wav", volume = 0.6, pitchMin = 0.8, pitchMax = 1.0 },
	dig_ore = { id = "rbxasset://sounds/collide.wav", volume = 0.7, pitchMin = 1.15, pitchMax = 1.35 },
	dig_crystal = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.35, pitchMin = 1.4, pitchMax = 1.7 },
	discover_rare = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, pitchMin = 1.0, pitchMax = 1.0 },
	discover_epic = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.75, pitchMin = 0.8, pitchMax = 0.8 },
	discover_legendary = {
		id = "rbxasset://sounds/electronicpingshort.wav",
		volume = 0.9,
		pitchMin = 0.6,
		pitchMax = 0.6,
	},
	swing_light = { id = "rbxasset://sounds/swoosh.wav", volume = 0.25, pitchMin = 1.2, pitchMax = 1.4 },
	swing_heavy = { id = "rbxasset://sounds/swoosh.wav", volume = 0.3, pitchMin = 0.9, pitchMax = 1.05 },
	drill = { id = "rbxasset://sounds/clickfast.wav", volume = 0.35, pitchMin = 0.7, pitchMax = 0.8 },
	plasma = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.25, pitchMin = 2.0, pitchMax = 2.3 },
	pickup = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.2, pitchMin = 1.8, pitchMax = 2.0 },
	sell = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5, pitchMin = 1.3, pitchMax = 1.3 },
	purchase = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5, pitchMin = 1.6, pitchMax = 1.6 },
	ui_click = { id = "rbxasset://sounds/button.wav", volume = 0.4, pitchMin = 1, pitchMax = 1 },
	error = { id = "rbxasset://sounds/button.wav", volume = 0.4, pitchMin = 0.6, pitchMax = 0.6 },
	zone = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, pitchMin = 0.5, pitchMax = 0.5 },
}

return Sounds
