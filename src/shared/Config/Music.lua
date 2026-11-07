--!strict
-- Background music, one track per zone (MusicController crossfades as the player moves between
-- them). Library tracks from APM Music on the Roblox Creator Store (APMOfficial, verified creator,
-- free and licensed for Roblox experiences), checked to LOAD in Studio. Quiet on purpose: under the
-- digging, never over it. Replace an `id` to change a track; the player can mute music in ⚙.

export type Track = { id: string, volume: number, name: string }

local Music: { [string]: Track } = {
	garden = { id = "rbxassetid://1839605617", volume = 0.22, name = "Shiny And Happy Acoustic" }, -- 112 s
	forgotten_mines = { id = "rbxassetid://1842185105", volume = 0.2, name = "Explore OL (b)" }, -- 119 s
	crystal_caves = { id = "rbxassetid://1848350082", volume = 0.22, name = "Discovery" }, -- 185 s
	ancient_caverns = { id = "rbxassetid://1840715922", volume = 0.2, name = "Eastern Traveller (A)" }, -- 142 s
	volcanic_depths = { id = "rbxassetid://9038326809", volume = 0.25, name = "Digital Underworld (B)" }, -- 73 s
	abyss = { id = "rbxassetid://1840147295", volume = 0.22, name = "Games Played In The Dark" }, -- 77 s
	unknown_core = { id = "rbxassetid://1840981466", volume = 0.22, name = "Future Dreams (b)" }, -- 105 s
}

return Music
