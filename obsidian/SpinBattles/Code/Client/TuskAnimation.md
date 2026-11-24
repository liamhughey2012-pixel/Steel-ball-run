---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient"
updated: 2026-11-22
---
# TuskAnimation

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| **Exact name** | `TuskAnimation` (capitals matter) |

**What it does:** ("TuskAnimationController" in the design doc)

## How to add it
1. In Studio's Explorer, find **SpinClient** (StarterPlayer › StarterPlayerScripts › SpinClient).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **TuskAnimation**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskAnimation  (StarterPlayerScripts.SpinClient.TuskAnimation)
	("TuskAnimationController" in the design doc)

	Plays Johnny / Gyro move animations on ANY character, on every client.
	Two layers per character:
	  * Hold   : a sustained pose (Sneak, Charge, Gyro's ball stance) with a
	             breathing idle on top, until stopped
	  * Action : a keyframed move (M1 hits, throws...) that plays on top,
	             then settles back to the Hold pose or rest

	Default = procedural poses built from Motor6D C0 offsets (no uploads
	needed, works on R15 and R6). If TuskConfig.AnimationIds[name] holds
	an uploaded animation id, that real animation plays instead.

	Pose values: degrees {X, Y, Z} rotation in the parent part's space,
	optional 4th value = vertical offset (studs), optional 5th (Root only)
	= forward lunge (studs).
	  Arms:  +X raises the arm forward, +Z (right) / -Z (left) lifts it out.
	  Waist / Root: -X bends forward, -Y turns the right shoulder forward.
	  Hips:  +X lifts the thigh forward.   Knees: -X bends the knee.
	Mirror("Pose") makes the left-handed version of a pose.

	Keyframes: { Time, Pose, Ease, Shake }
	  Ease : "Out" (default), "Snap" (fast strike), "Back" (overshoot and
	         settle), "In" (slow then fast: anticipation), "Sine", "Linear"
	  Shake: impact jitter in degrees, fading over 0.16 s from that key
	Every move follows: anticipation -> strike (snap/overshoot + impact
	shake) -> follow-through -> settle.
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
		RightElbow = { "RightLowerArm", "RightElbow" },
		LeftElbow = { "LeftLowerArm", "LeftElbow" },
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
	Point = { Root = { 0, -12, 0 }, RightArm = { 92, 0, 0 }, LeftArm = { 15, 0, -10 }, Waist = { 0, -18, 0 }, Neck = { 0, 12, 0 } },
	PointRecoil = { Root = { 6, -8, 0 }, RightArm = { 112, 0, 0 }, RightElbow = { 10, 0, 0 }, Waist = { 8, -14, 0 }, Neck = { 4, 10, 0 } },
	ChargeNail = { RightArm = { 75, 0, 28 }, LeftArm = { 75, 0, -28 }, RightElbow = { 30, 0, 0 }, LeftElbow = { 30, 0, 0 }, Waist = { -8, 0, 0 }, Root = { 0, 0, 0, -0.15 }, RightKnee = { -12, 0, 0 }, LeftKnee = { -12, 0, 0 }, RightHip = { 8, 0, 0 }, LeftHip = { 8, 0, 0 } },
	AwakenCrouch = { Root = { -8, 0, 0, -0.45 }, RightArm = { 30, 0, 40 }, LeftArm = { 30, 0, -40 }, RightElbow = { 60, 0, 0 }, LeftElbow = { 60, 0, 0 }, Waist = { -28, 0, 0 }, Neck = { -18, 0, 0 }, RightHip = { 40, 0, 0 }, LeftHip = { 40, 0, 0 }, RightKnee = { -60, 0, 0 }, LeftKnee = { -60, 0, 0 } },
	AwakenRise = { Root = { 8, 0, 0, 0.15 }, RightArm = { 135, 0, 38 }, LeftArm = { 135, 0, -38 }, Waist = { 16, 0, 0 }, Neck = { 24, 0, 0 } },
	Sneak = { Root = { 0, 0, 0, -0.65 }, Waist = { -26, 0, 0 }, Neck = { 22, 0, 0 }, RightHip = { 50, 0, 0 }, LeftHip = { 50, 0, 0 }, RightKnee = { -85, 0, 0 }, LeftKnee = { -85, 0, 0 }, RightArm = { 25, 0, 8 }, LeftArm = { 25, 0, -8 } },
	Emerge = { Root = { 6, 0, 0, 0.2 }, RightArm = { 150, 0, 15 }, LeftArm = { 40, 0, -40 }, Waist = { 15, 0, 0 }, Neck = { 12, 0, 0 } },

	-- JOHNNY: finger-gun nail shots, fired from a low, steady stance.
	FlickRWind = { Root = { 0, 12, 0 }, Waist = { 2, 16, 0 }, RightArm = { 62, 0, -28 }, RightElbow = { 55, 0, 0 }, LeftArm = { 28, 0, -20 }, Neck = { 0, -10, 0 }, LeftHip = { 10, 0, 0 }, LeftKnee = { -10, 0, 0 } },
	FlickR = { Root = { 0, -18, 0, -0.05, 0.2 }, RightArm = { 96, -8, 6 }, RightElbow = { 0, 0, 0 }, LeftArm = { 38, 0, -22 }, LeftElbow = { 40, 0, 0 }, Waist = { 0, -22, 0 }, Neck = { 0, 16, 0 }, RightHip = { 18, 0, 0 }, RightKnee = { -16, 0, 0 }, LeftHip = { -10, 0, 0 } },
	FlickRFollow = { Root = { -2, -22, 0, -0.08, 0.15 }, RightArm = { 84, -14, 2 }, RightElbow = { 12, 0, 0 }, LeftArm = { 34, 0, -24 }, LeftElbow = { 40, 0, 0 }, Waist = { -4, -26, 0 }, Neck = { 0, 18, 0 }, RightHip = { 14, 0, 0 }, RightKnee = { -14, 0, 0 } },
	FingerGun = { Root = { 0, -14, 0, -0.08 }, RightArm = { 95, 0, 5 }, LeftArm = { 62, 0, -38 }, LeftElbow = { 50, 0, 0 }, Waist = { 0, -22, 0 }, Neck = { 0, 16, 0 }, RightHip = { 12, 0, 0 }, RightKnee = { -14, 0, 0 }, LeftHip = { -10, 0, 0 }, LeftKnee = { -6, 0, 0 } },
	FingerGunRecoil = { Root = { 8, -10, 0, -0.04, -0.15 }, RightArm = { 120, 0, 6 }, RightElbow = { 14, 0, 0 }, LeftArm = { 56, 0, -36 }, LeftElbow = { 50, 0, 0 }, Waist = { 8, -16, 0 }, Neck = { 6, 12, 0 }, RightHip = { 8, 0, 0 }, RightKnee = { -10, 0, 0 } },
	SlamWindup = { Root = { 10, 16, 0, -0.1 }, RightArm = { 168, 0, 12 }, RightElbow = { 30, 0, 0 }, LeftArm = { 42, 0, -32 }, Waist = { 14, 18, 0 }, Neck = { 8, -8, 0 }, LeftHip = { 24, 0, 0 }, LeftKnee = { -28, 0, 0 } },
	Slam = { Root = { -16, -12, 0, -0.4, 0.4 }, RightArm = { 52, 0, 0 }, RightElbow = { 0, 0, 0 }, LeftArm = { 18, 0, -24 }, Waist = { -24, -12, 0 }, Neck = { -6, 10, 0 }, RightHip = { 36, 0, 0 }, RightKnee = { -46, 0, 0 }, LeftHip = { -14, 0, 0 }, LeftKnee = { -20, 0, 0 } },
	SlamFollow = { Root = { -10, -10, 0, -0.3, 0.3 }, RightArm = { 40, 0, 6 }, LeftArm = { 20, 0, -24 }, Waist = { -16, -10, 0 }, RightHip = { 28, 0, 0 }, RightKnee = { -36, 0, 0 }, LeftKnee = { -14, 0, 0 } },
	SpinChargeA = { RightArm = { 104, 10, 30 }, RightElbow = { 20, 0, 0 }, LeftArm = { 72, 0, -42 }, LeftElbow = { 40, 0, 0 }, Waist = { -6, -10, 0 }, Root = { 0, -6, 0, -0.18 }, RightKnee = { -16, 0, 0 }, LeftKnee = { -16, 0, 0 }, RightHip = { 10, 0, 0 }, LeftHip = { 10, 0, 0 } },
	SpinChargeB = { RightArm = { 96, -10, 22 }, RightElbow = { 26, 0, 0 }, LeftArm = { 72, 0, -42 }, LeftElbow = { 40, 0, 0 }, Waist = { -6, -10, 0 }, Root = { 0, -6, 0, -0.2 }, RightKnee = { -18, 0, 0 }, LeftKnee = { -18, 0, 0 }, RightHip = { 12, 0, 0 }, LeftHip = { 12, 0, 0 } },
	SpreadWind = { Root = { -6, 0, 0, -0.2 }, RightArm = { 40, 0, 20 }, LeftArm = { 40, 0, -20 }, RightElbow = { 70, 0, 0 }, LeftElbow = { 70, 0, 0 }, Waist = { -14, 0, 0 }, Neck = { -10, 0, 0 }, RightKnee = { -20, 0, 0 }, LeftKnee = { -20, 0, 0 } },
	Spread = { Root = { 8, 0, 0, 0.05 }, RightArm = { 92, 0, 72 }, LeftArm = { 92, 0, -72 }, Waist = { 12, 0, 0 }, Neck = { 16, 0, 0 } },
	Dive = { Root = { 0, 0, 0, -0.45, 0.4 }, Waist = { -40, 0, 0 }, Neck = { 20, 0, 0 }, RightArm = { 158, 0, 12 }, LeftArm = { 158, 0, -12 }, RightHip = { 40, 0, 0 }, LeftHip = { 20, 0, 0 }, RightKnee = { -45, 0, 0 }, LeftKnee = { -30, 0, 0 } },
	LungeStep = { Root = { -12, -10, 0, -0.25, 0.6 }, Waist = { -18, -12, 0 }, Neck = { 10, 8, 0 }, RightArm = { 88, 0, 0 }, LeftArm = { -24, 0, -12 }, RightHip = { 40, 0, 0 }, LeftHip = { -28, 0, 0 }, RightKnee = { -34, 0, 0 }, LeftKnee = { -10, 0, 0 } },
	PushTwo = { Root = { -12, 0, 0, -0.1, 0.4 }, RightArm = { 94, 0, 14 }, LeftArm = { 94, 0, -14 }, Waist = { -14, 0, 0 }, Neck = { 8, 0, 0 }, RightHip = { 24, 0, 0 }, LeftHip = { -18, 0, 0 }, RightKnee = { -20, 0, 0 } },
	WindSpin = { Root = { 0, -48, 0, -0.1 }, Waist = { 0, -62, 0 }, Neck = { 0, 40, 0 }, RightArm = { 62, 0, 84 }, LeftArm = { 40, 0, -30 }, LeftHip = { 20, 0, 0 }, LeftKnee = { -24, 0, 0 } },
	DashPunch = { Root = { -18, -16, 0, -0.3, 0.8 }, Waist = { -22, -28, 0 }, Neck = { 12, 14, 0 }, RightArm = { 92, 0, 0 }, LeftArm = { -32, 0, -22 }, RightHip = { 44, 0, 0 }, RightKnee = { -62, 0, 0 }, LeftHip = { -32, 0, 0 }, LeftKnee = { -8, 0, 0 } },

	-- GYRO: a ball thrower: weight shifts, leg lifts, full follow-through.
	GyroIdle = { RightArm = { 55, 0, 14 }, RightElbow = { 45, 0, 0 }, LeftArm = { 12, 0, -10 }, Waist = { 0, -6, 0 }, Neck = { 0, 4, 0 } },
	JabWind = { Root = { 0, 12, 0 }, Waist = { 0, 14, 0 }, RightArm = { 38, 0, 18 }, RightElbow = { 80, 0, 0 }, LeftArm = { 48, 0, -24 }, LeftElbow = { 60, 0, 0 }, Neck = { 0, -8, 0 }, RightKnee = { -10, 0, 0 } },
	Jab = { Root = { 0, -20, 0, -0.05, 0.35 }, RightArm = { 90, 0, 12 }, RightElbow = { 0, 0, 0 }, Waist = { 0, -30, 0 }, Neck = { 0, 22, 0 }, LeftArm = { 32, 0, -20 }, LeftElbow = { 70, 0, 0 }, LeftHip = { 22, 0, 0 }, LeftKnee = { -18, 0, 0 }, RightHip = { -12, 0, 0 } },
	JabRecover = { Root = { 0, -8, 0, 0, 0.15 }, RightArm = { 66, 0, 14 }, RightElbow = { 40, 0, 0 }, Waist = { 0, -12, 0 }, LeftArm = { 36, 0, -20 }, LeftElbow = { 60, 0, 0 } },
	GHookWind = { Root = { 0, 26, 0, -0.05 }, RightArm = { 80, 0, 82 }, RightElbow = { 70, 0, 0 }, Waist = { 0, 28, 0 }, Neck = { 0, -14, 0 }, LeftArm = { 40, 0, -20 }, RightKnee = { -14, 0, 0 } },
	GHook = { Root = { 0, -40, 0, -0.1, 0.3 }, RightArm = { 86, -32, 12 }, RightElbow = { 60, 0, 0 }, Waist = { 0, -44, 0 }, Neck = { 0, 30, 0 }, LeftArm = { 30, 0, -20 }, LeftElbow = { 70, 0, 0 }, LeftHip = { 18, 0, 0 }, LeftKnee = { -20, 0, 0 } },
	GHookFollow = { Root = { 0, -50, 0, -0.1, 0.25 }, RightArm = { 76, -50, 20 }, RightElbow = { 70, 0, 0 }, Waist = { 0, -52, 0 }, Neck = { 0, 34, 0 }, LeftArm = { 26, 0, -24 } },
	KickChamber = { Root = { 10, 0, 0, 0.05 }, RightHip = { 74, 0, 0 }, RightKnee = { -95, 0, 0 }, LeftKnee = { -12, 0, 0 }, Waist = { 10, 0, 0 }, Neck = { 6, 0, 0 }, RightArm = { 30, 0, 34 }, LeftArm = { 34, 0, -34 } },
	FrontKick = { Root = { 18, 0, 0, 0, 0.3 }, RightHip = { 92, 0, 0 }, RightKnee = { -6, 0, 0 }, LeftKnee = { -16, 0, 0 }, Waist = { 14, 0, 0 }, Neck = { -6, 0, 0 }, RightArm = { 26, 0, 40 }, LeftArm = { 28, 0, -40 } },
	KickRechamber = { Root = { 8, 0, 0, 0, 0.2 }, RightHip = { 60, 0, 0 }, RightKnee = { -80, 0, 0 }, LeftKnee = { -10, 0, 0 }, Waist = { 8, 0, 0 }, RightArm = { 30, 0, 30 }, LeftArm = { 30, 0, -30 } },
	OverheadWind = { Root = { 12, 18, 0, 0.1 }, RightArm = { 175, 0, 15 }, RightElbow = { 40, 0, 0 }, Waist = { 16, 22, 0 }, Neck = { 10, -10, 0 }, LeftArm = { 60, 0, -30 }, LeftHip = { 22, 0, 0 }, LeftKnee = { -26, 0, 0 } },
	OverheadSmash = { Root = { -18, -10, 0, -0.45, 0.45 }, RightArm = { 56, 0, 0 }, RightElbow = { 0, 0, 0 }, Waist = { -28, -15, 0 }, Neck = { -10, 10, 0 }, LeftArm = { 10, 0, -30 }, LeftHip = { 40, 0, 0 }, LeftKnee = { -38, 0, 0 }, RightHip = { -18, 0, 0 }, RightKnee = { -24, 0, 0 } },
	SmashFollow = { Root = { -12, -8, 0, -0.35, 0.35 }, RightArm = { 36, 0, 4 }, Waist = { -20, -12, 0 }, Neck = { -4, 8, 0 }, LeftArm = { 14, 0, -28 }, LeftHip = { 34, 0, 0 }, LeftKnee = { -32, 0, 0 }, RightKnee = { -18, 0, 0 } },
	PitchSet = { Root = { 0, 24, 0 }, Waist = { 0, 22, 0 }, Neck = { 0, -24, 0 }, RightArm = { 58, 0, 12 }, RightElbow = { 70, 0, 0 }, LeftArm = { 58, 0, -12 }, LeftElbow = { 70, 0, 0 } },
	PitchBack = { Root = { 6, 34, 0, 0.1 }, RightArm = { 200, 0, 40 }, RightElbow = { 50, 0, 0 }, Waist = { 6, 38, 0 }, Neck = { 0, -30, 0 }, LeftArm = { 82, 0, -30 }, LeftHip = { 62, 0, 0 }, LeftKnee = { -70, 0, 0 }, RightKnee = { -12, 0, 0 } },
	PitchRelease = { Root = { -16, -34, 0, -0.2, 0.6 }, RightArm = { 76, 0, -10 }, RightElbow = { 0, 0, 0 }, Waist = { -24, -38, 0 }, Neck = { 0, 30, 0 }, LeftArm = { -14, 0, -32 }, LeftHip = { 32, 0, 0 }, LeftKnee = { -24, 0, 0 }, RightHip = { -32, 0, 0 }, RightKnee = { -20, 0, 0 } },
	PitchFollow = { Root = { -20, -46, 0, -0.25, 0.5 }, RightArm = { 38, 0, -42 }, RightElbow = { 30, 0, 0 }, Waist = { -30, -46, 0 }, Neck = { 0, 34, 0 }, LeftArm = { -22, 0, -26 }, LeftHip = { 36, 0, 0 }, LeftKnee = { -32, 0, 0 }, RightHip = { -40, 0, 0 }, RightKnee = { -40, 0, 0 } },
	BowlWind = { Root = { 0, 6, 0, -0.45 }, RightArm = { -58, 0, 12 }, Waist = { -18, 8, 0 }, Neck = { 12, 0, 0 }, LeftArm = { 40, 0, -30 }, LeftHip = { 52, 0, 0 }, LeftKnee = { -66, 0, 0 }, RightKnee = { -46, 0, 0 } },
	BowlRelease = { Root = { 0, -4, 0, -0.5, 0.5 }, RightArm = { 64, 0, 0 }, Waist = { -30, -4, 0 }, Neck = { 18, 0, 0 }, LeftArm = { 20, 0, -40 }, LeftHip = { 58, 0, 0 }, LeftKnee = { -68, 0, 0 }, RightHip = { -22, 0, 0 }, RightKnee = { -30, 0, 0 } },
	BowlFollow = { Root = { 0, -6, 0, -0.35, 0.4 }, RightArm = { 112, 0, 0 }, Waist = { -18, -6, 0 }, Neck = { 12, 0, 0 }, LeftArm = { 16, 0, -40 }, LeftHip = { 50, 0, 0 }, LeftKnee = { -60, 0, 0 }, RightHip = { -26, 0, 0 }, RightKnee = { -24, 0, 0 } },
	PalmWind = { Root = { 0, 22, 0, -0.1 }, RightArm = { 40, 0, 22 }, RightElbow = { 90, 0, 0 }, Waist = { 0, 28, 0 }, Neck = { 0, -14, 0 }, LeftArm = { 50, 0, -20 }, LeftElbow = { 50, 0, 0 }, RightKnee = { -18, 0, 0 } },
	PalmPress = { Root = { -12, -12, 0, -0.15, 0.45 }, RightArm = { 92, 0, 0 }, RightElbow = { 0, 0, 0 }, LeftArm = { 72, 0, -22 }, LeftElbow = { 40, 0, 0 }, Waist = { -16, -12, 0 }, Neck = { 6, 8, 0 }, LeftHip = { 32, 0, 0 }, LeftKnee = { -32, 0, 0 }, RightHip = { -16, 0, 0 } },
	PalmPush = { Root = { -16, -14, 0, -0.2, 0.6 }, RightArm = { 98, 0, 0 }, LeftArm = { 76, 0, -18 }, LeftElbow = { 30, 0, 0 }, Waist = { -20, -14, 0 }, Neck = { 6, 8, 0 }, LeftHip = { 38, 0, 0 }, LeftKnee = { -38, 0, 0 }, RightHip = { -20, 0, 0 }, RightKnee = { -10, 0, 0 } },
	BreakerWindA = { Root = { 0, 0, 0, -0.3 }, RightArm = { 122, 0, 62 }, RightElbow = { 30, 0, 0 }, Waist = { 0, 46, 0 }, Neck = { 0, -30, 0 }, LeftArm = { 60, 0, -40 }, LeftKnee = { -25, 0, 0 }, RightKnee = { -25, 0, 0 } },
	BreakerWindB = { Root = { 0, 0, 0, -0.35 }, RightArm = { 132, 10, 70 }, RightElbow = { 40, 0, 0 }, Waist = { 0, 52, 0 }, Neck = { 0, -34, 0 }, LeftArm = { 64, 0, -44 }, LeftKnee = { -30, 0, 0 }, RightKnee = { -30, 0, 0 } },

	-- DIEGO: a hunched, clawing predator (human form; the raptor animates itself).
	DiegoStance = { RightArm = { 38, 0, 18 }, RightElbow = { 55, 0, 0 }, LeftArm = { 38, 0, -18 }, LeftElbow = { 55, 0, 0 }, Waist = { -8, 0, 0 }, Neck = { 6, 0, 0 } },
	ClawWindR = { Root = { 0, 14, 0, -0.05 }, Waist = { 6, 18, 0 }, RightArm = { 152, 0, 32 }, RightElbow = { 50, 0, 0 }, LeftArm = { 42, 0, -20 }, LeftElbow = { 50, 0, 0 }, Neck = { 0, -10, 0 }, LeftHip = { 14, 0, 0 }, LeftKnee = { -16, 0, 0 } },
	ClawR = { Root = { -10, -20, 0, -0.15, 0.35 }, Waist = { -16, -24, 0 }, RightArm = { 42, 0, -30 }, RightElbow = { 18, 0, 0 }, LeftArm = { 50, 0, -24 }, LeftElbow = { 45, 0, 0 }, Neck = { 4, 16, 0 }, RightHip = { 24, 0, 0 }, RightKnee = { -30, 0, 0 }, LeftHip = { -12, 0, 0 } },
	TailWhipWind = { Root = { 0, 42, 0, -0.12 }, Waist = { 0, 30, 0 }, Neck = { 0, -20, 0 }, RightArm = { 40, 0, 40 }, LeftArm = { 40, 0, -40 }, RightElbow = { 40, 0, 0 }, LeftElbow = { 40, 0, 0 }, LeftKnee = { -22, 0, 0 }, RightKnee = { -22, 0, 0 }, LeftHip = { 12, 0, 0 }, RightHip = { 12, 0, 0 } },
	TailWhip = { Root = { 0, -75, 0, -0.18 }, Waist = { 0, -40, 0 }, Neck = { 0, 45, 0 }, RightArm = { 50, 0, 62 }, LeftArm = { 30, 0, -52 }, RightKnee = { -20, 0, 0 }, LeftKnee = { -20, 0, 0 }, RightHip = { 12, 0, 0 }, LeftHip = { 12, 0, 0 } },
	BiteWind = { Root = { 8, 0, 0, -0.12 }, Waist = { 14, 0, 0 }, Neck = { 22, 0, 0 }, RightArm = { 60, 0, 42 }, LeftArm = { 60, 0, -42 }, RightElbow = { 60, 0, 0 }, LeftElbow = { 60, 0, 0 }, RightKnee = { -22, 0, 0 }, LeftKnee = { -22, 0, 0 }, RightHip = { 14, 0, 0 }, LeftHip = { 14, 0, 0 } },
	Bite = { Root = { -20, 0, 0, -0.25, 0.6 }, Waist = { -26, 0, 0 }, Neck = { -12, 0, 0 }, RightArm = { 96, 0, 26 }, LeftArm = { 96, 0, -26 }, RightElbow = { 30, 0, 0 }, LeftElbow = { 30, 0, 0 }, LeftHip = { 36, 0, 0 }, LeftKnee = { -40, 0, 0 }, RightHip = { -24, 0, 0 } },
	PounceCrouch = { Root = { -14, 0, 0, -0.75 }, Waist = { -30, 0, 0 }, Neck = { 28, 0, 0 }, RightArm = { 40, 0, 30 }, LeftArm = { 40, 0, -30 }, RightElbow = { 70, 0, 0 }, LeftElbow = { 70, 0, 0 }, RightHip = { 70, 0, 0 }, LeftHip = { 70, 0, 0 }, RightKnee = { -100, 0, 0 }, LeftKnee = { -100, 0, 0 } },
	PounceLeap = { Root = { -30, 0, 0, 0, 0.3 }, Waist = { -20, 0, 0 }, Neck = { 30, 0, 0 }, RightArm = { 152, 0, 25 }, LeftArm = { 152, 0, -25 }, RightElbow = { 30, 0, 0 }, LeftElbow = { 30, 0, 0 }, RightHip = { 60, 0, 0 }, LeftHip = { 20, 0, 0 }, RightKnee = { -80, 0, 0 }, LeftKnee = { -40, 0, 0 } },
	PounceLand = { Root = { -18, 0, 0, -0.65, 0.3 }, Waist = { -28, 0, 0 }, Neck = { 22, 0, 0 }, RightArm = { 72, 0, 20 }, LeftArm = { 72, 0, -20 }, RightElbow = { 30, 0, 0 }, LeftElbow = { 30, 0, 0 }, RightHip = { 62, 0, 0 }, LeftHip = { 40, 0, 0 }, RightKnee = { -92, 0, 0 }, LeftKnee = { -60, 0, 0 } },
	TransformHunch = { Root = { -10, 0, 0, -0.45 }, Waist = { -36, 0, 0 }, Neck = { -22, 0, 0 }, RightArm = { 20, 0, 42 }, LeftArm = { 20, 0, -42 }, RightElbow = { 92, 0, 0 }, LeftElbow = { 92, 0, 0 }, RightKnee = { -52, 0, 0 }, LeftKnee = { -52, 0, 0 }, RightHip = { 32, 0, 0 }, LeftHip = { 32, 0, 0 } },
	Roar = { Root = { 10, 0, 0, 0.05 }, Waist = { 18, 0, 0 }, Neck = { 32, 0, 0 }, RightArm = { 100, 0, 72 }, LeftArm = { 100, 0, -72 }, RightElbow = { 40, 0, 0 }, LeftElbow = { 40, 0, 0 }, RightHip = { -10, 0, 0 }, LeftHip = { 10, 0, 0 }, LeftKnee = { -14, 0, 0 } },
	-- PORK PIE HAT KID: a crouched, twitchy kid; the hooks come out of his mouth.
	PPStance = { Root = { 0, 8, 0, -0.25 }, Waist = { -10, 6, 0 }, Neck = { 10, -6, 0 }, RightArm = { 20, 0, 30 }, RightElbow = { 30, 0, 0 }, LeftArm = { -10, 0, -35 }, LeftElbow = { 20, 0, 0 }, RightHip = { 30, 0, 0 }, RightKnee = { -45, 0, 0 }, LeftHip = { 12, 0, 0 }, LeftKnee = { -25, 0, 0 } },
	SpitWind = { Root = { 10, 0, 0, -0.1 }, Waist = { 16, 0, 0 }, Neck = { 34, 0, 0 }, RightArm = { 30, 0, 40 }, LeftArm = { 30, 0, -40 }, RightElbow = { 50, 0, 0 }, LeftElbow = { 50, 0, 0 }, RightKnee = { -18, 0, 0 }, LeftKnee = { -18, 0, 0 } },
	Spit = { Root = { -14, 0, 0, -0.2, 0.4 }, Waist = { -22, 0, 0 }, Neck = { -24, 0, 0 }, RightArm = { -20, 0, 30 }, LeftArm = { -20, 0, -30 }, RightHip = { 30, 0, 0 }, RightKnee = { -36, 0, 0 }, LeftHip = { -16, 0, 0 } },
	ReelBack = { Root = { 12, 0, 0, -0.2, -0.3 }, Waist = { 20, 0, 0 }, Neck = { 12, 0, 0 }, RightArm = { 70, 0, 20 }, RightElbow = { 80, 0, 0 }, LeftArm = { 70, 0, -20 }, LeftElbow = { 80, 0, 0 }, RightHip = { -20, 0, 0 }, LeftHip = { 34, 0, 0 }, LeftKnee = { -40, 0, 0 } },
	HoistUp = { Root = { 18, 0, 0, -0.1, -0.2 }, Waist = { 26, 0, 0 }, Neck = { 40, 0, 0 }, RightArm = { 150, 0, 30 }, LeftArm = { 150, 0, -30 }, RightElbow = { 20, 0, 0 }, LeftElbow = { 20, 0, 0 }, RightKnee = { -20, 0, 0 }, LeftKnee = { -20, 0, 0 } },
	HoistSlam = { Root = { -20, 0, 0, -0.5, 0.3 }, Waist = { -32, 0, 0 }, Neck = { -30, 0, 0 }, RightArm = { 40, 0, 20 }, LeftArm = { 40, 0, -20 }, RightHip = { 50, 0, 0 }, RightKnee = { -60, 0, 0 }, LeftHip = { 40, 0, 0 }, LeftKnee = { -50, 0, 0 } },
	SlapWind = { Root = { 0, 20, 0 }, Waist = { 0, 24, 0 }, RightArm = { 100, 0, 90 }, RightElbow = { 30, 0, 0 }, LeftArm = { 20, 0, -30 }, Neck = { 0, -10, 0 }, RightKnee = { -14, 0, 0 } },
	Slap = { Root = { 0, -26, 0, -0.08, 0.3 }, Waist = { 0, -34, 0 }, RightArm = { 88, -40, -10 }, RightElbow = { 10, 0, 0 }, LeftArm = { 24, 0, -30 }, Neck = { 0, 20, 0 }, LeftHip = { 18, 0, 0 }, LeftKnee = { -18, 0, 0 } },
	FlyKickWind = { Root = { -6, 0, 0, -0.3 }, RightHip = { 60, 0, 0 }, RightKnee = { -100, 0, 0 }, LeftHip = { 40, 0, 0 }, LeftKnee = { -80, 0, 0 }, Waist = { -10, 0, 0 }, RightArm = { 40, 0, 50 }, LeftArm = { 40, 0, -50 } },
	FlyKick = { Root = { 24, 0, 0, 0.3, 0.6 }, RightHip = { 96, 0, 0 }, RightKnee = { 0, 0, 0 }, LeftHip = { -10, 0, 0 }, LeftKnee = { -70, 0, 0 }, Waist = { 16, 0, 0 }, Neck = { -10, 0, 0 }, RightArm = { 20, 0, 70 }, LeftArm = { 20, 0, -70 } },

	-- M1 POLISH: a coil before every strike (twist away, weight back), a
	-- strike that drives the hips through with a forward step, then a
	-- follow-through. Used by every character's M1 combo.
	FlickRCoil = { Root = { 0, 24, 0, -0.14 }, Waist = { 4, 28, 0 }, RightArm = { 72, 0, -40 }, RightElbow = { 88, 0, 0 }, LeftArm = { 40, 0, -26 }, LeftElbow = { 50, 0, 0 }, Neck = { 0, -18, 0 }, LeftHip = { 18, 0, 0 }, LeftKnee = { -20, 0, 0 }, RightKnee = { -16, 0, 0 } },
	FlickRStrike = { Root = { -4, -24, 0, -0.1, 0.55 }, RightArm = { 98, -10, 6 }, RightElbow = { 0, 0, 0 }, LeftArm = { 30, 0, -32 }, LeftElbow = { 62, 0, 0 }, Waist = { -6, -30, 0 }, Neck = { 0, 22, 0 }, RightHip = { 28, 0, 0 }, RightKnee = { -28, 0, 0 }, LeftHip = { -18, 0, 0 }, LeftKnee = { -6, 0, 0 } },
	SlamLeap = { Root = { 14, 18, 0, 0.25, -0.1 }, RightArm = { 178, 0, 14 }, RightElbow = { 36, 0, 0 }, LeftArm = { 120, 0, -30 }, LeftElbow = { 30, 0, 0 }, Waist = { 18, 20, 0 }, Neck = { 12, -8, 0 }, LeftHip = { 40, 0, 0 }, LeftKnee = { -60, 0, 0 }, RightHip = { 20, 0, 0 }, RightKnee = { -30, 0, 0 } },
	JabCoil = { Root = { 0, 16, 0, -0.12 }, Waist = { 0, 18, 0 }, RightArm = { 34, 0, 22 }, RightElbow = { 95, 0, 0 }, LeftArm = { 52, 0, -26 }, LeftElbow = { 70, 0, 0 }, Neck = { 0, -10, 0 }, RightKnee = { -18, 0, 0 }, LeftKnee = { -12, 0, 0 }, LeftHip = { 10, 0, 0 } },
	JabStrike = { Root = { -4, -24, 0, -0.08, 0.6 }, RightArm = { 92, 0, 10 }, RightElbow = { 0, 0, 0 }, Waist = { -4, -34, 0 }, Neck = { 0, 24, 0 }, LeftArm = { 30, 0, -22 }, LeftElbow = { 80, 0, 0 }, LeftHip = { 26, 0, 0 }, LeftKnee = { -22, 0, 0 }, RightHip = { -16, 0, 0 }, RightKnee = { -8, 0, 0 } },
	ClawRStrike = { Root = { -14, -24, 0, -0.2, 0.55 }, Waist = { -20, -28, 0 }, RightArm = { 36, 0, -36 }, RightElbow = { 14, 0, 0 }, LeftArm = { 52, 0, -26 }, LeftElbow = { 48, 0, 0 }, Neck = { 6, 18, 0 }, RightHip = { 30, 0, 0 }, RightKnee = { -36, 0, 0 }, LeftHip = { -14, 0, 0 } },
	SlapCoil = { Root = { 0, 26, 0, -0.18 }, Waist = { 0, 30, 0 }, RightArm = { 110, 0, 100 }, RightElbow = { 40, 0, 0 }, LeftArm = { 20, 0, -34 }, Neck = { 0, -14, 0 }, RightKnee = { -22, 0, 0 }, LeftKnee = { -16, 0, 0 } },
	SlapStrike = { Root = { 0, -32, 0, -0.12, 0.45 }, Waist = { 0, -40, 0 }, RightArm = { 86, -48, -14 }, RightElbow = { 6, 0, 0 }, LeftArm = { 24, 0, -34 }, Neck = { 0, 24, 0 }, LeftHip = { 22, 0, 0 }, LeftKnee = { -22, 0, 0 }, RightHip = { -10, 0, 0 } },
	-- BLOCK AND DASH (every character)
	BlockPose = { Root = { 0, 0, 0, -0.2 }, Waist = { -8, 0, 0 }, Neck = { -12, 0, 0 }, RightArm = { 95, 0, -38 }, RightElbow = { 105, 0, 0 }, LeftArm = { 95, 0, 38 }, LeftElbow = { 105, 0, 0 }, RightHip = { 18, 0, 0 }, RightKnee = { -24, 0, 0 }, LeftHip = { -6, 0, 0 }, LeftKnee = { -12, 0, 0 } },
	DashFwd = { Root = { -24, 0, 0, -0.25, 0.2 }, Waist = { -18, 0, 0 }, Neck = { 18, 0, 0 }, RightArm = { -45, 0, 12 }, LeftArm = { -45, 0, -12 }, RightHip = { 55, 0, 0 }, RightKnee = { -70, 0, 0 }, LeftHip = { -25, 0, 0 }, LeftKnee = { -30, 0, 0 } },
	DashBack = { Root = { 18, 0, 0, -0.2, -0.2 }, Waist = { 14, 0, 0 }, Neck = { -6, 0, 0 }, RightArm = { 50, 0, 30 }, LeftArm = { 50, 0, -30 }, RightHip = { -20, 0, 0 }, LeftHip = { 45, 0, 0 }, LeftKnee = { -60, 0, 0 } },
	DashRight = { Root = { 0, 0, -22, -0.3 }, Waist = { 0, 0, -14 }, Neck = { 0, 0, 10 }, RightArm = { 20, 0, 70 }, LeftArm = { 40, 0, -20 }, LeftHip = { 0, 0, -30 }, RightKnee = { -40, 0, 0 }, LeftKnee = { -20, 0, 0 } },
	-- Block family: brace into it, recoil from blocked hits, sag when the guard is low.
	BlockBrace = { Root = { 0, 0, 0, -0.35, 0.1 }, Waist = { -14, 0, 0 }, Neck = { -16, 0, 0 }, RightArm = { 105, 0, -30 }, RightElbow = { 115, 0, 0 }, LeftArm = { 105, 0, 30 }, LeftElbow = { 115, 0, 0 }, RightHip = { 30, 0, 0 }, RightKnee = { -40, 0, 0 }, LeftHip = { -10, 0, 0 }, LeftKnee = { -26, 0, 0 } },
	BlockRecoil = { Root = { -8, 0, 0, -0.25, -0.25 }, Waist = { 8, 0, 0 }, Neck = { 6, 0, 0 }, RightArm = { 80, 0, -46 }, RightElbow = { 125, 0, 0 }, LeftArm = { 80, 0, 46 }, LeftElbow = { 125, 0, 0 }, RightHip = { 10, 0, 0 }, RightKnee = { -30, 0, 0 }, LeftHip = { -20, 0, 0 }, LeftKnee = { -16, 0, 0 } },
	BlockWeak = { Root = { 6, 0, 0, -0.4 }, Waist = { 14, 0, 0 }, Neck = { 10, 0, 0 }, RightArm = { 70, 0, -30 }, RightElbow = { 95, 0, 0 }, LeftArm = { 70, 0, 30 }, LeftElbow = { 95, 0, 0 }, RightHip = { 26, 0, 0 }, RightKnee = { -44, 0, 0 }, LeftHip = { 6, 0, 0 }, LeftKnee = { -34, 0, 0 } },
	ParryPose = { Root = { 6, 0, 0, -0.1, -0.15 }, Waist = { 12, 0, 0 }, RightArm = { 140, 0, -20 }, RightElbow = { 30, 0, 0 }, LeftArm = { 60, 0, 30 }, LeftElbow = { 50, 0, 0 }, Neck = { 6, 0, 0 } },
	GuardBroken = { Root = { 14, 0, 0, -0.35, -0.3 }, Waist = { 22, 0, 0 }, Neck = { 28, 0, 0 }, RightArm = { 60, 0, 60 }, LeftArm = { 60, 0, -60 }, RightElbow = { 20, 0, 0 }, LeftElbow = { 20, 0, 0 }, RightKnee = { -30, 0, 0 }, LeftKnee = { -30, 0, 0 } },
	-- MOUNTAIN TIM: a cowboy with a lasso.
	TimStance = { Root = { 0, 6, 0, -0.08 }, Waist = { -4, 6, 0 }, Neck = { 4, -4, 0 }, RightArm = { 18, 0, 22 }, RightElbow = { 40, 0, 0 }, LeftArm = { 10, 0, -18 }, LeftElbow = { 30, 0, 0 }, RightHip = { 6, 0, 0 }, LeftKnee = { -8, 0, 0 } },
	LassoSpin = { Root = { 0, 10, 0, -0.1 }, Waist = { 4, 12, 0 }, RightArm = { 175, 0, 20 }, RightElbow = { 25, 0, 0 }, LeftArm = { 40, 0, -30 }, LeftElbow = { 40, 0, 0 }, Neck = { 12, -6, 0 }, LeftKnee = { -14, 0, 0 } },
	RopeWhipWind = { Root = { 0, 34, 0, -0.08 }, Waist = { 0, 34, 0 }, RightArm = { 120, 0, 70 }, RightElbow = { 20, 0, 0 }, LeftArm = { 30, 0, -30 }, Neck = { 0, -18, 0 } },
	RopeWhip = { Root = { 0, -36, 0, -0.1, 0.35 }, Waist = { 0, -40, 0 }, RightArm = { 90, -40, -30 }, RightElbow = { 0, 0, 0 }, LeftArm = { 24, 0, -36 }, Neck = { 0, 26, 0 }, LeftHip = { 20, 0, 0 }, LeftKnee = { -20, 0, 0 } },
	SplitPose = { Root = { -16, 0, 0, -0.3, 0.3 }, Waist = { -18, 0, 0 }, Neck = { 12, 0, 0 }, RightArm = { 100, 0, 60 }, LeftArm = { 100, 0, -60 }, RightHip = { 30, 0, 0 }, RightKnee = { -40, 0, 0 }, LeftHip = { -20, 0, 0 } },
	-- HOT PANTS: quick and sharp, Cream Starter always in her right hand,
	-- left hand free for jabs (and on her hip at rest).
	HPStance = { Root = { 0, 10, 0, -0.05 }, Waist = { -2, 8, 0 }, Neck = { 0, -6, 0 }, RightArm = { 70, 0, 25 }, RightElbow = { 95, 0, 0 }, LeftArm = { -5, 0, -35 }, LeftElbow = { 70, 0, 0 }, LeftHip = { 10, 0, 0 }, LeftKnee = { -12, 0, 0 }, RightHip = { -4, 0, 0 } },
	CanShakeA = { Root = { 0, 6, 0, -0.06 }, Waist = { 0, 6, 0 }, Neck = { 6, -4, 0 }, RightArm = { 80, 0, 18 }, RightElbow = { 85, 0, 0 }, LeftArm = { -5, 0, -35 }, LeftElbow = { 70, 0, 0 }, LeftKnee = { -10, 0, 0 } },
	CanShakeB = { Root = { 0, 6, 0, -0.08 }, Waist = { 0, 8, 0 }, Neck = { 4, -4, 0 }, RightArm = { 104, 0, 30 }, RightElbow = { 45, 0, 0 }, LeftArm = { -5, 0, -35 }, LeftElbow = { 70, 0, 0 }, LeftKnee = { -10, 0, 0 } },
	SprayAimL = { Root = { 0, 12, 0, -0.1, 0.1 }, Waist = { 0, 22, 0 }, Neck = { 0, -14, 0 }, RightArm = { 92, -22, 10 }, RightElbow = { 4, 0, 0 }, LeftArm = { 50, 0, -30 }, LeftElbow = { 80, 0, 0 }, RightHip = { 16, 0, 0 }, RightKnee = { -18, 0, 0 }, LeftHip = { -8, 0, 0 } },
	SprayAimR = { Root = { 0, -14, 0, -0.1, 0.15 }, Waist = { 0, -26, 0 }, Neck = { 0, 18, 0 }, RightArm = { 92, 20, 0 }, RightElbow = { 4, 0, 0 }, LeftArm = { 50, 0, -30 }, LeftElbow = { 80, 0, 0 }, RightHip = { 16, 0, 0 }, RightKnee = { -18, 0, 0 }, LeftHip = { -8, 0, 0 } },
	SprayThrust = { Root = { -8, -18, 0, -0.12, 0.5 }, Waist = { -10, -22, 0 }, Neck = { 6, 14, 0 }, RightArm = { 100, 0, 0 }, RightElbow = { 0, 0, 0 }, LeftArm = { 20, 0, -40 }, LeftElbow = { 60, 0, 0 }, RightHip = { 28, 0, 0 }, RightKnee = { -30, 0, 0 }, LeftHip = { -14, 0, 0 } },
	HighKickChamber = { Root = { 12, 0, 0, 0.05 }, RightHip = { 95, 0, 0 }, RightKnee = { -100, 0, 0 }, LeftKnee = { -15, 0, 0 }, Waist = { 14, 0, 0 }, RightArm = { 60, 0, 40 }, RightElbow = { 80, 0, 0 }, LeftArm = { 30, 0, -50 } },
	HighKick = { Root = { 26, 0, 0, 0.05, 0.35 }, RightHip = { 125, 0, 0 }, RightKnee = { -4, 0, 0 }, LeftKnee = { -10, 0, 0 }, Waist = { 20, 0, 0 }, Neck = { -12, 0, 0 }, RightArm = { 70, 0, 50 }, RightElbow = { 80, 0, 0 }, LeftArm = { 20, 0, -60 } },
	JumpSpinWind = { Root = { 0, 60, 0, -0.45 }, Waist = { 0, 40, 0 }, Neck = { 0, -30, 0 }, RightArm = { 50, 0, 60 }, RightElbow = { 70, 0, 0 }, LeftArm = { 50, 0, -60 }, LeftHip = { 40, 0, 0 }, LeftKnee = { -70, 0, 0 }, RightHip = { 30, 0, 0 }, RightKnee = { -50, 0, 0 } },
	JumpSpinKick = { Root = { 0, -120, 0, 0.6, 0.3 }, Waist = { 0, -35, 0 }, Neck = { 0, 55, 0 }, RightHip = { 85, 0, 35 }, RightKnee = { -5, 0, 0 }, LeftHip = { 50, 0, 0 }, LeftKnee = { -90, 0, 0 }, RightArm = { 60, 0, 70 }, RightElbow = { 70, 0, 0 }, LeftArm = { 40, 0, -80 } },
	SealDash = { Root = { -24, 0, 0, -0.2, 0.9 }, Waist = { -24, 0, 0 }, Neck = { 14, 0, 0 }, RightArm = { 100, 0, 0 }, RightElbow = { 0, 0, 0 }, LeftArm = { -30, 0, -20 }, RightHip = { 50, 0, 0 }, RightKnee = { -60, 0, 0 }, LeftHip = { -30, 0, 0 }, LeftKnee = { -20, 0, 0 } },
	SealPress = { Root = { -10, -10, 0, -0.15, 0.6 }, Waist = { -14, -16, 0 }, Neck = { 4, 10, 0 }, RightArm = { 95, -10, -10 }, RightElbow = { 20, 0, 0 }, LeftArm = { 70, 0, -20 }, LeftElbow = { 60, 0, 0 }, RightHip = { 30, 0, 0 }, RightKnee = { -34, 0, 0 } },
	SelfSprayHigh = { Root = { 0, 10, 0, -0.05 }, Waist = { 4, 14, 0 }, Neck = { -10, -20, 0 }, RightArm = { 120, 0, -50 }, RightElbow = { 100, 0, 0 }, LeftArm = { 80, 0, -10 }, LeftElbow = { 90, 0, 0 } },
	SelfSprayLow = { Root = { 6, 6, 0, -0.3 }, Waist = { 26, 8, 0 }, Neck = { -26, 0, 0 }, RightArm = { 40, 0, -30 }, RightElbow = { 60, 0, 0 }, LeftArm = { 30, 0, -20 }, RightHip = { 40, 0, 0 }, RightKnee = { -60, 0, 0 }, LeftHip = { 30, 0, 0 }, LeftKnee = { -50, 0, 0 } },
	MendRelief = { Root = { 4, 0, 0, 0.02 }, Waist = { -8, 0, 0 }, Neck = { 16, 0, 0 }, RightArm = { 40, 0, 30 }, RightElbow = { 80, 0, 0 }, LeftArm = { 10, 0, -20 }, LeftElbow = { 30, 0, 0 } },
	StormRaise = { Root = { 8, 0, 0, 0.25 }, Waist = { 16, 0, 0 }, Neck = { 30, 0, 0 }, RightArm = { 175, 0, 15 }, RightElbow = { 10, 0, 0 }, LeftArm = { 60, 0, -60 }, LeftHip = { 30, 0, 0 }, LeftKnee = { -50, 0, 0 } },
	StormSweepL = { Root = { 0, 30, 0, -0.1, 0.2 }, Waist = { -6, 30, 0 }, Neck = { 0, -20, 0 }, RightArm = { 110, -30, 10 }, RightElbow = { 6, 0, 0 }, LeftArm = { 40, 0, -50 }, RightHip = { 20, 0, 0 }, RightKnee = { -24, 0, 0 } },
	StormSweepR = { Root = { 0, -30, 0, -0.1, 0.2 }, Waist = { -6, -30, 0 }, Neck = { 0, 24, 0 }, RightArm = { 110, 30, 0 }, RightElbow = { 6, 0, 0 }, LeftArm = { 40, 0, -50 }, RightHip = { 20, 0, 0 }, RightKnee = { -24, 0, 0 } },
	-- FUNNY VALENTINE: upright and presidential, a hand at his chest.
	VStance = { Root = { 0, 6, 0, 0.02 }, Waist = { 4, 4, 0 }, Neck = { 8, -6, 0 }, RightArm = { 40, 0, -30 }, RightElbow = { 110, 0, 0 }, LeftArm = { -6, 0, -6 }, LeftElbow = { 10, 0, 0 } },
	VWrap = { Root = { 0, 30, 0, -0.05 }, Waist = { 0, 30, 0 }, Neck = { 0, -20, 0 }, RightArm = { 60, 0, -60 }, RightElbow = { 90, 0, 0 }, LeftArm = { 60, 0, 60 }, LeftElbow = { 90, 0, 0 } },
	VPresent = { Root = { 0, -10, 0, 0 }, Waist = { 0, -10, 0 }, Neck = { 6, 10, 0 }, RightArm = { 70, 0, 50 }, RightElbow = { 10, 0, 0 }, LeftArm = { 30, 0, -10 }, LeftElbow = { 40, 0, 0 } },
	VPledge = { Root = { 6, 0, 0, 0.04 }, Waist = { 8, 0, 0 }, Neck = { 20, 0, 0 }, RightArm = { 50, 0, -40 }, RightElbow = { 120, 0, 0 }, LeftArm = { 150, 0, -20 }, LeftElbow = { 10, 0, 0 } },
	-- DIEGO (AU): cocky, two fingers at his temple, weight on one leg.
	DWStance = { Root = { 0, -10, 0, 0 }, Waist = { 2, -8, 4 }, Neck = { 6, 12, -4 }, RightArm = { 100, 0, 30 }, RightElbow = { 135, 0, 0 }, LeftArm = { -4, 0, -16 }, LeftElbow = { 24, 0, 0 }, RightHip = { 6, 0, 0 }, LeftHip = { -6, 0, 0 }, LeftKnee = { -8, 0, 0 } },
	DWThrowWind = { Root = { 0, 34, 0, -0.04 }, Waist = { -4, 34, 0 }, Neck = { 0, -28, 0 }, RightArm = { 70, 0, -70 }, RightElbow = { 100, 0, 0 }, LeftArm = { 40, 0, -20 }, LeftElbow = { 30, 0, 0 } },
	DWThrow = { Root = { -4, -34, 0, -0.06, 0.3 }, Waist = { -8, -36, 0 }, Neck = { 0, 26, 0 }, RightArm = { 92, 0, 46 }, RightElbow = { 0, 0, 0 }, LeftArm = { 10, 0, -26 }, LeftElbow = { 20, 0, 0 }, LeftHip = { 20, 0, 0 }, LeftKnee = { -18, 0, 0 } },
	DWSpread = { Root = { 4, 0, 0, 0.06 }, Waist = { 10, 0, 0 }, Neck = { 14, 0, 0 }, RightArm = { 50, 0, 80 }, RightElbow = { 20, 0, 0 }, LeftArm = { 50, 0, -80 }, LeftElbow = { 20, 0, 0 } },
	DWAim = { Root = { 0, -20, 0, 0 }, Waist = { 0, -20, 0 }, Neck = { 0, 20, 0 }, RightArm = { 90, 0, 6 }, RightElbow = { 0, 0, 0 }, LeftArm = { 82, 0, -34 }, LeftElbow = { 40, 0, 0 }, RightHip = { 10, 0, 0 }, LeftHip = { -8, 0, 0 } },
	DWFan = { Root = { 0, -20, 0, 0 }, Waist = { 0, -20, 0 }, Neck = { 0, 20, 0 }, RightArm = { 96, 0, 6 }, RightElbow = { 0, 0, 0 }, LeftArm = { 70, 0, -30 }, LeftElbow = { 56, 0, 0 }, RightHip = { 10, 0, 0 }, LeftHip = { -8, 0, 0 } },
	DWTwirl = { Root = { 0, -6, 0, 0 }, Waist = { 0, -6, 0 }, Neck = { 4, 10, 0 }, RightArm = { 40, 0, 50 }, RightElbow = { 70, 0, 0 }, LeftArm = { -4, 0, -16 }, LeftElbow = { 24, 0, 0 } },
	-- JOSUKE (JoJolion): relaxed, hands behind his head; Soft & Wet does the fighting.
	JStance = { Root = { 0, 4, 0, 0 }, Waist = { -4, 4, 0 }, Neck = { -6, -6, 0 }, RightArm = { 160, 0, 40 }, RightElbow = { 130, 0, 0 }, LeftArm = { 160, 0, -40 }, LeftElbow = { 130, 0, 0 }, LeftHip = { 4, 0, 0 } },
	JPoint = { Root = { 0, -16, 0, -0.02 }, Waist = { 0, -16, 0 }, Neck = { 4, 16, 0 }, RightArm = { 90, 0, 4 }, RightElbow = { 0, 0, 0 }, LeftArm = { 160, 0, -40 }, LeftElbow = { 130, 0, 0 } },
	JBlow = { Root = { 0, -10, 0, 0 }, Waist = { 4, -10, 0 }, Neck = { 10, 10, 0 }, RightArm = { 80, 0, 40 }, RightElbow = { 90, 0, 0 }, LeftArm = { 160, 0, -40 }, LeftElbow = { 130, 0, 0 } },
	JFlick = { Root = { -2, -22, 0, -0.04, 0.3 }, Waist = { -4, -24, 0 }, Neck = { 0, 22, 0 }, RightArm = { 95, 0, 10 }, RightElbow = { 0, 0, 0 }, LeftArm = { 160, 0, -40 }, LeftElbow = { 130, 0, 0 }, LeftHip = { 14, 0, 0 } },
	JSpread = { Root = { 2, 0, 0, 0.04 }, Waist = { 6, 0, 0 }, Neck = { 10, 0, 0 }, RightArm = { 60, 0, 70 }, RightElbow = { 30, 0, 0 }, LeftArm = { 60, 0, -70 }, LeftElbow = { 30, 0, 0 } },
	-- GO BEYOND: pointing straight at you, leaning in, left arm hanging loose.
	JGoPoint = { Root = { 6, -12, 0, -0.04 }, Waist = { 8, -14, 0 }, Neck = { 6, 14, -6 }, RightArm = { 88, 0, 6 }, RightElbow = { 4, 0, 0 }, LeftArm = { -6, 0, -10 }, LeftElbow = { 18, 0, 0 }, RightHip = { -6, 0, 0 }, LeftHip = { 14, 0, 0 }, LeftKnee = { -14, 0, 0 } },
	JGoJab = { Root = { 10, -14, 0, -0.08, 0.3 }, Waist = { 12, -16, 0 }, Neck = { 8, 16, -6 }, RightArm = { 94, 0, 4 }, RightElbow = { 0, 0, 0 }, LeftArm = { -10, 0, -12 }, LeftElbow = { 18, 0, 0 }, RightHip = { -10, 0, 0 }, LeftHip = { 20, 0, 0 }, LeftKnee = { -18, 0, 0 } },
	JCharge = { Root = { 6, -20, 0, -0.1 }, Waist = { 10, -20, 0 }, Neck = { 14, 20, 0 }, RightArm = { 70, 0, -10 }, RightElbow = { 100, 0, 0 }, LeftArm = { 60, 0, 10 }, LeftElbow = { 100, 0, 0 }, RightKnee = { -16, 0, 0 }, LeftKnee = { -16, 0, 0 }, RightHip = { 12, 0, 0 }, LeftHip = { 12, 0, 0 } },
	-- TOORU: loose and unbothered, head tilted; Wonder of U does the fighting.
	TStance = { Root = { -2, 8, 0, 0 }, Waist = { -4, 6, 2 }, Neck = { -6, -10, 10 }, RightArm = { -8, 0, 12 }, RightElbow = { 34, 0, 0 }, LeftArm = { -8, 0, -12 }, LeftElbow = { 34, 0, 0 }, RightHip = { 4, 0, 0 }, LeftKnee = { -6, 0, 0 } },
	TFlick = { Root = { 0, -10, 0, 0 }, Waist = { 0, -12, 0 }, Neck = { -4, 12, 6 }, RightArm = { 50, 0, 64 }, RightElbow = { 40, 0, 0 }, LeftArm = { -6, 0, -12 }, LeftElbow = { 30, 0, 0 } },
	TPoint = { Root = { 0, -16, 0, -0.02 }, Waist = { 0, -16, 0 }, Neck = { 4, 16, 4 }, RightArm = { 90, 0, 4 }, RightElbow = { 0, 0, 0 }, LeftArm = { -8, 0, -12 }, LeftElbow = { 30, 0, 0 } },
	TOpen = { Root = { -4, 0, 0, 0.04 }, Waist = { -10, 0, 0 }, Neck = { -26, 0, 8 }, RightArm = { 30, 0, 72 }, RightElbow = { 30, 0, 0 }, LeftArm = { 30, 0, -72 }, LeftElbow = { 30, 0, 0 } },
	-- JODIO: slouched and cocky, one hand behind his head.
	JDStance = { Root = { -3, 6, 0, -0.02 }, Waist = { -6, 6, 0 }, Neck = { 4, -10, 6 }, LeftArm = { 160, 0, -40 }, LeftElbow = { 130, 0, 0 }, RightArm = { -6, 0, 10 }, RightElbow = { 24, 0, 0 }, RightHip = { 4, 0, 0 }, LeftKnee = { -6, 0, 0 } },
	JDPoint = { Root = { 0, -14, 0, -0.02 }, Waist = { 0, -14, 0 }, Neck = { 4, 14, 4 }, RightArm = { 90, 0, 4 }, RightElbow = { 0, 0, 0 }, LeftArm = { 160, 0, -40 }, LeftElbow = { 130, 0, 0 } },
	JDRaise = { Root = { -4, 0, 0, 0.02 }, Waist = { -8, 0, 0 }, Neck = { -20, 0, 0 }, RightArm = { 170, 0, 10 }, RightElbow = { 10, 0, 0 }, LeftArm = { 160, 0, -40 }, LeftElbow = { 130, 0, 0 } },
	JDSurf = { Root = { 18, -30, 0, -0.2 }, Waist = { 14, -20, 0 }, Neck = { -10, 20, 0 }, RightArm = { 40, 0, 70 }, RightElbow = { 20, 0, 0 }, LeftArm = { 40, 0, -70 }, LeftElbow = { 20, 0, 0 }, RightHip = { 30, 0, 0 }, RightKnee = { -40, 0, 0 }, LeftHip = { -10, 0, 0 }, LeftKnee = { -20, 0, 0 } },
	-- RIDING a horse: astride (legs out round its sides, not through it), leaning in, hands on the reins.
	Ride = { Root = { 0, 0, 0, 0 }, Waist = { -10, 0, 0 }, Neck = { 10, 0, 0 }, RightHip = { 25, 0, 50 }, RightKnee = { -40, 0, 0 }, LeftHip = { 25, 0, -50 }, LeftKnee = { -40, 0, 0 }, RightArm = { 50, 0, 8 }, RightElbow = { 55, 0, 0 }, LeftArm = { 50, 0, -8 }, LeftElbow = { 55, 0, 0 } },
	-- AXL RO: slouched and mocking; Civil War does the fighting.
	AxlStance = { Root = { -4, -8, 0, -0.04 }, Waist = { -6, -6, 4 }, Neck = { -10, 12, 8 }, RightArm = { -6, 0, 8 }, RightElbow = { 10, 0, 0 }, LeftArm = { -4, 0, -8 }, LeftElbow = { 14, 0, 0 }, RightHip = { 4, 0, 0 } },
	AxlPoint = { Root = { 0, -14, 0, -0.04 }, Waist = { 0, -14, 0 }, Neck = { 6, 14, 0 }, RightArm = { 88, 0, 6 }, RightElbow = { 0, 0, 0 }, LeftArm = { 0, 0, -10 }, LeftElbow = { 20, 0, 0 } },
	AxlPress = { Root = { 10, -10, 0, -0.2 }, Waist = { 16, -10, 0 }, Neck = { 20, 10, 0 }, RightArm = { 60, 0, 10 }, RightElbow = { 0, 0, 0 }, LeftArm = { 10, 0, -10 }, LeftElbow = { 20, 0, 0 }, RightKnee = { -24, 0, 0 }, LeftKnee = { -24, 0, 0 }, RightHip = { 20, 0, 0 }, LeftHip = { 20, 0, 0 } },
	AxlSummon = { Root = { -6, 0, 0, 0.05 }, Waist = { -8, 0, 0 }, Neck = { -18, 0, 0 }, RightArm = { 120, 0, 50 }, RightElbow = { 10, 0, 0 }, LeftArm = { 120, 0, -50 }, LeftElbow = { 10, 0, 0 } },
	-- BLACKMORE: calm and precise; umbrella in his left hand like a cane.
	BMStance = { Root = { 0, 6, 0, -0.03 }, Waist = { -2, 6, 0 }, Neck = { 2, -4, 0 }, RightArm = { 20, 0, 12 }, RightElbow = { 40, 0, 0 }, LeftArm = { 18, 0, -8 }, LeftElbow = { 20, 0, 0 }, LeftHip = { 4, 0, 0 } },
	BladesWind = { Root = { 0, 22, 0, -0.08 }, Waist = { 0, 24, 0 }, Neck = { 0, -14, 0 }, RightArm = { 70, 0, 80 }, RightElbow = { 30, 0, 0 }, LeftArm = { 30, 0, -20 }, RightKnee = { -14, 0, 0 } },
	BladesSweep = { Root = { 0, -26, 0, -0.1, 0.3 }, Waist = { 0, -32, 0 }, Neck = { 0, 18, 0 }, RightArm = { 92, -50, -10 }, RightElbow = { 0, 0, 0 }, LeftArm = { 40, 0, -30 }, LeftHip = { 20, 0, 0 }, LeftKnee = { -20, 0, 0 } },
	RainStep = { Root = { -20, 0, 0, 0.3, 0.5 }, Waist = { -16, 0, 0 }, Neck = { 14, 0, 0 }, RightArm = { -30, 0, 20 }, LeftArm = { -30, 0, -20 }, RightHip = { 80, 0, 0 }, RightKnee = { -70, 0, 0 }, LeftHip = { -20, 0, 0 }, LeftKnee = { -40, 0, 0 } },
	CagePalm = { Root = { -8, -10, 0, -0.1, 0.4 }, Waist = { -10, -14, 0 }, RightArm = { 95, 0, 10 }, RightElbow = { 0, 0, 0 }, LeftArm = { 30, 0, -20 }, LeftElbow = { 30, 0, 0 }, RightHip = { 24, 0, 0 }, RightKnee = { -26, 0, 0 }, Neck = { 4, 8, 0 } },
	CageClose = { Root = { -6, -8, 0, -0.1, 0.3 }, Waist = { -8, -10, 0 }, RightArm = { 100, 0, 30 }, RightElbow = { 70, 0, 0 }, LeftArm = { 30, 0, -20 }, LeftElbow = { 30, 0, 0 }, RightHip = { 20, 0, 0 }, RightKnee = { -22, 0, 0 } },
	StormCall = { Root = { 8, 0, 0, 0.05 }, Waist = { 14, 0, 0 }, Neck = { 34, 0, 0 }, RightArm = { 165, 0, 30 }, RightElbow = { 20, 0, 0 }, LeftArm = { 150, 0, -10 }, LeftElbow = { 30, 0, 0 } },
	StormHold = { Root = { 0, 0, 0, 0 }, Waist = { 4, 0, 0 }, Neck = { 10, 0, 0 }, RightArm = { 60, 0, 40 }, RightElbow = { 40, 0, 0 }, LeftArm = { 120, 0, -10 }, LeftElbow = { 60, 0, 0 } },
	-- SANDMAN: a light-footed runner; knife-hand chops and spinning kicks.
	SandStance = { Root = { 0, 10, 0, -0.18 }, Waist = { -8, 8, 0 }, Neck = { 8, -6, 0 }, RightArm = { 40, 0, 18 }, RightElbow = { 70, 0, 0 }, LeftArm = { 55, 0, -22 }, LeftElbow = { 60, 0, 0 }, RightHip = { 20, 0, 0 }, RightKnee = { -30, 0, 0 }, LeftHip = { -8, 0, 0 }, LeftKnee = { -14, 0, 0 } },
	ChopCoil = { Root = { 0, 26, 0, -0.14 }, Waist = { 6, 30, 0 }, RightArm = { 160, 0, 40 }, RightElbow = { 60, 0, 0 }, LeftArm = { 60, 0, -20 }, LeftElbow = { 50, 0, 0 }, Neck = { 0, -14, 0 }, LeftHip = { 14, 0, 0 }, LeftKnee = { -16, 0, 0 }, RightKnee = { -12, 0, 0 } },
	ChopStrike = { Root = { -12, -26, 0, -0.16, 0.55 }, Waist = { -16, -30, 0 }, RightArm = { 62, 0, -28 }, RightElbow = { 0, 0, 0 }, LeftArm = { 30, 0, -40 }, LeftElbow = { 60, 0, 0 }, Neck = { 4, 20, 0 }, RightHip = { 30, 0, 0 }, RightKnee = { -34, 0, 0 }, LeftHip = { -16, 0, 0 } },
	SpinKickWind = { Root = { 0, 60, 0, -0.3 }, Waist = { 0, 40, 0 }, Neck = { 0, -30, 0 }, RightArm = { 50, 0, 60 }, LeftArm = { 50, 0, -60 }, LeftHip = { 30, 0, 0 }, LeftKnee = { -50, 0, 0 }, RightKnee = { -30, 0, 0 } },
	SpinKick = { Root = { 0, -110, 0, -0.35, 0.3 }, Waist = { 0, -30, 0 }, Neck = { 0, 50, 0 }, RightHip = { 80, 0, 30 }, RightKnee = { -10, 0, 0 }, LeftKnee = { -60, 0, 0 }, LeftHip = { 40, 0, 0 }, RightArm = { 40, 0, 80 }, LeftArm = { 40, 0, -80 } },
	AxeWind = { Root = { 10, 0, 0, 0.2 }, RightHip = { 130, 0, 0 }, RightKnee = { -10, 0, 0 }, LeftKnee = { -20, 0, 0 }, Waist = { 14, 0, 0 }, Neck = { -6, 0, 0 }, RightArm = { 40, 0, 60 }, LeftArm = { 40, 0, -60 } },
	AxeKick = { Root = { -16, 0, 0, -0.25, 0.6 }, RightHip = { 20, 0, 0 }, RightKnee = { -10, 0, 0 }, LeftHip = { 40, 0, 0 }, LeftKnee = { -60, 0, 0 }, Waist = { -24, 0, 0 }, Neck = { -10, 0, 0 }, RightArm = { 20, 0, 50 }, LeftArm = { 20, 0, -50 } },
	SlashThrow = { Root = { -10, -40, 0, -0.35, 0.4 }, Waist = { -20, -40, 0 }, RightArm = { 40, -60, -20 }, RightElbow = { 0, 0, 0 }, LeftArm = { 20, 0, -50 }, Neck = { 0, 30, 0 }, RightHip = { 50, 0, 0 }, RightKnee = { -60, 0, 0 }, LeftHip = { -20, 0, 0 } },
	TrapPress = { Root = { -20, 0, 0, -1.0, 0.3 }, Waist = { -36, 0, 0 }, Neck = { 20, 0, 0 }, RightArm = { 60, 0, 10 }, RightElbow = { 0, 0, 0 }, LeftArm = { 30, 0, -40 }, RightHip = { 80, 0, 0 }, RightKnee = { -110, 0, 0 }, LeftHip = { 40, 0, 0 }, LeftKnee = { -100, 0, 0 } },
	Sprint = { Root = { -26, 0, 0, -0.2, 0.4 }, Waist = { -20, 0, 0 }, Neck = { 22, 0, 0 }, RightArm = { -50, 0, 10 }, RightElbow = { 80, 0, 0 }, LeftArm = { 80, 0, -10 }, LeftElbow = { 80, 0, 0 }, RightHip = { 70, 0, 0 }, RightKnee = { -90, 0, 0 }, LeftHip = { -30, 0, 0 }, LeftKnee = { -40, 0, 0 } },
	ConductUp = { Root = { 8, 0, 0, 0.1 }, Waist = { 16, 0, 0 }, Neck = { 30, 0, 0 }, RightArm = { 170, 0, 30 }, LeftArm = { 170, 0, -30 }, RightElbow = { 10, 0, 0 }, LeftElbow = { 10, 0, 0 } },
	ConductDown = { Root = { -16, 0, 0, -0.4, 0.3 }, Waist = { -28, 0, 0 }, Neck = { -10, 0, 0 }, RightArm = { 70, 0, 30 }, LeftArm = { 70, 0, -30 }, RightHip = { 40, 0, 0 }, RightKnee = { -50, 0, 0 }, LeftHip = { 30, 0, 0 }, LeftKnee = { -40, 0, 0 } },
}

