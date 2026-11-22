--[[
	ProceduralPose  (StarterPlayerScripts.SpinClient.ProceduralPose)

	Animation-free arm posing for the Spin throw: tweens the right shoulder
	Motor6D's C0 on top of whatever Animator is playing, then restores it.
	Works on R15 and R6. C0 edits made on a client do not replicate, so
	SpinVFX calls this on EVERY client for EVERY charging character (driven
	by the replicated SpinChargeStart attribute). Everyone sees the pose.

	When real animations are uploaded, set ProceduralPose.Enabled = false
	and play the Animation tracks from SpinController instead.

	Pitch angles (degrees, rotation about the shoulder's side axis):
	  0 = arm down, 90 = arm straight forward, 180 = arm straight up.
]]

local ProceduralPose = {}

ProceduralPose.Enabled = true
ProceduralPose.Poses = {
	Charge = { Pitch = 195, Roll = -12 }, -- wound up over the shoulder, behind the head
	Throw = { Pitch = 80, Roll = 0 }, -- whipped forward at release
}

local originals = setmetatable({}, { __mode = "k" }) -- Motor6D -> original C0
local jobs = setmetatable({}, { __mode = "k" })

local VFXLib = require(script.Parent.VFXLib)

local function getShoulder(character)
	local upper = character:FindFirstChild("RightUpperArm")
	if upper then
		return upper:FindFirstChild("RightShoulder"), "R15"
	end
	local torso = character:FindFirstChild("Torso")
	if torso then
		return torso:FindFirstChild("Right Shoulder"), "R6"
	end
	return nil
end

local function poseOffset(rig, pose)
	local pitch = math.rad(pose.Pitch)
	local roll = math.rad(pose.Roll or 0)
	if rig == "R15" then
		return CFrame.Angles(pitch, 0, roll)
	end
	-- R6 shoulder C0 is rotated so its local Z is the torso's side axis.
	return CFrame.Angles(roll, 0, pitch)
end

local function tweenC0(motor, target, duration)
	VFXLib.cancel(jobs[motor])
	local from = motor.C0
	jobs[motor] = VFXLib.animate(duration, function(a)
		if motor.Parent then
			motor.C0 = from:Lerp(target, VFXLib.easeOut(a))
		end
	end)
end

function ProceduralPose.play(character, poseName, duration)
	if not ProceduralPose.Enabled or not character then
		return
	end
	local motor, rig = getShoulder(character)
	local pose = ProceduralPose.Poses[poseName]
	if not motor or not pose then
		return
	end
	if not originals[motor] then
		originals[motor] = motor.C0
	end
	tweenC0(motor, originals[motor] * poseOffset(rig, pose), duration or 0.15)
end

function ProceduralPose.reset(character, duration)
	if not character then
		return
	end
	local motor = getShoulder(character)
	if motor and originals[motor] then
		tweenC0(motor, originals[motor], duration or 0.25)
	end
end

-- Hand part the held ball is welded to, plus the grip offset.
function ProceduralPose.getHand(character)
	local hand = character:FindFirstChild("RightHand")
	if hand then
		return hand, CFrame.new(0, -0.45, -0.1)
	end
	local arm = character:FindFirstChild("Right Arm")
	if arm then
		return arm, CFrame.new(0, -1.1, -0.1)
	end
	return nil
end

return ProceduralPose
