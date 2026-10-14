--!strict
-- Finds the plot (and dig cell) under a world position on the client, using the attributes the
-- server puts on each plot folder. Used only for UI feedback; the server re-validates everything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Grid = require(ReplicatedStorage.Shared.Util.Grid)

local PlotLocator = {}

local N = GameConfig.PlotDigCells

export type CellInfo = {
	folder: Folder,
	originX: number,
	originZ: number,
	cx: number,
	d: number,
	cz: number,
	canDig: boolean,
}

function PlotLocator.cellAt(position: Vector3): CellInfo?
	local world = workspace:FindFirstChild("World")
	if not world then
		return nil
	end
	for _, folder in world:GetChildren() do
		local originX = folder:GetAttribute("OriginX") :: number?
		local originZ = folder:GetAttribute("OriginZ") :: number?
		if folder:IsA("Folder") and originX and originZ then
			local cx, d, cz = Grid.worldToCell(originX, originZ, position)
			if cx >= -1 and cx <= N and cz >= -1 and cz <= N then
				local owner = folder:GetAttribute("Owner")
				return {
					folder = folder,
					originX = originX,
					originZ = originZ,
					cx = cx,
					d = d,
					cz = cz,
					canDig = Grid.inDigArea(cx, d, cz) and owner == Players.LocalPlayer.UserId,
				}
			end
		end
	end
	return nil
end

return PlotLocator