-- Left-handed version of a pose: swap Right/Left joints and flip Y/Z.
local function mirror(pose)
	local out = {}
	for joint, v in pairs(pose) do
		local target = joint
		if joint:sub(1, 5) == "Right" then
			target = "Left" .. joint:sub(6)
		elseif joint:sub(1, 4) == "Left" then
			target = "Right" .. joint:sub(5)
		end
		out[target] = { v[1], -v[2], -v[3], v[4], v[5] }
	end
	return out
end
TuskAnimation.Mirror = mirror
do
	local P = TuskAnimation.Poses
	P.FlickLWind = mirror(P.FlickRWind)
	P.FlickL = mirror(P.FlickR)
	P.FlickLFollow = mirror(P.FlickRFollow)
	P.JabLeft = mirror(P.Jab)
	-- Older names kept so nothing else breaks.
	P.BarrageA = P.FlickR
	P.BarrageB = P.FlickL
	P.SpinPoke = P.FlickR
	P.ClawWindL = mirror(P.ClawWindR)
	P.ClawL = mirror(P.ClawR)
	P.SlapWindL = mirror(P.SlapWind)
	P.SlapL = mirror(P.Slap)
	P.FlickLCoil = mirror(P.FlickRCoil)
	P.FlickLStrike = mirror(P.FlickRStrike)
	P.ClawLStrike = mirror(P.ClawRStrike)
	P.SlapCoilL = mirror(P.SlapCoil)
	P.SlapStrikeL = mirror(P.SlapStrike)
	P.ChopCoilL = mirror(P.ChopCoil)
	P.ChopStrikeL = mirror(P.ChopStrike)
	P.DashLeft = mirror(P.DashRight)
	P.JabCoilL = mirror(P.JabCoil)
	P.JabStrikeL = mirror(P.JabStrike)
	P.BladesSweepL = mirror(P.BladesSweep)
	P.AxlPointL = mirror(P.AxlPoint)
	P.BladesWindL = mirror(P.BladesWind)
