--[[
	StandAssetLoader  (ServerScriptService.SpinServer.StandAssetLoader)

	Loads the Stand models listed in TuskConfig.StandModels (by asset id)
	into ReplicatedStorage.SpinAssets as "TuskAct1", "TuskAct2"...
	Every client then uses that model instead of the built-in one.

	Safety: every Script, LocalScript and ModuleScript inside a loaded
	model is deleted before anyone can see it (free models sometimes hide
	harmful scripts).

	If Roblox refuses to load an asset (InsertService can only load models
	your account owns, or free models depending on Roblox's rules), the
	Output says so. Then insert the model yourself: Toolbox > search the id
	> drag it into ReplicatedStorage > put it in a Folder named SpinAssets
	> rename it TuskAct1.
]]

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TuskConfig = require(game:GetService("ReplicatedStorage").SpinShared.TuskConfig)

local StandAssetLoader = {}

local function assetsFolder()
	local folder = ReplicatedStorage:FindFirstChild("SpinAssets")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "SpinAssets"
		folder.Parent = ReplicatedStorage
	end
	return folder
end

local function sanitize(model)
	local removed = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
			removed = removed + 1
		end
	end
	return removed
end

local function load(act, entry)
	local name = "TuskAct" .. act
	local folder = assetsFolder()
	if folder:FindFirstChild(name) then
		return -- already placed by hand: keep it
	end
	local ok, container = pcall(function()
		return InsertService:LoadAsset(entry.AssetId)
	end)
	if not ok or not container then
		warn(("[Spin] Could not load Stand model %d for Act %d (%s). Insert it by hand: Toolbox > drag into ReplicatedStorage.SpinAssets > rename %s."):format(entry.AssetId, act, tostring(container), name))
		return
	end
	local model = container:FindFirstChildWhichIsA("Model", true) or container
	local removed = sanitize(model)
	model.Name = name
	if not model:IsA("Model") then
		local wrapper = Instance.new("Model")
		for _, child in ipairs(model:GetChildren()) do
			child.Parent = wrapper
		end
		model = wrapper
		model.Name = name
	end
	model.Parent = folder
	container:Destroy()
	print(("[Spin] Loaded Stand model %d as %s%s"):format(entry.AssetId, name, removed > 0 and (" (removed " .. removed .. " scripts for safety)") or ""))
end

function StandAssetLoader.init()
	for act, entry in pairs(TuskConfig.StandModels or {}) do
		if entry.AssetId and entry.AssetId ~= 0 then
			task.spawn(load, act, entry)
		end
	end
end

return StandAssetLoader
