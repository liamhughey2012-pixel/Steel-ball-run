--[[
	WeatherService  (ServerScriptService.SpinServer.WeatherService)

	Rain for the whole server: every TuskConfig.Weather.RainEvery seconds it
	rains for RainDuration seconds. Sets these ReplicatedStorage attributes:
	  SpinRaining   true while it rains
	  SpinRainEnds  server time the rain stops
	  SpinNextRain  server time the next rain starts
	Clients draw the rain (WeatherClient). Blackmore can walk on raindrops
	while it rains (TuskActs/Blackmore + BlackmoreVFX).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)

local WeatherService = {}

local function now()
	return workspace:GetServerTimeNow()
end

function WeatherService.isRaining()
	return ReplicatedStorage:GetAttribute("SpinRaining") == true
end

function WeatherService.setRain(on, seconds)
	ReplicatedStorage:SetAttribute("SpinRaining", on and true or nil)
	ReplicatedStorage:SetAttribute("SpinRainEnds", on and (now() + (seconds or 60)) or nil)
end

function WeatherService.init()
	local cfg = TuskConfig.Weather
	if not cfg or cfg.Enabled == false then
		return
	end
	local first = RunService:IsStudio() and (cfg.StudioFirstRainAfter or cfg.FirstRainAfter) or cfg.FirstRainAfter
	task.spawn(function()
		local nextRain = now() + (first or cfg.RainEvery)
		while true do
			ReplicatedStorage:SetAttribute("SpinNextRain", nextRain)
			task.wait(math.max(nextRain - now(), 0.1))
			WeatherService.setRain(true, cfg.RainDuration)
			task.wait(cfg.RainDuration)
			WeatherService.setRain(false)
			nextRain = nextRain + math.max(cfg.RainEvery, cfg.RainDuration + 1)
			if nextRain < now() then
				nextRain = now() + cfg.RainEvery
			end
		end
	end)
end

return WeatherService