end

--[[
	Action sequences: { Time, Pose, Ease, Shake }. The last key's Time is the
	length; the move then holds briefly (HoldExtra) and settles back.
]]
TuskAnimation.Actions = {
	-- JOHNNY
	M1_1 = { { 0, "Rest" }, { 0.07, "FlickRCoil", "In" }, { 0.12, "FlickRStrike", "Back", 4 }, { 0.17, "FlickRStrike", "Linear" }, { 0.3, "FlickRFollow", "Sine" } },
	M1_2 = { { 0, "FlickRFollow" }, { 0.07, "FlickLCoil", "In" }, { 0.12, "FlickLStrike", "Back", 4 }, { 0.17, "FlickLStrike", "Linear" }, { 0.3, "FlickLFollow", "Sine" } },
	M1_3 = { { 0, "Rest" }, { 0.06, "FlickRCoil", "In" }, { 0.1, "FingerGun", "Snap" }, { 0.14, "FingerGunRecoil", "Snap", 4 }, { 0.2, "FingerGun", "Out" }, { 0.24, "FingerGunRecoil", "Snap", 3 }, { 0.36, "FingerGun", "Sine" } },
	M1_4 = { { 0, "Rest" }, { 0.08, "SlamWindup", "In" }, { 0.16, "SlamLeap", "Out" }, { 0.24, "Slam", "Snap", 8 }, { 0.3, "Slam", "Linear" }, { 0.48, "SlamFollow", "Sine" }, { 0.6, "SlamFollow" } },
	NailShot = { { 0, "Rest" }, { 0.12, "FingerGun", "Sine" }, { 0.2, "FingerGunRecoil", "Snap", 5 }, { 0.45, "FingerGun", "Back" } },
	NailBarrage = {
		{ 0, "Rest" }, { 0.08, "FlickRWind", "In" }, { 0.12, "FlickR", "Snap", 2 }, { 0.2, "FlickL", "Snap", 2 }, { 0.28, "FlickR", "Snap", 2 },
		{ 0.36, "FlickL", "Snap", 2 }, { 0.44, "FlickR", "Snap", 2 }, { 0.52, "FlickL", "Snap", 2 }, { 0.62, "FingerGunRecoil", "Snap", 4 }, { 0.82, "FingerGun", "Sine" },
	},
	SpinChargeLoop = { { 0, "SpinChargeA" }, { 0.12, "SpinChargeB", "Sine" }, { 0.24, "SpinChargeA", "Sine" } },
	UndergroundDive = { { 0, "Rest" }, { 0.1, "SpreadWind", "In" }, { 0.22, "Dive", "Snap" }, { 0.55, "Dive" } },
	NailDimension = { { 0, "Rest" }, { 0.16, "SpreadWind", "In" }, { 0.28, "Spread", "Back", 3 }, { 0.8, "Spread" } },
	DimensionalStep = { { 0, "Rest" }, { 0.06, "FlickRWind", "In" }, { 0.12, "LungeStep", "Snap", 2 }, { 0.38, "LungeStep", "Sine" } },
	SpatialPursuit = { { 0, "Rest" }, { 0.08, "FlickR", "Snap", 2 }, { 0.22, "SpreadWind", "In" }, { 0.32, "Spread", "Back", 3 }, { 0.6, "Spread" } },
	DimensionalBreak = { { 0, "Rest" }, { 0.25, "AwakenCrouch", "In" }, { 0.72, "AwakenCrouch", "Linear", 2 }, { 0.82, "PushTwo", "Snap", 6 }, { 1.2, "PushTwo", "Sine" } },
	GoldenSpinNail = { { 0, "Rest" }, { 0.16, "WindSpin", "In" }, { 0.28, "FingerGunRecoil", "Snap", 6 }, { 0.6, "FingerGun", "Back" } },
	GoldenPursuit = { { 0, "Rest" }, { 0.12, "SlamWindup", "In" }, { 0.24, "DashPunch", "Snap", 5 }, { 0.7, "DashPunch", "Sine" } },

	-- GYRO
	G_M1_1 = { { 0, "Rest" }, { 0.06, "JabCoil", "In" }, { 0.11, "JabStrike", "Back", 4 }, { 0.16, "JabStrike", "Linear" }, { 0.28, "JabRecover", "Sine" } },
	G_M1_2 = { { 0, "JabRecover" }, { 0.07, "GHookWind", "In" }, { 0.13, "GHook", "Back", 5 }, { 0.18, "GHook", "Linear" }, { 0.32, "GHookFollow", "Sine" } },
	G_M1_3 = { { 0, "Rest" }, { 0.07, "KickChamber", "In" }, { 0.13, "FrontKick", "Back", 5 }, { 0.18, "FrontKick", "Linear" }, { 0.27, "KickRechamber", "Sine" }, { 0.38, "Rest", "Sine" } },
	G_M1_4 = { { 0, "Rest" }, { 0.1, "PitchSet", "Sine" }, { 0.17, "OverheadWind", "In" }, { 0.25, "OverheadSmash", "Snap", 8 }, { 0.31, "OverheadSmash", "Linear" }, { 0.48, "SmashFollow", "Sine" }, { 0.6, "SmashFollow" } },
	GyroThrow = { { 0, "Rest" }, { 0.06, "PitchSet", "Sine" }, { 0.16, "PitchBack", "In" }, { 0.24, "PitchRelease", "Snap", 5 }, { 0.42, "PitchFollow", "Sine" }, { 0.58, "PitchFollow" } },
	GyroBowl = { { 0, "Rest" }, { 0.14, "BowlWind", "In" }, { 0.27, "BowlRelease", "Snap", 4 }, { 0.45, "BowlFollow", "Sine" }, { 0.6, "BowlFollow" } },
	GyroPalm = { { 0, "Rest" }, { 0.12, "PalmWind", "In" }, { 0.2, "PalmPress", "Snap", 4 }, { 0.32, "PalmPush", "Linear", 7 }, { 0.6, "PalmPush", "Sine", 3 } },
	GyroBreakerCharge = {
		{ 0, "Rest" }, { 0.3, "BreakerWindA", "Sine" }, { 0.55, "BreakerWindB", "Sine", 1 }, { 0.8, "BreakerWindA", "Sine" },
		{ 1.05, "BreakerWindB", "Sine", 2 }, { 1.3, "BreakerWindA", "Sine" }, { 1.55, "BreakerWindB", "Sine", 3 }, { 1.75, "PitchBack", "In" },
	},
	SpinningNailRelease = { { 0, "ChargeNail" }, { 0.06, "PointRecoil", "Snap", 6 }, { 0.4, "Point", "Back" } },

	-- DIEGO
	D_M1_1 = { { 0, "Rest" }, { 0.07, "ClawWindR", "In" }, { 0.12, "ClawRStrike", "Back", 4 }, { 0.17, "ClawRStrike", "Linear" }, { 0.3, "ClawR", "Sine" } },
	D_M1_2 = { { 0, "ClawR" }, { 0.07, "ClawWindL", "In" }, { 0.12, "ClawLStrike", "Back", 4 }, { 0.17, "ClawLStrike", "Linear" }, { 0.3, "ClawL", "Sine" } },
	D_M1_3 = { { 0, "Rest" }, { 0.08, "TailWhipWind", "In" }, { 0.17, "TailWhip", "Snap", 5 }, { 0.22, "TailWhip", "Linear" }, { 0.36, "TailWhip", "Sine" } },
	D_M1_4 = { { 0, "Rest" }, { 0.13, "BiteWind", "In" }, { 0.21, "Bite", "Snap", 7 }, { 0.27, "Bite", "Linear" }, { 0.48, "Bite", "Sine" } },
	DiegoPounce = { { 0, "Rest" }, { 0.16, "PounceCrouch", "In" }, { 0.24, "PounceLeap", "Snap", 3 }, { 0.5, "PounceLeap", "Sine" } },
	DiegoLand = { { 0, "PounceLeap" }, { 0.06, "PounceLand", "Snap", 6 }, { 0.35, "PounceLand", "Sine" } },
	DiegoBite = { { 0, "Rest" }, { 0.14, "BiteWind", "In" }, { 0.22, "Bite", "Snap", 6 }, { 0.5, "Bite", "Sine" } },
	DiegoTransform = { { 0, "Rest" }, { 0.18, "TransformHunch", "In" }, { 0.35, "TransformHunch", "Linear", 4 }, { 0.5, "Roar", "Back", 6 } },
	DiegoRoar = { { 0, "Rest" }, { 0.2, "BiteWind", "In" }, { 0.35, "Roar", "Back", 6 }, { 0.9, "Roar", "Linear", 4 }, { 1.2, "Roar", "Sine", 2 } },

	-- PORK PIE HAT KID
	P_M1_1 = { { 0, "Rest" }, { 0.06, "SlapCoil", "In" }, { 0.11, "SlapStrike", "Back", 4 }, { 0.16, "SlapStrike", "Linear" }, { 0.28, "Slap", "Sine" } },
	P_M1_2 = { { 0, "Slap" }, { 0.06, "SlapCoilL", "In" }, { 0.11, "SlapStrikeL", "Back", 4 }, { 0.16, "SlapStrikeL", "Linear" }, { 0.28, "SlapL", "Sine" } },
	P_M1_3 = { { 0, "Rest" }, { 0.08, "SpitWind", "In" }, { 0.14, "Spit", "Snap", 5 }, { 0.19, "Spit", "Linear" }, { 0.32, "Spit", "Sine" } },
	P_M1_4 = { { 0, "Rest" }, { 0.12, "FlyKickWind", "In" }, { 0.2, "FlyKick", "Snap", 7 }, { 0.26, "FlyKick", "Linear" }, { 0.45, "FlyKick", "Sine" }, { 0.58, "FlyKick" } },
	-- BLOCK AND DASH
	DashF = { { 0, "Rest" }, { 0.05, "DashFwd", "Snap", 2 }, { 0.22, "DashFwd", "Linear" }, { 0.32, "Rest", "Sine" } },
	DashB = { { 0, "Rest" }, { 0.05, "DashBack", "Snap", 2 }, { 0.22, "DashBack", "Linear" }, { 0.32, "Rest", "Sine" } },
	DashR = { { 0, "Rest" }, { 0.05, "DashRight", "Snap", 2 }, { 0.22, "DashRight", "Linear" }, { 0.32, "Rest", "Sine" } },
	DashL = { { 0, "Rest" }, { 0.05, "DashLeft", "Snap", 2 }, { 0.22, "DashLeft", "Linear" }, { 0.32, "Rest", "Sine" } },
	BlockRaise = { { 0, "Rest" }, { 0.07, "BlockBrace", "Snap", 3 }, { 0.18, "BlockPose", "Back", 2 } },
	BlockHit = { { 0, "BlockPose" }, { 0.05, "BlockRecoil", "Snap", 5 }, { 0.22, "BlockPose", "Back", 2 } },
	BlockHitWeak = { { 0, "BlockWeak" }, { 0.05, "BlockRecoil", "Snap", 7 }, { 0.3, "BlockWeak", "Back", 2 } },
	Parry = { { 0, "BlockPose" }, { 0.06, "ParryPose", "Snap", 4 }, { 0.3, "ParryPose", "Sine" } },
	GuardBreak = { { 0, "BlockPose" }, { 0.08, "GuardBroken", "Snap", 6 }, { 0.8, "GuardBroken", "Linear" }, { 1.0, "Rest", "Sine" } },

	-- MOUNTAIN TIM
	T_M1_1 = { { 0, "Rest" }, { 0.06, "JabCoil", "In" }, { 0.11, "JabStrike", "Back", 4 }, { 0.16, "JabStrike", "Linear" }, { 0.28, "TimStance", "Sine" } },
	T_M1_2 = { { 0, "JabStrike" }, { 0.06, "JabCoilL", "In" }, { 0.11, "JabStrikeL", "Back", 4 }, { 0.16, "JabStrikeL", "Linear" }, { 0.28, "TimStance", "Sine" } },
	T_M1_3 = { { 0, "Rest" }, { 0.08, "RopeWhipWind", "In" }, { 0.15, "RopeWhip", "Snap", 5 }, { 0.2, "RopeWhip", "Linear" }, { 0.34, "TimStance", "Sine" } },
	T_M1_4 = { { 0, "Rest" }, { 0.12, "OverheadWind", "In" }, { 0.21, "OverheadSmash", "Snap", 8 }, { 0.27, "OverheadSmash", "Linear" }, { 0.46, "SmashFollow", "Sine" }, { 0.58, "TimStance", "Sine" } },
	TimLassoThrow = { { 0, "Rest" }, { 0.08, "LassoSpin", "Out" }, { 0.26, "LassoSpin", "Linear", 1 }, { 0.34, "PitchRelease", "Snap", 4 }, { 0.5, "PitchFollow", "Sine" } },
	TimReel = { { 0, "PitchFollow" }, { 0.1, "ReelBack", "Snap", 3 }, { 0.5, "ReelBack", "Linear", 2 }, { 0.65, "TimStance", "Sine" } },
	TimSplit = { { 0, "Rest" }, { 0.1, "SplitPose", "Snap", 3 }, { 0.5, "SplitPose", "Linear" }, { 0.65, "TimStance", "Sine" } },
	TimPunch = { { 0, "Rest" }, { 0.1, "JabCoil", "In" }, { 0.18, "JabStrike", "Snap", 4 }, { 0.6, "JabStrike", "Linear", 2 }, { 0.75, "TimStance", "Sine" } },
	TimRoundup = { { 0, "Rest" }, { 0.15, "LassoSpin", "Out" }, { 0.85, "LassoSpin", "Linear", 2 }, { 0.95, "Spread", "Snap", 5 }, { 1.6, "ReelBack", "Snap", 3 }, { 2.2, "ReelBack", "Linear", 2 }, { 2.35, "HoistSlam", "Snap", 8 }, { 2.7, "HoistSlam", "Sine" } },

	-- HOT PANTS
	H_M1_1 = { { 0, "HPStance" }, { 0.06, "JabCoilL", "In" }, { 0.11, "JabStrikeL", "Back", 4 }, { 0.16, "JabStrikeL", "Linear" }, { 0.28, "HPStance", "Sine" } },
	H_M1_2 = { { 0, "HPStance" }, { 0.07, "HighKickChamber", "In" }, { 0.13, "HighKick", "Back", 5 }, { 0.19, "HighKick", "Linear" }, { 0.32, "HPStance", "Sine" } },
	H_M1_3 = { { 0, "HPStance" }, { 0.05, "CanShakeB", "In" }, { 0.11, "SprayThrust", "Snap", 4 }, { 0.17, "SprayThrust", "Linear" }, { 0.3, "HPStance", "Sine" } },
	H_M1_4 = { { 0, "HPStance" }, { 0.1, "JumpSpinWind", "In" }, { 0.19, "JumpSpinKick", "Snap", 7 }, { 0.25, "JumpSpinKick", "Linear" }, { 0.42, "HPStance", "Sine" } },
	HPSpray = { { 0, "HPStance" }, { 0.05, "CanShakeA", "Snap" }, { 0.09, "CanShakeB", "Snap", 1 }, { 0.13, "CanShakeA", "Snap", 1 }, { 0.2, "SprayAimL", "Snap", 2 }, { 0.47, "SprayAimR", "Sine", 2 }, { 0.72, "SprayAimL", "Sine", 2 }, { 0.88, "HPStance", "Sine" } },
	HPSeal = { { 0, "HPStance" }, { 0.1, "CanShakeB", "In" }, { 0.18, "SealDash", "Snap", 4 }, { 0.28, "SealPress", "Snap", 5 }, { 0.5, "SealPress", "Linear", 2 }, { 0.66, "HPStance", "Sine" } },
	HPMend = { { 0, "HPStance" }, { 0.12, "SelfSprayHigh", "Out" }, { 0.55, "SelfSprayLow", "Sine", 1 }, { 0.92, "SelfSprayHigh", "Sine", 1 }, { 1.12, "MendRelief", "Back" }, { 1.35, "HPStance", "Sine" } },
	HPStorm = { { 0, "HPStance" }, { 0.05, "CanShakeA", "Snap" }, { 0.1, "CanShakeB", "Snap", 1 }, { 0.15, "CanShakeA", "Snap", 1 }, { 0.2, "CanShakeB", "Snap", 2 }, { 0.38, "StormRaise", "Back", 4 }, { 0.6, "StormSweepL", "Snap", 3 }, { 0.9, "StormSweepR", "Sine", 2 }, { 1.1, "SprayThrust", "Snap", 5 }, { 1.4, "SprayThrust", "Linear", 2 }, { 1.6, "HPStance", "Sine" } },

	-- FUNNY VALENTINE
	V_M1_1 = { { 0, "VStance" }, { 0.07, "JabStrike", "Back", 4 }, { 0.15, "JabStrike", "Linear" }, { 0.3, "VStance", "Sine" } },
	V_M1_2 = { { 0, "VStance" }, { 0.07, "JabStrikeL", "Back", 4 }, { 0.15, "JabStrikeL", "Linear" }, { 0.3, "VStance", "Sine" } },
	V_M1_3 = { { 0, "VStance" }, { 0.07, "KickChamber", "In" }, { 0.13, "FrontKick", "Back", 5 }, { 0.18, "FrontKick", "Linear" }, { 0.32, "VStance", "Sine" } },
	V_M1_4 = { { 0, "VStance" }, { 0.12, "VWrap", "In" }, { 0.2, "AxlPoint", "Snap", 7 }, { 0.3, "AxlPoint", "Linear" }, { 0.46, "VStance", "Sine" } },
	VHop = { { 0, "VStance" }, { 0.12, "VWrap", "Out" }, { 0.32, "VWrap", "Linear" }, { 0.5, "VStance", "Sine" } },
	VCall = { { 0, "VStance" }, { 0.15, "VPresent", "Out" }, { 0.4, "VPresent", "Linear" }, { 0.6, "VStance", "Sine" } },
	VMenger = { { 0, "VStance" }, { 0.14, "AxlPoint", "Out" }, { 0.36, "AxlPoint", "Linear" }, { 0.55, "VStance", "Sine" } },
	VLoveTrain = { { 0, "VStance" }, { 0.3, "VPledge", "Back", 3 }, { 0.9, "VPledge", "Linear", 3 }, { 1.2, "VStance", "Sine" } },

	-- DIEGO (AU)
	J_M1_1 = { { 0, "JStance" }, { 0.07, "JPoint", "Back", 3 }, { 0.3, "JStance", "Sine" } },
	J_M1_2 = { { 0, "JStance" }, { 0.07, "JPoint", "Back", 3 }, { 0.3, "JStance", "Sine" } },
	J_M1_3 = { { 0, "JStance" }, { 0.07, "KickChamber", "In" }, { 0.13, "FrontKick", "Back", 5 }, { 0.18, "FrontKick", "Linear" }, { 0.32, "JStance", "Sine" } },
	J_M1_4 = { { 0, "JStance" }, { 0.1, "JFlick", "Snap", 6 }, { 0.25, "JFlick", "Linear" }, { 0.42, "JStance", "Sine" } },
	JBubble = { { 0, "JStance" }, { 0.12, "JBlow", "Out" }, { 0.2, "JFlick", "Snap", 4 }, { 0.4, "JFlick", "Linear" }, { 0.6, "JStance", "Sine" } },
	JMines = { { 0, "JStance" }, { 0.15, "JSpread", "Back", 3 }, { 0.5, "JSpread", "Linear" }, { 0.75, "JStance", "Sine" } },
	JGoBeyond = { { 0, "JStance" }, { 0.22, "JGoPoint", "Back", 3 }, { 0.95, "JGoPoint", "Linear", 1 }, { 1.03, "JGoJab", "Snap", 6 }, { 1.5, "JGoJab", "Linear" }, { 1.8, "JStance", "Sine" } },
	T_M1_1 = { { 0, "TStance" }, { 0.08, "TFlick", "Back", 3 }, { 0.3, "TStance", "Sine" } },
	T_M1_2 = { { 0, "TStance" }, { 0.08, "TPoint", "Back", 3 }, { 0.3, "TStance", "Sine" } },
	T_M1_3 = { { 0, "TStance" }, { 0.08, "TFlick", "Back", 3 }, { 0.3, "TStance", "Sine" } },
	T_M1_4 = { { 0, "TStance" }, { 0.1, "TPoint", "Snap", 6 }, { 0.3, "TPoint", "Linear" }, { 0.46, "TStance", "Sine" } },
	TCast = { { 0, "TStance" }, { 0.12, "TFlick", "Back", 3 }, { 0.5, "TFlick", "Linear" }, { 0.75, "TStance", "Sine" } },
	TCurse = { { 0, "TStance" }, { 0.15, "TPoint", "Back", 3 }, { 0.6, "TPoint", "Linear" }, { 0.85, "TStance", "Sine" } },
	TUlt = { { 0, "TStance" }, { 0.3, "TOpen", "Out" }, { 1.2, "TOpen", "Linear", 1 }, { 1.6, "TStance", "Sine" } },
	JD_M1_1 = { { 0, "JDStance" }, { 0.07, "JDPoint", "Back", 3 }, { 0.3, "JDStance", "Sine" } },
	JD_M1_2 = { { 0, "JDStance" }, { 0.07, "JDPoint", "Back", 3 }, { 0.3, "JDStance", "Sine" } },
	JD_M1_3 = { { 0, "JDStance" }, { 0.07, "KickChamber", "In" }, { 0.13, "FrontKick", "Back", 5 }, { 0.18, "FrontKick", "Linear" }, { 0.32, "JDStance", "Sine" } },
	JD_M1_4 = { { 0, "JDStance" }, { 0.1, "JDPoint", "Snap", 6 }, { 0.3, "JDPoint", "Linear" }, { 0.46, "JDStance", "Sine" } },
	JDCall = { { 0, "JDStance" }, { 0.15, "JDRaise", "Back", 3 }, { 0.6, "JDRaise", "Linear" }, { 0.85, "JDStance", "Sine" } },
	JDShoot = { { 0, "JDStance" }, { 0.12, "JDPoint", "Back", 3 }, { 0.6, "JDPoint", "Linear" }, { 0.8, "JDStance", "Sine" } },
	JDJet = { { 0, "JDStance" }, { 0.1, "JDSurf", "Out" }, { 0.42, "JDSurf", "Linear" }, { 0.65, "JDStance", "Sine" } },
	JDTorrent = { { 0, "JDStance" }, { 0.25, "JDRaise", "Out" }, { 1.0, "JDRaise", "Linear", 1 }, { 1.3, "JDStance", "Sine" } },
	DW_M1_1 = { { 0, "DWStance" }, { 0.07, "JabStrike", "Back", 4 }, { 0.15, "JabStrike", "Linear" }, { 0.3, "DWStance", "Sine" } },
	DW_M1_2 = { { 0, "DWStance" }, { 0.07, "JabStrikeL", "Back", 4 }, { 0.15, "JabStrikeL", "Linear" }, { 0.3, "DWStance", "Sine" } },
	DW_M1_3 = { { 0, "DWStance" }, { 0.07, "KickChamber", "In" }, { 0.13, "FrontKick", "Back", 5 }, { 0.18, "FrontKick", "Linear" }, { 0.32, "DWStance", "Sine" } },
	DW_M1_4 = { { 0, "DWStance" }, { 0.12, "DWThrowWind", "In" }, { 0.2, "AxlPoint", "Snap", 7 }, { 0.3, "AxlPoint", "Linear" }, { 0.46, "DWStance", "Sine" } },
	DWGrab = { { 0, "DWStance" }, { 0.12, "AxlPoint", "Back", 3 }, { 0.7, "AxlPoint", "Linear" }, { 0.8, "DWThrow", "Snap", 5 }, { 1.05, "DWStance", "Sine" } },
	DWBarrage = { { 0, "DWStance" }, { 0.12, "AxlPoint", "Out" }, { 1.7, "AxlPoint", "Linear", 1 }, { 1.9, "DWStance", "Sine" } },
	DWKnife = { { 0, "DWStance" }, { 0.14, "DWThrowWind", "In" }, { 0.22, "DWThrow", "Snap", 4 }, { 0.45, "DWStance", "Sine" } },
	DWTimeStop = { { 0, "DWStance" }, { 0.35, "DWSpread", "Back", 3 }, { 0.95, "DWSpread", "Linear", 2 }, { 1.25, "DWStance", "Sine" } },

	DWRevolver = { { 0, "DWStance" }, { 0.22, "DWAim", "Back", 2 }, { 0.38, "DWFan", "Snap", 3 }, { 0.45, "DWAim", "Out" }, { 0.52, "DWFan", "Snap", 3 }, { 0.59, "DWAim", "Out" }, { 0.66, "DWFan", "Snap", 3 }, { 0.73, "DWAim", "Out" }, { 0.80, "DWFan", "Snap", 3 }, { 0.87, "DWAim", "Out" }, { 0.94, "DWFan", "Snap", 3 }, { 1.01, "DWAim", "Out" }, { 1.08, "DWFan", "Snap", 3 }, { 1.15, "DWAim", "Out" }, { 1.32, "DWTwirl", "Out" }, { 1.62, "DWTwirl", "Linear" }, { 1.85, "DWStance", "Sine" } },

	-- AXL RO
	A_M1_1 = { { 0, "AxlStance" }, { 0.07, "JabStrike", "Back", 4 }, { 0.16, "JabStrike", "Linear" }, { 0.3, "AxlStance", "Sine" } },
	A_M1_2 = { { 0, "AxlStance" }, { 0.07, "JabStrikeL", "Back", 4 }, { 0.16, "JabStrikeL", "Linear" }, { 0.3, "AxlStance", "Sine" } },
	A_M1_3 = { { 0, "AxlStance" }, { 0.07, "KickChamber", "In" }, { 0.13, "FrontKick", "Back", 5 }, { 0.18, "FrontKick", "Linear" }, { 0.32, "AxlStance", "Sine" } },
	A_M1_4 = { { 0, "AxlStance" }, { 0.12, "AxlSummon", "In" }, { 0.2, "AxlPoint", "Snap", 7 }, { 0.3, "AxlPoint", "Linear" }, { 0.46, "AxlStance", "Sine" } },
	AxlSpecter = { { 0, "AxlStance" }, { 0.12, "AxlPoint", "Out" }, { 0.35, "AxlPoint", "Linear" }, { 0.55, "AxlStance", "Sine" } },
	AxlJunk = { { 0, "AxlStance" }, { 0.15, "AxlSummon", "Out" }, { 0.3, "AxlSummon", "Linear" }, { 0.36, "AxlPointL", "Snap", 5 }, { 0.6, "AxlStance", "Sine" } },
	AxlMembrane = { { 0, "AxlStance" }, { 0.14, "AxlPoint", "Out" }, { 0.3, "AxlPress", "Snap", 5 }, { 0.5, "AxlPress", "Sine" }, { 0.7, "AxlStance", "Sine" } },
	AxlCivilWar = { { 0, "AxlStance" }, { 0.4, "AxlSummon", "Back", 3 }, { 1.0, "AxlSummon", "Linear", 3 }, { 1.3, "AxlStance", "Sine" } },

	-- BLACKMORE
	B_M1_1 = { { 0, "Rest" }, { 0.07, "BladesWind", "In" }, { 0.12, "BladesSweep", "Back", 4 }, { 0.17, "BladesSweep", "Linear" }, { 0.3, "BMStance", "Sine" } },
	B_M1_2 = { { 0, "BladesSweep" }, { 0.07, "BladesWindL", "In" }, { 0.12, "BladesSweepL", "Back", 4 }, { 0.17, "BladesSweepL", "Linear" }, { 0.3, "BMStance", "Sine" } },
	B_M1_3 = { { 0, "Rest" }, { 0.07, "KickChamber", "In" }, { 0.13, "FrontKick", "Back", 5 }, { 0.18, "FrontKick", "Linear" }, { 0.32, "BMStance", "Sine" } },
	B_M1_4 = { { 0, "Rest" }, { 0.12, "CagePalm", "In" }, { 0.2, "BladesSweep", "Snap", 7 }, { 0.26, "BladesSweep", "Linear" }, { 0.44, "BMStance", "Sine" } },
	BMBlades = { { 0, "Rest" }, { 0.12, "BladesWind", "In" }, { 0.3, "BladesWind", "Linear", 1 }, { 0.36, "BladesSweep", "Snap", 5 }, { 0.55, "BMStance", "Sine" } },
	BMStep = { { 0, "Rest" }, { 0.06, "RainStep", "Snap", 2 }, { 0.3, "RainStep", "Linear" }, { 0.45, "BMStance", "Sine" } },
	BMCage = { { 0, "Rest" }, { 0.12, "CagePalm", "Out" }, { 0.24, "CageClose", "Snap", 5 }, { 0.45, "CageClose", "Sine" }, { 0.6, "BMStance", "Sine" } },
	BMStorm = { { 0, "Rest" }, { 0.3, "StormCall", "Back", 3 }, { 0.8, "StormCall", "Linear", 3 }, { 1.1, "StormHold", "Sine" }, { 1.4, "StormHold" } },

	-- SANDMAN
	S_M1_1 = { { 0, "Rest" }, { 0.07, "ChopCoil", "In" }, { 0.12, "ChopStrike", "Back", 4 }, { 0.17, "ChopStrike", "Linear" }, { 0.3, "SandStance", "Sine" } },
	S_M1_2 = { { 0, "ChopStrike" }, { 0.07, "ChopCoilL", "In" }, { 0.12, "ChopStrikeL", "Back", 4 }, { 0.17, "ChopStrikeL", "Linear" }, { 0.3, "SandStance", "Sine" } },
	S_M1_3 = { { 0, "Rest" }, { 0.08, "SpinKickWind", "In" }, { 0.16, "SpinKick", "Snap", 5 }, { 0.21, "SpinKick", "Linear" }, { 0.36, "SandStance", "Sine" } },
	S_M1_4 = { { 0, "Rest" }, { 0.13, "AxeWind", "In" }, { 0.21, "AxeKick", "Snap", 8 }, { 0.27, "AxeKick", "Linear" }, { 0.46, "AxeKick", "Sine" }, { 0.58, "SandStance", "Sine" } },
	SandSlash = { { 0, "Rest" }, { 0.12, "ChopCoil", "In" }, { 0.2, "SlashThrow", "Snap", 5 }, { 0.42, "SlashThrow", "Sine" } },
	SandTrap = { { 0, "Rest" }, { 0.14, "TrapPress", "In" }, { 0.25, "TrapPress", "Snap", 5 }, { 0.45, "TrapPress", "Sine" } },
	SandRun = { { 0, "Rest" }, { 0.1, "Sprint", "Snap", 2 }, { 0.4, "Sprint", "Linear" }, { 0.55, "SandStance", "Sine" } },
	SandSymphony = { { 0, "Rest" }, { 0.3, "ConductUp", "Back", 3 }, { 0.9, "ConductUp", "Linear", 2 }, { 1.05, "ConductDown", "Snap", 6 }, { 1.6, "ConductUp", "Back", 2 }, { 2.2, "ConductDown", "Snap", 8 }, { 2.5, "ConductDown", "Sine" } },

	PPHookSpit = { { 0, "Rest" }, { 0.18, "SpitWind", "In" }, { 0.26, "Spit", "Snap", 5 }, { 0.42, "Spit", "Sine" } },
	PPReel = { { 0, "Spit" }, { 0.1, "ReelBack", "Snap", 3 }, { 0.3, "ReelBack", "Linear", 2 }, { 0.55, "ReelBack", "Sine" } },
	PPBaitToss = { { 0, "Rest" }, { 0.14, "BowlWind", "In" }, { 0.26, "BowlRelease", "Snap", 3 }, { 0.42, "BowlFollow", "Sine" } },
	PPHoist = { { 0, "Rest" }, { 0.2, "SpitWind", "In" }, { 0.3, "Spit", "Snap", 4 }, { 0.45, "HoistUp", "Back", 5 }, { 0.8, "HoistUp", "Linear", 2 }, { 0.92, "HoistSlam", "Snap", 7 }, { 1.2, "HoistSlam", "Sine" } },
	PPWinch = {
		{ 0, "Rest" }, { 0.3, "Spread", "Back", 3 }, { 0.9, "Spread", "Linear", 2 }, { 1.05, "Spit", "Snap", 5 },
		{ 1.3, "ReelBack", "Snap", 3 }, { 1.7, "HoistUp", "Sine", 2 }, { 2.1, "ReelBack", "Sine", 2 }, { 2.35, "HoistSlam", "Snap", 8 }, { 2.7, "HoistSlam", "Sine" },
	},
	Awakening = {
		{ 0, "Rest" }, { 0.35, "AwakenCrouch", "In" }, { 0.7, "AwakenCrouch", "Linear", 1 }, { 1.0, "AwakenCrouch", "Linear", 2 },
		{ 1.2, "AwakenCrouch", "Linear", 3 }, { 1.45, "AwakenRise", "Back", 6 }, { 2.2, "AwakenRise", "Sine" },
	},
	Emerge = { { 0, "Sneak" }, { 0.12, "Emerge", "Back", 3 }, { 0.5, "Emerge", "Sine" } },
	Throw = { { 0, "Rest" }, { 0.14, "SlamWindup", "In" }, { 0.24, "Point", "Snap", 3 }, { 0.5, "Point", "Sine" } },
}

