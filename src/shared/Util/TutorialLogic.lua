--!strict
-- First minutes: which hint to show, derived from the real state snapshot (pure; tested offline).
-- Nothing is tracked per step, so a hint can never get stuck or repeat after it is done: each one
-- disappears as soon as the player has done what it asks. Only "finished" is saved (settings).

local Tools = require(script.Parent.Parent.Config.Tools)

local TutorialLogic = {}

export type Step = { id: string, text: string, target: string? } -- target: "sell" | "shop"

TutorialLogic.FinishDepth = 25 -- metres: past this the quest chain takes over

function TutorialLogic.step(state: any, touch: boolean?): Step?
	if not state or (state.settings and state.settings.tutorialDone) then
		return nil
	end
	local stats = state.stats or {}
	if (state.maxDepth or 0) >= TutorialLogic.FinishDepth then
		return nil
	end
	if (stats.cellsDug or 0) < 3 then
		return {
			id = "dig",
			text = if touch
				then "Mantén pulsado CAVAR apuntando al suelo del agujero."
				else "Apunta al suelo del agujero y mantén pulsado el clic izquierdo (o E) para cavar.",
		}
	end
	local used, capacity = state.used or 0, state.capacity or 1
	if (stats.sales or 0) == 0 then
		if used >= math.min(10, capacity) then
			return {
				id = "sell",
				text = "Tu mochila lleva minerales. Sube (R) y véndelos en el carro de venta.",
				target = "sell",
			}
		end
		return { id = "fill", text = "Cada bloque roto va a tu mochila. Sigue cavando hacia abajo." }
	end
	local next = Tools.get("reinforced_shovel")
	if next and not (state.tools and state.tools[next.id]) then
		if (state.coins or 0) >= next.price then
			return {
				id = "shop",
				text = "Ya puedes comprar la " .. next.name .. ": entra en el garaje.",
				target = "shop",
			}
		end
		return {
			id = "earn",
			text = string.format("Reúne %d monedas para la %s: cava, vende y repite.", next.price, next.name),
		}
	end
	return {
		id = "deeper",
		text = "Cada capa trae minerales nuevos. La misión de la izquierda te dice qué buscar.",
	}
end

return TutorialLogic
