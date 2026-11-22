--[[
	TuskAnimation  (StarterPlayerScripts.SpinClient.TuskAnimation)
	("TuskAnimationController" in the design doc)

	Plays Tusk character animations on ANY character, on every client.
	Two layers per character:
	  * Hold   : a sustained pose (Sneak, Charge) until stopped
	  * Action : a short keyframed move (M1 hits, Nail Shot...) that plays
	             on top, then blends back to the Hold pose or rest

	Default = procedural poses built from Motor6D C0 offsets (no uploads
	needed, works on R15 and R6). If TuskConfig.AnimationIds[name] holds
	an uploaded animation id, that real animation plays instead.

	Pose values: degrees {X, Y, Z} rotation in the parent part's space,
	optional 4th value = vertical offset in studs.
	  Arms:  +X raises the arm forward.   Waist: -X bends forward.
	  Hips:  +X lifts the thigh forward.   Knees: -X bends the knee.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local VFXLib = require(script.Parent.VFXLib)
local JointCache = require(script.Parent.JointCache)

local TuskAnimation = {}

local JOINTS = {
	R15 = {
		RightArm = { "RightUpperArm", "RightShoulder" },
		LeftArm = { "LeftUpperArm", "LeftShoulder" },
		Waist = { "UpperTorso", "Waist" },
		Neck = { "Head", "Neck" },
		Root = { "LowerTorso", "Root" },
		RightHip = { "RightUpperLeg", "RightHip" },
		LeftHip = { "LeftUpperLeg", "LeftHip" },
		RightKnee = { "RightLowerLeg", "RightKnee" },
		LeftKnee = { "LeftLowerLeg", "LeftKnee" },
	},
	R6 = {
		RightArm = { "Torso", "Right Shoulder" },
		LeftArm = { "Torso", "Left Shoulder" },
		Neck = { "Torso", "Neck" },
		Root = { "HumanoidRootPart", "RootJoint" },
		RightHip = { "Torso", "Right Hip" },
		LeftHip = { "Torso", "Left Hip" },
	},
}

TuskAnimation.Poses = {
	Rest = {},
	Point = { RightArm = { 92, 0, 0 }, LeftArm = { 15, 0, -10 }, Waist = { 0, -18, 0 } },
	PointRecoil = { RightArm = { 110, 0, 0 }, Waist = { 6, -14, 0 } },
	Jab = { RightArm = { 88, 0, 12 }, Waist = { 0, -28, 0 }, LeftArm = { 30, 0, -20 } },
	JabLeft = { LeftArm = { 88, 0, -12 }, Waist = { 0, 28, 0 }, RightArm = { 30, 0, 20 } },
	SpinPoke = { RightArm = { 100, 25, 0 }, Waist = { -10, -24, 0 }, LeftArm = { 20, 0, -30 } },
	SlamWindup = { RightArm = { 165, 0, 10 }, LeftArm = { 40, 0, -30 }, Waist = { 12, 15, 0 } },
	Slam = { RightArm = { 55, 0, 0 }, LeftArm = { 20, 0, -20 }, Waist = { -22, -10, 0 } },
	ChargeNail = { RightArm = { 75, 0, 28 }, LeftArm = { 75, 0, -28 }, Waist = { -8, 0, 0 } },
	BarrageA = { RightArm = { 95, 4, 0 }, LeftArm = { 60, 0, -20 }, Waist = { 0, -14, 0 } },
	BarrageB = { RightArm = { 88, -4, 0 }, LeftArm = { 60, 0, -20 }, Waist = { 0, -18, 0 } },
	AwakenCrouch = { RightArm = { 30, 0, 40 }, LeftArm = { 30, 0, -40 }, Waist = { -25, 0, 0 }, Neck = { -15, 0, 0 } },
	AwakenRise = { RightArm = { 130, 0, 35 }, LeftArm = { 130, 0, -35 }, Waist = { 14, 0, 0 }, Neck = { 22, 0, 0 } },
	Sneak = {
		Root = { 0, 0, 0, -0.65 },
		Waist = { -26, 0, 0 },
		Neck = { 22, 0, 0 },
		RightHip = { 50, 0, 0 },
		LeftHip = { 50, 0, 0 },
		RightKnee = { -85, 0, 0 },
		LeftKnee = { -85, 0, 0 },
		RightArm = { 25, 0, 8 },
		LeftArm = { 25, 0, -8 },
	},
	Emerge = { RightArm = { 150, 0, 15 }, LeftArm = { 40, 0, -40 }, Waist = { 15, 0, 0 } },
}

--[[
	Action sequences: list of keyframes { Time, Pose, (optional) Ease }.
	The last keyframe's Time is the length; after it the joints blend back.
]]
TuskAnimation.Actions = {
	M1_1 = { { 0, "Rest" }, { 0.07, "Jab" }, { 0.22, "Jab" } },
	M1_2 = { { 0, "Rest" }, { 0.07, "JabLeft" }, { 0.22, "JabLeft" } },
	M1_3 = { { 0, "Rest" }, { 0.08, "SpinPoke" }, { 0.25, "SpinPoke" } },
	M1_4 = { { 0, "Rest" }, { 0.12, "SlamWindup" }, { 0.2, "Slam" }, { 0.5, "Slam" } },
	NailShot = { { 0, "Rest" }, { 0.12, "Point" }, { 0.2, "PointRecoil" }, { 0.45, "Point" } },
	NailBarrage = {
		{ 0, "Rest" }, { 0.12, "BarrageA" }, { 0.21, "BarrageB" }, { 0.3, "BarrageA" },
		{ 0.39, "BarrageB" }, { 0.48, "BarrageA" }, { 0.57, "BarrageB" }, { 0.8, "BarrageB" },
	},
	SpinningNailRelease = { { 0, "ChargeNail" }, { 0.06, "PointRecoil" }, { 0.4, "Point" } },
	Awakening = { { 0, "Rest" }, { 0.35, "AwakenCrouch" }, { 1.2, "AwakenCrouch" }, { 1.45, "AwakenRise" }, { 2.2, "AwakenRise" } },
	Emerge = { { 0, "Sneak" }, { 0.12, "Emerge" }, { 0.5, "Emerge" } },
}

local states = setmetatable({}, { __mode = "k" }) -- character -> { Hold, ActionJob, Tracks }

local function rigOf(character)
	if character:FindFirstChild("UpperTorso") then
		return "R15"
	elseif character:FindFirstChild("Torso") then
		return "R6"
	end
	return nil
end

local function motorsOf(character)
	local rig = rigOf(character)
	if not rig then
		return {}
	end
	local motors = {}
	for name, path in pairs(JOINTS[rig]) do
		local holder = character:FindFirstChild(path[1])
		local motor = holder and holder:FindFirstChild(path[2])
		if motor and motor:IsA("Motor6D") then
			motors[name] = motor
		end
	end
	return motors
end

-- C0 for a pose value (rotation applied in the parent part's space, about the joint).
local function poseC0(motor, value)
	local base = JointCache.original(motor)
	if not value then
		return base
	end
	local rotation = CFrame.Angles(math.rad(value[1]), math.rad(value[2]), math.rad(value[3]))
	local position = base.Position + Vector3.new(0, value[4] or 0, 0)
	return CFrame.new(position) * rotation * (base - base.Position)
end

local function resolvePose(pose)
	if typeof(pose) == "string" then
		return TuskAnimation.Poses[pose] or {}
	end
	return pose or {}
end

local function getState(character)
	local s = states[character]
	if not s then
		s = { Hold = nil, Action = nil, Tracks = {} }
		states[character] = s
	end
	return s
end

local function animator(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid:FindFirstChildOfClass("Animator")
end

-- Real uploaded animation, if one is configured for this name.
local function playTrack(character, name, looped)
	local id = TuskConfig.AnimationIds[name]
	if not id or id == "" then
		return nil
	end
	local a = animator(character)
	if not a then
		return nil
	end
	local s = getState(character)
	local track = s.Tracks[name]
	if not track then
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, loaded = pcall(function()
			return a:LoadAnimation(anim)
		end)
		if not ok then
			return nil
		end
		track = loaded
		track.Priority = Enum.AnimationPriority.Action
		s.Tracks[name] = track
	end
	track.Looped = looped == true
	track:Play(0.1)
	return track
end

-- Blend every joint toward a target pose over `duration`.
local function blendTo(character, pose, duration)
	local motors = motorsOf(character)
	local from, to = {}, {}
	for name, motor in pairs(motors) do
		from[name] = motor.C0
		to[name] = poseC0(motor, pose[name])
	end
	return VFXLib.animate(duration, function(a)
		local e = VFXLib.easeOut(a)
		for name, motor in pairs(motors) do
			if motor.Parent then
				motor.C0 = from[name]:Lerp(to[name], e)
			end
		end
	end)
end

function TuskAnimation.play(character, name)
	if not character then
		return
	end
	if playTrack(character, name, false) then
		return
	end
	local frames = TuskAnimation.Actions[name]
	if not frames then
		return
	end
	local s = getState(character)
	VFXLib.cancel(s.Action)
	local motors = motorsOf(character)
	local holdPose = resolvePose(s.Hold)
	local length = frames[#frames][1]
	-- Precompute C0 targets per keyframe; frame 1 starts from the current pose.
	local keys = {}
	for i, frame in ipairs(frames) do
		local pose = resolvePose(frame[2])
		local c0s = {}
		for jointName, motor in pairs(motors) do
			if i == 1 then
				c0s[jointName] = motor.C0
			else
				c0s[jointName] = poseC0(motor, pose[jointName] or holdPose[jointName])
			end
		end
		keys[i] = { Time = frame[1], C0 = c0s }
	end
	local job
	job = VFXLib.animate(length, function(a)
		local t = a * length
		local k = 1
		while k < #keys and keys[k + 1].Time < t do
			k = k + 1
		end
		local current = keys[k]
		local nextKey = keys[math.min(k + 1, #keys)]
		local span = math.max(nextKey.Time - current.Time, 1e-3)
		local local01 = math.clamp((t - current.Time) / span, 0, 1)
		local e = VFXLib.easeOut(local01)
		for jointName, motor in pairs(motors) do
			if motor.Parent then
				motor.C0 = current.C0[jointName]:Lerp(nextKey.C0[jointName], e)
			end
		end
	end, function()
		if s.Action == job then
			s.Action = nil
			blendTo(character, resolvePose(s.Hold), 0.2)
		end
	end)
	s.Action = job
end

-- Sustained pose (e.g. "Sneak", "ChargeNail"). stopHold() releases it.
function TuskAnimation.hold(character, poseName)
	if not character then
		return
	end
	local s = getState(character)
	if s.Hold == poseName then
		return
	end
	s.Hold = poseName
	local track = playTrack(character, poseName, true)
	if track then
		return
	end
	if not s.Action then
		blendTo(character, resolvePose(poseName), 0.2)
	end
end

function TuskAnimation.stopHold(character, poseName)
	if not character then
		return
	end
	local s = getState(character)
	if poseName and s.Hold ~= poseName then
		return
	end
	local track = s.Hold and s.Tracks[s.Hold]
	if track then
		track:Stop(0.15)
	end
	s.Hold = nil
	if not s.Action then
		blendTo(character, {}, 0.25)
	end
end

-- Swap the local character's idle/walk/run animations while Tusk is equipped
-- (only if ids are configured). Restores the originals on unequip.
local savedAnimate = {}
function TuskAnimation.applyLocomotion(character, enabled)
	local animate = character and character:FindFirstChild("Animate")
	if not animate then
		return
	end
	local map = { idle = "Idle", walk = "Walk", run = "Run" }
	for folderName, key in pairs(map) do
		local id = TuskConfig.AnimationIds[key]
		local folder = animate:FindFirstChild(folderName)
		if folder and id and id ~= "" then
			for _, anim in ipairs(folder:GetChildren()) do
				if anim:IsA("Animation") then
					if enabled then
						savedAnimate[anim] = savedAnimate[anim] or anim.AnimationId
						anim.AnimationId = id
					elseif savedAnimate[anim] then
						anim.AnimationId = savedAnimate[anim]
					end
				end
			end
		end
	end
end

Players.LocalPlayer.CharacterRemoving:Connect(function(character)
	states[character] = nil
end)

return TuskAnimation