local states = setmetatable({}, { __mode = "k" }) -- character -> { Hold, Action, Idle, Tracks }
local warned = setmetatable({}, { __mode = "k" })
-- Extra time each move holds its last pose before settling (makes moves read clearly).
TuskAnimation.HoldExtra = 0.1
TuskAnimation.SettleTime = 0.3
local OVERSHOOT = 1.14 -- "Back" eases swing this far past the pose, then settle
local SHAKE_TIME = 0.16
local SHAKE_JOINTS = { "Root", "Waist", "RightArm", "LeftArm", "Neck" }

local EASES = {
	Linear = function(a)
		return a
	end,
	Out = function(a)
		return 1 - (1 - a) ^ 3
	end,
	Snap = function(a)
		return 1 - (1 - a) ^ 5
	end,
	In = function(a)
		return a * a * a
	end,
	Sine = function(a)
		return 0.5 - 0.5 * math.cos(a * math.pi)
	end,
}

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
	local found = 0
	for name, path in pairs(JOINTS[rig]) do
		local holder = character:FindFirstChild(path[1])
		local motor = holder and holder:FindFirstChild(path[2])
		if JointCache.isJoint(motor) then
			motors[name] = motor
			found = found + 1
		end
	end
	if found == 0 and not warned[character] then
		warned[character] = true
		warn("[Spin] No animatable joints found on " .. character.Name .. " (" .. rig .. "). Move animations can't play on this character.")
	end
	return motors
