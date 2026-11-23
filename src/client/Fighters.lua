--[[
	Fighters  (StarterPlayerScripts.SpinClient.Fighters)

	Everyone who can use a Stand: the players plus the Stand-user NPCs
	(StandBots, tagged "SpinFighter" on the server). Returned in the same
	shape as Players:GetPlayers() ({ Character = model }), so visual code
	that loops over players draws the NPCs' Stands and effects too.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Fighters = {}
Fighters.Tag = "SpinFighter"

function Fighters.list()
	local out = {}
	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(out, player)
	end
	for _, model in ipairs(CollectionService:GetTagged(Fighters.Tag)) do
		if model.Parent then
			table.insert(out, { Character = model })
		end
	end
	return out
end

return Fighters