end

-- Riders sit up on a horse: their whole body is lifted on the root joint by
-- this many studs, under every pose (TuskAnimation.setLift).
local lifts = setmetatable({}, { __mode = "k" }) -- [character] = studs

local function liftOf(motor)
	if motor.Name == "Root" or motor.Name == "RootJoint" then
		local character = motor.Parent and motor.Parent.Parent
		return character and lifts[character] or 0
	end
	return 0
end

-- C0 for a pose value (rotation applied in the parent part's space, about the joint).
local function poseC0(motor, value, scale)
	local base = JointCache.original(motor)
	local lift = liftOf(motor)
	if lift ~= 0 then
		base = base + Vector3.new(0, lift, 0)
	end
	if not value then
		return base
	end
	scale = scale or 1
	local rotation = CFrame.Angles(math.rad(value[1] * scale), math.rad(value[2] * scale), math.rad(value[3] * scale))
	local position = base.Position + Vector3.new(0, (value[4] or 0) * scale, -(value[5] or 0) * scale)
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
		s = { Hold = nil, Action = nil, Tracks = {}, SettleUntil = 0 }
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

-- Smoothly settle every joint toward a target pose.
local function blendTo(character, pose, duration)
	local s = getState(character)
	local motors = motorsOf(character)
	local from, to = {}, {}
	for name, motor in pairs(motors) do
		from[name] = JointCache.read(motor)
		to[name] = poseC0(motor, pose[name])
	end
	s.SettleUntil = os.clock() + duration
	-- Only the newest blend runs (an older one finishing later would undo it).
	VFXLib.cancel(s.Blend)
	s.Blend = VFXLib.animate(duration, function(a)
		local e = EASES.Sine(a)
		for name, motor in pairs(motors) do
			if motor.Parent then
				JointCache.write(motor, from[name]:Lerp(to[name], e))
			end
		end
	end)
	return s.Blend
end

-- Breathing idle layered on a Hold pose (chest rise, head and arm sway).
local function startIdle(character, s)
	VFXLib.cancel(s.Idle)
	local motors = motorsOf(character)
	local seed = math.random() * 10
	s.Idle = VFXLib.animate(1e6, function()
		if s.Action or not s.Hold or os.clock() < s.SettleUntil then
			return
		end
		local pose = resolvePose(s.Hold)
		local t = os.clock() + seed
		local breath = math.sin(t * 2.2)
		local sway = math.sin(t * 1.1)
		local extra = {
			Waist = CFrame.Angles(math.rad(breath * 1.6), math.rad(sway * 1.2), 0),
			Neck = CFrame.Angles(math.rad(-breath * 1.2), math.rad(math.sin(t * 0.7) * 3), 0),
			RightArm = CFrame.Angles(math.rad(breath * 2.2), 0, math.rad(sway * 1.5)),
			LeftArm = CFrame.Angles(math.rad(breath * 2.2), 0, math.rad(-sway * 1.5)),
		}
		for name, offset in pairs(extra) do
			local motor = motors[name]
			if motor and motor.Parent then
				JointCache.write(motor, poseC0(motor, pose[name]) * offset)
			end
		end
	end)
end

local function stopIdle(s)
	VFXLib.cancel(s.Idle)
	s.Idle = nil
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
		local ease = frame[3] or "Out"
		local c0s, over = {}, nil
		if ease == "Back" then
			over = {}
		end
		for jointName, motor in pairs(motors) do
			local value = pose[jointName] or holdPose[jointName]
			if i == 1 then
				c0s[jointName] = JointCache.read(motor)
			else
				c0s[jointName] = poseC0(motor, value)
				if over then
					over[jointName] = poseC0(motor, value, OVERSHOOT)
				end
			end
		end
		keys[i] = { Time = frame[1], C0 = c0s, Over = over, Ease = ease, Shake = frame[4] }
	end
	local total = length + TuskAnimation.HoldExtra
	local job
	job = VFXLib.animate(total, function(a)
		local t = math.min(a * total, length)
		local k = 1
		while k < #keys and keys[k + 1].Time < t do
			k = k + 1
		end
		local current = keys[k]
		local nextKey = keys[math.min(k + 1, #keys)]
		local span = math.max(nextKey.Time - current.Time, 1e-3)
		local local01 = math.clamp((t - current.Time) / span, 0, 1)
		-- Impact shake from the most recent key that has one.
		local shake = 0
		for i = 1, #keys do
			local key = keys[i]
			if key.Shake and key.Time <= t and t < key.Time + SHAKE_TIME then
				shake = math.max(shake, key.Shake * (1 - (t - key.Time) / SHAKE_TIME))
			end
		end
		for jointName, motor in pairs(motors) do
			if motor.Parent then
				local fromC0, toC0 = current.C0[jointName], nextKey.C0[jointName]
				local c0
				if nextKey.Over and nextKey ~= current then
					-- Overshoot: snap past the pose, then settle back onto it.
					if local01 < 0.6 then
						c0 = fromC0:Lerp(nextKey.Over[jointName], EASES.Snap(local01 / 0.6))
					else
						c0 = nextKey.Over[jointName]:Lerp(toC0, EASES.Sine((local01 - 0.6) / 0.4))
					end
				else
					local ease = EASES[nextKey.Ease] or EASES.Out
					c0 = fromC0:Lerp(toC0, ease(local01))
				end
				if shake > 0 and table.find(SHAKE_JOINTS, jointName) then
					local r = math.rad(shake)
					c0 = c0 * CFrame.Angles((math.random() - 0.5) * r, (math.random() - 0.5) * r, (math.random() - 0.5) * r)
				end
				JointCache.write(motor, c0)
			end
		end
	end, function()
		if s.Action == job then
			s.Action = nil
			blendTo(character, resolvePose(s.Hold), TuskAnimation.SettleTime)
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
		blendTo(character, resolvePose(poseName), 0.25)
	end
	startIdle(character, s)
end

-- Lift a character's whole body (e.g. onto a horse's saddle); nil / 0 to stop.
function TuskAnimation.setLift(character, studs)
	if not character then
		return
	end
	studs = (studs and studs ~= 0) and studs or nil
	if lifts[character] == studs then
		return
	end
	lifts[character] = studs
	local s = getState(character)
	if not s.Action then
		blendTo(character, resolvePose(s.Hold), 0.15)
	end
end

-- The pose currently held on a character (so a temporary hold can put it back).
function TuskAnimation.currentHold(character)
	return character and getState(character).Hold
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
	stopIdle(s)
	if not s.Action then
		blendTo(character, {}, TuskAnimation.SettleTime)
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
	local s = states[character]
	if s then
		stopIdle(s)
	end
	states[character] = nil
end)

return TuskAnimation
```
