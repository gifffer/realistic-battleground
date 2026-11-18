--!strict
-- ALSClips: the player's Unreal "Advanced Locomotion System" animations
-- (UE5 mannequin, 88 bones), retargeted onto R6 by tools/anim/als_retarget.py
-- (how the bones become 6 parts is explained there). DO NOT edit the
-- generated block by hand: change the tool and run it again.
--
--   • Phase clips (length 1 = one cycle, left foot planting at 7/16, the
--     right one at 15/16): Walk*, Jog*, Sprint, CrouchWalk*. Played by
--     Animation/Locomotion on one shared phase, blended by direction and speed.
--   • The others are in seconds: Stand / Crouch (poses), JumpLoop, FallLoop,
--     FallFast, Flail (loops), LandLight / LandHeavy / LandRoll, turns on the
--     spot, GetUpBack / GetUpFront, StopLeft / StopRight, Mantle.

local R6Pose = require(script.Parent.R6Pose)

local clips: { [string]: R6Pose.Clip } = {
	-- BEGIN generated ALS clips (tools/anim/als_retarget.py)
	-- ALS_N_Walk_F: phase clip (one cycle = 1), left foot plants at 0.4375; natural cycle 1.167 s, stride 3.61 studs per cycle
	Walk = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-3.93, -2.69, -1.98),
						pos = Vector3.new(0.01, -0.14, -0.02),
					},
					Neck = { rot = Vector3.new(3.85, 2.83, 1.73) },
					RightShoulder = { rot = Vector3.new(1.59, 0, 16.35) },
					LeftShoulder = { rot = Vector3.new(13.71, 0, -15.63) },
					RightHip = { rot = Vector3.new(16.43, 0, 0), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(-25.16, 0, 6.02), pos = Vector3.new(0, 0.09, 0) },
				},
			},
			{
				time = 0.0312,
				pose = {
					Root = {
						rot = Vector3.new(-3.95, -2.44, -2.22),
						pos = Vector3.new(0.02, -0.12, -0.02),
					},
					Neck = { rot = Vector3.new(3.85, 2.58, 2.02) },
					RightShoulder = { rot = Vector3.new(4.64, 0, 16.1) },
					LeftShoulder = { rot = Vector3.new(10.45, 0, -16.01) },
					RightHip = { rot = Vector3.new(13.12, 0, 0.19), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(-23.43, 0, 6.05), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.0625,
				pose = {
					Root = {
						rot = Vector3.new(-3.96, -2.09, -2.35),
						pos = Vector3.new(0.02, -0.09, -0.02),
					},
					Neck = { rot = Vector3.new(3.85, 2.23, 2.21) },
					RightShoulder = { rot = Vector3.new(7.84, 0, 15.69) },
					LeftShoulder = { rot = Vector3.new(7.07, 0, -16.16) },
					RightHip = { rot = Vector3.new(9.89, 0, 0.25), pos = Vector3.new(0, 0.17, 0) },
					LeftHip = { rot = Vector3.new(-19.5, 0, 5.85), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.0938,
				pose = {
					Root = {
						rot = Vector3.new(-3.96, -1.65, -2.41),
						pos = Vector3.new(0.03, -0.07, -0.01),
					},
					Neck = { rot = Vector3.new(3.85, 1.78, 2.32) },
					RightShoulder = { rot = Vector3.new(11.05, 0, 15.1) },
					LeftShoulder = { rot = Vector3.new(3.71, 0, -16.1) },
					RightHip = { rot = Vector3.new(6.69, 0, 0.2), pos = Vector3.new(0, 0.12, 0) },
					LeftHip = { rot = Vector3.new(-14.03, 0, 5.52), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = {
						rot = Vector3.new(-3.94, -1.15, -2.38),
						pos = Vector3.new(0.04, -0.05, -0.01),
					},
					Neck = { rot = Vector3.new(3.86, 1.25, 2.37) },
					RightShoulder = { rot = Vector3.new(14.13, 0, 14.35) },
					LeftShoulder = { rot = Vector3.new(0.52, 0, -15.86) },
					RightHip = { rot = Vector3.new(3.77, 0, 0.02), pos = Vector3.new(0, 0.08, 0) },
					LeftHip = { rot = Vector3.new(-6.57, 0, 4.98), pos = Vector3.new(0, 0.21, 0) },
				},
			},
			{
				time = 0.1562,
				pose = {
					Root = {
						rot = Vector3.new(-3.92, -0.59, -2.29),
						pos = Vector3.new(0.04, -0.03, -0.01),
					},
					Neck = { rot = Vector3.new(3.86, 0.68, 2.34) },
					RightShoulder = { rot = Vector3.new(16.96, 0, 13.52) },
					LeftShoulder = { rot = Vector3.new(-2.38, 0, -15.51) },
					RightHip = { rot = Vector3.new(0.63, 0, 0.05), pos = Vector3.new(0, 0.09, 0) },
					LeftHip = { rot = Vector3.new(1.58, 0, 4.49), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 0.1875,
				pose = {
					Root = {
						rot = Vector3.new(-3.9, -0.01, -2.13),
						pos = Vector3.new(0.04, -0.03, 0),
					},
					Neck = { rot = Vector3.new(3.87, 0.07, 2.25) },
					RightShoulder = { rot = Vector3.new(19.43, 0, 12.69) },
					LeftShoulder = { rot = Vector3.new(-4.86, 0, -15.16) },
					RightHip = { rot = Vector3.new(-2.55, 0, -0.08), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10.22, 0, 4.09), pos = Vector3.new(0, 0.11, 0) },
				},
			},
			{
				time = 0.2188,
				pose = {
					Root = {
						rot = Vector3.new(-3.88, 0.58, -1.89),
						pos = Vector3.new(0.04, -0.04, 0),
					},
					Neck = { rot = Vector3.new(3.88, -0.54, 2.07) },
					RightShoulder = { rot = Vector3.new(21.46, 0, 12) },
					LeftShoulder = { rot = Vector3.new(-6.84, 0, -14.89) },
					RightHip = { rot = Vector3.new(-5.76, 0, -0.36), pos = Vector3.new(0, 0.12, 0) },
					LeftHip = { rot = Vector3.new(18.37, 0, 3.55), pos = Vector3.new(0, 0.05, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(-3.86, 1.13, -1.59),
						pos = Vector3.new(0.04, -0.06, 0.01),
					},
					Neck = { rot = Vector3.new(3.88, -1.12, 1.82) },
					RightShoulder = { rot = Vector3.new(22.98, 0, 11.55) },
					LeftShoulder = { rot = Vector3.new(-8.23, 0, -14.82) },
					RightHip = { rot = Vector3.new(-8.99, 0, -0.78), pos = Vector3.new(0, 0.14, 0) },
					LeftHip = { rot = Vector3.new(24.57, 0, 2.88), pos = Vector3.new(0, 0.07, 0) },
				},
			},
			{
				time = 0.2812,
				pose = {
					Root = {
						rot = Vector3.new(-3.86, 1.64, -1.21),
						pos = Vector3.new(0.04, -0.09, 0.01),
					},
					Neck = { rot = Vector3.new(3.89, -1.66, 1.49) },
					RightShoulder = { rot = Vector3.new(23.87, 0, 11.48) },
					LeftShoulder = { rot = Vector3.new(-8.93, 0, -15.02) },
					RightHip = {
						rot = Vector3.new(-12.19, 0, -1.35),
						pos = Vector3.new(0, 0.16, 0),
					},
					LeftHip = { rot = Vector3.new(29.09, 0, 2.74), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.3125,
				pose = {
					Root = {
						rot = Vector3.new(-3.86, 2.07, -0.79),
						pos = Vector3.new(0.03, -0.12, 0.01),
					},
					Neck = { rot = Vector3.new(3.89, -2.12, 1.1) },
					RightShoulder = { rot = Vector3.new(24.09, 0, 11.78) },
					LeftShoulder = { rot = Vector3.new(-8.96, 0, -15.43) },
					RightHip = {
						rot = Vector3.new(-15.24, 0, -1.92),
						pos = Vector3.new(0, 0.18, 0),
					},
					LeftHip = { rot = Vector3.new(31.69, 0, 2.62), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.3438,
				pose = {
					Root = {
						rot = Vector3.new(-3.88, 2.45, -0.25),
						pos = Vector3.new(0.03, -0.14, 0.01),
					},
					Neck = { rot = Vector3.new(3.9, -2.52, 0.58) },
					RightShoulder = { rot = Vector3.new(23.42, 0, 12.44) },
					LeftShoulder = { rot = Vector3.new(-8.08, 0, -15.87) },
					RightHip = {
						rot = Vector3.new(-18.53, 0, -2.73),
						pos = Vector3.new(0, 0.18, 0),
					},
					LeftHip = { rot = Vector3.new(30.71, 0, 2.19), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = {
						rot = Vector3.new(-3.88, 2.49, -0.19),
						pos = Vector3.new(0.02, -0.15, 0.01),
					},
					Neck = { rot = Vector3.new(3.9, -2.57, 0.52) },
					RightShoulder = { rot = Vector3.new(23.34, 0, 12.52) },
					LeftShoulder = { rot = Vector3.new(-7.97, 0, -15.91) },
					RightHip = {
						rot = Vector3.new(-18.93, 0, -2.83),
						pos = Vector3.new(0, 0.18, 0),
					},
					LeftHip = { rot = Vector3.new(30.49, 0, 2.13), pos = Vector3.new(0, 0.14, 0) },
				},
			},
			{
				time = 0.4062,
				pose = {
					Root = {
						rot = Vector3.new(-3.9, 2.69, 0.26),
						pos = Vector3.new(0.02, -0.15, 0),
					},
					Neck = { rot = Vector3.new(3.89, -2.78, 0.08) },
					RightShoulder = { rot = Vector3.new(22.23, 0, 13.13) },
					LeftShoulder = { rot = Vector3.new(-6.74, 0, -16.17) },
					RightHip = { rot = Vector3.new(-21, 0, -3.6), pos = Vector3.new(0, 0.17, 0) },
					LeftHip = { rot = Vector3.new(27.83, 0, 1.68), pos = Vector3.new(0, 0.17, 0) },
				},
			},
			{
				time = 0.4375,
				pose = {
					Root = {
						rot = Vector3.new(-3.93, 2.83, 0.83),
						pos = Vector3.new(0.01, -0.16, 0),
					},
					Neck = { rot = Vector3.new(3.89, -2.95, -0.5) },
					RightShoulder = { rot = Vector3.new(20.36, 0, 13.88) },
					LeftShoulder = { rot = Vector3.new(-4.81, 0, -16.42) },
					RightHip = { rot = Vector3.new(-23.1, 0, -4.55), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(24.68, 0, 1.18), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.4688,
				pose = {
					Root = {
						rot = Vector3.new(-3.95, 2.85, 1.39),
						pos = Vector3.new(0, -0.15, -0.01),
					},
					Neck = { rot = Vector3.new(3.88, -2.99, -1.08) },
					RightShoulder = { rot = Vector3.new(17.97, 0, 14.58) },
					LeftShoulder = { rot = Vector3.new(-2.45, 0, -16.57) },
					RightHip = {
						rot = Vector3.new(-24.49, 0, -5.34),
						pos = Vector3.new(0, 0.12, 0),
					},
					LeftHip = { rot = Vector3.new(21.43, 0, 0.64), pos = Vector3.new(0, 0.22, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-3.96, 2.76, 1.83),
						pos = Vector3.new(-0.01, -0.14, -0.01),
					},
					Neck = { rot = Vector3.new(3.87, -2.91, -1.56) },
					RightShoulder = { rot = Vector3.new(15.14, 0, 15.19) },
					LeftShoulder = { rot = Vector3.new(0.25, 0, -16.58) },
					RightHip = { rot = Vector3.new(-25.18, 0, -5.81), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(18.05, 0, 0.23), pos = Vector3.new(0, 0.22, 0) },
				},
			},
			{
				time = 0.5312,
				pose = {
					Root = {
						rot = Vector3.new(-3.96, 2.56, 2.13),
						pos = Vector3.new(-0.01, -0.13, -0.02),
					},
					Neck = { rot = Vector3.new(3.86, -2.71, -1.9) },
					RightShoulder = { rot = Vector3.new(11.99, 0, 15.66) },
					LeftShoulder = { rot = Vector3.new(3.21, 0, -16.41) },
					RightHip = {
						rot = Vector3.new(-24.55, 0, -5.97),
						pos = Vector3.new(0, 0.09, 0),
					},
					LeftHip = { rot = Vector3.new(14.66, 0, -0.02), pos = Vector3.new(0, 0.21, 0) },
				},
			},
			{
				time = 0.5625,
				pose = {
					Root = {
						rot = Vector3.new(-3.95, 2.26, 2.31),
						pos = Vector3.new(-0.02, -0.11, -0.02),
					},
					Neck = { rot = Vector3.new(3.86, -2.4, -2.13) },
					RightShoulder = { rot = Vector3.new(8.64, 0, 15.92) },
					LeftShoulder = { rot = Vector3.new(6.35, 0, -16.08) },
					RightHip = {
						rot = Vector3.new(-21.58, 0, -5.84),
						pos = Vector3.new(0, 0.13, 0),
					},
					LeftHip = { rot = Vector3.new(11.36, 0, -0.15), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 0.5938,
				pose = {
					Root = {
						rot = Vector3.new(-3.93, 1.86, 2.4),
						pos = Vector3.new(-0.03, -0.08, -0.01),
					},
					Neck = { rot = Vector3.new(3.85, -2, -2.28) },
					RightShoulder = { rot = Vector3.new(5.25, 0, 15.96) },
					LeftShoulder = { rot = Vector3.new(9.57, 0, -15.57) },
					RightHip = {
						rot = Vector3.new(-16.87, 0, -5.51),
						pos = Vector3.new(0, 0.18, 0),
					},
					LeftHip = { rot = Vector3.new(8.08, 0, -0.18), pos = Vector3.new(0, 0.14, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = {
						rot = Vector3.new(-3.89, 1.39, 2.42),
						pos = Vector3.new(-0.03, -0.06, -0.01),
					},
					Neck = { rot = Vector3.new(3.84, -1.51, -2.36) },
					RightShoulder = { rot = Vector3.new(1.97, 0, 15.8) },
					LeftShoulder = { rot = Vector3.new(12.73, 0, -14.9) },
					RightHip = {
						rot = Vector3.new(-10.32, 0, -5.02),
						pos = Vector3.new(0, 0.21, 0),
					},
					LeftHip = { rot = Vector3.new(5.05, 0, -0.09), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.6562,
				pose = {
					Root = {
						rot = Vector3.new(-3.85, 0.85, 2.36),
						pos = Vector3.new(-0.04, -0.04, -0.01),
					},
					Neck = { rot = Vector3.new(3.84, -0.95, -2.37) },
					RightShoulder = { rot = Vector3.new(-1.08, 0, 15.5) },
					LeftShoulder = { rot = Vector3.new(15.69, 0, -14.1) },
					RightHip = { rot = Vector3.new(-2.39, 0, -4.49), pos = Vector3.new(0, 0.21, 0) },
					LeftHip = { rot = Vector3.new(1.98, 0, -0.05), pos = Vector3.new(0, 0.09, 0) },
				},
			},
			{
				time = 0.6875,
				pose = {
					Root = {
						rot = Vector3.new(-3.81, 0.28, 2.24),
						pos = Vector3.new(-0.04, -0.03, 0),
					},
					Neck = { rot = Vector3.new(3.84, -0.36, -2.31) },
					RightShoulder = { rot = Vector3.new(-3.76, 0, 15.14) },
					LeftShoulder = { rot = Vector3.new(18.34, 0, -13.26) },
					RightHip = { rot = Vector3.new(5.99, 0, -4.06), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(-1.23, 0, 0.04), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.7188,
				pose = {
					Root = {
						rot = Vector3.new(-3.77, -0.3, 2.04),
						pos = Vector3.new(-0.04, -0.03, 0),
					},
					Neck = { rot = Vector3.new(3.84, 0.25, -2.17) },
					RightShoulder = { rot = Vector3.new(-5.98, 0, 14.82) },
					LeftShoulder = { rot = Vector3.new(20.58, 0, -12.49) },
					RightHip = { rot = Vector3.new(14.68, 0, -3.78), pos = Vector3.new(0, 0.06, 0) },
					LeftHip = { rot = Vector3.new(-4.43, 0, 0.26), pos = Vector3.new(0, 0.11, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(-3.74, -0.88, 1.77),
						pos = Vector3.new(-0.04, -0.05, 0.01),
					},
					Neck = { rot = Vector3.new(3.84, 0.85, -1.96) },
					RightShoulder = { rot = Vector3.new(-7.65, 0, 14.66) },
					LeftShoulder = { rot = Vector3.new(22.34, 0, -11.92) },
					RightHip = { rot = Vector3.new(21.74, 0, -3.09), pos = Vector3.new(0, 0.07, 0) },
					LeftHip = { rot = Vector3.new(-7.68, 0, 0.6), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 0.7812,
				pose = {
					Root = {
						rot = Vector3.new(-3.73, -1.41, 1.43),
						pos = Vector3.new(-0.04, -0.08, 0.01),
					},
					Neck = { rot = Vector3.new(3.84, 1.4, -1.66) },
					RightShoulder = { rot = Vector3.new(-8.69, 0, 14.72) },
					LeftShoulder = { rot = Vector3.new(23.53, 0, -11.66) },
					RightHip = { rot = Vector3.new(27.06, 0, -2.81), pos = Vector3.new(0, 0.08, 0) },
					LeftHip = { rot = Vector3.new(-10.92, 0, 1.05), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.8125,
				pose = {
					Root = {
						rot = Vector3.new(-3.72, -1.88, 1.02),
						pos = Vector3.new(-0.03, -0.11, 0.01),
					},
					Neck = { rot = Vector3.new(3.85, 1.9, -1.29) },
					RightShoulder = { rot = Vector3.new(-9.01, 0, 15.08) },
					LeftShoulder = { rot = Vector3.new(24.05, 0, -11.81) },
					RightHip = { rot = Vector3.new(30.55, 0, -2.65), pos = Vector3.new(0, 0.09, 0) },
					LeftHip = { rot = Vector3.new(-14.06, 0, 1.66), pos = Vector3.new(0, 0.17, 0) },
				},
			},
			{
				time = 0.8438,
				pose = {
					Root = {
						rot = Vector3.new(-3.74, -2.28, 0.56),
						pos = Vector3.new(-0.03, -0.13, 0.01),
					},
					Neck = { rot = Vector3.new(3.85, 2.32, -0.86) },
					RightShoulder = { rot = Vector3.new(-8.61, 0, 15.51) },
					LeftShoulder = { rot = Vector3.new(23.84, 0, -12.29) },
					RightHip = { rot = Vector3.new(31.49, 0, -2.38), pos = Vector3.new(0, 0.11, 0) },
					LeftHip = { rot = Vector3.new(-17.14, 0, 2.33), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = {
						rot = Vector3.new(-3.77, -2.57, 0.05),
						pos = Vector3.new(-0.02, -0.15, 0.01),
					},
					Neck = { rot = Vector3.new(3.85, 2.64, -0.36) },
					RightShoulder = { rot = Vector3.new(-7.54, 0, 15.85) },
					LeftShoulder = { rot = Vector3.new(22.95, 0, -12.94) },
					RightHip = { rot = Vector3.new(29.36, 0, -1.93), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(-19.89, 0, 3.19), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 0.9062,
				pose = {
					Root = {
						rot = Vector3.new(-3.81, -2.77, -0.5),
						pos = Vector3.new(-0.02, -0.16, 0),
					},
					Neck = { rot = Vector3.new(3.85, 2.86, 0.18) },
					RightShoulder = { rot = Vector3.new(-5.9, 0, 16.13) },
					LeftShoulder = { rot = Vector3.new(21.42, 0, -13.68) },
					RightHip = { rot = Vector3.new(26.21, 0, -1.45), pos = Vector3.new(0, 0.19, 0) },
					LeftHip = { rot = Vector3.new(-22.17, 0, 4.17), pos = Vector3.new(0, 0.16, 0) },
				},
			},
			{
				time = 0.9375,
				pose = {
					Root = {
						rot = Vector3.new(-3.86, -2.85, -1.08),
						pos = Vector3.new(-0.01, -0.16, -0.01),
					},
					Neck = { rot = Vector3.new(3.85, 2.97, 0.77) },
					RightShoulder = { rot = Vector3.new(-3.77, 0, 16.34) },
					LeftShoulder = { rot = Vector3.new(19.31, 0, -14.42) },
					RightHip = { rot = Vector3.new(23.1, 0, -0.89), pos = Vector3.new(0, 0.21, 0) },
					LeftHip = { rot = Vector3.new(-23.91, 0, 5.08), pos = Vector3.new(0, 0.14, 0) },
				},
			},
			{
				time = 0.9688,
				pose = {
					Root = {
						rot = Vector3.new(-3.9, -2.83, -1.6),
						pos = Vector3.new(0, -0.15, -0.01),
					},
					Neck = { rot = Vector3.new(3.85, 2.96, 1.32) },
					RightShoulder = { rot = Vector3.new(-1.24, 0, 16.42) },
					LeftShoulder = { rot = Vector3.new(16.71, 0, -15.08) },
					RightHip = { rot = Vector3.new(19.8, 0, -0.36), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(-24.94, 0, 5.72), pos = Vector3.new(0, 0.11, 0) },
				},
			},
		},
	},
	-- ALS_N_Walk_B: phase clip (one cycle = 1), left foot plants at 0.4375; natural cycle 1.167 s, stride 3.68 studs per cycle
	WalkBack = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(2.22, 0.83, -2.3),
						pos = Vector3.new(0.04, -0.06, -0.01),
					},
					Neck = { rot = Vector3.new(-2.24, -1, 2.42) },
					RightShoulder = { rot = Vector3.new(13.33, 0, 12.42) },
					LeftShoulder = { rot = Vector3.new(-10.98, 0, -16.6) },
					RightHip = { rot = Vector3.new(-8.93, 0, 0.03), pos = Vector3.new(0, 0.14, 0) },
					LeftHip = { rot = Vector3.new(-5.61, 0, 4.37), pos = Vector3.new(0, 0.21, 0) },
				},
			},
			{
				time = 0.0312,
				pose = {
					Root = {
						rot = Vector3.new(2.2, 0.25, -2.44),
						pos = Vector3.new(0.04, -0.04, -0.01),
					},
					Neck = { rot = Vector3.new(-2.25, -0.4, 2.55) },
					RightShoulder = { rot = Vector3.new(10.71, 0, 13.19) },
					LeftShoulder = { rot = Vector3.new(-7.99, 0, -16.92) },
					RightHip = { rot = Vector3.new(-5.74, 0, 0.3), pos = Vector3.new(0, 0.11, 0) },
					LeftHip = { rot = Vector3.new(-13.74, 0, 4.79), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.0625,
				pose = {
					Root = {
						rot = Vector3.new(2.18, -0.35, -2.5),
						pos = Vector3.new(0.03, -0.04, -0.01),
					},
					Neck = { rot = Vector3.new(-2.26, 0.21, 2.61) },
					RightShoulder = { rot = Vector3.new(7.79, 0, 13.89) },
					LeftShoulder = { rot = Vector3.new(-4.64, 0, -17.09) },
					RightHip = { rot = Vector3.new(-2.55, 0, 0.41), pos = Vector3.new(0, 0.08, 0) },
					LeftHip = { rot = Vector3.new(-21.49, 0, 5.29), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.0938,
				pose = {
					Root = {
						rot = Vector3.new(2.17, -0.93, -2.5),
						pos = Vector3.new(0.02, -0.04, -0.01),
					},
					Neck = { rot = Vector3.new(-2.27, 0.82, 2.6) },
					RightShoulder = { rot = Vector3.new(4.68, 0, 14.49) },
					LeftShoulder = { rot = Vector3.new(-1.06, 0, -17.02) },
					RightHip = { rot = Vector3.new(0.72, 0, 0.67), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(-27.42, 0, 5.7), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = {
						rot = Vector3.new(2.16, -1.48, -2.43),
						pos = Vector3.new(0.02, -0.06, -0.01),
					},
					Neck = { rot = Vector3.new(-2.27, 1.39, 2.52) },
					RightShoulder = { rot = Vector3.new(1.54, 0, 14.95) },
					LeftShoulder = { rot = Vector3.new(2.57, 0, -16.68) },
					RightHip = { rot = Vector3.new(4.19, 0, 0.8), pos = Vector3.new(0, 0.14, 0) },
					LeftHip = { rot = Vector3.new(-31.82, 0, 6.06), pos = Vector3.new(0, 0.01, 0) },
				},
			},
			{
				time = 0.1562,
				pose = {
					Root = {
						rot = Vector3.new(2.17, -1.97, -2.29),
						pos = Vector3.new(0.01, -0.09, -0.01),
					},
					Neck = { rot = Vector3.new(-2.28, 1.9, 2.36) },
					RightShoulder = { rot = Vector3.new(-1.66, 0, 15.39) },
					LeftShoulder = { rot = Vector3.new(6.11, 0, -16.08) },
					RightHip = { rot = Vector3.new(7.74, 0, 0.8), pos = Vector3.new(0, 0.18, 0) },
					LeftHip = { rot = Vector3.new(-33.76, 0, 6.15), pos = Vector3.new(0, 0.01, 0) },
				},
			},
			{
				time = 0.1875,
				pose = {
					Root = { rot = Vector3.new(2.18, -2.38, -2.05), pos = Vector3.new(0, -0.12, 0) },
					Neck = { rot = Vector3.new(-2.28, 2.33, 2.11) },
					RightShoulder = { rot = Vector3.new(-4.94, 0, 15.82) },
					LeftShoulder = { rot = Vector3.new(9.39, 0, -15.27) },
					RightHip = { rot = Vector3.new(11.36, 0, 0.63), pos = Vector3.new(0, 0.21, 0) },
					LeftHip = { rot = Vector3.new(-33.55, 0, 6.24), pos = Vector3.new(0, 0.05, 0) },
				},
			},
			{
				time = 0.2188,
				pose = {
					Root = {
						rot = Vector3.new(2.2, -2.68, -1.7),
						pos = Vector3.new(-0.01, -0.15, 0.01),
					},
					Neck = { rot = Vector3.new(-2.28, 2.67, 1.74) },
					RightShoulder = { rot = Vector3.new(-8.19, 0, 16.14) },
					LeftShoulder = { rot = Vector3.new(12.32, 0, -14.33) },
					RightHip = { rot = Vector3.new(14.83, 0, 0.26), pos = Vector3.new(0, 0.23, 0) },
					LeftHip = { rot = Vector3.new(-32.48, 0, 5.99), pos = Vector3.new(0, 0.09, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(2.23, -2.87, -1.22),
						pos = Vector3.new(-0.01, -0.16, 0.02),
					},
					Neck = { rot = Vector3.new(-2.28, 2.89, 1.25) },
					RightShoulder = { rot = Vector3.new(-11.14, 0, 16.3) },
					LeftShoulder = { rot = Vector3.new(14.74, 0, -13.39) },
					RightHip = { rot = Vector3.new(17.87, 0, -0.25), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(-30.92, 0, 5.4), pos = Vector3.new(0, 0.12, 0) },
				},
			},
			{
				time = 0.2812,
				pose = {
					Root = {
						rot = Vector3.new(2.28, -2.92, -0.52),
						pos = Vector3.new(-0.02, -0.16, 0.02),
					},
					Neck = { rot = Vector3.new(-2.28, 2.99, 0.52) },
					RightShoulder = { rot = Vector3.new(-13.92, 0, 16.24) },
					LeftShoulder = { rot = Vector3.new(16.8, 0, -12.42) },
					RightHip = { rot = Vector3.new(21.12, 0, -1.06), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(-28.41, 0, 4.34), pos = Vector3.new(0, 0.16, 0) },
				},
			},
			{
				time = 0.3125,
				pose = {
					Root = {
						rot = Vector3.new(2.3, -2.92, -0.3),
						pos = Vector3.new(-0.02, -0.17, 0.02),
					},
					Neck = { rot = Vector3.new(-2.28, 3, 0.3) },
					RightShoulder = { rot = Vector3.new(-14.65, 0, 16.21) },
					LeftShoulder = { rot = Vector3.new(17.32, 0, -12.15) },
					RightHip = { rot = Vector3.new(22.1, 0, -1.32), pos = Vector3.new(0, 0.19, 0) },
					LeftHip = { rot = Vector3.new(-27.66, 0, 4), pos = Vector3.new(0, 0.17, 0) },
				},
			},
			{
				time = 0.3438,
				pose = {
					Root = {
						rot = Vector3.new(2.32, -2.86, 0.1),
						pos = Vector3.new(-0.03, -0.16, 0.02),
					},
					Neck = { rot = Vector3.new(-2.28, 2.96, -0.12) },
					RightShoulder = { rot = Vector3.new(-15.68, 0, 16.08) },
					LeftShoulder = { rot = Vector3.new(18.01, 0, -11.72) },
					RightHip = { rot = Vector3.new(23.22, 0, -1.83), pos = Vector3.new(0, 0.17, 0) },
					LeftHip = { rot = Vector3.new(-25.9, 0, 3.42), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = {
						rot = Vector3.new(2.36, -2.69, 0.74),
						pos = Vector3.new(-0.03, -0.16, 0.02),
					},
					Neck = { rot = Vector3.new(-2.28, 2.82, -0.78) },
					RightShoulder = { rot = Vector3.new(-16.8, 0, 15.78) },
					LeftShoulder = { rot = Vector3.new(18.74, 0, -11.11) },
					RightHip = { rot = Vector3.new(22.8, 0, -2.45), pos = Vector3.new(0, 0.16, 0) },
					LeftHip = { rot = Vector3.new(-22.75, 0, 2.56), pos = Vector3.new(0, 0.21, 0) },
				},
			},
			{
				time = 0.4062,
				pose = {
					Root = {
						rot = Vector3.new(2.38, -2.42, 1.24),
						pos = Vector3.new(-0.04, -0.15, 0.01),
					},
					Neck = { rot = Vector3.new(-2.28, 2.57, -1.3) },
					RightShoulder = { rot = Vector3.new(-16.8, 0, 15.57) },
					LeftShoulder = { rot = Vector3.new(18.63, 0, -10.89) },
					RightHip = { rot = Vector3.new(19.19, 0, -2.74), pos = Vector3.new(0, 0.16, 0) },
					LeftHip = { rot = Vector3.new(-19.79, 0, 1.83), pos = Vector3.new(0, 0.21, 0) },
				},
			},
			{
				time = 0.4375,
				pose = {
					Root = {
						rot = Vector3.new(2.38, -2.05, 1.65),
						pos = Vector3.new(-0.04, -0.13, 0),
					},
					Neck = { rot = Vector3.new(-2.28, 2.22, -1.73) },
					RightShoulder = { rot = Vector3.new(-15.97, 0, 15.62) },
					LeftShoulder = { rot = Vector3.new(17.82, 0, -11.08) },
					RightHip = { rot = Vector3.new(13.62, 0, -3.11), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(-16.73, 0, 1.18), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.4688,
				pose = {
					Root = {
						rot = Vector3.new(2.36, -1.6, 1.98),
						pos = Vector3.new(-0.04, -0.1, 0),
					},
					Neck = { rot = Vector3.new(-2.28, 1.78, -2.07) },
					RightShoulder = { rot = Vector3.new(-14.4, 0, 15.89) },
					LeftShoulder = { rot = Vector3.new(16.37, 0, -11.58) },
					RightHip = { rot = Vector3.new(6.46, 0, -3.77), pos = Vector3.new(0, 0.14, 0) },
					LeftHip = { rot = Vector3.new(-13.63, 0, 0.62), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(2.33, -1.08, 2.22),
						pos = Vector3.new(-0.04, -0.07, -0.01),
					},
					Neck = { rot = Vector3.new(-2.28, 1.26, -2.33) },
					RightShoulder = { rot = Vector3.new(-12.17, 0, 16.26) },
					LeftShoulder = { rot = Vector3.new(14.38, 0, -12.27) },
					RightHip = { rot = Vector3.new(-1.99, 0, -3.97), pos = Vector3.new(0, 0.19, 0) },
					LeftHip = { rot = Vector3.new(-10.51, 0, 0.16), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.5312,
				pose = {
					Root = {
						rot = Vector3.new(2.29, -0.52, 2.38),
						pos = Vector3.new(-0.04, -0.05, -0.01),
					},
					Neck = { rot = Vector3.new(-2.28, 0.69, -2.49) },
					RightShoulder = { rot = Vector3.new(-9.39, 0, 16.61) },
					LeftShoulder = { rot = Vector3.new(11.94, 0, -13.04) },
					RightHip = {
						rot = Vector3.new(-10.24, 0, -4.34),
						pos = Vector3.new(0, 0.21, 0),
					},
					LeftHip = { rot = Vector3.new(-7.33, 0, -0.19), pos = Vector3.new(0, 0.12, 0) },
				},
			},
			{
				time = 0.5625,
				pose = {
					Root = {
						rot = Vector3.new(2.25, 0.08, 2.47),
						pos = Vector3.new(-0.03, -0.04, -0.01),
					},
					Neck = { rot = Vector3.new(-2.28, 0.08, -2.58) },
					RightShoulder = { rot = Vector3.new(-6.18, 0, 16.86) },
					LeftShoulder = { rot = Vector3.new(9.14, 0, -13.78) },
					RightHip = {
						rot = Vector3.new(-18.21, 0, -4.82),
						pos = Vector3.new(0, 0.18, 0),
					},
					LeftHip = { rot = Vector3.new(-4.08, 0, -0.34), pos = Vector3.new(0, 0.09, 0) },
				},
			},
			{
				time = 0.5938,
				pose = {
					Root = {
						rot = Vector3.new(2.21, 0.67, 2.5),
						pos = Vector3.new(-0.03, -0.04, -0.01),
					},
					Neck = { rot = Vector3.new(-2.28, -0.53, -2.6) },
					RightShoulder = { rot = Vector3.new(-2.69, 0, 16.89) },
					LeftShoulder = { rot = Vector3.new(6.1, 0, -14.43) },
					RightHip = {
						rot = Vector3.new(-25.04, 0, -5.34),
						pos = Vector3.new(0, 0.11, 0),
					},
					LeftHip = { rot = Vector3.new(-0.84, 0, -0.5), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = {
						rot = Vector3.new(2.17, 1.24, 2.46),
						pos = Vector3.new(-0.02, -0.05, -0.01),
					},
					Neck = { rot = Vector3.new(-2.27, -1.12, -2.55) },
					RightShoulder = { rot = Vector3.new(0.94, 0, 16.67) },
					LeftShoulder = { rot = Vector3.new(2.96, 0, -14.93) },
					RightHip = {
						rot = Vector3.new(-30.08, 0, -5.79),
						pos = Vector3.new(0, 0.03, 0),
					},
					LeftHip = { rot = Vector3.new(2.56, 0, -0.74), pos = Vector3.new(0, 0.12, 0) },
				},
			},
			{
				time = 0.6562,
				pose = {
					Root = {
						rot = Vector3.new(2.15, 1.76, 2.35),
						pos = Vector3.new(-0.01, -0.08, -0.01),
					},
					Neck = { rot = Vector3.new(-2.27, -1.67, -2.43) },
					RightShoulder = { rot = Vector3.new(4.53, 0, 16.18) },
					LeftShoulder = { rot = Vector3.new(-0.2, 0, -15.37) },
					RightHip = { rot = Vector3.new(-33.21, 0, -6.02) },
					LeftHip = { rot = Vector3.new(6.12, 0, -0.78), pos = Vector3.new(0, 0.16, 0) },
				},
			},
			{
				time = 0.6875,
				pose = {
					Root = {
						rot = Vector3.new(2.13, 2.2, 2.16),
						pos = Vector3.new(-0.01, -0.11, 0),
					},
					Neck = { rot = Vector3.new(-2.27, -2.14, -2.22) },
					RightShoulder = { rot = Vector3.new(7.95, 0, 15.46) },
					LeftShoulder = { rot = Vector3.new(-3.45, 0, -15.8) },
					RightHip = {
						rot = Vector3.new(-33.77, 0, -6.11),
						pos = Vector3.new(0, 0.03, 0),
					},
					LeftHip = { rot = Vector3.new(9.78, 0, -0.69), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.7188,
				pose = {
					Root = {
						rot = Vector3.new(2.12, 2.55, 1.87),
						pos = Vector3.new(0, -0.14, 0.01),
					},
					Neck = { rot = Vector3.new(-2.26, -2.52, -1.91) },
					RightShoulder = { rot = Vector3.new(11.04, 0, 14.57) },
					LeftShoulder = { rot = Vector3.new(-6.73, 0, -16.18) },
					RightHip = { rot = Vector3.new(-32.96, 0, -6), pos = Vector3.new(0, 0.07, 0) },
					LeftHip = { rot = Vector3.new(13.37, 0, -0.42), pos = Vector3.new(0, 0.22, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(2.12, 2.79, 1.45),
						pos = Vector3.new(0.01, -0.15, 0.01),
					},
					Neck = { rot = Vector3.new(-2.25, -2.8, -1.47) },
					RightShoulder = { rot = Vector3.new(13.72, 0, 13.61) },
					LeftShoulder = { rot = Vector3.new(-9.86, 0, -16.41) },
					RightHip = {
						rot = Vector3.new(-31.57, 0, -5.55),
						pos = Vector3.new(0, 0.11, 0),
					},
					LeftHip = { rot = Vector3.new(16.68, 0, 0.02), pos = Vector3.new(0, 0.22, 0) },
				},
			},
			{
				time = 0.7812,
				pose = {
					Root = {
						rot = Vector3.new(2.14, 2.91, 0.89),
						pos = Vector3.new(0.02, -0.16, 0.02),
					},
					Neck = { rot = Vector3.new(-2.24, -2.96, -0.88) },
					RightShoulder = { rot = Vector3.new(15.89, 0, 12.67) },
					LeftShoulder = { rot = Vector3.new(-12.65, 0, -16.45) },
					RightHip = {
						rot = Vector3.new(-29.58, 0, -4.75),
						pos = Vector3.new(0, 0.14, 0),
					},
					LeftHip = { rot = Vector3.new(19.7, 0, 0.66), pos = Vector3.new(0, 0.21, 0) },
				},
			},
			{
				time = 0.8125,
				pose = {
					Root = {
						rot = Vector3.new(2.17, 2.91, 0.23),
						pos = Vector3.new(0.03, -0.17, 0.02),
					},
					Neck = { rot = Vector3.new(-2.24, -3, -0.2) },
					RightShoulder = { rot = Vector3.new(17.49, 0, 11.85) },
					LeftShoulder = { rot = Vector3.new(-14.9, 0, -16.33) },
					RightHip = {
						rot = Vector3.new(-27.12, 0, -3.75),
						pos = Vector3.new(0, 0.17, 0),
					},
					LeftHip = { rot = Vector3.new(22.59, 0, 1.5), pos = Vector3.new(0, 0.19, 0) },
				},
			},
			{
				time = 0.8438,
				pose = {
					Root = {
						rot = Vector3.new(2.2, 2.8, -0.4),
						pos = Vector3.new(0.03, -0.16, 0.02),
					},
					Neck = { rot = Vector3.new(-2.23, -2.92, 0.46) },
					RightShoulder = { rot = Vector3.new(18.48, 0, 11.18) },
					LeftShoulder = { rot = Vector3.new(-16.38, 0, -16.1) },
					RightHip = { rot = Vector3.new(-24.23, 0, -2.87), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(23.74, 0, 2.2), pos = Vector3.new(0, 0.16, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = {
						rot = Vector3.new(2.22, 2.58, -0.95),
						pos = Vector3.new(0.04, -0.15, 0.01),
					},
					Neck = { rot = Vector3.new(-2.23, -2.73, 1.03) },
					RightShoulder = { rot = Vector3.new(18.79, 0, 10.75) },
					LeftShoulder = { rot = Vector3.new(-16.91, 0, -15.81) },
					RightHip = {
						rot = Vector3.new(-21.23, 0, -2.13),
						pos = Vector3.new(0, 0.21, 0),
					},
					LeftHip = { rot = Vector3.new(21.65, 0, 2.6), pos = Vector3.new(0, 0.16, 0) },
				},
			},
			{
				time = 0.9062,
				pose = {
					Root = {
						rot = Vector3.new(2.24, 2.27, -1.42),
						pos = Vector3.new(0.04, -0.14, 0.01),
					},
					Neck = { rot = Vector3.new(-2.23, -2.43, 1.51) },
					RightShoulder = { rot = Vector3.new(18.36, 0, 10.72) },
					LeftShoulder = { rot = Vector3.new(-16.53, 0, -15.71) },
					RightHip = {
						rot = Vector3.new(-18.23, 0, -1.43),
						pos = Vector3.new(0, 0.21, 0),
					},
					LeftHip = { rot = Vector3.new(17.07, 0, 2.94), pos = Vector3.new(0, 0.16, 0) },
				},
			},
			{
				time = 0.9375,
				pose = {
					Root = {
						rot = Vector3.new(2.24, 1.86, -1.8),
						pos = Vector3.new(0.04, -0.12, 0),
					},
					Neck = { rot = Vector3.new(-2.23, -2.03, 1.9) },
					RightShoulder = { rot = Vector3.new(17.24, 0, 11.07) },
					LeftShoulder = { rot = Vector3.new(-15.35, 0, -15.88) },
					RightHip = { rot = Vector3.new(-15.15, 0, -0.84), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(10.78, 0, 3.58), pos = Vector3.new(0, 0.14, 0) },
				},
			},
			{
				time = 0.9688,
				pose = {
					Root = {
						rot = Vector3.new(2.23, 1.38, -2.09),
						pos = Vector3.new(0.04, -0.09, 0),
					},
					Neck = { rot = Vector3.new(-2.24, -1.55, 2.21) },
					RightShoulder = { rot = Vector3.new(15.54, 0, 11.67) },
					LeftShoulder = { rot = Vector3.new(-13.47, 0, -16.21) },
					RightHip = {
						rot = Vector3.new(-12.06, 0, -0.35),
						pos = Vector3.new(0, 0.17, 0),
					},
					LeftHip = { rot = Vector3.new(2.88, 0, 4.09), pos = Vector3.new(0, 0.16, 0) },
				},
			},
		},
	},
	-- ALS_N_Walk_LF: phase clip (one cycle = 1), left foot plants at 0.4375; natural cycle 1.167 s, stride 3.40 studs per cycle
	WalkLeft = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-4.78, 34.2, 3.31),
						pos = Vector3.new(0, -0.18, -0.01),
					},
					Neck = { rot = Vector3.new(3.48, -34.32, -0.93) },
					RightShoulder = { rot = Vector3.new(-2.6, 0, 17.96) },
					LeftShoulder = { rot = Vector3.new(16.48, 0, -19.63) },
					RightHip = {
						rot = Vector3.new(12.21, 0, -16.07),
						pos = Vector3.new(0, 0.14, 0),
					},
					LeftHip = { rot = Vector3.new(-7.95, 0, 19.25), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 0.0312,
				pose = {
					Root = {
						rot = Vector3.new(-4.91, 34.35, 3.02),
						pos = Vector3.new(0, -0.17, -0.01),
					},
					Neck = { rot = Vector3.new(3.83, -34.46, -0.47) },
					RightShoulder = { rot = Vector3.new(0.39, 0, 18.48) },
					LeftShoulder = { rot = Vector3.new(14.54, 0, -21.17) },
					RightHip = {
						rot = Vector3.new(10.22, 0, -12.99),
						pos = Vector3.new(0, 0.14, 0),
					},
					LeftHip = { rot = Vector3.new(-7.66, 0, 20.17), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.0625,
				pose = {
					Root = {
						rot = Vector3.new(-5, 34.61, 2.85),
						pos = Vector3.new(0, -0.15, -0.01),
					},
					Neck = { rot = Vector3.new(4.06, -34.72, -0.15) },
					RightShoulder = { rot = Vector3.new(3.64, 0, 18.81) },
					LeftShoulder = { rot = Vector3.new(12.28, 0, -22.64) },
					RightHip = { rot = Vector3.new(8.26, 0, -10.02), pos = Vector3.new(0, 0.14, 0) },
					LeftHip = { rot = Vector3.new(-6.94, 0, 19.35), pos = Vector3.new(0, 0.09, 0) },
				},
			},
			{
				time = 0.0938,
				pose = {
					Root = {
						rot = Vector3.new(-5.06, 34.96, 2.76),
						pos = Vector3.new(0, -0.12, -0.02),
					},
					Neck = { rot = Vector3.new(4.2, -35.08, 0.06) },
					RightShoulder = { rot = Vector3.new(7.06, 0, 18.91) },
					LeftShoulder = { rot = Vector3.new(9.81, 0, -23.94) },
					RightHip = { rot = Vector3.new(6.36, 0, -7.2), pos = Vector3.new(0, 0.12, 0) },
					LeftHip = { rot = Vector3.new(-5.12, 0, 16.17), pos = Vector3.new(0, 0.16, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = {
						rot = Vector3.new(-5.1, 35.4, 2.73),
						pos = Vector3.new(0, -0.1, -0.02),
					},
					Neck = { rot = Vector3.new(4.27, -35.53, 0.18) },
					RightShoulder = { rot = Vector3.new(10.49, 0, 18.77) },
					LeftShoulder = { rot = Vector3.new(7.23, 0, -25.02) },
					RightHip = { rot = Vector3.new(4.48, 0, -4.51), pos = Vector3.new(0, 0.09, 0) },
					LeftHip = { rot = Vector3.new(-2.59, 0, 11.63), pos = Vector3.new(0, 0.23, 0) },
				},
			},
			{
				time = 0.1562,
				pose = {
					Root = {
						rot = Vector3.new(-5.11, 35.92, 2.77),
						pos = Vector3.new(-0.01, -0.08, -0.02),
					},
					Neck = { rot = Vector3.new(4.28, -36.05, 0.22) },
					RightShoulder = { rot = Vector3.new(13.78, 0, 18.39) },
					LeftShoulder = { rot = Vector3.new(4.67, 0, -25.88) },
					RightHip = { rot = Vector3.new(2.84, 0, -1.82), pos = Vector3.new(0, 0.09, 0) },
					LeftHip = { rot = Vector3.new(1.23, 0, 5.94), pos = Vector3.new(0, 0.28, 0) },
				},
			},
			{
				time = 0.1875,
				pose = {
					Root = {
						rot = Vector3.new(-5.1, 36.47, 2.86),
						pos = Vector3.new(-0.01, -0.06, -0.02),
					},
					Neck = { rot = Vector3.new(4.22, -36.62, 0.17) },
					RightShoulder = { rot = Vector3.new(16.77, 0, 17.84) },
					LeftShoulder = { rot = Vector3.new(2.25, 0, -26.52) },
					RightHip = { rot = Vector3.new(0.59, 0, 0.64), pos = Vector3.new(0, 0.09, 0) },
					LeftHip = { rot = Vector3.new(5.5, 0, -0.01), pos = Vector3.new(0, 0.27, 0) },
				},
			},
			{
				time = 0.2188,
				pose = {
					Root = {
						rot = Vector3.new(-5.08, 37.06, 3.02),
						pos = Vector3.new(-0.01, -0.06, -0.02),
					},
					Neck = { rot = Vector3.new(4.09, -37.22, 0.03) },
					RightShoulder = { rot = Vector3.new(19.35, 0, 17.22) },
					LeftShoulder = { rot = Vector3.new(0.1, 0, -27) },
					RightHip = { rot = Vector3.new(-1.42, 0, 2.58), pos = Vector3.new(0, 0.14, 0) },
					LeftHip = { rot = Vector3.new(10.28, 0, -5.9), pos = Vector3.new(0, 0.24, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(-5.04, 37.64, 3.24),
						pos = Vector3.new(-0.02, -0.07, -0.02),
					},
					Neck = { rot = Vector3.new(3.89, -37.82, -0.21) },
					RightShoulder = { rot = Vector3.new(21.42, 0, 16.69) },
					LeftShoulder = { rot = Vector3.new(-1.64, 0, -27.38) },
					RightHip = { rot = Vector3.new(-3.49, 0, 4.78), pos = Vector3.new(0, 0.19, 0) },
					LeftHip = { rot = Vector3.new(14.75, 0, -10.95), pos = Vector3.new(0, 0.27, 0) },
				},
			},
			{
				time = 0.2812,
				pose = {
					Root = {
						rot = Vector3.new(-4.99, 38.19, 3.53),
						pos = Vector3.new(-0.02, -0.09, -0.02),
					},
					Neck = { rot = Vector3.new(3.61, -38.4, -0.55) },
					RightShoulder = { rot = Vector3.new(22.91, 0, 16.37) },
					LeftShoulder = { rot = Vector3.new(-2.88, 0, -27.71) },
					RightHip = { rot = Vector3.new(-5.54, 0, 6.84), pos = Vector3.new(0, 0.24, 0) },
					LeftHip = { rot = Vector3.new(18.34, 0, -14.89), pos = Vector3.new(0, 0.33, 0) },
				},
			},
			{
				time = 0.3125,
				pose = {
					Root = {
						rot = Vector3.new(-4.93, 38.7, 3.88),
						pos = Vector3.new(-0.02, -0.13, -0.01),
					},
					Neck = { rot = Vector3.new(3.26, -38.92, -1.01) },
					RightShoulder = { rot = Vector3.new(23.66, 0, 16.42) },
					LeftShoulder = { rot = Vector3.new(-3.47, 0, -28.06) },
					RightHip = { rot = Vector3.new(-7.5, 0, 8.96), pos = Vector3.new(0, 0.3, 0) },
					LeftHip = { rot = Vector3.new(21.08, 0, -17.84), pos = Vector3.new(0, 0.38, 0) },
				},
			},
			{
				time = 0.3438,
				pose = {
					Root = {
						rot = Vector3.new(-4.87, 39.13, 4.27),
						pos = Vector3.new(-0.03, -0.15, -0.01),
					},
					Neck = { rot = Vector3.new(2.86, -39.36, -1.53) },
					RightShoulder = { rot = Vector3.new(23.68, 0, 16.83) },
					LeftShoulder = { rot = Vector3.new(-3.47, 0, -28.33) },
					RightHip = { rot = Vector3.new(-9.31, 0, 11.03), pos = Vector3.new(0, 0.35, 0) },
					LeftHip = { rot = Vector3.new(22.78, 0, -19.52), pos = Vector3.new(0, 0.42, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = {
						rot = Vector3.new(-4.79, 39.5, 4.76),
						pos = Vector3.new(-0.03, -0.18, 0),
					},
					Neck = { rot = Vector3.new(2.33, -39.74, -2.21) },
					RightShoulder = { rot = Vector3.new(22.73, 0, 17.56) },
					LeftShoulder = { rot = Vector3.new(-2.81, 0, -28.3) },
					RightHip = {
						rot = Vector3.new(-11.07, 0, 13.06),
						pos = Vector3.new(0, 0.38, 0),
					},
					LeftHip = { rot = Vector3.new(22.47, 0, -19.04), pos = Vector3.new(0, 0.44, 0) },
				},
			},
			{
				time = 0.4062,
				pose = {
					Root = {
						rot = Vector3.new(-4.79, 39.52, 4.79),
						pos = Vector3.new(-0.03, -0.18, 0),
					},
					Neck = { rot = Vector3.new(2.3, -39.76, -2.26) },
					RightShoulder = { rot = Vector3.new(22.67, 0, 17.6) },
					LeftShoulder = { rot = Vector3.new(-2.77, 0, -28.29) },
					RightHip = { rot = Vector3.new(-11.19, 0, 13.2), pos = Vector3.new(0, 0.38, 0) },
					LeftHip = { rot = Vector3.new(22.44, 0, -18.98), pos = Vector3.new(0, 0.44, 0) },
				},
			},
			{
				time = 0.4375,
				pose = {
					Root = {
						rot = Vector3.new(-4.71, 39.74, 5.24),
						pos = Vector3.new(-0.03, -0.19, 0),
					},
					Neck = { rot = Vector3.new(1.8, -39.98, -2.91) },
					RightShoulder = { rot = Vector3.new(21.17, 0, 18.3) },
					LeftShoulder = { rot = Vector3.new(-1.76, 0, -28) },
					RightHip = {
						rot = Vector3.new(-12.25, 0, 14.45),
						pos = Vector3.new(0, 0.39, 0),
					},
					LeftHip = { rot = Vector3.new(21.01, 0, -17.51), pos = Vector3.new(0, 0.45, 0) },
				},
			},
			{
				time = 0.4688,
				pose = {
					Root = {
						rot = Vector3.new(-4.6, 39.88, 5.75),
						pos = Vector3.new(-0.04, -0.19, 0.01),
					},
					Neck = { rot = Vector3.new(1.22, -40.11, -3.67) },
					RightShoulder = { rot = Vector3.new(18.95, 0, 19.01) },
					LeftShoulder = { rot = Vector3.new(-0.29, 0, -27.48) },
					RightHip = { rot = Vector3.new(-13, 0, 15.57), pos = Vector3.new(0, 0.4, 0) },
					LeftHip = { rot = Vector3.new(19.43, 0, -16.12), pos = Vector3.new(0, 0.45, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-4.49, 39.91, 6.23),
						pos = Vector3.new(-0.04, -0.19, 0.01),
					},
					Neck = { rot = Vector3.new(0.64, -40.13, -4.41) },
					RightShoulder = { rot = Vector3.new(16.18, 0, 19.58) },
					LeftShoulder = { rot = Vector3.new(1.52, 0, -26.74) },
					RightHip = {
						rot = Vector3.new(-13.35, 0, 16.72),
						pos = Vector3.new(0, 0.39, 0),
					},
					LeftHip = { rot = Vector3.new(17.71, 0, -14.55), pos = Vector3.new(0, 0.44, 0) },
				},
			},
			{
				time = 0.5312,
				pose = {
					Root = {
						rot = Vector3.new(-4.38, 39.83, 6.59),
						pos = Vector3.new(-0.04, -0.17, 0.02),
					},
					Neck = { rot = Vector3.new(0.19, -40.02, -5) },
					RightShoulder = { rot = Vector3.new(13, 0, 19.94) },
					LeftShoulder = { rot = Vector3.new(3.6, 0, -25.74) },
					RightHip = {
						rot = Vector3.new(-13.37, 0, 17.96),
						pos = Vector3.new(0, 0.38, 0),
					},
					LeftHip = { rot = Vector3.new(15.83, 0, -12.8), pos = Vector3.new(0, 0.42, 0) },
				},
			},
			{
				time = 0.5625,
				pose = {
					Root = {
						rot = Vector3.new(-4.29, 39.63, 6.82),
						pos = Vector3.new(-0.04, -0.16, 0.02),
					},
					Neck = { rot = Vector3.new(-0.11, -39.8, -5.4) },
					RightShoulder = { rot = Vector3.new(9.55, 0, 20.05) },
					LeftShoulder = { rot = Vector3.new(5.9, 0, -24.51) },
					RightHip = {
						rot = Vector3.new(-12.72, 0, 18.11),
						pos = Vector3.new(0, 0.36, 0),
					},
					LeftHip = { rot = Vector3.new(13.87, 0, -10.93), pos = Vector3.new(0, 0.38, 0) },
				},
			},
			{
				time = 0.5938,
				pose = {
					Root = {
						rot = Vector3.new(-4.21, 39.33, 6.94),
						pos = Vector3.new(-0.04, -0.13, 0.02),
					},
					Neck = { rot = Vector3.new(-0.29, -39.48, -5.64) },
					RightShoulder = { rot = Vector3.new(6, 0, 19.83) },
					LeftShoulder = { rot = Vector3.new(8.32, 0, -23.1) },
					RightHip = {
						rot = Vector3.new(-10.86, 0, 15.83),
						pos = Vector3.new(0, 0.33, 0),
					},
					LeftHip = { rot = Vector3.new(11.96, 0, -8.99), pos = Vector3.new(0, 0.33, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = {
						rot = Vector3.new(-4.12, 38.93, 6.97),
						pos = Vector3.new(-0.03, -0.11, 0.03),
					},
					Neck = { rot = Vector3.new(-0.38, -39.07, -5.77) },
					RightShoulder = { rot = Vector3.new(2.49, 0, 19.31) },
					LeftShoulder = { rot = Vector3.new(10.73, 0, -21.53) },
					RightHip = { rot = Vector3.new(-7.99, 0, 11.82), pos = Vector3.new(0, 0.29, 0) },
					LeftHip = { rot = Vector3.new(10.04, 0, -7), pos = Vector3.new(0, 0.27, 0) },
				},
			},
			{
				time = 0.6562,
				pose = {
					Root = {
						rot = Vector3.new(-4.05, 38.45, 6.93),
						pos = Vector3.new(-0.03, -0.09, 0.03),
					},
					Neck = { rot = Vector3.new(-0.4, -38.58, -5.8) },
					RightShoulder = { rot = Vector3.new(-0.81, 0, 18.51) },
					LeftShoulder = { rot = Vector3.new(13.01, 0, -19.87) },
					RightHip = { rot = Vector3.new(-3.7, 0, 6.18), pos = Vector3.new(0, 0.27, 0) },
					LeftHip = { rot = Vector3.new(8.11, 0, -5), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.6875,
				pose = {
					Root = {
						rot = Vector3.new(-3.98, 37.91, 6.83),
						pos = Vector3.new(-0.03, -0.07, 0.03),
					},
					Neck = { rot = Vector3.new(-0.33, -38.03, -5.73) },
					RightShoulder = { rot = Vector3.new(-3.78, 0, 17.55) },
					LeftShoulder = { rot = Vector3.new(15.06, 0, -18.2) },
					RightHip = { rot = Vector3.new(1.29, 0, -0.55), pos = Vector3.new(0, 0.21, 0) },
					LeftHip = { rot = Vector3.new(5.99, 0, -3.28), pos = Vector3.new(0, 0.16, 0) },
				},
			},
			{
				time = 0.7188,
				pose = {
					Root = {
						rot = Vector3.new(-3.93, 37.34, 6.66),
						pos = Vector3.new(-0.02, -0.06, 0.03),
					},
					Neck = { rot = Vector3.new(-0.2, -37.45, -5.58) },
					RightShoulder = { rot = Vector3.new(-6.33, 0, 16.55) },
					LeftShoulder = { rot = Vector3.new(16.82, 0, -16.62) },
					RightHip = { rot = Vector3.new(6.46, 0, -7.9), pos = Vector3.new(0, 0.09, 0) },
					LeftHip = { rot = Vector3.new(3.71, 0, -1.08), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(-3.9, 36.74, 6.44),
						pos = Vector3.new(-0.02, -0.06, 0.03),
					},
					Neck = { rot = Vector3.new(0.01, -36.86, -5.33) },
					RightShoulder = { rot = Vector3.new(-8.37, 0, 15.66) },
					LeftShoulder = { rot = Vector3.new(18.28, 0, -15.26) },
					RightHip = { rot = Vector3.new(11.38, 0, -14.84), pos = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(1.99, 0, 1.03), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 0.7812,
				pose = {
					Root = {
						rot = Vector3.new(-3.9, 36.17, 6.16),
						pos = Vector3.new(-0.01, -0.08, 0.02),
					},
					Neck = { rot = Vector3.new(0.28, -36.28, -4.99) },
					RightShoulder = { rot = Vector3.new(-9.85, 0, 15.01) },
					LeftShoulder = { rot = Vector3.new(19.4, 0, -14.24) },
					RightHip = { rot = Vector3.new(15.2, 0, -19.42) },
					LeftHip = { rot = Vector3.new(0.07, 0, 3.1), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.8125,
				pose = {
					Root = {
						rot = Vector3.new(-3.94, 35.62, 5.83),
						pos = Vector3.new(-0.01, -0.11, 0.02),
					},
					Neck = { rot = Vector3.new(0.63, -35.75, -4.57) },
					RightShoulder = { rot = Vector3.new(-10.73, 0, 14.73) },
					LeftShoulder = { rot = Vector3.new(20.17, 0, -13.72) },
					RightHip = { rot = Vector3.new(17.34, 0, -23.3) },
					LeftHip = { rot = Vector3.new(-1.84, 0, 5.39), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 0.8438,
				pose = {
					Root = {
						rot = Vector3.new(-4.02, 35.15, 5.46),
						pos = Vector3.new(-0.01, -0.14, 0.02),
					},
					Neck = { rot = Vector3.new(1.02, -35.28, -4.08) },
					RightShoulder = { rot = Vector3.new(-10.93, 0, 14.9) },
					LeftShoulder = { rot = Vector3.new(20.52, 0, -13.81) },
					RightHip = { rot = Vector3.new(18.62, 0, -25.59) },
					LeftHip = { rot = Vector3.new(-4.07, 0, 8.35), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = {
						rot = Vector3.new(-4.12, 34.75, 5.05),
						pos = Vector3.new(0, -0.17, 0.01),
					},
					Neck = { rot = Vector3.new(1.46, -34.88, -3.52) },
					RightShoulder = { rot = Vector3.new(-10.43, 0, 15.35) },
					LeftShoulder = { rot = Vector3.new(20.48, 0, -14.42) },
					RightHip = { rot = Vector3.new(18.65, 0, -26.75) },
					LeftHip = { rot = Vector3.new(-5.69, 0, 10.87), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.9062,
				pose = {
					Root = {
						rot = Vector3.new(-4.26, 34.45, 4.63),
						pos = Vector3.new(0, -0.18, 0.01),
					},
					Neck = { rot = Vector3.new(1.94, -34.59, -2.92) },
					RightShoulder = { rot = Vector3.new(-9.26, 0, 15.91) },
					LeftShoulder = { rot = Vector3.new(20.06, 0, -15.4) },
					RightHip = {
						rot = Vector3.new(17.03, 0, -24.92),
						pos = Vector3.new(0, 0.04, 0),
					},
					LeftHip = { rot = Vector3.new(-6.94, 0, 13.51), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.9375,
				pose = {
					Root = { rot = Vector3.new(-4.43, 34.25, 4.18), pos = Vector3.new(0, -0.19, 0) },
					Neck = { rot = Vector3.new(2.46, -34.39, -2.25) },
					RightShoulder = { rot = Vector3.new(-7.52, 0, 16.58) },
					LeftShoulder = { rot = Vector3.new(19.26, 0, -16.67) },
					RightHip = {
						rot = Vector3.new(15.33, 0, -21.68),
						pos = Vector3.new(0, 0.09, 0),
					},
					LeftHip = { rot = Vector3.new(-7.71, 0, 15.83), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 0.9688,
				pose = {
					Root = { rot = Vector3.new(-4.61, 34.17, 3.71), pos = Vector3.new(0, -0.19, 0) },
					Neck = { rot = Vector3.new(3, -34.3, -1.56) },
					RightShoulder = { rot = Vector3.new(-5.27, 0, 17.3) },
					LeftShoulder = { rot = Vector3.new(18.07, 0, -18.1) },
					RightHip = {
						rot = Vector3.new(13.93, 0, -19.02),
						pos = Vector3.new(0, 0.12, 0),
					},
					LeftHip = { rot = Vector3.new(-8.02, 0, 17.73), pos = Vector3.new(0, 0.16, 0) },
				},
			},
		},
	},
	-- ALS_N_Walk_RF: phase clip (one cycle = 1), left foot plants at 0.4375; natural cycle 1.167 s, stride 3.34 studs per cycle
	WalkRight = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-4.41, -39.77, -6.83),
						pos = Vector3.new(0.04, -0.17, 0.02),
					},
					Neck = { rot = Vector3.new(0.09, 39.97, 5.19) },
					RightShoulder = { rot = Vector3.new(4.44, 0, 25.17) },
					LeftShoulder = { rot = Vector3.new(11.73, 0, -20.18) },
					RightHip = { rot = Vector3.new(15.08, 0, 12.36), pos = Vector3.new(0, 0.41, 0) },
					LeftHip = {
						rot = Vector3.new(-13.18, 0, -18.13),
						pos = Vector3.new(0, 0.37, 0),
					},
				},
			},
			{
				time = 0.0312,
				pose = {
					Root = {
						rot = Vector3.new(-4.34, -39.53, -7.02),
						pos = Vector3.new(0.04, -0.15, 0.02),
					},
					Neck = { rot = Vector3.new(-0.16, 39.72, 5.53) },
					RightShoulder = { rot = Vector3.new(6.79, 0, 23.86) },
					LeftShoulder = { rot = Vector3.new(8.23, 0, -20.17) },
					RightHip = { rot = Vector3.new(13.16, 0, 10.46), pos = Vector3.new(0, 0.36, 0) },
					LeftHip = { rot = Vector3.new(-12.07, 0, -17.3), pos = Vector3.new(0, 0.35, 0) },
				},
			},
			{
				time = 0.0625,
				pose = {
					Root = {
						rot = Vector3.new(-4.28, -39.18, -7.11),
						pos = Vector3.new(0.03, -0.13, 0.02),
					},
					Neck = { rot = Vector3.new(-0.3, 39.36, 5.72) },
					RightShoulder = { rot = Vector3.new(9.22, 0, 22.38) },
					LeftShoulder = { rot = Vector3.new(4.68, 0, -19.83) },
					RightHip = { rot = Vector3.new(11.28, 0, 8.46), pos = Vector3.new(0, 0.31, 0) },
					LeftHip = { rot = Vector3.new(-9.75, 0, -14.35), pos = Vector3.new(0, 0.31, 0) },
				},
			},
			{
				time = 0.0938,
				pose = {
					Root = {
						rot = Vector3.new(-4.21, -38.75, -7.11),
						pos = Vector3.new(0.03, -0.1, 0.03),
					},
					Neck = { rot = Vector3.new(-0.35, 38.91, 5.81) },
					RightShoulder = { rot = Vector3.new(11.6, 0, 20.77) },
					LeftShoulder = { rot = Vector3.new(1.23, 0, -19.2) },
					RightHip = { rot = Vector3.new(9.39, 0, 6.43), pos = Vector3.new(0, 0.24, 0) },
					LeftHip = { rot = Vector3.new(-6.41, 0, -9.66), pos = Vector3.new(0, 0.28, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = {
						rot = Vector3.new(-4.15, -38.25, -7.04),
						pos = Vector3.new(0.03, -0.08, 0.03),
					},
					Neck = { rot = Vector3.new(-0.33, 38.4, 5.8) },
					RightShoulder = { rot = Vector3.new(13.8, 0, 19.09) },
					LeftShoulder = { rot = Vector3.new(-1.96, 0, -18.33) },
					RightHip = { rot = Vector3.new(7.47, 0, 4.45), pos = Vector3.new(0, 0.18, 0) },
					LeftHip = { rot = Vector3.new(-1.58, 0, -3.53), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.1562,
				pose = {
					Root = {
						rot = Vector3.new(-4.1, -37.69, -6.91),
						pos = Vector3.new(0.03, -0.06, 0.03),
					},
					Neck = { rot = Vector3.new(-0.23, 37.83, 5.7) },
					RightShoulder = { rot = Vector3.new(15.75, 0, 17.44) },
					LeftShoulder = { rot = Vector3.new(-4.78, 0, -17.33) },
					RightHip = { rot = Vector3.new(5.28, 0, 2.65), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(3.47, 0, 3.48), pos = Vector3.new(0, 0.17, 0) },
				},
			},
			{
				time = 0.1875,
				pose = {
					Root = {
						rot = Vector3.new(-4.07, -37.1, -6.72),
						pos = Vector3.new(0.02, -0.06, 0.03),
					},
					Neck = { rot = Vector3.new(-0.06, 37.24, 5.5) },
					RightShoulder = { rot = Vector3.new(17.4, 0, 15.92) },
					LeftShoulder = { rot = Vector3.new(-7.15, 0, -16.35) },
					RightHip = { rot = Vector3.new(3.17, 0, 0.31), pos = Vector3.new(0, 0.13, 0) },
					LeftHip = { rot = Vector3.new(8.67, 0, 10.87), pos = Vector3.new(0, 0.05, 0) },
				},
			},
			{
				time = 0.2188,
				pose = {
					Root = {
						rot = Vector3.new(-4.06, -36.51, -6.47),
						pos = Vector3.new(0.02, -0.07, 0.03),
					},
					Neck = { rot = Vector3.new(0.17, 36.65, 5.22) },
					RightShoulder = { rot = Vector3.new(18.74, 0, 14.67) },
					LeftShoulder = { rot = Vector3.new(-8.98, 0, -15.53) },
					RightHip = { rot = Vector3.new(1.31, 0, -1.91), pos = Vector3.new(0, 0.14, 0) },
					LeftHip = { rot = Vector3.new(13.24, 0, 16.87), pos = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(-4.07, -35.95, -6.17),
						pos = Vector3.new(0.01, -0.09, 0.02),
					},
					Neck = { rot = Vector3.new(0.48, 36.08, 4.86) },
					RightShoulder = { rot = Vector3.new(19.74, 0, 13.81) },
					LeftShoulder = { rot = Vector3.new(-10.25, 0, -15) },
					RightHip = { rot = Vector3.new(-0.82, 0, -4.2), pos = Vector3.new(0, 0.16, 0) },
					LeftHip = { rot = Vector3.new(16.37, 0, 21.02) },
				},
			},
			{
				time = 0.2812,
				pose = {
					Root = {
						rot = Vector3.new(-4.13, -35.43, -5.82),
						pos = Vector3.new(0.01, -0.12, 0.02),
					},
					Neck = { rot = Vector3.new(0.85, 35.57, 4.4) },
					RightShoulder = { rot = Vector3.new(20.35, 0, 13.52) },
					LeftShoulder = { rot = Vector3.new(-10.87, 0, -14.9) },
					RightHip = { rot = Vector3.new(-2.78, 0, -6.59), pos = Vector3.new(0, 0.19, 0) },
					LeftHip = { rot = Vector3.new(18.11, 0, 24.34) },
				},
			},
			{
				time = 0.3125,
				pose = {
					Root = {
						rot = Vector3.new(-4.2, -34.98, -5.45),
						pos = Vector3.new(0.01, -0.15, 0.02),
					},
					Neck = { rot = Vector3.new(1.25, 35.13, 3.91) },
					RightShoulder = { rot = Vector3.new(20.57, 0, 13.78) },
					LeftShoulder = { rot = Vector3.new(-10.86, 0, -15.19) },
					RightHip = { rot = Vector3.new(-4.56, 0, -8.95), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(19.14, 0, 26.38) },
				},
			},
			{
				time = 0.3438,
				pose = {
					Root = {
						rot = Vector3.new(-4.33, -34.59, -4.99),
						pos = Vector3.new(0, -0.17, 0.01),
					},
					Neck = { rot = Vector3.new(1.76, 34.75, 3.26) },
					RightShoulder = { rot = Vector3.new(20.32, 0, 14.68) },
					LeftShoulder = { rot = Vector3.new(-9.94, 0, -15.75) },
					RightHip = {
						rot = Vector3.new(-6.23, 0, -11.83),
						pos = Vector3.new(0, 0.21, 0),
					},
					LeftHip = { rot = Vector3.new(18.21, 0, 26.25), pos = Vector3.new(0, 0.01, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = {
						rot = Vector3.new(-4.35, -34.55, -4.94),
						pos = Vector3.new(0, -0.18, 0.01),
					},
					Neck = { rot = Vector3.new(1.82, 34.7, 3.18) },
					RightShoulder = { rot = Vector3.new(20.29, 0, 14.79) },
					LeftShoulder = { rot = Vector3.new(-9.82, 0, -15.82) },
					RightHip = {
						rot = Vector3.new(-6.43, 0, -12.18),
						pos = Vector3.new(0, 0.21, 0),
					},
					LeftHip = { rot = Vector3.new(18.04, 0, 26.29), pos = Vector3.new(0, 0.02, 0) },
				},
			},
			{
				time = 0.4062,
				pose = {
					Root = {
						rot = Vector3.new(-4.47, -34.34, -4.57),
						pos = Vector3.new(0, -0.19, 0.01),
					},
					Neck = { rot = Vector3.new(2.24, 34.5, 2.65) },
					RightShoulder = { rot = Vector3.new(19.76, 0, 15.77) },
					LeftShoulder = { rot = Vector3.new(-8.55, 0, -16.35) },
					RightHip = {
						rot = Vector3.new(-7.25, 0, -14.25),
						pos = Vector3.new(0, 0.19, 0),
					},
					LeftHip = { rot = Vector3.new(16.39, 0, 23.41), pos = Vector3.new(0, 0.06, 0) },
				},
			},
			{
				time = 0.4375,
				pose = {
					Root = { rot = Vector3.new(-4.63, -34.2, -4.1), pos = Vector3.new(0, -0.19, 0) },
					Neck = { rot = Vector3.new(2.78, 34.35, 1.95) },
					RightShoulder = { rot = Vector3.new(18.77, 0, 17.14) },
					LeftShoulder = { rot = Vector3.new(-6.54, 0, -17.06) },
					RightHip = { rot = Vector3.new(-7.85, 0, -16.4), pos = Vector3.new(0, 0.18, 0) },
					LeftHip = { rot = Vector3.new(14.91, 0, 20.63), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.4688,
				pose = {
					Root = {
						rot = Vector3.new(-4.8, -34.17, -3.65),
						pos = Vector3.new(0, -0.19, 0),
					},
					Neck = { rot = Vector3.new(3.29, 34.32, 1.27) },
					RightShoulder = { rot = Vector3.new(17.4, 0, 18.63) },
					LeftShoulder = { rot = Vector3.new(-4.09, 0, -17.77) },
					RightHip = {
						rot = Vector3.new(-7.94, 0, -18.14),
						pos = Vector3.new(0, 0.15, 0),
					},
					LeftHip = { rot = Vector3.new(13.36, 0, 17.85), pos = Vector3.new(0, 0.12, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-4.94, -34.26, -3.3),
						pos = Vector3.new(0, -0.18, -0.01),
					},
					Neck = { rot = Vector3.new(3.71, 34.4, 0.72) },
					RightShoulder = { rot = Vector3.new(15.64, 0, 20.18) },
					LeftShoulder = { rot = Vector3.new(-1.27, 0, -18.38) },
					RightHip = {
						rot = Vector3.new(-7.75, 0, -19.49),
						pos = Vector3.new(0, 0.12, 0),
					},
					LeftHip = { rot = Vector3.new(11.48, 0, 14.86), pos = Vector3.new(0, 0.14, 0) },
				},
			},
			{
				time = 0.5312,
				pose = {
					Root = {
						rot = Vector3.new(-5.03, -34.46, -3.06),
						pos = Vector3.new(0, -0.16, -0.01),
					},
					Neck = { rot = Vector3.new(3.99, 34.59, 0.33) },
					RightShoulder = { rot = Vector3.new(13.55, 0, 21.7) },
					LeftShoulder = { rot = Vector3.new(1.85, 0, -18.81) },
					RightHip = { rot = Vector3.new(-7.33, 0, -19.8), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(9.44, 0, 11.82), pos = Vector3.new(0, 0.14, 0) },
				},
			},
			{
				time = 0.5625,
				pose = {
					Root = {
						rot = Vector3.new(-5.08, -34.76, -2.92),
						pos = Vector3.new(0, -0.14, -0.02),
					},
					Neck = { rot = Vector3.new(4.17, 34.9, 0.06) },
					RightShoulder = { rot = Vector3.new(11.19, 0, 23.1) },
					LeftShoulder = { rot = Vector3.new(5.19, 0, -19.05) },
					RightHip = {
						rot = Vector3.new(-6.18, 0, -17.82),
						pos = Vector3.new(0, 0.12, 0),
					},
					LeftHip = { rot = Vector3.new(7.5, 0, 8.95), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 0.5938,
				pose = {
					Root = {
						rot = Vector3.new(-5.1, -35.16, -2.85),
						pos = Vector3.new(0, -0.11, -0.02),
					},
					Neck = { rot = Vector3.new(4.27, 35.3, -0.11) },
					RightShoulder = { rot = Vector3.new(8.65, 0, 24.31) },
					LeftShoulder = { rot = Vector3.new(8.64, 0, -19.04) },
					RightHip = { rot = Vector3.new(-4.12, 0, -13.87), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(5.51, 0, 6.19), pos = Vector3.new(0, 0.11, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = {
						rot = Vector3.new(-5.1, -35.63, -2.84),
						pos = Vector3.new(0, -0.09, -0.02),
					},
					Neck = { rot = Vector3.new(4.3, 35.78, -0.19) },
					RightShoulder = { rot = Vector3.new(6.06, 0, 25.29) },
					LeftShoulder = { rot = Vector3.new(12.02, 0, -18.79) },
					RightHip = { rot = Vector3.new(-1.03, 0, -8.7), pos = Vector3.new(0, 0.26, 0) },
					LeftHip = { rot = Vector3.new(3.81, 0, 3.51), pos = Vector3.new(0, 0.09, 0) },
				},
			},
			{
				time = 0.6562,
				pose = {
					Root = {
						rot = Vector3.new(-5.08, -36.17, -2.89),
						pos = Vector3.new(0.01, -0.07, -0.02),
					},
					Neck = { rot = Vector3.new(4.27, 36.33, -0.19) },
					RightShoulder = { rot = Vector3.new(3.55, 0, 26.05) },
					LeftShoulder = { rot = Vector3.new(15.19, 0, -18.32) },
					RightHip = { rot = Vector3.new(2.98, 0, -2.83), pos = Vector3.new(0, 0.29, 0) },
					LeftHip = { rot = Vector3.new(1.8, 0, 0.78), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.6875,
				pose = {
					Root = {
						rot = Vector3.new(-5.05, -36.75, -3.01),
						pos = Vector3.new(0.01, -0.06, -0.02),
					},
					Neck = { rot = Vector3.new(4.17, 36.92, -0.1) },
					RightShoulder = { rot = Vector3.new(1.24, 0, 26.62) },
					LeftShoulder = { rot = Vector3.new(18, 0, -17.73) },
					RightHip = { rot = Vector3.new(7.48, 0, 3.12), pos = Vector3.new(0, 0.26, 0) },
					LeftHip = { rot = Vector3.new(-0.38, 0, -1.31), pos = Vector3.new(0, 0.11, 0) },
				},
			},
			{
				time = 0.7188,
				pose = {
					Root = {
						rot = Vector3.new(-5.01, -37.33, -3.18),
						pos = Vector3.new(0.01, -0.06, -0.02),
					},
					Neck = { rot = Vector3.new(4, 37.52, 0.09) },
					RightShoulder = { rot = Vector3.new(-0.74, 0, 27.05) },
					LeftShoulder = { rot = Vector3.new(20.36, 0, -17.14) },
					RightHip = { rot = Vector3.new(12.27, 0, 8.67), pos = Vector3.new(0, 0.25, 0) },
					LeftHip = { rot = Vector3.new(-2.43, 0, -3.42), pos = Vector3.new(0, 0.16, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(-4.95, -37.91, -3.43),
						pos = Vector3.new(0.02, -0.08, -0.02),
					},
					Neck = { rot = Vector3.new(3.76, 38.11, 0.38) },
					RightShoulder = { rot = Vector3.new(-2.26, 0, 27.4) },
					LeftShoulder = { rot = Vector3.new(22.17, 0, -16.69) },
					RightHip = { rot = Vector3.new(16.34, 0, 13.08), pos = Vector3.new(0, 0.3, 0) },
					LeftHip = { rot = Vector3.new(-4.5, 0, -5.53), pos = Vector3.new(0, 0.21, 0) },
				},
			},
			{
				time = 0.7812,
				pose = {
					Root = {
						rot = Vector3.new(-4.9, -38.44, -3.75),
						pos = Vector3.new(0.02, -0.11, -0.01),
					},
					Neck = { rot = Vector3.new(3.45, 38.66, 0.77) },
					RightShoulder = { rot = Vector3.new(-3.22, 0, 27.74) },
					LeftShoulder = { rot = Vector3.new(23.34, 0, -16.52) },
					RightHip = { rot = Vector3.new(19.62, 0, 16.55), pos = Vector3.new(0, 0.36, 0) },
					LeftHip = { rot = Vector3.new(-6.51, 0, -7.57), pos = Vector3.new(0, 0.26, 0) },
				},
			},
			{
				time = 0.8125,
				pose = {
					Root = {
						rot = Vector3.new(-4.84, -38.92, -4.13),
						pos = Vector3.new(0.03, -0.14, -0.01),
					},
					Neck = { rot = Vector3.new(3.06, 39.14, 1.27) },
					RightShoulder = { rot = Vector3.new(-3.53, 0, 28.08) },
					LeftShoulder = { rot = Vector3.new(23.75, 0, -16.75) },
					RightHip = { rot = Vector3.new(21.94, 0, 18.95), pos = Vector3.new(0, 0.4, 0) },
					LeftHip = { rot = Vector3.new(-8.39, 0, -9.66), pos = Vector3.new(0, 0.32, 0) },
				},
			},
			{
				time = 0.8438,
				pose = {
					Root = {
						rot = Vector3.new(-4.78, -39.31, -4.56),
						pos = Vector3.new(0.03, -0.17, -0.01),
					},
					Neck = { rot = Vector3.new(2.62, 39.55, 1.85) },
					RightShoulder = { rot = Vector3.new(-3.24, 0, 28.23) },
					LeftShoulder = { rot = Vector3.new(23.36, 0, -17.31) },
					RightHip = { rot = Vector3.new(22.87, 0, 19.72), pos = Vector3.new(0, 0.43, 0) },
					LeftHip = { rot = Vector3.new(-10.18, 0, -11.7), pos = Vector3.new(0, 0.36, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = {
						rot = Vector3.new(-4.72, -39.61, -5.03),
						pos = Vector3.new(0.03, -0.18, 0),
					},
					Neck = { rot = Vector3.new(2.13, 39.86, 2.5) },
					RightShoulder = { rot = Vector3.new(-2.46, 0, 28.09) },
					LeftShoulder = { rot = Vector3.new(22.23, 0, -18.01) },
					RightHip = { rot = Vector3.new(21.96, 0, 18.68), pos = Vector3.new(0, 0.45, 0) },
					LeftHip = {
						rot = Vector3.new(-11.61, 0, -13.36),
						pos = Vector3.new(0, 0.38, 0),
					},
				},
			},
			{
				time = 0.9062,
				pose = {
					Root = {
						rot = Vector3.new(-4.65, -39.82, -5.54),
						pos = Vector3.new(0.04, -0.19, 0),
					},
					Neck = { rot = Vector3.new(1.58, 40.06, 3.22) },
					RightShoulder = { rot = Vector3.new(-1.25, 0, 27.7) },
					LeftShoulder = { rot = Vector3.new(20.41, 0, -18.75) },
					RightHip = { rot = Vector3.new(20.37, 0, 17.18), pos = Vector3.new(0, 0.46, 0) },
					LeftHip = { rot = Vector3.new(-12.58, 0, -14.6), pos = Vector3.new(0, 0.39, 0) },
				},
			},
			{
				time = 0.9375,
				pose = {
					Root = {
						rot = Vector3.new(-4.56, -39.91, -6.06),
						pos = Vector3.new(0.04, -0.19, 0.01),
					},
					Neck = { rot = Vector3.new(1, 40.15, 3.99) },
					RightShoulder = { rot = Vector3.new(0.35, 0, 27.1) },
					LeftShoulder = { rot = Vector3.new(17.97, 0, -19.41) },
					RightHip = { rot = Vector3.new(18.77, 0, 15.8), pos = Vector3.new(0, 0.45, 0) },
					LeftHip = {
						rot = Vector3.new(-13.15, 0, -15.73),
						pos = Vector3.new(0, 0.39, 0),
					},
				},
			},
			{
				time = 0.9688,
				pose = {
					Root = {
						rot = Vector3.new(-4.48, -39.9, -6.51),
						pos = Vector3.new(0.04, -0.18, 0.01),
					},
					Neck = { rot = Vector3.new(0.47, 40.12, 4.68) },
					RightShoulder = { rot = Vector3.new(2.27, 0, 26.26) },
					LeftShoulder = { rot = Vector3.new(15.03, 0, -19.91) },
					RightHip = { rot = Vector3.new(17, 0, 14.16), pos = Vector3.new(0, 0.44, 0) },
					LeftHip = {
						rot = Vector3.new(-13.35, 0, -16.96),
						pos = Vector3.new(0, 0.38, 0),
					},
				},
			},
		},
	},
	-- ALS_N_Run_F: phase clip (one cycle = 1), left foot plants at 0.4375; natural cycle 0.833 s, stride 6.22 studs per cycle
	Jog = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-11.28, -4.55, -1.74),
						pos = Vector3.new(0.02, -0.27, 0.03),
					},
					Neck = { rot = Vector3.new(3.05, 4.75, 1.36) },
					RightShoulder = { rot = Vector3.new(10.85, 0, 19.66) },
					LeftShoulder = { rot = Vector3.new(35.43, 0, -11.88) },
					RightHip = { rot = Vector3.new(15.85, 0, -2.15), pos = Vector3.new(0, 0.3, 0) },
					LeftHip = { rot = Vector3.new(-13.42, 0, 6.02), pos = Vector3.new(0, 0.84, 0) },
				},
			},
			{
				time = 0.0312,
				pose = {
					Root = {
						rot = Vector3.new(-11.33, -3.68, -2.1),
						pos = Vector3.new(0.03, -0.28, 0.04),
					},
					Neck = { rot = Vector3.new(3.05, 3.85, 1.8) },
					RightShoulder = { rot = Vector3.new(18.44, 0, 18.51) },
					LeftShoulder = { rot = Vector3.new(28.56, 0, -14.51) },
					RightHip = { rot = Vector3.new(11, 0, -1.34), pos = Vector3.new(0, 0.3, 0) },
					LeftHip = { rot = Vector3.new(-7.68, 0, 5.82), pos = Vector3.new(0, 0.84, 0) },
				},
			},
			{
				time = 0.0625,
				pose = {
					Root = {
						rot = Vector3.new(-11.34, -2.49, -2.34),
						pos = Vector3.new(0.03, -0.28, 0.04),
					},
					Neck = { rot = Vector3.new(3.06, 2.61, 2.14) },
					RightShoulder = { rot = Vector3.new(25.75, 0, 15.87) },
					LeftShoulder = { rot = Vector3.new(20.7, 0, -15.83) },
					RightHip = { rot = Vector3.new(5.5, 0, -0.35), pos = Vector3.new(0, 0.32, 0) },
					LeftHip = { rot = Vector3.new(-1.74, 0, 5.69), pos = Vector3.new(0, 0.78, 0) },
				},
			},
			{
				time = 0.0938,
				pose = {
					Root = {
						rot = Vector3.new(-11.31, -0.93, -2.49),
						pos = Vector3.new(0.03, -0.26, 0.04),
					},
					Neck = { rot = Vector3.new(3.07, 1.03, 2.41) },
					RightShoulder = { rot = Vector3.new(31.27, 0, 13.04) },
					LeftShoulder = { rot = Vector3.new(13.94, 0, -15.76) },
					RightHip = { rot = Vector3.new(-0.23, 0, 0.33), pos = Vector3.new(0, 0.34, 0) },
					LeftHip = { rot = Vector3.new(4.46, 0, 5.76), pos = Vector3.new(0, 0.66, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = {
						rot = Vector3.new(-11.26, 0.83, -2.58),
						pos = Vector3.new(0.03, -0.22, 0.04),
					},
					Neck = { rot = Vector3.new(3.09, -0.76, 2.62) },
					RightShoulder = { rot = Vector3.new(34.96, 0, 10.97) },
					LeftShoulder = { rot = Vector3.new(9.08, 0, -15.04) },
					RightHip = { rot = Vector3.new(-5.45, 0, 0.36), pos = Vector3.new(0, 0.31, 0) },
					LeftHip = { rot = Vector3.new(11.13, 0, 6.19), pos = Vector3.new(0, 0.47, 0) },
				},
			},
			{
				time = 0.1562,
				pose = {
					Root = {
						rot = Vector3.new(-11.2, 2.52, -2.6),
						pos = Vector3.new(0.03, -0.16, 0.03),
					},
					Neck = { rot = Vector3.new(3.11, -2.46, 2.74) },
					RightShoulder = { rot = Vector3.new(37.68, 0, 9.6) },
					LeftShoulder = { rot = Vector3.new(5.55, 0, -14.44) },
					RightHip = { rot = Vector3.new(-9.69, 0, -0.01), pos = Vector3.new(0, 0.24, 0) },
					LeftHip = { rot = Vector3.new(18.19, 0, 6.88), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.1875,
				pose = {
					Root = {
						rot = Vector3.new(-11.16, 3.86, -2.51),
						pos = Vector3.new(0.03, -0.09, 0.02),
					},
					Neck = { rot = Vector3.new(3.13, -3.82, 2.75) },
					RightShoulder = { rot = Vector3.new(39.8, 0, 8.58) },
					LeftShoulder = { rot = Vector3.new(2.88, 0, -14.16) },
					RightHip = {
						rot = Vector3.new(-12.67, 0, -0.45),
						pos = Vector3.new(0, 0.16, 0),
					},
					LeftHip = { rot = Vector3.new(24.72, 0, 7.29), pos = Vector3.new(0, 0.09, 0) },
				},
			},
			{
				time = 0.2188,
				pose = {
					Root = {
						rot = Vector3.new(-11.14, 4.81, -2.33),
						pos = Vector3.new(0.02, -0.05, 0.01),
					},
					Neck = { rot = Vector3.new(3.15, -4.79, 2.62) },
					RightShoulder = { rot = Vector3.new(41.51, 0, 7.72) },
					LeftShoulder = { rot = Vector3.new(0.8, 0, -14.2) },
					RightHip = {
						rot = Vector3.new(-15.64, 0, -1.12),
						pos = Vector3.new(0, 0.09, 0),
					},
					LeftHip = { rot = Vector3.new(30.17, 0, 7.32), pos = Vector3.new(0, 0.01, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(-11.15, 5.44, -2.01),
						pos = Vector3.new(0.02, -0.04, 0),
					},
					Neck = { rot = Vector3.new(3.16, -5.44, 2.34) },
					RightShoulder = { rot = Vector3.new(42.87, 0, 6.94) },
					LeftShoulder = { rot = Vector3.new(-0.77, 0, -14.54) },
					RightHip = {
						rot = Vector3.new(-19.29, 0, -2.16),
						pos = Vector3.new(0, 0.08, 0),
					},
					LeftHip = { rot = Vector3.new(33.86, 0, 7.09) },
				},
			},
			{
				time = 0.2812,
				pose = {
					Root = {
						rot = Vector3.new(-11.18, 5.8, -1.59),
						pos = Vector3.new(0.01, -0.03, -0.01),
					},
					Neck = { rot = Vector3.new(3.17, -5.83, 1.94) },
					RightShoulder = { rot = Vector3.new(43.93, 0, 6.22) },
					LeftShoulder = { rot = Vector3.new(-1.91, 0, -15.12) },
					RightHip = { rot = Vector3.new(-22.96, 0, -3.38), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(35.94, 0, 6.79) },
				},
			},
			{
				time = 0.3125,
				pose = {
					Root = {
						rot = Vector3.new(-11.23, 5.96, -1.08),
						pos = Vector3.new(0.01, -0.04, -0.01),
					},
					Neck = { rot = Vector3.new(3.17, -6.01, 1.44) },
					RightShoulder = { rot = Vector3.new(44.65, 0, 5.62) },
					LeftShoulder = { rot = Vector3.new(-2.56, 0, -15.87) },
					RightHip = {
						rot = Vector3.new(-25.28, 0, -4.47),
						pos = Vector3.new(0, 0.15, 0),
					},
					LeftHip = { rot = Vector3.new(37.07, 0, 6.53) },
				},
			},
			{
				time = 0.3438,
				pose = {
					Root = {
						rot = Vector3.new(-11.29, 5.95, -0.44),
						pos = Vector3.new(0, -0.07, -0.01),
					},
					Neck = { rot = Vector3.new(3.17, -6.03, 0.8) },
					RightShoulder = { rot = Vector3.new(44.84, 0, 5.36) },
					LeftShoulder = { rot = Vector3.new(-2.42, 0, -16.92) },
					RightHip = {
						rot = Vector3.new(-25.75, 0, -5.32),
						pos = Vector3.new(0, 0.28, 0),
					},
					LeftHip = { rot = Vector3.new(36.6, 0, 5.95), pos = Vector3.new(0, 0.03, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = {
						rot = Vector3.new(-11.31, 5.94, -0.27),
						pos = Vector3.new(0, -0.08, -0.01),
					},
					Neck = { rot = Vector3.new(3.17, -6.03, 0.62) },
					RightShoulder = { rot = Vector3.new(44.9, 0, 5.28) },
					LeftShoulder = { rot = Vector3.new(-2.39, 0, -17.21) },
					RightHip = {
						rot = Vector3.new(-25.73, 0, -5.53),
						pos = Vector3.new(0, 0.31, 0),
					},
					LeftHip = { rot = Vector3.new(36.79, 0, 5.81), pos = Vector3.new(0, 0.04, 0) },
				},
			},
			{
				time = 0.4062,
				pose = {
					Root = {
						rot = Vector3.new(-11.31, 5.91, -0.2),
						pos = Vector3.new(0, -0.09, -0.01),
					},
					Neck = { rot = Vector3.new(3.17, -6, 0.55) },
					RightShoulder = { rot = Vector3.new(44.75, 0, 5.4) },
					LeftShoulder = { rot = Vector3.new(-2.14, 0, -17.35) },
					RightHip = {
						rot = Vector3.new(-25.58, 0, -5.56),
						pos = Vector3.new(0, 0.34, 0),
					},
					LeftHip = { rot = Vector3.new(35.64, 0, 5.63), pos = Vector3.new(0, 0.06, 0) },
				},
			},
			{
				time = 0.4375,
				pose = {
					Root = {
						rot = Vector3.new(-11.36, 5.72, 0.35),
						pos = Vector3.new(-0.01, -0.16, 0),
					},
					Neck = { rot = Vector3.new(3.16, -5.83, -0.01) },
					RightShoulder = { rot = Vector3.new(43.84, 0, 6.04) },
					LeftShoulder = { rot = Vector3.new(-0.56, 0, -18.4) },
					RightHip = {
						rot = Vector3.new(-24.36, 0, -5.86),
						pos = Vector3.new(0, 0.53, 0),
					},
					LeftHip = { rot = Vector3.new(30.47, 0, 4.68), pos = Vector3.new(0, 0.17, 0) },
				},
			},
			{
				time = 0.4688,
				pose = {
					Root = {
						rot = Vector3.new(-11.39, 5.42, 0.78),
						pos = Vector3.new(-0.01, -0.22, 0.01),
					},
					Neck = { rot = Vector3.new(3.15, -5.53, -0.47) },
					RightShoulder = { rot = Vector3.new(41.91, 0, 7.43) },
					LeftShoulder = { rot = Vector3.new(2.28, 0, -19.29) },
					RightHip = { rot = Vector3.new(-21.49, 0, -5.8), pos = Vector3.new(0, 0.7, 0) },
					LeftHip = { rot = Vector3.new(24.93, 0, 3.99), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-11.41, 4.95, 1.19),
						pos = Vector3.new(-0.02, -0.26, 0.02),
					},
					Neck = { rot = Vector3.new(3.13, -5.06, -0.93) },
					RightShoulder = { rot = Vector3.new(38.59, 0, 9.62) },
					LeftShoulder = { rot = Vector3.new(6.81, 0, -19.93) },
					RightHip = {
						rot = Vector3.new(-16.89, 0, -5.55),
						pos = Vector3.new(0, 0.81, 0),
					},
					LeftHip = { rot = Vector3.new(19.44, 0, 3.33), pos = Vector3.new(0, 0.29, 0) },
				},
			},
			{
				time = 0.5312,
				pose = {
					Root = {
						rot = Vector3.new(-11.39, 4.26, 1.59),
						pos = Vector3.new(-0.02, -0.28, 0.03),
					},
					Neck = { rot = Vector3.new(3.11, -4.34, -1.4) },
					RightShoulder = { rot = Vector3.new(33.15, 0, 12.37) },
					LeftShoulder = { rot = Vector3.new(13.42, 0, -19.72) },
					RightHip = { rot = Vector3.new(-11.41, 0, -5.3), pos = Vector3.new(0, 0.86, 0) },
					LeftHip = { rot = Vector3.new(14.31, 0, 2.6), pos = Vector3.new(0, 0.29, 0) },
				},
			},
			{
				time = 0.5625,
				pose = {
					Root = {
						rot = Vector3.new(-11.34, 3.28, 1.9),
						pos = Vector3.new(-0.03, -0.28, 0.04),
					},
					Neck = { rot = Vector3.new(3.08, -3.33, -1.81) },
					RightShoulder = { rot = Vector3.new(25.75, 0, 14.69) },
					LeftShoulder = { rot = Vector3.new(21.18, 0, -18.02) },
					RightHip = { rot = Vector3.new(-5.73, 0, -5.11), pos = Vector3.new(0, 0.84, 0) },
					LeftHip = { rot = Vector3.new(9.2, 0, 1.74), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.5938,
				pose = {
					Root = {
						rot = Vector3.new(-11.26, 1.96, 2.11),
						pos = Vector3.new(-0.03, -0.27, 0.04),
					},
					Neck = { rot = Vector3.new(3.05, -1.97, -2.12) },
					RightShoulder = { rot = Vector3.new(18.06, 0, 15.5) },
					LeftShoulder = { rot = Vector3.new(27.99, 0, -15.14) },
					RightHip = { rot = Vector3.new(0.19, 0, -5.02), pos = Vector3.new(0, 0.75, 0) },
					LeftHip = { rot = Vector3.new(3.34, 0, 0.7), pos = Vector3.new(0, 0.33, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = {
						rot = Vector3.new(-11.16, 0.3, 2.26),
						pos = Vector3.new(-0.03, -0.25, 0.04),
					},
					Neck = { rot = Vector3.new(3.03, -0.29, -2.37) },
					RightShoulder = { rot = Vector3.new(12.05, 0, 15.12) },
					LeftShoulder = { rot = Vector3.new(32.76, 0, -12.57) },
					RightHip = { rot = Vector3.new(6.45, 0, -5.18), pos = Vector3.new(0, 0.6, 0) },
					LeftHip = { rot = Vector3.new(-1.99, 0, 0.26), pos = Vector3.new(0, 0.33, 0) },
				},
			},
			{
				time = 0.6562,
				pose = {
					Root = {
						rot = Vector3.new(-11.06, -1.47, 2.34),
						pos = Vector3.new(-0.03, -0.2, 0.04),
					},
					Neck = { rot = Vector3.new(3.02, 1.5, -2.56) },
					RightShoulder = { rot = Vector3.new(7.75, 0, 14.43) },
					LeftShoulder = { rot = Vector3.new(36.04, 0, -10.81) },
					RightHip = { rot = Vector3.new(13.28, 0, -5.75), pos = Vector3.new(0, 0.4, 0) },
					LeftHip = { rot = Vector3.new(-7.08, 0, 0.32), pos = Vector3.new(0, 0.28, 0) },
				},
			},
			{
				time = 0.6875,
				pose = {
					Root = {
						rot = Vector3.new(-10.98, -3.05, 2.33),
						pos = Vector3.new(-0.03, -0.13, 0.03),
					},
					Neck = { rot = Vector3.new(3.02, 3.09, -2.65) },
					RightShoulder = { rot = Vector3.new(4.59, 0, 13.96) },
					LeftShoulder = { rot = Vector3.new(38.52, 0, -9.63) },
					RightHip = { rot = Vector3.new(20.2, 0, -6.44), pos = Vector3.new(0, 0.19, 0) },
					LeftHip = { rot = Vector3.new(-11.22, 0, 0.57), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.7188,
				pose = {
					Root = {
						rot = Vector3.new(-10.92, -4.25, 2.23),
						pos = Vector3.new(-0.03, -0.08, 0.01),
					},
					Neck = { rot = Vector3.new(3.03, 4.31, -2.61) },
					RightShoulder = { rot = Vector3.new(2.15, 0, 13.82) },
					LeftShoulder = { rot = Vector3.new(40.48, 0, -8.7) },
					RightHip = { rot = Vector3.new(26.41, 0, -6.85), pos = Vector3.new(0, 0.06, 0) },
					LeftHip = { rot = Vector3.new(-14.01, 0, 1.03), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(-10.9, -5.07, 2),
						pos = Vector3.new(-0.02, -0.04, 0),
					},
					Neck = { rot = Vector3.new(3.03, 5.16, -2.43) },
					RightShoulder = { rot = Vector3.new(0.26, 0, 13.99) },
					LeftShoulder = { rot = Vector3.new(42.07, 0, -7.9) },
					RightHip = { rot = Vector3.new(31.41, 0, -6.95), pos = Vector3.new(0, 0.01, 0) },
					LeftHip = { rot = Vector3.new(-17.27, 0, 1.83), pos = Vector3.new(0, 0.07, 0) },
				},
			},
			{
				time = 0.7812,
				pose = {
					Root = {
						rot = Vector3.new(-10.9, -5.6, 1.65),
						pos = Vector3.new(-0.02, -0.03, -0.01),
					},
					Neck = { rot = Vector3.new(3.04, 5.7, -2.11) },
					RightShoulder = { rot = Vector3.new(-1.16, 0, 14.44) },
					LeftShoulder = { rot = Vector3.new(43.32, 0, -7.17) },
					RightHip = { rot = Vector3.new(34.43, 0, -6.71) },
					LeftHip = { rot = Vector3.new(-21.13, 0, 2.97), pos = Vector3.new(0, 0.07, 0) },
				},
			},
			{
				time = 0.8125,
				pose = {
					Root = {
						rot = Vector3.new(-10.93, -5.88, 1.18),
						pos = Vector3.new(-0.01, -0.03, -0.01),
					},
					Neck = { rot = Vector3.new(3.04, 6.01, -1.66) },
					RightShoulder = { rot = Vector3.new(-2.12, 0, 15.11) },
					LeftShoulder = { rot = Vector3.new(44.26, 0, -6.52) },
					RightHip = { rot = Vector3.new(36.1, 0, -6.43) },
					LeftHip = { rot = Vector3.new(-24.42, 0, 4.21), pos = Vector3.new(0, 0.11, 0) },
				},
			},
			{
				time = 0.8438,
				pose = {
					Root = {
						rot = Vector3.new(-10.98, -5.98, 0.63),
						pos = Vector3.new(-0.01, -0.04, -0.01),
					},
					Neck = { rot = Vector3.new(3.04, 6.14, -1.13) },
					RightShoulder = { rot = Vector3.new(-2.56, 0, 15.94) },
					LeftShoulder = { rot = Vector3.new(44.85, 0, -6.02) },
					RightHip = { rot = Vector3.new(37.01, 0, -6.14) },
					LeftHip = { rot = Vector3.new(-26.08, 0, 5.27), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = {
						rot = Vector3.new(-11.04, -5.95, 0.08),
						pos = Vector3.new(0, -0.07, -0.01),
					},
					Neck = { rot = Vector3.new(3.04, 6.13, -0.57) },
					RightShoulder = { rot = Vector3.new(-2.32, 0, 16.87) },
					LeftShoulder = { rot = Vector3.new(44.92, 0, -5.89) },
					RightHip = { rot = Vector3.new(36.21, 0, -5.53), pos = Vector3.new(0, 0.04, 0) },
					LeftHip = { rot = Vector3.new(-26.11, 0, 5.97), pos = Vector3.new(0, 0.29, 0) },
				},
			},
			{
				time = 0.9062,
				pose = {
					Root = {
						rot = Vector3.new(-11.1, -5.81, -0.43),
						pos = Vector3.new(0.01, -0.13, 0),
					},
					Neck = { rot = Vector3.new(3.04, 6.01, -0.06) },
					RightShoulder = { rot = Vector3.new(-1.18, 0, 17.81) },
					LeftShoulder = { rot = Vector3.new(44.33, 0, -6.31) },
					RightHip = { rot = Vector3.new(32.02, 0, -4.57), pos = Vector3.new(0, 0.13, 0) },
					LeftHip = { rot = Vector3.new(-25.25, 0, 6.36), pos = Vector3.new(0, 0.46, 0) },
				},
			},
			{
				time = 0.9375,
				pose = {
					Root = {
						rot = Vector3.new(-11.16, -5.56, -0.88),
						pos = Vector3.new(0.01, -0.2, 0.01),
					},
					Neck = { rot = Vector3.new(3.04, 5.77, 0.41) },
					RightShoulder = { rot = Vector3.new(1.14, 0, 18.72) },
					LeftShoulder = { rot = Vector3.new(42.8, 0, -7.42) },
					RightHip = { rot = Vector3.new(26.54, 0, -3.7), pos = Vector3.new(0, 0.23, 0) },
					LeftHip = { rot = Vector3.new(-22.96, 0, 6.43), pos = Vector3.new(0, 0.63, 0) },
				},
			},
			{
				time = 0.9688,
				pose = {
					Root = {
						rot = Vector3.new(-11.22, -5.16, -1.31),
						pos = Vector3.new(0.02, -0.25, 0.02),
					},
					Neck = { rot = Vector3.new(3.04, 5.36, 0.88) },
					RightShoulder = { rot = Vector3.new(5.01, 0, 19.48) },
					LeftShoulder = { rot = Vector3.new(40.04, 0, -9.31) },
					RightHip = { rot = Vector3.new(21.09, 0, -2.94), pos = Vector3.new(0, 0.29, 0) },
					LeftHip = { rot = Vector3.new(-18.84, 0, 6.26), pos = Vector3.new(0, 0.77, 0) },
				},
			},
		},
	},
	-- ALS_N_Run_B: phase clip (one cycle = 1), left foot plants at 0.4375; natural cycle 0.700 s, stride 5.23 studs per cycle
	JogBack = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(0.12, 0.36, -1.08),
						pos = Vector3.new(0.03, -0.23, 0.07),
					},
					Neck = { rot = Vector3.new(-6.45, -0.4, 0.99) },
					RightShoulder = { rot = Vector3.new(10.67, 0, 12.59) },
					LeftShoulder = { rot = Vector3.new(20.66, 0, -6.57) },
					RightHip = { rot = Vector3.new(-0.39, 0, -2.8), pos = Vector3.new(0, 0.25, 0) },
					LeftHip = { rot = Vector3.new(-7.86, 0, 2.25), pos = Vector3.new(0, 0.52, 0) },
				},
			},
			{
				time = 0.0312,
				pose = {
					Root = {
						rot = Vector3.new(0.1, -0.93, -1.04),
						pos = Vector3.new(0.02, -0.18, 0.06),
					},
					Neck = { rot = Vector3.new(-6.46, 0.9, 1.08) },
					RightShoulder = { rot = Vector3.new(8.75, 0, 12.94) },
					LeftShoulder = { rot = Vector3.new(22.55, 0, -5.89) },
					RightHip = { rot = Vector3.new(3.89, 0, -2.69), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(-12, 0, 2.54), pos = Vector3.new(0, 0.48, 0) },
				},
			},
			{
				time = 0.0625,
				pose = {
					Root = {
						rot = Vector3.new(0.09, -2.08, -0.99),
						pos = Vector3.new(0.02, -0.14, 0.05),
					},
					Neck = { rot = Vector3.new(-6.46, 2.05, 1.15) },
					RightShoulder = { rot = Vector3.new(7.35, 0, 13.18) },
					LeftShoulder = { rot = Vector3.new(23.95, 0, -5.54) },
					RightHip = { rot = Vector3.new(8.51, 0, -2.57), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(-15.52, 0, 3), pos = Vector3.new(0, 0.42, 0) },
				},
			},
			{
				time = 0.0938,
				pose = {
					Root = {
						rot = Vector3.new(0.09, -2.95, -0.94),
						pos = Vector3.new(0.01, -0.11, 0.04),
					},
					Neck = { rot = Vector3.new(-6.47, 2.92, 1.2) },
					RightShoulder = { rot = Vector3.new(6.55, 0, 13.27) },
					LeftShoulder = { rot = Vector3.new(24.74, 0, -5.46) },
					RightHip = { rot = Vector3.new(13.37, 0, -2.6), pos = Vector3.new(0, 0.18, 0) },
					LeftHip = { rot = Vector3.new(-18.23, 0, 3.54), pos = Vector3.new(0, 0.36, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = {
						rot = Vector3.new(0.09, -3.56, -0.89),
						pos = Vector3.new(0.01, -0.09, 0.03),
					},
					Neck = { rot = Vector3.new(-6.47, 3.54, 1.21) },
					RightShoulder = { rot = Vector3.new(6.12, 0, 13.28) },
					LeftShoulder = { rot = Vector3.new(25.14, 0, -5.53) },
					RightHip = { rot = Vector3.new(17.34, 0, -2.61), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(-20.09, 0, 4.09), pos = Vector3.new(0, 0.31, 0) },
				},
			},
			{
				time = 0.1562,
				pose = {
					Root = {
						rot = Vector3.new(0.09, -3.97, -0.84),
						pos = Vector3.new(0, -0.09, 0.03),
					},
					Neck = { rot = Vector3.new(-6.48, 3.95, 1.21) },
					RightShoulder = { rot = Vector3.new(5.89, 0, 13.25) },
					LeftShoulder = { rot = Vector3.new(25.31, 0, -5.65) },
					RightHip = { rot = Vector3.new(20.02, 0, -2.54), pos = Vector3.new(0, 0.14, 0) },
					LeftHip = { rot = Vector3.new(-21.25, 0, 4.61), pos = Vector3.new(0, 0.27, 0) },
				},
			},
			{
				time = 0.1875,
				pose = {
					Root = {
						rot = Vector3.new(0.1, -4.22, -0.78),
						pos = Vector3.new(-0.01, -0.09, 0.03),
					},
					Neck = { rot = Vector3.new(-6.48, 4.21, 1.17) },
					RightShoulder = { rot = Vector3.new(5.81, 0, 13.19) },
					LeftShoulder = { rot = Vector3.new(25.31, 0, -5.82) },
					RightHip = { rot = Vector3.new(21.37, 0, -2.42), pos = Vector3.new(0, 0.14, 0) },
					LeftHip = { rot = Vector3.new(-21.86, 0, 5.05), pos = Vector3.new(0, 0.23, 0) },
				},
			},
			{
				time = 0.2188,
				pose = {
					Root = {
						rot = Vector3.new(0.11, -4.34, -0.64),
						pos = Vector3.new(-0.01, -0.12, 0.04),
					},
					Neck = { rot = Vector3.new(-6.48, 4.34, 1.04) },
					RightShoulder = { rot = Vector3.new(6.03, 0, 13.04) },
					LeftShoulder = { rot = Vector3.new(25.03, 0, -6.14) },
					RightHip = { rot = Vector3.new(20.99, 0, -2.29), pos = Vector3.new(0, 0.17, 0) },
					LeftHip = { rot = Vector3.new(-21.94, 0, 5.37), pos = Vector3.new(0, 0.22, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(0.12, -4.38, -0.53),
						pos = Vector3.new(-0.02, -0.15, 0.05),
					},
					Neck = { rot = Vector3.new(-6.47, 4.39, 0.93) },
					RightShoulder = { rot = Vector3.new(6.26, 0, 12.92) },
					LeftShoulder = { rot = Vector3.new(24.77, 0, -6.38) },
					RightHip = { rot = Vector3.new(20.2, 0, -2.18), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(-21.8, 0, 5.53), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.2812,
				pose = {
					Root = {
						rot = Vector3.new(0.12, -4.38, -0.56),
						pos = Vector3.new(-0.02, -0.15, 0.05),
					},
					Neck = { rot = Vector3.new(-6.47, 4.4, 0.97) },
					RightShoulder = { rot = Vector3.new(6.21, 0, 12.94) },
					LeftShoulder = { rot = Vector3.new(24.82, 0, -6.35) },
					RightHip = { rot = Vector3.new(20.4, 0, -2.16), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(-21.8, 0, 5.55), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.3125,
				pose = {
					Root = {
						rot = Vector3.new(0.13, -4.36, -0.37),
						pos = Vector3.new(-0.02, -0.17, 0.06),
					},
					Neck = { rot = Vector3.new(-6.47, 4.39, 0.78) },
					RightShoulder = { rot = Vector3.new(6.5, 0, 12.81) },
					LeftShoulder = { rot = Vector3.new(24.54, 0, -6.56) },
					RightHip = { rot = Vector3.new(19.31, 0, -2.28), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(-21.79, 0, 5.48), pos = Vector3.new(0, 0.22, 0) },
				},
			},
			{
				time = 0.3438,
				pose = {
					Root = {
						rot = Vector3.new(0.15, -4.26, 0.07),
						pos = Vector3.new(-0.03, -0.22, 0.07),
					},
					Neck = { rot = Vector3.new(-6.46, 4.34, 0.32) },
					RightShoulder = { rot = Vector3.new(7.34, 0, 12.45) },
					LeftShoulder = { rot = Vector3.new(23.77, 0, -7.17) },
					RightHip = { rot = Vector3.new(16.48, 0, -2.52), pos = Vector3.new(0, 0.27, 0) },
					LeftHip = { rot = Vector3.new(-21.42, 0, 5.23), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = {
						rot = Vector3.new(0.18, -4.05, 0.48),
						pos = Vector3.new(-0.03, -0.25, 0.08),
					},
					Neck = { rot = Vector3.new(-6.46, 4.17, -0.11) },
					RightShoulder = { rot = Vector3.new(8.64, 0, 11.96) },
					LeftShoulder = { rot = Vector3.new(22.65, 0, -7.99) },
					RightHip = { rot = Vector3.new(13.13, 0, -2.69), pos = Vector3.new(0, 0.33, 0) },
					LeftHip = { rot = Vector3.new(-20.1, 0, 4.66), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.4062,
				pose = {
					Root = {
						rot = Vector3.new(0.17, -3.7, 0.72),
						pos = Vector3.new(-0.03, -0.27, 0.09),
					},
					Neck = { rot = Vector3.new(-6.46, 3.83, -0.39) },
					RightShoulder = { rot = Vector3.new(10.78, 0, 11.14) },
					LeftShoulder = { rot = Vector3.new(20.76, 0, -9.21) },
					RightHip = { rot = Vector3.new(9.19, 0, -2.5), pos = Vector3.new(0, 0.4, 0) },
					LeftHip = { rot = Vector3.new(-16.89, 0, 4.12), pos = Vector3.new(0, 0.33, 0) },
				},
			},
			{
				time = 0.4375,
				pose = {
					Root = {
						rot = Vector3.new(0.15, -3.16, 0.81),
						pos = Vector3.new(-0.03, -0.28, 0.09),
					},
					Neck = { rot = Vector3.new(-6.45, 3.28, -0.53) },
					RightShoulder = { rot = Vector3.new(13.61, 0, 9.88) },
					LeftShoulder = { rot = Vector3.new(18.08, 0, -10.66) },
					RightHip = { rot = Vector3.new(4.73, 0, -2.03), pos = Vector3.new(0, 0.48, 0) },
					LeftHip = { rot = Vector3.new(-12.27, 0, 3.76), pos = Vector3.new(0, 0.34, 0) },
				},
			},
			{
				time = 0.4688,
				pose = {
					Root = {
						rot = Vector3.new(0.12, -2.38, 0.86),
						pos = Vector3.new(-0.03, -0.27, 0.09),
					},
					Neck = { rot = Vector3.new(-6.44, 2.49, -0.66) },
					RightShoulder = { rot = Vector3.new(16.45, 0, 8.36) },
					LeftShoulder = { rot = Vector3.new(15.11, 0, -11.82) },
					RightHip = { rot = Vector3.new(0.11, 0, -1.71), pos = Vector3.new(0, 0.53, 0) },
					LeftHip = { rot = Vector3.new(-7.72, 0, 3.51), pos = Vector3.new(0, 0.33, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(0.08, -1.32, 0.88),
						pos = Vector3.new(-0.03, -0.25, 0.08),
					},
					Neck = { rot = Vector3.new(-6.43, 1.42, -0.79) },
					RightShoulder = { rot = Vector3.new(18.98, 0, 7) },
					LeftShoulder = { rot = Vector3.new(12.4, 0, -12.56) },
					RightHip = { rot = Vector3.new(-4.48, 0, -1.61), pos = Vector3.new(0, 0.54, 0) },
					LeftHip = { rot = Vector3.new(-3.44, 0, 3.39), pos = Vector3.new(0, 0.28, 0) },
				},
			},
			{
				time = 0.5312,
				pose = {
					Root = {
						rot = Vector3.new(0.05, -0.06, 0.87),
						pos = Vector3.new(-0.03, -0.22, 0.07),
					},
					Neck = { rot = Vector3.new(-6.43, 0.15, -0.9) },
					RightShoulder = { rot = Vector3.new(21.12, 0, 6.05) },
					LeftShoulder = { rot = Vector3.new(10.16, 0, -12.99) },
					RightHip = { rot = Vector3.new(-8.89, 0, -1.72), pos = Vector3.new(0, 0.52, 0) },
					LeftHip = { rot = Vector3.new(0.77, 0, 3.31), pos = Vector3.new(0, 0.23, 0) },
				},
			},
			{
				time = 0.5625,
				pose = {
					Root = {
						rot = Vector3.new(0.02, 1.22, 0.82),
						pos = Vector3.new(-0.02, -0.17, 0.06),
					},
					Neck = { rot = Vector3.new(-6.42, -1.13, -0.98) },
					RightShoulder = { rot = Vector3.new(22.91, 0, 5.43) },
					LeftShoulder = { rot = Vector3.new(8.33, 0, -13.31) },
					RightHip = {
						rot = Vector3.new(-12.86, 0, -2.08),
						pos = Vector3.new(0, 0.48, 0),
					},
					LeftHip = { rot = Vector3.new(5.11, 0, 3.11), pos = Vector3.new(0, 0.21, 0) },
				},
			},
			{
				time = 0.5938,
				pose = {
					Root = {
						rot = Vector3.new(0, 2.3, 0.77),
						pos = Vector3.new(-0.02, -0.13, 0.05),
					},
					Neck = { rot = Vector3.new(-6.42, -2.22, -1.05) },
					RightShoulder = { rot = Vector3.new(24.16, 0, 5.13) },
					LeftShoulder = { rot = Vector3.new(7.08, 0, -13.5) },
					RightHip = {
						rot = Vector3.new(-16.16, 0, -2.58),
						pos = Vector3.new(0, 0.41, 0),
					},
					LeftHip = { rot = Vector3.new(9.85, 0, 2.95), pos = Vector3.new(0, 0.19, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = {
						rot = Vector3.new(-0.01, 3.1, 0.72),
						pos = Vector3.new(-0.01, -0.1, 0.03),
					},
					Neck = { rot = Vector3.new(-6.41, -3.03, -1.08) },
					RightShoulder = { rot = Vector3.new(24.82, 0, 5.09) },
					LeftShoulder = { rot = Vector3.new(6.4, 0, -13.56) },
					RightHip = {
						rot = Vector3.new(-18.64, 0, -3.15),
						pos = Vector3.new(0, 0.35, 0),
					},
					LeftHip = { rot = Vector3.new(14.6, 0, 2.92), pos = Vector3.new(0, 0.17, 0) },
				},
			},
			{
				time = 0.6562,
				pose = {
					Root = {
						rot = Vector3.new(-0.02, 3.66, 0.67),
						pos = Vector3.new(0, -0.09, 0.03),
					},
					Neck = { rot = Vector3.new(-6.41, -3.59, -1.1) },
					RightShoulder = { rot = Vector3.new(25.16, 0, 5.16) },
					LeftShoulder = { rot = Vector3.new(6.01, 0, -13.56) },
					RightHip = { rot = Vector3.new(-20.29, 0, -3.71), pos = Vector3.new(0, 0.3, 0) },
					LeftHip = { rot = Vector3.new(18.3, 0, 2.9), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.6875,
				pose = {
					Root = {
						rot = Vector3.new(-0.02, 4.03, 0.61),
						pos = Vector3.new(0, -0.09, 0.03),
					},
					Neck = { rot = Vector3.new(-6.41, -3.96, -1.08) },
					RightShoulder = { rot = Vector3.new(25.27, 0, 5.3) },
					LeftShoulder = { rot = Vector3.new(5.83, 0, -13.51) },
					RightHip = {
						rot = Vector3.new(-21.29, 0, -4.21),
						pos = Vector3.new(0, 0.27, 0),
					},
					LeftHip = { rot = Vector3.new(20.63, 0, 2.83), pos = Vector3.new(0, 0.14, 0) },
				},
			},
			{
				time = 0.7188,
				pose = {
					Root = {
						rot = Vector3.new(-0.02, 4.25, 0.54),
						pos = Vector3.new(0.01, -0.1, 0.03),
					},
					Neck = { rot = Vector3.new(-6.41, -4.19, -1.03) },
					RightShoulder = { rot = Vector3.new(25.21, 0, 5.49) },
					LeftShoulder = { rot = Vector3.new(5.81, 0, -13.43) },
					RightHip = {
						rot = Vector3.new(-21.77, 0, -4.63),
						pos = Vector3.new(0, 0.24, 0),
					},
					LeftHip = { rot = Vector3.new(21.6, 0, 2.7), pos = Vector3.new(0, 0.14, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(-0.01, 4.35, 0.44),
						pos = Vector3.new(0.01, -0.13, 0.04),
					},
					Neck = { rot = Vector3.new(-6.41, -4.3, -0.94) },
					RightShoulder = { rot = Vector3.new(24.98, 0, 5.75) },
					LeftShoulder = { rot = Vector3.new(5.98, 0, -13.32) },
					RightHip = {
						rot = Vector3.new(-21.75, 0, -4.92),
						pos = Vector3.new(0, 0.22, 0),
					},
					LeftHip = { rot = Vector3.new(21.3, 0, 2.56), pos = Vector3.new(0, 0.17, 0) },
				},
			},
			{
				time = 0.7812,
				pose = {
					Root = {
						rot = Vector3.new(0.01, 4.36, 0.21),
						pos = Vector3.new(0.02, -0.16, 0.05),
					},
					Neck = { rot = Vector3.new(-6.4, -4.34, -0.72) },
					RightShoulder = { rot = Vector3.new(24.57, 0, 6.11) },
					LeftShoulder = { rot = Vector3.new(6.38, 0, -13.12) },
					RightHip = {
						rot = Vector3.new(-21.64, 0, -4.99),
						pos = Vector3.new(0, 0.22, 0),
					},
					LeftHip = { rot = Vector3.new(19.84, 0, 2.61), pos = Vector3.new(0, 0.21, 0) },
				},
			},
			{
				time = 0.8125,
				pose = {
					Root = {
						rot = Vector3.new(0.04, 4.29, -0.19),
						pos = Vector3.new(0.02, -0.21, 0.07),
					},
					Neck = { rot = Vector3.new(-6.4, -4.3, -0.31) },
					RightShoulder = { rot = Vector3.new(23.92, 0, 6.62) },
					LeftShoulder = { rot = Vector3.new(7.09, 0, -12.81) },
					RightHip = {
						rot = Vector3.new(-21.46, 0, -4.77),
						pos = Vector3.new(0, 0.25, 0),
					},
					LeftHip = { rot = Vector3.new(17.42, 0, 2.91), pos = Vector3.new(0, 0.26, 0) },
				},
			},
			{
				time = 0.8438,
				pose = {
					Root = {
						rot = Vector3.new(0.08, 4.11, -0.61),
						pos = Vector3.new(0.03, -0.24, 0.08),
					},
					Neck = { rot = Vector3.new(-6.4, -4.16, 0.13) },
					RightShoulder = { rot = Vector3.new(22.94, 0, 7.36) },
					LeftShoulder = { rot = Vector3.new(8.23, 0, -12.38) },
					RightHip = {
						rot = Vector3.new(-20.49, 0, -4.22),
						pos = Vector3.new(0, 0.29, 0),
					},
					LeftHip = { rot = Vector3.new(14.25, 0, 3.19), pos = Vector3.new(0, 0.31, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = {
						rot = Vector3.new(0.11, 3.79, -0.91),
						pos = Vector3.new(0.03, -0.27, 0.09),
					},
					Neck = { rot = Vector3.new(-6.41, -3.87, 0.46) },
					RightShoulder = { rot = Vector3.new(21.27, 0, 8.49) },
					LeftShoulder = { rot = Vector3.new(10.16, 0, -11.66) },
					RightHip = {
						rot = Vector3.new(-17.83, 0, -3.63),
						pos = Vector3.new(0, 0.33, 0),
					},
					LeftHip = { rot = Vector3.new(10.4, 0, 3.14), pos = Vector3.new(0, 0.37, 0) },
				},
			},
			{
				time = 0.9062,
				pose = {
					Root = {
						rot = Vector3.new(0.12, 3.3, -1.02),
						pos = Vector3.new(0.03, -0.28, 0.09),
					},
					Neck = { rot = Vector3.new(-6.42, -3.37, 0.62) },
					RightShoulder = { rot = Vector3.new(18.74, 0, 9.95) },
					LeftShoulder = { rot = Vector3.new(12.9, 0, -10.5) },
					RightHip = {
						rot = Vector3.new(-13.44, 0, -3.22),
						pos = Vector3.new(0, 0.34, 0),
					},
					LeftHip = { rot = Vector3.new(5.98, 0, 2.71), pos = Vector3.new(0, 0.45, 0) },
				},
			},
			{
				time = 0.9375,
				pose = {
					Root = {
						rot = Vector3.new(0.13, 2.58, -1.07),
						pos = Vector3.new(0.03, -0.27, 0.09),
					},
					Neck = { rot = Vector3.new(-6.43, -2.64, 0.75) },
					RightShoulder = { rot = Vector3.new(15.81, 0, 11.22) },
					LeftShoulder = { rot = Vector3.new(15.79, 0, -9.02) },
					RightHip = { rot = Vector3.new(-8.88, 0, -2.94), pos = Vector3.new(0, 0.34, 0) },
					LeftHip = { rot = Vector3.new(1.32, 0, 2.35), pos = Vector3.new(0, 0.51, 0) },
				},
			},
			{
				time = 0.9688,
				pose = {
					Root = {
						rot = Vector3.new(0.13, 1.59, -1.1),
						pos = Vector3.new(0.03, -0.26, 0.08),
					},
					Neck = { rot = Vector3.new(-6.44, -1.64, 0.88) },
					RightShoulder = { rot = Vector3.new(13.01, 0, 12.08) },
					LeftShoulder = { rot = Vector3.new(18.43, 0, -7.6) },
					RightHip = { rot = Vector3.new(-4.59, 0, -2.81), pos = Vector3.new(0, 0.3, 0) },
					LeftHip = { rot = Vector3.new(-3.35, 0, 2.19), pos = Vector3.new(0, 0.53, 0) },
				},
			},
		},
	},
	-- ALS_N_Run_LF: phase clip (one cycle = 1), left foot plants at 0.4375; natural cycle 0.833 s, stride 5.92 studs per cycle
	JogLeft = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-9.49, 30.06, 6.21),
						pos = Vector3.new(0.1, -0.26, -0.05),
					},
					Neck = { rot = Vector3.new(-3.31, -30.49, -3.13) },
					RightShoulder = { rot = Vector3.new(11.31, 0, 15.03) },
					LeftShoulder = { rot = Vector3.new(24.67, 0, -18.45) },
					RightHip = { rot = Vector3.new(8.81, 0, -12.88), pos = Vector3.new(0, 0.19, 0) },
					LeftHip = { rot = Vector3.new(-7.2, 0, 11.76), pos = Vector3.new(0, 0.68, 0) },
				},
			},
			{
				time = 0.0312,
				pose = {
					Root = {
						rot = Vector3.new(-9.71, 30.88, 5.94),
						pos = Vector3.new(0.11, -0.27, -0.05),
					},
					Neck = { rot = Vector3.new(-3.01, -31.39, -2.7) },
					RightShoulder = { rot = Vector3.new(16.9, 0, 13.77) },
					LeftShoulder = { rot = Vector3.new(18.84, 0, -22.42) },
					RightHip = { rot = Vector3.new(6.78, 0, -7.63), pos = Vector3.new(0, 0.24, 0) },
					LeftHip = { rot = Vector3.new(-4.1, 0, 7.38), pos = Vector3.new(0, 0.75, 0) },
				},
			},
			{
				time = 0.0625,
				pose = {
					Root = {
						rot = Vector3.new(-9.91, 32.05, 5.79),
						pos = Vector3.new(0.11, -0.27, -0.06),
					},
					Neck = { rot = Vector3.new(-2.84, -32.62, -2.45) },
					RightShoulder = { rot = Vector3.new(22.38, 0, 11.49) },
					LeftShoulder = { rot = Vector3.new(11.79, 0, -25.29) },
					RightHip = { rot = Vector3.new(3.6, 0, -2.48), pos = Vector3.new(0, 0.27, 0) },
					LeftHip = { rot = Vector3.new(-0.44, 0, 3.99), pos = Vector3.new(0, 0.76, 0) },
				},
			},
			{
				time = 0.0938,
				pose = {
					Root = {
						rot = Vector3.new(-10.11, 33.58, 5.77),
						pos = Vector3.new(0.11, -0.25, -0.06),
					},
					Neck = { rot = Vector3.new(-2.8, -34.2, -2.36) },
					RightShoulder = { rot = Vector3.new(26.64, 0, 9.2) },
					LeftShoulder = { rot = Vector3.new(5.55, 0, -26.52) },
					RightHip = { rot = Vector3.new(0.02, 0, 1.69), pos = Vector3.new(0, 0.31, 0) },
					LeftHip = { rot = Vector3.new(3.44, 0, 1.29), pos = Vector3.new(0, 0.71, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = {
						rot = Vector3.new(-10.31, 35.34, 5.84),
						pos = Vector3.new(0.11, -0.22, -0.06),
					},
					Neck = { rot = Vector3.new(-2.84, -35.98, -2.39) },
					RightShoulder = { rot = Vector3.new(29.66, 0, 7.6) },
					LeftShoulder = { rot = Vector3.new(1.03, 0, -26.69) },
					RightHip = { rot = Vector3.new(-3.2, 0, 5.22), pos = Vector3.new(0, 0.34, 0) },
					LeftHip = { rot = Vector3.new(7.78, 0, -1.68), pos = Vector3.new(0, 0.59, 0) },
				},
			},
			{
				time = 0.1562,
				pose = {
					Root = {
						rot = Vector3.new(-10.51, 37.02, 5.98),
						pos = Vector3.new(0.1, -0.16, -0.06),
					},
					Neck = { rot = Vector3.new(-2.93, -37.68, -2.51) },
					RightShoulder = { rot = Vector3.new(31.97, 0, 6.6) },
					LeftShoulder = { rot = Vector3.new(-2.24, 0, -26.57) },
					RightHip = { rot = Vector3.new(-6.29, 0, 8.84), pos = Vector3.new(0, 0.33, 0) },
					LeftHip = { rot = Vector3.new(12.23, 0, -5.32), pos = Vector3.new(0, 0.44, 0) },
				},
			},
			{
				time = 0.1875,
				pose = {
					Root = {
						rot = Vector3.new(-10.68, 38.37, 6.16),
						pos = Vector3.new(0.1, -0.1, -0.05),
					},
					Neck = { rot = Vector3.new(-3.05, -39.04, -2.68) },
					RightShoulder = { rot = Vector3.new(33.85, 0, 5.88) },
					LeftShoulder = { rot = Vector3.new(-4.75, 0, -26.44) },
					RightHip = { rot = Vector3.new(-8.66, 0, 12.1), pos = Vector3.new(0, 0.31, 0) },
					LeftHip = { rot = Vector3.new(16.52, 0, -9.25), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.2188,
				pose = {
					Root = {
						rot = Vector3.new(-10.8, 39.35, 6.37),
						pos = Vector3.new(0.09, -0.06, -0.05),
					},
					Neck = { rot = Vector3.new(-3.22, -40.03, -2.93) },
					RightShoulder = { rot = Vector3.new(35.42, 0, 5.28) },
					LeftShoulder = { rot = Vector3.new(-6.75, 0, -26.39) },
					RightHip = { rot = Vector3.new(-10.48, 0, 15.3), pos = Vector3.new(0, 0.29, 0) },
					LeftHip = { rot = Vector3.new(19.83, 0, -12.33), pos = Vector3.new(0, 0.26, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(-10.87, 40.01, 6.64),
						pos = Vector3.new(0.08, -0.05, -0.05),
					},
					Neck = { rot = Vector3.new(-3.45, -40.68, -3.26) },
					RightShoulder = { rot = Vector3.new(36.69, 0, 4.76) },
					LeftShoulder = { rot = Vector3.new(-8.34, 0, -26.44) },
					RightHip = {
						rot = Vector3.new(-11.83, 0, 18.32),
						pos = Vector3.new(0, 0.29, 0),
					},
					LeftHip = { rot = Vector3.new(22.18, 0, -14.48), pos = Vector3.new(0, 0.27, 0) },
				},
			},
			{
				time = 0.2812,
				pose = {
					Root = {
						rot = Vector3.new(-10.91, 40.42, 6.95),
						pos = Vector3.new(0.08, -0.04, -0.04),
					},
					Neck = { rot = Vector3.new(-3.74, -41.08, -3.67) },
					RightShoulder = { rot = Vector3.new(37.7, 0, 4.3) },
					LeftShoulder = { rot = Vector3.new(-9.55, 0, -26.62) },
					RightHip = {
						rot = Vector3.new(-12.64, 0, 20.78),
						pos = Vector3.new(0, 0.29, 0),
					},
					LeftHip = { rot = Vector3.new(23.91, 0, -16.06), pos = Vector3.new(0, 0.28, 0) },
				},
			},
			{
				time = 0.3125,
				pose = {
					Root = {
						rot = Vector3.new(-10.91, 40.63, 7.3),
						pos = Vector3.new(0.08, -0.05, -0.03),
					},
					Neck = { rot = Vector3.new(-4.08, -41.27, -4.16) },
					RightShoulder = { rot = Vector3.new(38.41, 0, 3.95) },
					LeftShoulder = { rot = Vector3.new(-10.33, 0, -26.9) },
					RightHip = {
						rot = Vector3.new(-13.03, 0, 22.39),
						pos = Vector3.new(0, 0.33, 0),
					},
					LeftHip = { rot = Vector3.new(24.71, 0, -16.83), pos = Vector3.new(0, 0.29, 0) },
				},
			},
			{
				time = 0.3438,
				pose = {
					Root = {
						rot = Vector3.new(-10.89, 40.69, 7.72),
						pos = Vector3.new(0.08, -0.08, -0.03),
					},
					Neck = { rot = Vector3.new(-4.5, -41.28, -4.76) },
					RightShoulder = { rot = Vector3.new(38.68, 0, 3.93) },
					LeftShoulder = { rot = Vector3.new(-10.35, 0, -27.35) },
					RightHip = {
						rot = Vector3.new(-13.09, 0, 23.07),
						pos = Vector3.new(0, 0.41, 0),
					},
					LeftHip = { rot = Vector3.new(24.19, 0, -16.29), pos = Vector3.new(0, 0.32, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = {
						rot = Vector3.new(-10.88, 40.7, 7.84),
						pos = Vector3.new(0.08, -0.08, -0.03),
					},
					Neck = { rot = Vector3.new(-4.62, -41.28, -4.92) },
					RightShoulder = { rot = Vector3.new(38.76, 0, 3.92) },
					LeftShoulder = { rot = Vector3.new(-10.37, 0, -27.48) },
					RightHip = {
						rot = Vector3.new(-13.07, 0, 23.23),
						pos = Vector3.new(0, 0.43, 0),
					},
					LeftHip = { rot = Vector3.new(24.11, 0, -16.23), pos = Vector3.new(0, 0.32, 0) },
				},
			},
			{
				time = 0.4062,
				pose = {
					Root = {
						rot = Vector3.new(-10.87, 40.68, 7.89),
						pos = Vector3.new(0.08, -0.09, -0.02),
					},
					Neck = { rot = Vector3.new(-4.67, -41.25, -4.99) },
					RightShoulder = { rot = Vector3.new(38.64, 0, 4.04) },
					LeftShoulder = { rot = Vector3.new(-10.14, 0, -27.55) },
					RightHip = {
						rot = Vector3.new(-13.07, 0, 23.11),
						pos = Vector3.new(0, 0.44, 0),
					},
					LeftHip = { rot = Vector3.new(23.6, 0, -15.66), pos = Vector3.new(0, 0.33, 0) },
				},
			},
			{
				time = 0.4375,
				pose = {
					Root = {
						rot = Vector3.new(-10.81, 40.55, 8.26),
						pos = Vector3.new(0.09, -0.16, -0.02),
					},
					Neck = { rot = Vector3.new(-5.05, -41.08, -5.53) },
					RightShoulder = { rot = Vector3.new(37.99, 0, 4.78) },
					LeftShoulder = { rot = Vector3.new(-8.74, 0, -28.01) },
					RightHip = {
						rot = Vector3.new(-12.79, 0, 22.41),
						pos = Vector3.new(0, 0.55, 0),
					},
					LeftHip = { rot = Vector3.new(20.95, 0, -12.8), pos = Vector3.new(0, 0.38, 0) },
				},
			},
			{
				time = 0.4688,
				pose = {
					Root = {
						rot = Vector3.new(-10.72, 40.3, 8.56),
						pos = Vector3.new(0.09, -0.21, -0.01),
					},
					Neck = { rot = Vector3.new(-5.39, -40.77, -6) },
					RightShoulder = { rot = Vector3.new(36.49, 0, 6.14) },
					LeftShoulder = { rot = Vector3.new(-6.07, 0, -28.35) },
					RightHip = {
						rot = Vector3.new(-11.71, 0, 20.46),
						pos = Vector3.new(0, 0.64, 0),
					},
					LeftHip = { rot = Vector3.new(17.92, 0, -9.66), pos = Vector3.new(0, 0.4, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-10.58, 39.88, 8.88),
						pos = Vector3.new(0.1, -0.25, -0.01),
					},
					Neck = { rot = Vector3.new(-5.75, -40.28, -6.5) },
					RightShoulder = { rot = Vector3.new(33.92, 0, 8.19) },
					LeftShoulder = { rot = Vector3.new(-1.8, 0, -28.35) },
					RightHip = { rot = Vector3.new(-9.54, 0, 17.07), pos = Vector3.new(0, 0.7, 0) },
					LeftHip = { rot = Vector3.new(14.82, 0, -6.52), pos = Vector3.new(0, 0.39, 0) },
				},
			},
			{
				time = 0.5312,
				pose = {
					Root = {
						rot = Vector3.new(-10.38, 39.24, 9.18),
						pos = Vector3.new(0.1, -0.27, 0),
					},
					Neck = { rot = Vector3.new(-6.12, -39.55, -7.01) },
					RightShoulder = { rot = Vector3.new(29.77, 0, 10.82) },
					LeftShoulder = { rot = Vector3.new(4.36, 0, -27.35) },
					RightHip = { rot = Vector3.new(-6.52, 0, 12.66), pos = Vector3.new(0, 0.71, 0) },
					LeftHip = { rot = Vector3.new(11.67, 0, -3.58), pos = Vector3.new(0, 0.35, 0) },
				},
			},
			{
				time = 0.5625,
				pose = {
					Root = {
						rot = Vector3.new(-10.11, 38.31, 9.35),
						pos = Vector3.new(0.11, -0.27, 0),
					},
					Neck = { rot = Vector3.new(-6.38, -38.52, -7.35) },
					RightShoulder = { rot = Vector3.new(24.2, 0, 13.24) },
					LeftShoulder = { rot = Vector3.new(11.38, 0, -24.78) },
					RightHip = { rot = Vector3.new(-2.9, 0, 7.66), pos = Vector3.new(0, 0.67, 0) },
					LeftHip = { rot = Vector3.new(8.49, 0, -0.69), pos = Vector3.new(0, 0.32, 0) },
				},
			},
			{
				time = 0.5938,
				pose = {
					Root = {
						rot = Vector3.new(-9.78, 37.03, 9.35),
						pos = Vector3.new(0.11, -0.26, 0),
					},
					Neck = { rot = Vector3.new(-6.46, -37.16, -7.44) },
					RightShoulder = { rot = Vector3.new(18.44, 0, 14.48) },
					LeftShoulder = { rot = Vector3.new(17.26, 0, -21.11) },
					RightHip = { rot = Vector3.new(1.31, 0, 2.26), pos = Vector3.new(0, 0.59, 0) },
					LeftHip = { rot = Vector3.new(5.2, 0, 2.61), pos = Vector3.new(0, 0.32, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = {
						rot = Vector3.new(-9.43, 35.4, 9.25),
						pos = Vector3.new(0.11, -0.24, 0.01),
					},
					Neck = { rot = Vector3.new(-6.4, -35.48, -7.35) },
					RightShoulder = { rot = Vector3.new(13.89, 0, 14.54) },
					LeftShoulder = { rot = Vector3.new(21.18, 0, -17.91) },
					RightHip = { rot = Vector3.new(6.02, 0, -3.54), pos = Vector3.new(0, 0.48, 0) },
					LeftHip = { rot = Vector3.new(1.94, 0, 5.94), pos = Vector3.new(0, 0.31, 0) },
				},
			},
			{
				time = 0.6562,
				pose = {
					Root = {
						rot = Vector3.new(-9.1, 33.64, 9.1),
						pos = Vector3.new(0.1, -0.2, 0.01),
					},
					Neck = { rot = Vector3.new(-6.26, -33.7, -7.16) },
					RightShoulder = { rot = Vector3.new(10.55, 0, 14.1) },
					LeftShoulder = { rot = Vector3.new(23.78, 0, -15.6) },
					RightHip = { rot = Vector3.new(11.17, 0, -9.84), pos = Vector3.new(0, 0.31, 0) },
					LeftHip = { rot = Vector3.new(-1.04, 0, 9.34), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.6875,
				pose = {
					Root = {
						rot = Vector3.new(-8.85, 32.07, 8.94),
						pos = Vector3.new(0.09, -0.14, 0),
					},
					Neck = { rot = Vector3.new(-6.09, -32.11, -6.93) },
					RightShoulder = { rot = Vector3.new(8.02, 0, 13.64) },
					LeftShoulder = { rot = Vector3.new(25.76, 0, -13.97) },
					RightHip = {
						rot = Vector3.new(16.23, 0, -15.95),
						pos = Vector3.new(0, 0.11, 0),
					},
					LeftHip = { rot = Vector3.new(-3.55, 0, 12.75), pos = Vector3.new(0, 0.17, 0) },
				},
			},
			{
				time = 0.7188,
				pose = {
					Root = {
						rot = Vector3.new(-8.68, 30.86, 8.77),
						pos = Vector3.new(0.08, -0.08, 0),
					},
					Neck = { rot = Vector3.new(-5.91, -30.9, -6.69) },
					RightShoulder = { rot = Vector3.new(5.98, 0, 13.33) },
					LeftShoulder = { rot = Vector3.new(27.38, 0, -12.71) },
					RightHip = { rot = Vector3.new(20.21, 0, -20.59) },
					LeftHip = { rot = Vector3.new(-5.67, 0, 16.09), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = { rot = Vector3.new(-8.59, 30, 8.57), pos = Vector3.new(0.07, -0.05, 0) },
					Neck = { rot = Vector3.new(-5.7, -30.05, -6.41) },
					RightShoulder = { rot = Vector3.new(4.31, 0, 13.19) },
					LeftShoulder = { rot = Vector3.new(28.74, 0, -11.71) },
					RightHip = { rot = Vector3.new(22.45, 0, -23.2), pos = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(-7.65, 0, 19.32), pos = Vector3.new(0, 0.01, 0) },
				},
			},
			{
				time = 0.7812,
				pose = {
					Root = {
						rot = Vector3.new(-8.58, 29.43, 8.33),
						pos = Vector3.new(0.06, -0.04, -0.01),
					},
					Neck = { rot = Vector3.new(-5.46, -29.51, -6.09) },
					RightShoulder = { rot = Vector3.new(3, 0, 13.23) },
					LeftShoulder = { rot = Vector3.new(29.88, 0, -10.9) },
					RightHip = { rot = Vector3.new(24, 0, -24.98) },
					LeftHip = { rot = Vector3.new(-9.35, 0, 21.79) },
				},
			},
			{
				time = 0.8125,
				pose = {
					Root = {
						rot = Vector3.new(-8.62, 29.09, 8.05),
						pos = Vector3.new(0.06, -0.04, -0.01),
					},
					Neck = { rot = Vector3.new(-5.18, -29.2, -5.7) },
					RightShoulder = { rot = Vector3.new(2.06, 0, 13.43) },
					LeftShoulder = { rot = Vector3.new(30.81, 0, -10.27) },
					RightHip = { rot = Vector3.new(24.95, 0, -26.22) },
					LeftHip = { rot = Vector3.new(-11.22, 0, 24.07) },
				},
			},
			{
				time = 0.8438,
				pose = {
					Root = {
						rot = Vector3.new(-8.71, 28.93, 7.74),
						pos = Vector3.new(0.06, -0.05, -0.02),
					},
					Neck = { rot = Vector3.new(-4.87, -29.08, -5.28) },
					RightShoulder = { rot = Vector3.new(1.56, 0, 13.76) },
					LeftShoulder = { rot = Vector3.new(31.46, 0, -9.91) },
					RightHip = { rot = Vector3.new(25.16, 0, -26.32) },
					LeftHip = { rot = Vector3.new(-12.94, 0, 25.89), pos = Vector3.new(0, 0.01, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = {
						rot = Vector3.new(-8.83, 28.89, 7.42),
						pos = Vector3.new(0.06, -0.08, -0.03),
					},
					Neck = { rot = Vector3.new(-4.56, -29.09, -4.85) },
					RightShoulder = { rot = Vector3.new(1.62, 0, 14.17) },
					LeftShoulder = { rot = Vector3.new(31.72, 0, -10.01) },
					RightHip = { rot = Vector3.new(24.35, 0, -25.38) },
					LeftHip = { rot = Vector3.new(-13.78, 0, 26.06), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.9062,
				pose = {
					Root = {
						rot = Vector3.new(-8.96, 28.96, 7.12),
						pos = Vector3.new(0.07, -0.13, -0.03),
					},
					Neck = { rot = Vector3.new(-4.26, -29.21, -4.44) },
					RightShoulder = { rot = Vector3.new(2.39, 0, 14.61) },
					LeftShoulder = { rot = Vector3.new(31.44, 0, -10.76) },
					RightHip = { rot = Vector3.new(21.33, 0, -24.65) },
					LeftHip = { rot = Vector3.new(-13.99, 0, 24.75), pos = Vector3.new(0, 0.22, 0) },
				},
			},
			{
				time = 0.9375,
				pose = {
					Root = {
						rot = Vector3.new(-9.1, 29.16, 6.84),
						pos = Vector3.new(0.08, -0.19, -0.04),
					},
					Neck = { rot = Vector3.new(-3.97, -29.46, -4.05) },
					RightShoulder = { rot = Vector3.new(4.1, 0, 15) },
					LeftShoulder = { rot = Vector3.new(30.41, 0, -12.35) },
					RightHip = { rot = Vector3.new(16.56, 0, -21.9), pos = Vector3.new(0, 0.07, 0) },
					LeftHip = { rot = Vector3.new(-10.87, 0, 20.76), pos = Vector3.new(0, 0.4, 0) },
				},
			},
			{
				time = 0.9688,
				pose = {
					Root = {
						rot = Vector3.new(-9.28, 29.51, 6.54),
						pos = Vector3.new(0.09, -0.24, -0.04),
					},
					Neck = { rot = Vector3.new(-3.66, -29.87, -3.62) },
					RightShoulder = { rot = Vector3.new(6.99, 0, 15.26) },
					LeftShoulder = { rot = Vector3.new(28.35, 0, -14.91) },
					RightHip = {
						rot = Vector3.new(11.89, 0, -17.49),
						pos = Vector3.new(0, 0.15, 0),
					},
					LeftHip = { rot = Vector3.new(-7.89, 0, 15.86), pos = Vector3.new(0, 0.57, 0) },
				},
			},
		},
	},
	-- ALS_N_Run_RF: phase clip (one cycle = 1), left foot plants at 0.4375; natural cycle 0.833 s, stride 5.92 studs per cycle
	JogRight = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-9.77, -36.73, -9.64),
						pos = Vector3.new(-0.11, -0.26, 0.01),
					},
					Neck = { rot = Vector3.new(-6.53, 36.92, 7.59) },
					RightShoulder = { rot = Vector3.new(18.21, 0, 20.09) },
					LeftShoulder = { rot = Vector3.new(17.38, 0, -15) },
					RightHip = { rot = Vector3.new(4.4, 0, -2.64), pos = Vector3.new(0, 0.33, 0) },
					LeftHip = { rot = Vector3.new(2.39, 0, -0.39), pos = Vector3.new(0, 0.56, 0) },
				},
			},
			{
				time = 0.0312,
				pose = {
					Root = {
						rot = Vector3.new(-9.47, -35.04, -9.54),
						pos = Vector3.new(-0.11, -0.24, 0.01),
					},
					Neck = { rot = Vector3.new(-6.42, 35.2, 7.46) },
					RightShoulder = { rot = Vector3.new(21.77, 0, 17.05) },
					LeftShoulder = { rot = Vector3.new(13.09, 0, -14.87) },
					RightHip = { rot = Vector3.new(1.26, 0, -6.01), pos = Vector3.new(0, 0.31, 0) },
					LeftHip = { rot = Vector3.new(7.27, 0, 5.47), pos = Vector3.new(0, 0.44, 0) },
				},
			},
			{
				time = 0.0625,
				pose = {
					Root = {
						rot = Vector3.new(-9.19, -33.3, -9.39),
						pos = Vector3.new(-0.1, -0.19, 0.01),
					},
					Neck = { rot = Vector3.new(-6.24, 33.43, 7.25) },
					RightShoulder = { rot = Vector3.new(24.2, 0, 14.89) },
					LeftShoulder = { rot = Vector3.new(9.94, 0, -14.37) },
					RightHip = { rot = Vector3.new(-1.53, 0, -9.49), pos = Vector3.new(0, 0.24, 0) },
					LeftHip = { rot = Vector3.new(12.57, 0, 11.8), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.0938,
				pose = {
					Root = {
						rot = Vector3.new(-8.98, -31.78, -9.23),
						pos = Vector3.new(-0.09, -0.12, 0),
					},
					Neck = { rot = Vector3.new(-6.05, 31.91, 7.01) },
					RightShoulder = { rot = Vector3.new(26.07, 0, 13.33) },
					LeftShoulder = { rot = Vector3.new(7.52, 0, -13.91) },
					RightHip = {
						rot = Vector3.new(-3.84, 0, -12.93),
						pos = Vector3.new(0, 0.16, 0),
					},
					LeftHip = { rot = Vector3.new(17.51, 0, 17.56), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = {
						rot = Vector3.new(-8.85, -30.64, -9.06),
						pos = Vector3.new(-0.08, -0.07, 0),
					},
					Neck = { rot = Vector3.new(-5.85, 30.77, 6.76) },
					RightShoulder = { rot = Vector3.new(27.63, 0, 12.11) },
					LeftShoulder = { rot = Vector3.new(5.56, 0, -13.61) },
					RightHip = {
						rot = Vector3.new(-5.84, 0, -16.42),
						pos = Vector3.new(0, 0.07, 0),
					},
					LeftHip = { rot = Vector3.new(21.1, 0, 21.59), pos = Vector3.new(0, -0.01, 0) },
				},
			},
			{
				time = 0.1562,
				pose = {
					Root = {
						rot = Vector3.new(-8.79, -29.85, -8.86),
						pos = Vector3.new(-0.07, -0.05, 0),
					},
					Neck = { rot = Vector3.new(-5.63, 29.99, 6.47) },
					RightShoulder = { rot = Vector3.new(28.93, 0, 11.13) },
					LeftShoulder = { rot = Vector3.new(3.96, 0, -13.49) },
					RightHip = { rot = Vector3.new(-7.73, 0, -19.75) },
					LeftHip = { rot = Vector3.new(23.11, 0, 23.86) },
				},
			},
			{
				time = 0.1875,
				pose = {
					Root = {
						rot = Vector3.new(-8.8, -29.33, -8.62),
						pos = Vector3.new(-0.06, -0.04, -0.01),
					},
					Neck = { rot = Vector3.new(-5.37, 29.51, 6.13) },
					RightShoulder = { rot = Vector3.new(30.01, 0, 10.34) },
					LeftShoulder = { rot = Vector3.new(2.73, 0, -13.56) },
					RightHip = { rot = Vector3.new(-9.41, 0, -21.96) },
					LeftHip = { rot = Vector3.new(24.55, 0, 25.52) },
				},
			},
			{
				time = 0.2188,
				pose = {
					Root = {
						rot = Vector3.new(-8.86, -29.02, -8.34),
						pos = Vector3.new(-0.06, -0.04, -0.01),
					},
					Neck = { rot = Vector3.new(-5.09, 29.24, 5.75) },
					RightShoulder = { rot = Vector3.new(30.89, 0, 9.7) },
					LeftShoulder = { rot = Vector3.new(1.84, 0, -13.76) },
					RightHip = {
						rot = Vector3.new(-11.32, 0, -24.25),
						pos = Vector3.new(0, -0.01, 0),
					},
					LeftHip = { rot = Vector3.new(25.48, 0, 26.58) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(-8.97, -28.9, -7.99),
						pos = Vector3.new(-0.06, -0.06, -0.02),
					},
					Neck = { rot = Vector3.new(-4.74, 29.16, 5.28) },
					RightShoulder = { rot = Vector3.new(31.44, 0, 9.49) },
					LeftShoulder = { rot = Vector3.new(1.53, 0, -14.15) },
					RightHip = {
						rot = Vector3.new(-12.89, 0, -25.55),
						pos = Vector3.new(0, 0.03, 0),
					},
					LeftHip = { rot = Vector3.new(25.19, 0, 26.36) },
				},
			},
			{
				time = 0.2812,
				pose = {
					Root = {
						rot = Vector3.new(-9.06, -28.88, -7.73),
						pos = Vector3.new(-0.06, -0.08, -0.03),
					},
					Neck = { rot = Vector3.new(-4.48, 29.18, 4.92) },
					RightShoulder = { rot = Vector3.new(31.64, 0, 9.57) },
					LeftShoulder = { rot = Vector3.new(1.6, 0, -14.49) },
					RightHip = {
						rot = Vector3.new(-13.49, 0, -25.44),
						pos = Vector3.new(0, 0.1, 0),
					},
					LeftHip = { rot = Vector3.new(24.52, 0, 25.5) },
				},
			},
			{
				time = 0.3125,
				pose = {
					Root = {
						rot = Vector3.new(-9.06, -28.87, -7.75),
						pos = Vector3.new(-0.06, -0.08, -0.03),
					},
					Neck = { rot = Vector3.new(-4.5, 29.17, 4.95) },
					RightShoulder = { rot = Vector3.new(31.65, 0, 9.53) },
					LeftShoulder = { rot = Vector3.new(1.56, 0, -14.46) },
					RightHip = {
						rot = Vector3.new(-13.48, 0, -25.52),
						pos = Vector3.new(0, 0.09, 0),
					},
					LeftHip = { rot = Vector3.new(24.68, 0, 25.53) },
				},
			},
			{
				time = 0.3438,
				pose = {
					Root = {
						rot = Vector3.new(-9.15, -28.94, -7.52),
						pos = Vector3.new(-0.06, -0.13, -0.03),
					},
					Neck = { rot = Vector3.new(-4.27, 29.28, 4.63) },
					RightShoulder = { rot = Vector3.new(31.38, 0, 10.18) },
					LeftShoulder = { rot = Vector3.new(2.23, 0, -14.8) },
					RightHip = {
						rot = Vector3.new(-13.31, 0, -24.2),
						pos = Vector3.new(0, 0.21, 0),
					},
					LeftHip = { rot = Vector3.new(22.14, 0, 25.24), pos = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = {
						rot = Vector3.new(-9.29, -29.13, -7.2),
						pos = Vector3.new(-0.08, -0.19, -0.04),
					},
					Neck = { rot = Vector3.new(-3.96, 29.52, 4.19) },
					RightShoulder = { rot = Vector3.new(30.45, 0, 11.72) },
					LeftShoulder = { rot = Vector3.new(3.89, 0, -15.26) },
					RightHip = {
						rot = Vector3.new(-12.22, 0, -21.17),
						pos = Vector3.new(0, 0.39, 0),
					},
					LeftHip = { rot = Vector3.new(17.33, 0, 22.71), pos = Vector3.new(0, 0.05, 0) },
				},
			},
			{
				time = 0.4062,
				pose = {
					Root = {
						rot = Vector3.new(-9.43, -29.47, -6.9),
						pos = Vector3.new(-0.09, -0.24, -0.04),
					},
					Neck = { rot = Vector3.new(-3.68, 29.91, 3.78) },
					RightShoulder = { rot = Vector3.new(28.49, 0, 14.21) },
					LeftShoulder = { rot = Vector3.new(6.67, 0, -15.53) },
					RightHip = {
						rot = Vector3.new(-9.95, 0, -16.71),
						pos = Vector3.new(0, 0.56, 0),
					},
					LeftHip = { rot = Vector3.new(12.52, 0, 18.43), pos = Vector3.new(0, 0.14, 0) },
				},
			},
			{
				time = 0.4375,
				pose = {
					Root = {
						rot = Vector3.new(-9.59, -30, -6.55),
						pos = Vector3.new(-0.1, -0.26, -0.05),
					},
					Neck = { rot = Vector3.new(-3.35, 30.51, 3.3) },
					RightShoulder = { rot = Vector3.new(25, 0, 17.7) },
					LeftShoulder = { rot = Vector3.new(10.87, 0, -15.38) },
					RightHip = { rot = Vector3.new(-7.1, 0, -11.49), pos = Vector3.new(0, 0.68, 0) },
					LeftHip = { rot = Vector3.new(9.21, 0, 13.9), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 0.4688,
				pose = {
					Root = {
						rot = Vector3.new(-9.75, -30.81, -6.24),
						pos = Vector3.new(-0.1, -0.27, -0.05),
					},
					Neck = { rot = Vector3.new(-3.07, 31.38, 2.86) },
					RightShoulder = { rot = Vector3.new(19.35, 0, 21.72) },
					LeftShoulder = { rot = Vector3.new(16.42, 0, -14.23) },
					RightHip = { rot = Vector3.new(-4.07, 0, -6.99), pos = Vector3.new(0, 0.76, 0) },
					LeftHip = { rot = Vector3.new(7.09, 0, 8.75), pos = Vector3.new(0, 0.23, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-9.88, -31.95, -6.04),
						pos = Vector3.new(-0.11, -0.27, -0.05),
					},
					Neck = { rot = Vector3.new(-2.93, 32.58, 2.6) },
					RightShoulder = { rot = Vector3.new(12.38, 0, 24.75) },
					LeftShoulder = { rot = Vector3.new(21.97, 0, -12.02) },
					RightHip = { rot = Vector3.new(-0.76, 0, -3.61), pos = Vector3.new(0, 0.77, 0) },
					LeftHip = { rot = Vector3.new(3.98, 0, 3.36), pos = Vector3.new(0, 0.27, 0) },
				},
			},
			{
				time = 0.5312,
				pose = {
					Root = {
						rot = Vector3.new(-10.01, -33.47, -5.97),
						pos = Vector3.new(-0.11, -0.25, -0.06),
					},
					Neck = { rot = Vector3.new(-2.9, 34.13, 2.5) },
					RightShoulder = { rot = Vector3.new(6.03, 0, 26.14) },
					LeftShoulder = { rot = Vector3.new(26.37, 0, -9.71) },
					RightHip = { rot = Vector3.new(2.98, 0, -0.89), pos = Vector3.new(0, 0.72, 0) },
					LeftHip = { rot = Vector3.new(0.28, 0, -0.97), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.5625,
				pose = {
					Root = {
						rot = Vector3.new(-10.16, -35.22, -6),
						pos = Vector3.new(-0.11, -0.22, -0.06),
					},
					Neck = { rot = Vector3.new(-2.96, 35.91, 2.52) },
					RightShoulder = { rot = Vector3.new(1.4, 0, 26.38) },
					LeftShoulder = { rot = Vector3.new(29.46, 0, -8.08) },
					RightHip = { rot = Vector3.new(7.14, 0, 2), pos = Vector3.new(0, 0.61, 0) },
					LeftHip = { rot = Vector3.new(-3.08, 0, -4.34), pos = Vector3.new(0, 0.33, 0) },
				},
			},
			{
				time = 0.5938,
				pose = {
					Root = {
						rot = Vector3.new(-10.32, -36.92, -6.11),
						pos = Vector3.new(-0.1, -0.16, -0.06),
					},
					Neck = { rot = Vector3.new(-3.07, 37.63, 2.64) },
					RightShoulder = { rot = Vector3.new(-1.94, 0, 26.3) },
					LeftShoulder = { rot = Vector3.new(31.83, 0, -7.07) },
					RightHip = { rot = Vector3.new(11.52, 0, 5.58), pos = Vector3.new(0, 0.46, 0) },
					LeftHip = { rot = Vector3.new(-6.24, 0, -8.05), pos = Vector3.new(0, 0.33, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = {
						rot = Vector3.new(-10.46, -38.31, -6.26),
						pos = Vector3.new(-0.1, -0.1, -0.05),
					},
					Neck = { rot = Vector3.new(-3.21, 39.02, 2.81) },
					RightShoulder = { rot = Vector3.new(-4.49, 0, 26.18) },
					LeftShoulder = { rot = Vector3.new(33.75, 0, -6.36) },
					RightHip = { rot = Vector3.new(15.85, 0, 9.5), pos = Vector3.new(0, 0.31, 0) },
					LeftHip = { rot = Vector3.new(-8.71, 0, -11.44), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.6562,
				pose = {
					Root = {
						rot = Vector3.new(-10.56, -39.32, -6.45),
						pos = Vector3.new(-0.09, -0.06, -0.05),
					},
					Neck = { rot = Vector3.new(-3.38, 40.03, 3.05) },
					RightShoulder = { rot = Vector3.new(-6.53, 0, 26.14) },
					LeftShoulder = { rot = Vector3.new(35.34, 0, -5.79) },
					RightHip = { rot = Vector3.new(19.28, 0, 12.6), pos = Vector3.new(0, 0.26, 0) },
					LeftHip = { rot = Vector3.new(-10.6, 0, -14.67), pos = Vector3.new(0, 0.29, 0) },
				},
			},
			{
				time = 0.6875,
				pose = {
					Root = {
						rot = Vector3.new(-10.62, -40, -6.7),
						pos = Vector3.new(-0.08, -0.05, -0.05),
					},
					Neck = { rot = Vector3.new(-3.61, 40.71, 3.37) },
					RightShoulder = { rot = Vector3.new(-8.16, 0, 26.2) },
					LeftShoulder = { rot = Vector3.new(36.65, 0, -5.29) },
					RightHip = { rot = Vector3.new(21.73, 0, 14.74), pos = Vector3.new(0, 0.28, 0) },
					LeftHip = { rot = Vector3.new(-12, 0, -17.72), pos = Vector3.new(0, 0.28, 0) },
				},
			},
			{
				time = 0.7188,
				pose = {
					Root = {
						rot = Vector3.new(-10.64, -40.43, -7.01),
						pos = Vector3.new(-0.08, -0.04, -0.04),
					},
					Neck = { rot = Vector3.new(-3.91, 41.12, 3.78) },
					RightShoulder = { rot = Vector3.new(-9.4, 0, 26.38) },
					LeftShoulder = { rot = Vector3.new(37.68, 0, -4.86) },
					RightHip = { rot = Vector3.new(23.52, 0, 16.3), pos = Vector3.new(0, 0.28, 0) },
					LeftHip = { rot = Vector3.new(-12.86, 0, -20.2), pos = Vector3.new(0, 0.29, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(-10.64, -40.66, -7.37),
						pos = Vector3.new(-0.08, -0.05, -0.03),
					},
					Neck = { rot = Vector3.new(-4.25, 41.33, 4.27) },
					RightShoulder = { rot = Vector3.new(-10.21, 0, 26.68) },
					LeftShoulder = { rot = Vector3.new(38.42, 0, -4.53) },
					RightHip = { rot = Vector3.new(24.36, 0, 17.09), pos = Vector3.new(0, 0.29, 0) },
					LeftHip = {
						rot = Vector3.new(-13.28, 0, -21.87),
						pos = Vector3.new(0, 0.32, 0),
					},
				},
			},
			{
				time = 0.7812,
				pose = {
					Root = {
						rot = Vector3.new(-10.62, -40.74, -7.74),
						pos = Vector3.new(-0.08, -0.07, -0.03),
					},
					Neck = { rot = Vector3.new(-4.62, 41.38, 4.79) },
					RightShoulder = { rot = Vector3.new(-10.44, 0, 27.06) },
					LeftShoulder = { rot = Vector3.new(38.78, 0, -4.43) },
					RightHip = { rot = Vector3.new(24.29, 0, 17.02), pos = Vector3.new(0, 0.31, 0) },
					LeftHip = {
						rot = Vector3.new(-13.35, 0, -22.66),
						pos = Vector3.new(0, 0.38, 0),
					},
				},
			},
			{
				time = 0.8125,
				pose = {
					Root = {
						rot = Vector3.new(-10.59, -40.7, -8.1),
						pos = Vector3.new(-0.08, -0.11, -0.02),
					},
					Neck = { rot = Vector3.new(-4.98, 41.3, 5.3) },
					RightShoulder = { rot = Vector3.new(-9.88, 0, 27.48) },
					LeftShoulder = { rot = Vector3.new(38.64, 0, -4.73) },
					RightHip = { rot = Vector3.new(22.8, 0, 15.46), pos = Vector3.new(0, 0.35, 0) },
					LeftHip = {
						rot = Vector3.new(-13.28, 0, -22.62),
						pos = Vector3.new(0, 0.46, 0),
					},
				},
			},
			{
				time = 0.8438,
				pose = {
					Root = {
						rot = Vector3.new(-10.55, -40.55, -8.44),
						pos = Vector3.new(-0.09, -0.17, -0.02),
					},
					Neck = { rot = Vector3.new(-5.31, 41.11, 5.77) },
					RightShoulder = { rot = Vector3.new(-8.27, 0, 27.89) },
					LeftShoulder = { rot = Vector3.new(37.82, 0, -5.57) },
					RightHip = { rot = Vector3.new(20.05, 0, 12.66), pos = Vector3.new(0, 0.39, 0) },
					LeftHip = {
						rot = Vector3.new(-12.87, 0, -21.63),
						pos = Vector3.new(0, 0.56, 0),
					},
				},
			},
			{
				time = 0.875,
				pose = {
					Root = {
						rot = Vector3.new(-10.49, -40.27, -8.76),
						pos = Vector3.new(-0.09, -0.22, -0.01),
					},
					Neck = { rot = Vector3.new(-5.63, 40.77, 6.24) },
					RightShoulder = { rot = Vector3.new(-5.31, 0, 28.17) },
					LeftShoulder = { rot = Vector3.new(36.13, 0, -7.06) },
					RightHip = { rot = Vector3.new(16.97, 0, 9.61), pos = Vector3.new(0, 0.41, 0) },
					LeftHip = {
						rot = Vector3.new(-11.56, 0, -19.34),
						pos = Vector3.new(0, 0.65, 0),
					},
				},
			},
			{
				time = 0.9062,
				pose = {
					Root = {
						rot = Vector3.new(-10.39, -39.8, -9.13),
						pos = Vector3.new(-0.1, -0.25, -0.01),
					},
					Neck = { rot = Vector3.new(-5.99, 40.24, 6.77) },
					RightShoulder = { rot = Vector3.new(-0.66, 0, 28.04) },
					LeftShoulder = { rot = Vector3.new(33.27, 0, -9.23) },
					RightHip = { rot = Vector3.new(13.84, 0, 6.53), pos = Vector3.new(0, 0.39, 0) },
					LeftHip = { rot = Vector3.new(-9.12, 0, -15.63), pos = Vector3.new(0, 0.69, 0) },
				},
			},
			{
				time = 0.9375,
				pose = {
					Root = {
						rot = Vector3.new(-10.24, -39.1, -9.46),
						pos = Vector3.new(-0.11, -0.27, 0),
					},
					Neck = { rot = Vector3.new(-6.32, 39.45, 7.25) },
					RightShoulder = { rot = Vector3.new(5.81, 0, 26.71) },
					LeftShoulder = { rot = Vector3.new(28.76, 0, -11.87) },
					RightHip = { rot = Vector3.new(10.78, 0, 3.67), pos = Vector3.new(0, 0.35, 0) },
					LeftHip = { rot = Vector3.new(-5.87, 0, -11.01), pos = Vector3.new(0, 0.69, 0) },
				},
			},
			{
				time = 0.9688,
				pose = {
					Root = {
						rot = Vector3.new(-10.03, -38.1, -9.64),
						pos = Vector3.new(-0.11, -0.27, 0),
					},
					Neck = { rot = Vector3.new(-6.51, 38.36, 7.55) },
					RightShoulder = { rot = Vector3.new(12.72, 0, 23.81) },
					LeftShoulder = { rot = Vector3.new(23.01, 0, -14.07) },
					RightHip = { rot = Vector3.new(7.66, 0, 0.7), pos = Vector3.new(0, 0.32, 0) },
					LeftHip = { rot = Vector3.new(-2.02, 0, -5.88), pos = Vector3.new(0, 0.65, 0) },
				},
			},
		},
	},
	-- ALS_N_Sprint_F: phase clip (one cycle = 1), left foot plants at 0.4375; natural cycle 0.633 s, stride 6.98 studs per cycle
	Sprint = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-18.4, -1.74, -3.19),
						pos = Vector3.new(0, -0.23, -0.06),
					},
					Neck = { rot = Vector3.new(13.99, 2.33, 2.64) },
					RightShoulder = { rot = Vector3.new(53.6, 0, 8.68) },
					LeftShoulder = { rot = Vector3.new(19.56, 0, -22.93) },
					RightHip = { rot = Vector3.new(13.22, 0, 0.7), pos = Vector3.new(0, 0.27, 0) },
					LeftHip = { rot = Vector3.new(1.16, 0, 3.78), pos = Vector3.new(0, 1.08, 0) },
				},
			},
			{
				time = 0.0312,
				pose = {
					Root = {
						rot = Vector3.new(-18.48, -0.24, -3.35),
						pos = Vector3.new(0, -0.23, -0.06),
					},
					Neck = { rot = Vector3.new(14.11, 0.86, 3.18) },
					RightShoulder = { rot = Vector3.new(60.36, 0, 5.57) },
					LeftShoulder = { rot = Vector3.new(4.89, 0, -24.77) },
					RightHip = { rot = Vector3.new(6.25, 0, 1.49), pos = Vector3.new(0, 0.3, 0) },
					LeftHip = { rot = Vector3.new(7.47, 0, 4.02), pos = Vector3.new(0, 1.03, 0) },
				},
			},
			{
				time = 0.0625,
				pose = {
					Root = {
						rot = Vector3.new(-18.04, 1.25, -3.34),
						pos = Vector3.new(0, -0.23, -0.06),
					},
					Neck = { rot = Vector3.new(13.74, -0.65, 3.55) },
					RightShoulder = { rot = Vector3.new(66.34, 0, 2.59) },
					LeftShoulder = { rot = Vector3.new(-8.73, 0, -26.17) },
					RightHip = { rot = Vector3.new(-1.08, 0, 1.57), pos = Vector3.new(0, 0.3, 0) },
					LeftHip = { rot = Vector3.new(12.82, 0, 4.61), pos = Vector3.new(0, 0.94, 0) },
				},
			},
			{
				time = 0.0938,
				pose = {
					Root = {
						rot = Vector3.new(-17.26, 2.67, -3.19),
						pos = Vector3.new(0, -0.22, -0.07),
					},
					Neck = { rot = Vector3.new(13.07, -2.14, 3.75) },
					RightShoulder = { rot = Vector3.new(71.78, 0, -0.41) },
					LeftShoulder = { rot = Vector3.new(-20.6, 0, -27.76) },
					RightHip = { rot = Vector3.new(-7.82, 0, 1.11), pos = Vector3.new(0, 0.27, 0) },
					LeftHip = { rot = Vector3.new(17.24, 0, 5.5), pos = Vector3.new(0, 0.84, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = {
						rot = Vector3.new(-16.29, 4.01, -2.93),
						pos = Vector3.new(0, -0.21, -0.08),
					},
					Neck = { rot = Vector3.new(12.19, -3.57, 3.75) },
					RightShoulder = { rot = Vector3.new(76.3, 0, -2.99) },
					LeftShoulder = { rot = Vector3.new(-30.26, 0, -29.53) },
					RightHip = { rot = Vector3.new(-13.91, 0, 0.24), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(21.32, 0, 6.56), pos = Vector3.new(0, 0.71, 0) },
				},
			},
			{
				time = 0.1562,
				pose = {
					Root = {
						rot = Vector3.new(-15.24, 5.22, -2.58),
						pos = Vector3.new(0, -0.19, -0.09),
					},
					Neck = { rot = Vector3.new(11.2, -4.89, 3.58) },
					RightShoulder = { rot = Vector3.new(79.21, 0, -4.41) },
					LeftShoulder = { rot = Vector3.new(-37.04, 0, -31.16) },
					RightHip = { rot = Vector3.new(-19.6, 0, -0.89), pos = Vector3.new(0, 0.16, 0) },
					LeftHip = { rot = Vector3.new(25.76, 0, 7.67), pos = Vector3.new(0, 0.54, 0) },
				},
			},
			{
				time = 0.1875,
				pose = {
					Root = {
						rot = Vector3.new(-14.27, 6.24, -2.13),
						pos = Vector3.new(0, -0.16, -0.1),
					},
					Neck = { rot = Vector3.new(10.24, -6.02, 3.23) },
					RightShoulder = { rot = Vector3.new(79.68, 0, -3.95) },
					LeftShoulder = { rot = Vector3.new(-39.68, 0, -32.28) },
					RightHip = {
						rot = Vector3.new(-24.72, 0, -2.09),
						pos = Vector3.new(0, 0.14, 0),
					},
					LeftHip = { rot = Vector3.new(30.89, 0, 8.78), pos = Vector3.new(0, 0.32, 0) },
				},
			},
			{
				time = 0.2188,
				pose = {
					Root = {
						rot = Vector3.new(-13.47, 7.04, -1.63),
						pos = Vector3.new(0, -0.14, -0.11),
					},
					Neck = { rot = Vector3.new(9.39, -6.91, 2.77) },
					RightShoulder = { rot = Vector3.new(77.73, 0, -1.71) },
					LeftShoulder = { rot = Vector3.new(-38.03, 0, -32.88) },
					RightHip = {
						rot = Vector3.new(-28.89, 0, -3.19),
						pos = Vector3.new(0, 0.17, 0),
					},
					LeftHip = { rot = Vector3.new(35.87, 0, 9.53), pos = Vector3.new(0, 0.11, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(-12.88, 7.59, -1.12),
						pos = Vector3.new(0, -0.12, -0.12),
					},
					Neck = { rot = Vector3.new(8.71, -7.54, 2.24) },
					RightShoulder = { rot = Vector3.new(74.37, 0, 1.26) },
					LeftShoulder = { rot = Vector3.new(-33.1, 0, -33.32) },
					RightHip = {
						rot = Vector3.new(-31.51, 0, -4.09),
						pos = Vector3.new(0, 0.23, 0),
					},
					LeftHip = { rot = Vector3.new(38.8, 0, 9.19), pos = Vector3.new(0, 0.03, 0) },
				},
			},
			{
				time = 0.2812,
				pose = {
					Root = {
						rot = Vector3.new(-12.82, 7.71, -0.51),
						pos = Vector3.new(0, -0.12, -0.12),
					},
					Neck = { rot = Vector3.new(8.55, -7.72, 1.59) },
					RightShoulder = { rot = Vector3.new(69.76, 0, 4.66) },
					LeftShoulder = { rot = Vector3.new(-22.99, 0, -32.75) },
					RightHip = {
						rot = Vector3.new(-31.25, 0, -4.62),
						pos = Vector3.new(0, 0.35, 0),
					},
					LeftHip = { rot = Vector3.new(39.55, 0, 7.98), pos = Vector3.new(0, 0.05, 0) },
				},
			},
			{
				time = 0.3125,
				pose = {
					Root = {
						rot = Vector3.new(-13.45, 7.33, 0.2),
						pos = Vector3.new(0, -0.13, -0.11),
					},
					Neck = { rot = Vector3.new(9.09, -7.41, 0.85) },
					RightShoulder = { rot = Vector3.new(64.51, 0, 8.11) },
					LeftShoulder = { rot = Vector3.new(-7.96, 0, -30.66) },
					RightHip = {
						rot = Vector3.new(-27.89, 0, -4.69),
						pos = Vector3.new(0, 0.53, 0),
					},
					LeftHip = { rot = Vector3.new(39.26, 0, 6.67), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.3438,
				pose = {
					Root = {
						rot = Vector3.new(-13.8, 7.13, 0.51),
						pos = Vector3.new(0, -0.14, -0.11),
					},
					Neck = { rot = Vector3.new(9.39, -7.23, 0.53) },
					RightShoulder = { rot = Vector3.new(62.26, 0, 9.55) },
					LeftShoulder = { rot = Vector3.new(-1.06, 0, -29.79) },
					RightHip = {
						rot = Vector3.new(-26.09, 0, -4.66),
						pos = Vector3.new(0, 0.61, 0),
					},
					LeftHip = { rot = Vector3.new(39.68, 0, 6.19), pos = Vector3.new(0, 0.09, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = {
						rot = Vector3.new(-13.69, 7.21, 0.44),
						pos = Vector3.new(0, -0.14, -0.11),
					},
					Neck = { rot = Vector3.new(9.29, -7.3, 0.61) },
					RightShoulder = { rot = Vector3.new(62.8, 0, 9.22) },
					LeftShoulder = { rot = Vector3.new(-2.79, 0, -30.16) },
					RightHip = { rot = Vector3.new(-26.6, 0, -4.68), pos = Vector3.new(0, 0.59, 0) },
					LeftHip = { rot = Vector3.new(40, 0, 6.34), pos = Vector3.new(0, 0.09, 0) },
				},
			},
			{
				time = 0.4062,
				pose = {
					Root = {
						rot = Vector3.new(-14.35, 6.71, 0.79),
						pos = Vector3.new(0, -0.16, -0.1),
					},
					Neck = { rot = Vector3.new(9.95, -6.84, 0.24) },
					RightShoulder = { rot = Vector3.new(60, 0, 10.77) },
					LeftShoulder = { rot = Vector3.new(5.97, 0, -27.44) },
					RightHip = { rot = Vector3.new(-23.7, 0, -4.51), pos = Vector3.new(0, 0.67, 0) },
					LeftHip = { rot = Vector3.new(36.09, 0, 5.44), pos = Vector3.new(0, 0.14, 0) },
				},
			},
			{
				time = 0.4375,
				pose = {
					Root = {
						rot = Vector3.new(-15.67, 5.61, 1.52),
						pos = Vector3.new(0, -0.2, -0.09),
					},
					Neck = { rot = Vector3.new(11.27, -5.84, -0.55) },
					RightShoulder = { rot = Vector3.new(52.96, 0, 14.17) },
					LeftShoulder = { rot = Vector3.new(23.36, 0, -21.96) },
					RightHip = { rot = Vector3.new(-17.5, 0, -4.19), pos = Vector3.new(0, 0.85, 0) },
					LeftHip = { rot = Vector3.new(29.35, 0, 3.74), pos = Vector3.new(0, 0.22, 0) },
				},
			},
			{
				time = 0.4688,
				pose = {
					Root = {
						rot = Vector3.new(-16.85, 4.36, 2.13),
						pos = Vector3.new(0, -0.22, -0.08),
					},
					Neck = { rot = Vector3.new(12.49, -4.68, -1.29) },
					RightShoulder = { rot = Vector3.new(43.7, 0, 17.42) },
					LeftShoulder = { rot = Vector3.new(36.87, 0, -16.6) },
					RightHip = { rot = Vector3.new(-11.21, 0, -3.9), pos = Vector3.new(0, 1, 0) },
					LeftHip = { rot = Vector3.new(23.62, 0, 2.36), pos = Vector3.new(0, 0.23, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-17.72, 2.99, 2.59),
						pos = Vector3.new(0, -0.23, -0.07),
					},
					Neck = { rot = Vector3.new(13.41, -3.4, -1.97) },
					RightShoulder = { rot = Vector3.new(31.75, 0, 20.31) },
					LeftShoulder = { rot = Vector3.new(46.55, 0, -12.16) },
					RightHip = { rot = Vector3.new(-4.79, 0, -3.75), pos = Vector3.new(0, 1.07, 0) },
					LeftHip = { rot = Vector3.new(18.19, 0, 1.08), pos = Vector3.new(0, 0.24, 0) },
				},
			},
			{
				time = 0.5312,
				pose = {
					Root = {
						rot = Vector3.new(-18.19, 1.51, 2.92),
						pos = Vector3.new(0, -0.23, -0.06),
					},
					Neck = { rot = Vector3.new(13.95, -1.99, -2.62) },
					RightShoulder = { rot = Vector3.new(17.37, 0, 22.85) },
					LeftShoulder = { rot = Vector3.new(54.57, 0, -8.63) },
					RightHip = { rot = Vector3.new(1.94, 0, -3.81), pos = Vector3.new(0, 1.08, 0) },
					LeftHip = { rot = Vector3.new(11.88, 0, -0.21), pos = Vector3.new(0, 0.28, 0) },
				},
			},
			{
				time = 0.5625,
				pose = {
					Root = {
						rot = Vector3.new(-18.11, 0.01, 3.08),
						pos = Vector3.new(0, -0.23, -0.06),
					},
					Neck = { rot = Vector3.new(13.96, -0.52, -3.17) },
					RightShoulder = { rot = Vector3.new(2.81, 0, 24.7) },
					LeftShoulder = { rot = Vector3.new(61.27, 0, -5.58) },
					RightHip = { rot = Vector3.new(8.05, 0, -4.16), pos = Vector3.new(0, 1.02, 0) },
					LeftHip = { rot = Vector3.new(4.68, 0, -0.98), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.5938,
				pose = {
					Root = {
						rot = Vector3.new(-17.56, -1.47, 3.08),
						pos = Vector3.new(0, -0.23, -0.07),
					},
					Neck = { rot = Vector3.new(13.54, 0.97, -3.55) },
					RightShoulder = { rot = Vector3.new(-10.56, 0, 26.18) },
					LeftShoulder = { rot = Vector3.new(67.08, 0, -2.65) },
					RightHip = { rot = Vector3.new(13.16, 0, -4.79), pos = Vector3.new(0, 0.93, 0) },
					LeftHip = { rot = Vector3.new(-2.7, 0, -1.07), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = {
						rot = Vector3.new(-16.75, -2.88, 2.96),
						pos = Vector3.new(0, -0.22, -0.07),
					},
					Neck = { rot = Vector3.new(12.85, 2.45, -3.74) },
					RightShoulder = { rot = Vector3.new(-22.15, 0, 27.89) },
					LeftShoulder = { rot = Vector3.new(72.39, 0, 0.3) },
					RightHip = { rot = Vector3.new(17.42, 0, -5.63), pos = Vector3.new(0, 0.82, 0) },
					LeftHip = { rot = Vector3.new(-9.34, 0, -0.65), pos = Vector3.new(0, 0.26, 0) },
				},
			},
			{
				time = 0.6562,
				pose = {
					Root = {
						rot = Vector3.new(-15.8, -4.21, 2.71),
						pos = Vector3.new(0, -0.2, -0.08),
					},
					Neck = { rot = Vector3.new(12.01, 3.85, -3.75) },
					RightShoulder = { rot = Vector3.new(-31.41, 0, 29.71) },
					LeftShoulder = { rot = Vector3.new(76.72, 0, 2.71) },
					RightHip = { rot = Vector3.new(21.48, 0, -6.58), pos = Vector3.new(0, 0.69, 0) },
					LeftHip = { rot = Vector3.new(-15.33, 0, 0.19), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.6875,
				pose = {
					Root = {
						rot = Vector3.new(-14.81, -5.39, 2.36),
						pos = Vector3.new(0, -0.18, -0.09),
					},
					Neck = { rot = Vector3.new(11.08, 5.13, -3.56) },
					RightShoulder = { rot = Vector3.new(-37.6, 0, 31.3) },
					LeftShoulder = { rot = Vector3.new(79.33, 0, 3.86) },
					RightHip = { rot = Vector3.new(26.02, 0, -7.54), pos = Vector3.new(0, 0.51, 0) },
					LeftHip = { rot = Vector3.new(-20.87, 0, 1.33), pos = Vector3.new(0, 0.14, 0) },
				},
			},
			{
				time = 0.7188,
				pose = {
					Root = {
						rot = Vector3.new(-13.91, -6.39, 1.92),
						pos = Vector3.new(0, -0.16, -0.1),
					},
					Neck = { rot = Vector3.new(10.17, 6.24, -3.22) },
					RightShoulder = { rot = Vector3.new(-39.67, 0, 32.37) },
					LeftShoulder = { rot = Vector3.new(79.48, 0, 3.09) },
					RightHip = { rot = Vector3.new(31.34, 0, -8.55), pos = Vector3.new(0, 0.29, 0) },
					LeftHip = { rot = Vector3.new(-25.85, 0, 2.54), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(-13.21, -7.15, 1.39),
						pos = Vector3.new(0, -0.13, -0.11),
					},
					Neck = { rot = Vector3.new(9.41, 7.11, -2.73) },
					RightShoulder = { rot = Vector3.new(-37.34, 0, 32.9) },
					LeftShoulder = { rot = Vector3.new(77.3, 0, 0.65) },
					RightHip = { rot = Vector3.new(36.16, 0, -9.11), pos = Vector3.new(0, 0.09, 0) },
					LeftHip = { rot = Vector3.new(-29.72, 0, 3.66), pos = Vector3.new(0, 0.17, 0) },
				},
			},
			{
				time = 0.7812,
				pose = {
					Root = {
						rot = Vector3.new(-12.78, -7.61, 0.81),
						pos = Vector3.new(0, -0.12, -0.12),
					},
					Neck = { rot = Vector3.new(8.87, 7.66, -2.15) },
					RightShoulder = { rot = Vector3.new(-30.98, 0, 33.02) },
					LeftShoulder = { rot = Vector3.new(73.6, 0, -2.54) },
					RightHip = { rot = Vector3.new(38.48, 0, -8.55), pos = Vector3.new(0, 0.03, 0) },
					LeftHip = { rot = Vector3.new(-31.66, 0, 4.54), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.8125,
				pose = {
					Root = {
						rot = Vector3.new(-12.8, -7.71, 0.19),
						pos = Vector3.new(0, -0.12, -0.12),
					},
					Neck = { rot = Vector3.new(8.76, 7.84, -1.51) },
					RightShoulder = { rot = Vector3.new(-21.07, 0, 32.53) },
					LeftShoulder = { rot = Vector3.new(69.25, 0, -5.78) },
					RightHip = { rot = Vector3.new(39.61, 0, -7.46), pos = Vector3.new(0, 0.05, 0) },
					LeftHip = { rot = Vector3.new(-31.18, 0, 5.02), pos = Vector3.new(0, 0.37, 0) },
				},
			},
			{
				time = 0.8438,
				pose = {
					Root = {
						rot = Vector3.new(-13.35, -7.42, -0.45),
						pos = Vector3.new(0, -0.13, -0.11),
					},
					Neck = { rot = Vector3.new(9.2, 7.6, -0.85) },
					RightShoulder = { rot = Vector3.new(-8.29, 0, 30.94) },
					LeftShoulder = { rot = Vector3.new(64.82, 0, -8.71) },
					RightHip = { rot = Vector3.new(40.16, 0, -6.44), pos = Vector3.new(0, 0.08, 0) },
					LeftHip = { rot = Vector3.new(-28.29, 0, 5.05), pos = Vector3.new(0, 0.52, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = {
						rot = Vector3.new(-14.33, -6.76, -1.09),
						pos = Vector3.new(0, -0.16, -0.1),
					},
					Neck = { rot = Vector3.new(10.07, 7.01, -0.17) },
					RightShoulder = { rot = Vector3.new(6.38, 0, 27.51) },
					LeftShoulder = { rot = Vector3.new(60.14, 0, -11.48) },
					RightHip = { rot = Vector3.new(36.89, 0, -5.07), pos = Vector3.new(0, 0.14, 0) },
					LeftHip = { rot = Vector3.new(-23.82, 0, 4.81), pos = Vector3.new(0, 0.67, 0) },
				},
			},
			{
				time = 0.9062,
				pose = {
					Root = {
						rot = Vector3.new(-15.53, -5.8, -1.74),
						pos = Vector3.new(0, -0.19, -0.09),
					},
					Neck = { rot = Vector3.new(11.21, 6.12, 0.54) },
					RightShoulder = { rot = Vector3.new(21.32, 0, 22.51) },
					LeftShoulder = { rot = Vector3.new(54.22, 0, -14.31) },
					RightHip = { rot = Vector3.new(30.37, 0, -3.4), pos = Vector3.new(0, 0.21, 0) },
					LeftHip = { rot = Vector3.new(-18.4, 0, 4.45), pos = Vector3.new(0, 0.83, 0) },
				},
			},
			{
				time = 0.9375,
				pose = {
					Root = {
						rot = Vector3.new(-16.75, -4.59, -2.34),
						pos = Vector3.new(0, -0.22, -0.08),
					},
					Neck = { rot = Vector3.new(12.38, 5.01, 1.27) },
					RightShoulder = { rot = Vector3.new(34.58, 0, 17.14) },
					LeftShoulder = { rot = Vector3.new(45.56, 0, -17.39) },
					RightHip = { rot = Vector3.new(24.54, 0, -1.93), pos = Vector3.new(0, 0.23, 0) },
					LeftHip = { rot = Vector3.new(-12.29, 0, 4.09), pos = Vector3.new(0, 0.97, 0) },
				},
			},
			{
				time = 0.9688,
				pose = {
					Root = {
						rot = Vector3.new(-17.77, -3.22, -2.85),
						pos = Vector3.new(0, -0.23, -0.07),
					},
					Neck = { rot = Vector3.new(13.37, 3.73, 1.98) },
					RightShoulder = { rot = Vector3.new(45.33, 0, 12.38) },
					LeftShoulder = { rot = Vector3.new(33.79, 0, -20.4) },
					RightHip = { rot = Vector3.new(19.28, 0, -0.59), pos = Vector3.new(0, 0.24, 0) },
					LeftHip = { rot = Vector3.new(-5.67, 0, 3.83), pos = Vector3.new(0, 1.06, 0) },
				},
			},
		},
	},
	-- ALS_CLF_Walk_F: phase clip (one cycle = 1), left foot plants at 0.4375; natural cycle 1.167 s, stride 3.47 studs per cycle
	CrouchWalk = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-53.83, -18.85, -10.92),
						pos = Vector3.new(-0.08, -0.81, 0.45),
					},
					Neck = { rot = Vector3.new(43.53, 20.71, -5.47) },
					RightShoulder = { rot = Vector3.new(53.13, 0, 18.42) },
					LeftShoulder = { rot = Vector3.new(52.07, 0, -40.1) },
					RightHip = {
						rot = Vector3.new(90.11, 0, -12.13),
						pos = Vector3.new(0, 0.33, 0),
					},
					LeftHip = { rot = Vector3.new(34.44, 0, -1.72), pos = Vector3.new(0, 1.14, 0) },
				},
			},
			{
				time = 0.0312,
				pose = {
					Root = {
						rot = Vector3.new(-53.56, -18.94, -10.87),
						pos = Vector3.new(-0.08, -0.79, 0.44),
					},
					Neck = { rot = Vector3.new(43.22, 20.76, -5.45) },
					RightShoulder = { rot = Vector3.new(55.5, 0, 17.5) },
					LeftShoulder = { rot = Vector3.new(47.52, 0, -39.49) },
					RightHip = {
						rot = Vector3.new(89.23, 0, -12.12),
						pos = Vector3.new(0, 0.25, 0),
					},
					LeftHip = { rot = Vector3.new(35.09, 0, -2.76), pos = Vector3.new(0, 1.17, 0) },
				},
			},
			{
				time = 0.0625,
				pose = {
					Root = {
						rot = Vector3.new(-53.39, -18.96, -10.83),
						pos = Vector3.new(-0.07, -0.77, 0.44),
					},
					Neck = { rot = Vector3.new(43.02, 20.76, -5.41) },
					RightShoulder = { rot = Vector3.new(58.04, 0, 16.35) },
					LeftShoulder = { rot = Vector3.new(42.98, 0, -38.44) },
					RightHip = { rot = Vector3.new(86.3, 0, -11.92), pos = Vector3.new(0, 0.27, 0) },
					LeftHip = { rot = Vector3.new(37.22, 0, -4.33), pos = Vector3.new(0, 1.23, 0) },
				},
			},
			{
				time = 0.0938,
				pose = {
					Root = {
						rot = Vector3.new(-53.36, -18.92, -10.83),
						pos = Vector3.new(-0.07, -0.74, 0.44),
					},
					Neck = { rot = Vector3.new(42.97, 20.74, -5.34) },
					RightShoulder = { rot = Vector3.new(60.69, 0, 15.12) },
					LeftShoulder = { rot = Vector3.new(38.67, 0, -37) },
					RightHip = {
						rot = Vector3.new(82.78, 0, -11.49),
						pos = Vector3.new(0, 0.29, 0),
					},
					LeftHip = { rot = Vector3.new(40.42, 0, -6.01), pos = Vector3.new(0, 1.29, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = {
						rot = Vector3.new(-53.38, -18.86, -10.81),
						pos = Vector3.new(-0.07, -0.72, 0.44),
					},
					Neck = { rot = Vector3.new(42.97, 20.68, -5.3) },
					RightShoulder = { rot = Vector3.new(63.25, 0, 13.85) },
					LeftShoulder = { rot = Vector3.new(34.71, 0, -35.26) },
					RightHip = { rot = Vector3.new(79.17, 0, -10.94), pos = Vector3.new(0, 0.3, 0) },
					LeftHip = { rot = Vector3.new(45.23, 0, -7.84), pos = Vector3.new(0, 1.29, 0) },
				},
			},
			{
				time = 0.1562,
				pose = {
					Root = {
						rot = Vector3.new(-53.44, -18.77, -10.75),
						pos = Vector3.new(-0.07, -0.7, 0.45),
					},
					Neck = { rot = Vector3.new(43.02, 20.58, -5.27) },
					RightShoulder = { rot = Vector3.new(65.63, 0, 12.53) },
					LeftShoulder = { rot = Vector3.new(31.22, 0, -33.35) },
					RightHip = { rot = Vector3.new(75.58, 0, -10.3), pos = Vector3.new(0, 0.32, 0) },
					LeftHip = { rot = Vector3.new(53.3, 0, -10.1), pos = Vector3.new(0, 1.19, 0) },
				},
			},
			{
				time = 0.1875,
				pose = {
					Root = {
						rot = Vector3.new(-53.52, -18.65, -10.67),
						pos = Vector3.new(-0.07, -0.69, 0.45),
					},
					Neck = { rot = Vector3.new(43.11, 20.43, -5.27) },
					RightShoulder = { rot = Vector3.new(67.78, 0, 11.24) },
					LeftShoulder = { rot = Vector3.new(28.29, 0, -31.44) },
					RightHip = { rot = Vector3.new(72.13, 0, -9.69), pos = Vector3.new(0, 0.35, 0) },
					LeftHip = { rot = Vector3.new(64.72, 0, -12.56), pos = Vector3.new(0, 0.98, 0) },
				},
			},
			{
				time = 0.2188,
				pose = {
					Root = {
						rot = Vector3.new(-53.63, -18.51, -10.53),
						pos = Vector3.new(-0.07, -0.7, 0.46),
					},
					Neck = { rot = Vector3.new(43.24, 20.23, -5.29) },
					RightShoulder = { rot = Vector3.new(69.63, 0, 10.04) },
					LeftShoulder = { rot = Vector3.new(25.96, 0, -29.7) },
					RightHip = { rot = Vector3.new(68.93, 0, -9.17), pos = Vector3.new(0, 0.37, 0) },
					LeftHip = { rot = Vector3.new(73.04, 0, -14.44), pos = Vector3.new(0, 0.92, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(-53.75, -18.35, -10.24),
						pos = Vector3.new(-0.07, -0.71, 0.47),
					},
					Neck = { rot = Vector3.new(43.44, 19.91, -5.44) },
					RightShoulder = { rot = Vector3.new(71.14, 0, 8.97) },
					LeftShoulder = { rot = Vector3.new(24.28, 0, -28.39) },
					RightHip = { rot = Vector3.new(65.86, 0, -8.76), pos = Vector3.new(0, 0.4, 0) },
					LeftHip = { rot = Vector3.new(80.72, 0, -16.17), pos = Vector3.new(0, 0.87, 0) },
				},
			},
			{
				time = 0.2812,
				pose = {
					Root = {
						rot = Vector3.new(-53.9, -18.18, -9.79),
						pos = Vector3.new(-0.07, -0.73, 0.47),
					},
					Neck = { rot = Vector3.new(43.7, 19.47, -5.72) },
					RightShoulder = { rot = Vector3.new(72.24, 0, 8.13) },
					LeftShoulder = { rot = Vector3.new(23.25, 0, -27.68) },
					RightHip = { rot = Vector3.new(62.82, 0, -8.67), pos = Vector3.new(0, 0.43, 0) },
					LeftHip = { rot = Vector3.new(85.64, 0, -17.16), pos = Vector3.new(0, 0.84, 0) },
				},
			},
			{
				time = 0.3125,
				pose = {
					Root = {
						rot = Vector3.new(-54.04, -18, -9.31),
						pos = Vector3.new(-0.08, -0.76, 0.48),
					},
					Neck = { rot = Vector3.new(43.95, 19, -6) },
					RightShoulder = { rot = Vector3.new(72.91, 0, 7.6) },
					LeftShoulder = { rot = Vector3.new(22.84, 0, -27.55) },
					RightHip = { rot = Vector3.new(59.5, 0, -8.13), pos = Vector3.new(0, 0.48, 0) },
					LeftHip = { rot = Vector3.new(86.47, 0, -17.18), pos = Vector3.new(0, 0.87, 0) },
				},
			},
			{
				time = 0.3438,
				pose = {
					Root = {
						rot = Vector3.new(-54.2, -17.75, -8.83),
						pos = Vector3.new(-0.08, -0.79, 0.48),
					},
					Neck = { rot = Vector3.new(44.23, 18.48, -6.25) },
					RightShoulder = { rot = Vector3.new(73.06, 0, 7.52) },
					LeftShoulder = { rot = Vector3.new(23.34, 0, -28.24) },
					RightHip = { rot = Vector3.new(54.41, 0, -6.99), pos = Vector3.new(0, 0.59, 0) },
					LeftHip = { rot = Vector3.new(84.75, 0, -16.5), pos = Vector3.new(0, 0.95, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = {
						rot = Vector3.new(-54.22, -17.72, -8.78),
						pos = Vector3.new(-0.09, -0.79, 0.48),
					},
					Neck = { rot = Vector3.new(44.26, 18.42, -6.28) },
					RightShoulder = { rot = Vector3.new(73.07, 0, 7.51) },
					LeftShoulder = { rot = Vector3.new(23.4, 0, -28.34) },
					RightHip = { rot = Vector3.new(53.69, 0, -6.87), pos = Vector3.new(0, 0.61, 0) },
					LeftHip = { rot = Vector3.new(84.51, 0, -16.42), pos = Vector3.new(0, 0.96, 0) },
				},
			},
			{
				time = 0.4062,
				pose = {
					Root = {
						rot = Vector3.new(-54.35, -17.54, -8.46),
						pos = Vector3.new(-0.09, -0.81, 0.48),
					},
					Neck = { rot = Vector3.new(44.46, 18.06, -6.44) },
					RightShoulder = { rot = Vector3.new(72.88, 0, 7.81) },
					LeftShoulder = { rot = Vector3.new(24.61, 0, -29.29) },
					RightHip = { rot = Vector3.new(50.49, 0, -6.12), pos = Vector3.new(0, 0.69, 0) },
					LeftHip = { rot = Vector3.new(82.6, 0, -15.72), pos = Vector3.new(0, 1.01, 0) },
				},
			},
			{
				time = 0.4375,
				pose = {
					Root = {
						rot = Vector3.new(-54.4, -17.36, -8.09),
						pos = Vector3.new(-0.1, -0.81, 0.47),
					},
					Neck = { rot = Vector3.new(44.61, 17.67, -6.62) },
					RightShoulder = { rot = Vector3.new(72.42, 0, 8.37) },
					LeftShoulder = { rot = Vector3.new(26.78, 0, -30.6) },
					RightHip = { rot = Vector3.new(47.43, 0, -4.98), pos = Vector3.new(0, 0.79, 0) },
					LeftHip = { rot = Vector3.new(80.48, 0, -14.91), pos = Vector3.new(0, 1.04, 0) },
				},
			},
			{
				time = 0.4688,
				pose = {
					Root = {
						rot = Vector3.new(-54.32, -17.22, -7.74),
						pos = Vector3.new(-0.1, -0.82, 0.46),
					},
					Neck = { rot = Vector3.new(44.61, 17.35, -6.78) },
					RightShoulder = { rot = Vector3.new(71.66, 0, 9.11) },
					LeftShoulder = { rot = Vector3.new(29.59, 0, -31.96) },
					RightHip = { rot = Vector3.new(45.45, 0, -3.74), pos = Vector3.new(0, 0.86, 0) },
					LeftHip = { rot = Vector3.new(77.42, 0, -13.94), pos = Vector3.new(0, 1.08, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-54.15, -17.12, -7.45),
						pos = Vector3.new(-0.11, -0.82, 0.46),
					},
					Neck = { rot = Vector3.new(44.52, 17.1, -6.9) },
					RightShoulder = { rot = Vector3.new(70.46, 0, 10.09) },
					LeftShoulder = { rot = Vector3.new(32.94, 0, -33.22) },
					RightHip = { rot = Vector3.new(44.19, 0, -2.73), pos = Vector3.new(0, 0.88, 0) },
					LeftHip = { rot = Vector3.new(74.03, 0, -12.95), pos = Vector3.new(0, 1.09, 0) },
				},
			},
			{
				time = 0.5312,
				pose = {
					Root = {
						rot = Vector3.new(-53.94, -17.08, -7.23),
						pos = Vector3.new(-0.11, -0.8, 0.45),
					},
					Neck = { rot = Vector3.new(44.38, 16.95, -7) },
					RightShoulder = { rot = Vector3.new(68.85, 0, 11.25) },
					LeftShoulder = { rot = Vector3.new(36.66, 0, -34.29) },
					RightHip = { rot = Vector3.new(44.16, 0, -2.28), pos = Vector3.new(0, 0.89, 0) },
					LeftHip = { rot = Vector3.new(71, 0, -12.03), pos = Vector3.new(0, 1.08, 0) },
				},
			},
			{
				time = 0.5625,
				pose = {
					Root = {
						rot = Vector3.new(-53.75, -17.1, -7.1),
						pos = Vector3.new(-0.11, -0.78, 0.44),
					},
					Neck = { rot = Vector3.new(44.24, 16.91, -7.06) },
					RightShoulder = { rot = Vector3.new(67.01, 0, 12.44) },
					LeftShoulder = { rot = Vector3.new(40.59, 0, -35.11) },
					RightHip = { rot = Vector3.new(44.6, 0, -2.62), pos = Vector3.new(0, 0.9, 0) },
					LeftHip = { rot = Vector3.new(68.57, 0, -11.22), pos = Vector3.new(0, 1.03, 0) },
				},
			},
			{
				time = 0.5938,
				pose = {
					Root = {
						rot = Vector3.new(-53.66, -17.14, -7.04),
						pos = Vector3.new(-0.11, -0.76, 0.44),
					},
					Neck = { rot = Vector3.new(44.19, 16.9, -7.14) },
					RightShoulder = { rot = Vector3.new(65.03, 0, 13.6) },
					LeftShoulder = { rot = Vector3.new(44.62, 0, -35.75) },
					RightHip = { rot = Vector3.new(47.81, 0, -4.17), pos = Vector3.new(0, 0.88, 0) },
					LeftHip = { rot = Vector3.new(66.56, 0, -10.48), pos = Vector3.new(0, 0.98, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = {
						rot = Vector3.new(-53.63, -17.19, -7.01),
						pos = Vector3.new(-0.12, -0.73, 0.44),
					},
					Neck = { rot = Vector3.new(44.2, 16.93, -7.21) },
					RightShoulder = { rot = Vector3.new(62.9, 0, 14.68) },
					LeftShoulder = { rot = Vector3.new(48.54, 0, -36.26) },
					RightHip = { rot = Vector3.new(54.62, 0, -6.57), pos = Vector3.new(0, 0.79, 0) },
					LeftHip = { rot = Vector3.new(64.77, 0, -9.82), pos = Vector3.new(0, 0.92, 0) },
				},
			},
			{
				time = 0.6562,
				pose = {
					Root = {
						rot = Vector3.new(-53.62, -17.27, -7.02),
						pos = Vector3.new(-0.12, -0.71, 0.44),
					},
					Neck = { rot = Vector3.new(44.21, 17, -7.27) },
					RightShoulder = { rot = Vector3.new(60.62, 0, 15.62) },
					LeftShoulder = { rot = Vector3.new(52.2, 0, -36.65) },
					RightHip = { rot = Vector3.new(71.58, 0, -9.72), pos = Vector3.new(0, 0.42, 0) },
					LeftHip = { rot = Vector3.new(62.53, 0, -9.68), pos = Vector3.new(0, 0.88, 0) },
				},
			},
			{
				time = 0.6875,
				pose = {
					Root = {
						rot = Vector3.new(-53.64, -17.36, -7.09),
						pos = Vector3.new(-0.12, -0.7, 0.45),
					},
					Neck = { rot = Vector3.new(44.24, 17.11, -7.3) },
					RightShoulder = { rot = Vector3.new(58.24, 0, 16.38) },
					LeftShoulder = { rot = Vector3.new(55.55, 0, -36.94) },
					RightHip = {
						rot = Vector3.new(86.84, 0, -10.91),
						pos = Vector3.new(0, 0.12, 0),
					},
					LeftHip = { rot = Vector3.new(60.08, 0, -9.02), pos = Vector3.new(0, 0.86, 0) },
				},
			},
			{
				time = 0.7188,
				pose = {
					Root = {
						rot = Vector3.new(-53.68, -17.47, -7.22),
						pos = Vector3.new(-0.13, -0.7, 0.45),
					},
					Neck = { rot = Vector3.new(44.28, 17.27, -7.31) },
					RightShoulder = { rot = Vector3.new(55.82, 0, 16.93) },
					LeftShoulder = { rot = Vector3.new(58.5, 0, -37.24) },
					RightHip = {
						rot = Vector3.new(90.04, 0, -10.45),
						pos = Vector3.new(0, 0.19, 0),
					},
					LeftHip = { rot = Vector3.new(57.66, 0, -8.03), pos = Vector3.new(0, 0.84, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(-53.73, -17.59, -7.48),
						pos = Vector3.new(-0.13, -0.7, 0.46),
					},
					Neck = { rot = Vector3.new(44.3, 17.53, -7.22) },
					RightShoulder = { rot = Vector3.new(53.43, 0, 17.37) },
					LeftShoulder = { rot = Vector3.new(60.92, 0, -37.58) },
					RightHip = {
						rot = Vector3.new(90.04, 0, -10.68),
						pos = Vector3.new(0, 0.41, 0),
					},
					LeftHip = { rot = Vector3.new(55.18, 0, -6.96), pos = Vector3.new(0, 0.83, 0) },
				},
			},
			{
				time = 0.7812,
				pose = {
					Root = {
						rot = Vector3.new(-53.81, -17.71, -7.94),
						pos = Vector3.new(-0.13, -0.72, 0.46),
					},
					Neck = { rot = Vector3.new(44.29, 17.92, -6.99) },
					RightShoulder = { rot = Vector3.new(51.22, 0, 17.85) },
					LeftShoulder = { rot = Vector3.new(62.69, 0, -38.05) },
					RightHip = {
						rot = Vector3.new(90.05, 0, -11.44),
						pos = Vector3.new(0, 0.59, 0),
					},
					LeftHip = { rot = Vector3.new(52.54, 0, -5.69), pos = Vector3.new(0, 0.83, 0) },
				},
			},
			{
				time = 0.8125,
				pose = {
					Root = {
						rot = Vector3.new(-53.9, -17.84, -8.54),
						pos = Vector3.new(-0.13, -0.75, 0.47),
					},
					Neck = { rot = Vector3.new(44.25, 18.41, -6.66) },
					RightShoulder = { rot = Vector3.new(49.42, 0, 18.35) },
					LeftShoulder = { rot = Vector3.new(63.75, 0, -38.59) },
					RightHip = {
						rot = Vector3.new(90.06, 0, -12.11),
						pos = Vector3.new(0, 0.68, 0),
					},
					LeftHip = { rot = Vector3.new(48.68, 0, -4.41), pos = Vector3.new(0, 0.88, 0) },
				},
			},
			{
				time = 0.8438,
				pose = {
					Root = {
						rot = Vector3.new(-54.01, -17.99, -9.19),
						pos = Vector3.new(-0.12, -0.78, 0.47),
					},
					Neck = { rot = Vector3.new(44.22, 18.95, -6.31) },
					RightShoulder = { rot = Vector3.new(48.27, 0, 18.85) },
					LeftShoulder = { rot = Vector3.new(64, 0, -39.08) },
					RightHip = {
						rot = Vector3.new(90.06, 0, -12.37),
						pos = Vector3.new(0, 0.69, 0),
					},
					LeftHip = { rot = Vector3.new(44.81, 0, -3.17), pos = Vector3.new(0, 0.94, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = {
						rot = Vector3.new(-54.17, -18.15, -9.82),
						pos = Vector3.new(-0.12, -0.8, 0.48),
					},
					Neck = { rot = Vector3.new(44.22, 19.47, -5.99) },
					RightShoulder = { rot = Vector3.new(47.93, 0, 19.24) },
					LeftShoulder = { rot = Vector3.new(63.39, 0, -39.53) },
					RightHip = {
						rot = Vector3.new(90.06, 0, -12.39),
						pos = Vector3.new(0, 0.66, 0),
					},
					LeftHip = { rot = Vector3.new(41.44, 0, -2.07), pos = Vector3.new(0, 0.98, 0) },
				},
			},
			{
				time = 0.9062,
				pose = {
					Root = {
						rot = Vector3.new(-54.32, -18.32, -10.33),
						pos = Vector3.new(-0.11, -0.81, 0.48),
					},
					Neck = { rot = Vector3.new(44.24, 19.92, -5.76) },
					RightShoulder = { rot = Vector3.new(48.36, 0, 19.39) },
					LeftShoulder = { rot = Vector3.new(61.92, 0, -39.95) },
					RightHip = {
						rot = Vector3.new(90.05, 0, -12.24),
						pos = Vector3.new(0, 0.61, 0),
					},
					LeftHip = { rot = Vector3.new(38.8, 0, -1.19), pos = Vector3.new(0, 1.01, 0) },
				},
			},
			{
				time = 0.9375,
				pose = {
					Root = {
						rot = Vector3.new(-54.3, -18.5, -10.68),
						pos = Vector3.new(-0.1, -0.82, 0.47),
					},
					Neck = { rot = Vector3.new(44.12, 20.28, -5.6) },
					RightShoulder = { rot = Vector3.new(49.38, 0, 19.32) },
					LeftShoulder = { rot = Vector3.new(59.52, 0, -40.24) },
					RightHip = { rot = Vector3.new(90.06, 0, -12), pos = Vector3.new(0, 0.54, 0) },
					LeftHip = { rot = Vector3.new(36.32, 0, -0.76), pos = Vector3.new(0, 1.06, 0) },
				},
			},
			{
				time = 0.9688,
				pose = {
					Root = {
						rot = Vector3.new(-54.11, -18.69, -10.86),
						pos = Vector3.new(-0.09, -0.82, 0.46),
					},
					Neck = { rot = Vector3.new(43.85, 20.55, -5.52) },
					RightShoulder = { rot = Vector3.new(50.99, 0, 19.02) },
					LeftShoulder = { rot = Vector3.new(56.22, 0, -40.32) },
					RightHip = {
						rot = Vector3.new(90.03, 0, -12.05),
						pos = Vector3.new(0, 0.44, 0),
					},
					LeftHip = { rot = Vector3.new(34.63, 0, -0.96), pos = Vector3.new(0, 1.11, 0) },
				},
			},
		},
	},
	-- ALS_CLF_Walk_B: phase clip (one cycle = 1), left foot plants at 0.4375; natural cycle 1.167 s, stride 3.67 studs per cycle
	CrouchWalkBack = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-59.88, -19.04, -10.82),
						pos = Vector3.new(-0.07, -0.6, 0.53),
					},
					Neck = { rot = Vector3.new(50.04, 20.04, -7.95) },
					RightShoulder = { rot = Vector3.new(58.42, 0, 16.25) },
					LeftShoulder = { rot = Vector3.new(61.52, 0, -42.56) },
					RightHip = {
						rot = Vector3.new(88.55, 0, -11.23),
						pos = Vector3.new(0, -0.01, 0),
					},
					LeftHip = { rot = Vector3.new(65.68, 0, -13.66), pos = Vector3.new(0, 1.05, 0) },
				},
			},
			{
				time = 0.0312,
				pose = {
					Root = {
						rot = Vector3.new(-59.93, -19.16, -10.84),
						pos = Vector3.new(-0.07, -0.62, 0.53),
					},
					Neck = { rot = Vector3.new(50.12, 20.14, -8.04) },
					RightShoulder = { rot = Vector3.new(56.28, 0, 16.58) },
					LeftShoulder = { rot = Vector3.new(64.97, 0, -42.7) },
					RightHip = {
						rot = Vector3.new(89.96, 0, -11.67),
						pos = Vector3.new(0, 0.05, 0),
					},
					LeftHip = { rot = Vector3.new(54.76, 0, -11.52), pos = Vector3.new(0, 1.27, 0) },
				},
			},
			{
				time = 0.0625,
				pose = {
					Root = {
						rot = Vector3.new(-59.87, -19.24, -10.83),
						pos = Vector3.new(-0.07, -0.64, 0.53),
					},
					Neck = { rot = Vector3.new(50.08, 20.2, -8.09) },
					RightShoulder = { rot = Vector3.new(54.76, 0, 16.74) },
					LeftShoulder = { rot = Vector3.new(67.38, 0, -42.58) },
					RightHip = {
						rot = Vector3.new(90.02, 0, -12.07),
						pos = Vector3.new(0, 0.16, 0),
					},
					LeftHip = { rot = Vector3.new(49.39, 0, -9.77), pos = Vector3.new(0, 1.28, 0) },
				},
			},
			{
				time = 0.0938,
				pose = {
					Root = {
						rot = Vector3.new(-59.74, -19.29, -10.79),
						pos = Vector3.new(-0.07, -0.67, 0.52),
					},
					Neck = { rot = Vector3.new(49.96, 20.22, -8.11) },
					RightShoulder = { rot = Vector3.new(53.96, 0, 16.77) },
					LeftShoulder = { rot = Vector3.new(68.94, 0, -42.28) },
					RightHip = {
						rot = Vector3.new(90.03, 0, -12.41),
						pos = Vector3.new(0, 0.26, 0),
					},
					LeftHip = { rot = Vector3.new(45.85, 0, -8.15), pos = Vector3.new(0, 1.23, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = {
						rot = Vector3.new(-59.66, -19.28, -10.8),
						pos = Vector3.new(-0.08, -0.7, 0.51),
					},
					Neck = { rot = Vector3.new(49.89, 20.24, -8.07) },
					RightShoulder = { rot = Vector3.new(54.05, 0, 16.69) },
					LeftShoulder = { rot = Vector3.new(69.68, 0, -41.84) },
					RightHip = {
						rot = Vector3.new(90.04, 0, -12.61),
						pos = Vector3.new(0, 0.36, 0),
					},
					LeftHip = { rot = Vector3.new(43.32, 0, -6.46), pos = Vector3.new(0, 1.16, 0) },
				},
			},
			{
				time = 0.1562,
				pose = {
					Root = {
						rot = Vector3.new(-59.66, -19.18, -10.84),
						pos = Vector3.new(-0.08, -0.72, 0.51),
					},
					Neck = { rot = Vector3.new(49.88, 20.2, -7.98) },
					RightShoulder = { rot = Vector3.new(55.04, 0, 16.47) },
					LeftShoulder = { rot = Vector3.new(69.61, 0, -41.31) },
					RightHip = {
						rot = Vector3.new(90.05, 0, -12.65),
						pos = Vector3.new(0, 0.47, 0),
					},
					LeftHip = { rot = Vector3.new(42.22, 0, -5.2), pos = Vector3.new(0, 1.12, 0) },
				},
			},
			{
				time = 0.1875,
				pose = {
					Root = {
						rot = Vector3.new(-59.65, -19.01, -10.8),
						pos = Vector3.new(-0.09, -0.72, 0.51),
					},
					Neck = { rot = Vector3.new(49.88, 20.05, -7.88) },
					RightShoulder = { rot = Vector3.new(56.74, 0, 16.19) },
					LeftShoulder = { rot = Vector3.new(68.78, 0, -40.63) },
					RightHip = {
						rot = Vector3.new(90.05, 0, -12.62),
						pos = Vector3.new(0, 0.57, 0),
					},
					LeftHip = { rot = Vector3.new(41.93, 0, -4.15), pos = Vector3.new(0, 1.09, 0) },
				},
			},
			{
				time = 0.2188,
				pose = {
					Root = {
						rot = Vector3.new(-59.61, -18.77, -10.62),
						pos = Vector3.new(-0.1, -0.72, 0.5),
					},
					Neck = { rot = Vector3.new(49.85, 19.79, -7.79) },
					RightShoulder = { rot = Vector3.new(58.92, 0, 15.88) },
					LeftShoulder = { rot = Vector3.new(67.29, 0, -39.87) },
					RightHip = {
						rot = Vector3.new(90.05, 0, -12.62),
						pos = Vector3.new(0, 0.65, 0),
					},
					LeftHip = { rot = Vector3.new(43.24, 0, -3.67), pos = Vector3.new(0, 1.02, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(-59.46, -18.53, -10.31),
						pos = Vector3.new(-0.11, -0.72, 0.5),
					},
					Neck = { rot = Vector3.new(49.75, 19.43, -7.76) },
					RightShoulder = { rot = Vector3.new(61.15, 0, 15.52) },
					LeftShoulder = { rot = Vector3.new(65.28, 0, -39.24) },
					RightHip = {
						rot = Vector3.new(90.06, 0, -12.64),
						pos = Vector3.new(0, 0.72, 0),
					},
					LeftHip = { rot = Vector3.new(45.64, 0, -3.83), pos = Vector3.new(0, 0.95, 0) },
				},
			},
			{
				time = 0.2812,
				pose = {
					Root = {
						rot = Vector3.new(-59.21, -18.26, -9.75),
						pos = Vector3.new(-0.11, -0.7, 0.49),
					},
					Neck = { rot = Vector3.new(49.57, 18.87, -7.85) },
					RightShoulder = { rot = Vector3.new(63.61, 0, 14.97) },
					LeftShoulder = { rot = Vector3.new(62.35, 0, -38.74) },
					RightHip = {
						rot = Vector3.new(90.06, 0, -12.68),
						pos = Vector3.new(0, 0.77, 0),
					},
					LeftHip = { rot = Vector3.new(49.11, 0, -4.64), pos = Vector3.new(0, 0.88, 0) },
				},
			},
			{
				time = 0.3125,
				pose = {
					Root = {
						rot = Vector3.new(-59.13, -18.19, -9.57),
						pos = Vector3.new(-0.11, -0.7, 0.49),
					},
					Neck = { rot = Vector3.new(49.52, 18.7, -7.88) },
					RightShoulder = { rot = Vector3.new(64.27, 0, 14.8) },
					LeftShoulder = { rot = Vector3.new(61.48, 0, -38.62) },
					RightHip = { rot = Vector3.new(90.06, 0, -12.7), pos = Vector3.new(0, 0.78, 0) },
					LeftHip = { rot = Vector3.new(50.13, 0, -4.91), pos = Vector3.new(0, 0.86, 0) },
				},
			},
			{
				time = 0.3438,
				pose = {
					Root = {
						rot = Vector3.new(-59.09, -18.03, -9.18),
						pos = Vector3.new(-0.12, -0.69, 0.49),
					},
					Neck = { rot = Vector3.new(49.53, 18.31, -8.01) },
					RightShoulder = { rot = Vector3.new(65.67, 0, 14.33) },
					LeftShoulder = { rot = Vector3.new(59.68, 0, -38.45) },
					RightHip = { rot = Vector3.new(90.06, 0, -12.68), pos = Vector3.new(0, 0.8, 0) },
					LeftHip = { rot = Vector3.new(52.53, 0, -5.63), pos = Vector3.new(0, 0.83, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = {
						rot = Vector3.new(-59.14, -17.78, -8.51),
						pos = Vector3.new(-0.12, -0.66, 0.5),
					},
					Neck = { rot = Vector3.new(49.69, 17.64, -8.28) },
					RightShoulder = { rot = Vector3.new(68.09, 0, 13.4) },
					LeftShoulder = { rot = Vector3.new(56.48, 0, -38.21) },
					RightHip = { rot = Vector3.new(90.06, 0, -12.49), pos = Vector3.new(0, 0.8, 0) },
					LeftHip = { rot = Vector3.new(57.25, 0, -7.01), pos = Vector3.new(0, 0.77, 0) },
				},
			},
			{
				time = 0.4062,
				pose = {
					Root = {
						rot = Vector3.new(-59.33, -17.58, -7.93),
						pos = Vector3.new(-0.11, -0.63, 0.5),
					},
					Neck = { rot = Vector3.new(49.97, 17.05, -8.56) },
					RightShoulder = { rot = Vector3.new(70.33, 0, 12.36) },
					LeftShoulder = { rot = Vector3.new(53.29, 0, -38) },
					RightHip = {
						rot = Vector3.new(90.06, 0, -12.11),
						pos = Vector3.new(0, 0.73, 0),
					},
					LeftHip = { rot = Vector3.new(61.49, 0, -8.47), pos = Vector3.new(0, 0.72, 0) },
				},
			},
			{
				time = 0.4375,
				pose = {
					Root = {
						rot = Vector3.new(-59.58, -17.41, -7.48),
						pos = Vector3.new(-0.11, -0.61, 0.51),
					},
					Neck = { rot = Vector3.new(50.28, 16.56, -8.79) },
					RightShoulder = { rot = Vector3.new(72.51, 0, 11.23) },
					LeftShoulder = { rot = Vector3.new(49.77, 0, -37.72) },
					RightHip = {
						rot = Vector3.new(90.05, 0, -11.61),
						pos = Vector3.new(0, 0.56, 0),
					},
					LeftHip = { rot = Vector3.new(65.07, 0, -9.89), pos = Vector3.new(0, 0.71, 0) },
				},
			},
			{
				time = 0.4688,
				pose = {
					Root = {
						rot = Vector3.new(-59.85, -17.25, -7.22),
						pos = Vector3.new(-0.1, -0.6, 0.52),
					},
					Neck = { rot = Vector3.new(50.57, 16.21, -8.91) },
					RightShoulder = { rot = Vector3.new(74.5, 0, 10.08) },
					LeftShoulder = { rot = Vector3.new(46.01, 0, -37.24) },
					RightHip = {
						rot = Vector3.new(90.04, 0, -11.29),
						pos = Vector3.new(0, 0.35, 0),
					},
					LeftHip = { rot = Vector3.new(68.54, 0, -11.07), pos = Vector3.new(0, 0.71, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-60.08, -17.11, -7.1),
						pos = Vector3.new(-0.1, -0.6, 0.53),
					},
					Neck = { rot = Vector3.new(50.8, 16, -8.94) },
					RightShoulder = { rot = Vector3.new(76.23, 0, 8.97) },
					LeftShoulder = { rot = Vector3.new(42.21, 0, -36.5) },
					RightHip = { rot = Vector3.new(89.98, 0, -11.3), pos = Vector3.new(0, 0.14, 0) },
					LeftHip = { rot = Vector3.new(71.97, 0, -11.43), pos = Vector3.new(0, 0.71, 0) },
				},
			},
			{
				time = 0.5312,
				pose = {
					Root = {
						rot = Vector3.new(-60.23, -17, -7.04),
						pos = Vector3.new(-0.1, -0.61, 0.53),
					},
					Neck = { rot = Vector3.new(50.94, 15.85, -8.92) },
					RightShoulder = { rot = Vector3.new(77.58, 0, 8) },
					LeftShoulder = { rot = Vector3.new(38.62, 0, -35.54) },
					RightHip = {
						rot = Vector3.new(89.23, 0, -11.45),
						pos = Vector3.new(0, -0.04, 0),
					},
					LeftHip = { rot = Vector3.new(74.51, 0, -12.01), pos = Vector3.new(0, 0.74, 0) },
				},
			},
			{
				time = 0.5625,
				pose = {
					Root = {
						rot = Vector3.new(-60.27, -16.92, -7.03),
						pos = Vector3.new(-0.09, -0.63, 0.53),
					},
					Neck = { rot = Vector3.new(50.95, 15.79, -8.86) },
					RightShoulder = { rot = Vector3.new(78.38, 0, 7.31) },
					LeftShoulder = { rot = Vector3.new(35.4, 0, -34.4) },
					RightHip = { rot = Vector3.new(77.6, 0, -10.63), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(76.55, 0, -12.64), pos = Vector3.new(0, 0.79, 0) },
				},
			},
			{
				time = 0.5938,
				pose = {
					Root = {
						rot = Vector3.new(-60.18, -16.86, -7.06),
						pos = Vector3.new(-0.09, -0.66, 0.52),
					},
					Neck = { rot = Vector3.new(50.83, 15.79, -8.76) },
					RightShoulder = { rot = Vector3.new(78.79, 0, 6.88) },
					LeftShoulder = { rot = Vector3.new(32.78, 0, -33.2) },
					RightHip = { rot = Vector3.new(59.71, 0, -7.94), pos = Vector3.new(0, 0.55, 0) },
					LeftHip = { rot = Vector3.new(78.21, 0, -13.16), pos = Vector3.new(0, 0.84, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = {
						rot = Vector3.new(-60.05, -16.82, -7.13),
						pos = Vector3.new(-0.09, -0.69, 0.52),
					},
					Neck = { rot = Vector3.new(50.67, 15.84, -8.64) },
					RightShoulder = { rot = Vector3.new(79.04, 0, 6.67) },
					LeftShoulder = { rot = Vector3.new(31.01, 0, -32.1) },
					RightHip = { rot = Vector3.new(53.82, 0, -6.06), pos = Vector3.new(0, 0.6, 0) },
					LeftHip = { rot = Vector3.new(79.86, 0, -13.67), pos = Vector3.new(0, 0.89, 0) },
				},
			},
			{
				time = 0.6562,
				pose = {
					Root = {
						rot = Vector3.new(-59.95, -16.81, -7.26),
						pos = Vector3.new(-0.1, -0.71, 0.51),
					},
					Neck = { rot = Vector3.new(50.54, 15.94, -8.52) },
					RightShoulder = { rot = Vector3.new(79.11, 0, 6.75) },
					LeftShoulder = { rot = Vector3.new(30.27, 0, -31.29) },
					RightHip = { rot = Vector3.new(50.94, 0, -5.16), pos = Vector3.new(0, 0.62, 0) },
					LeftHip = { rot = Vector3.new(81.82, 0, -14.22), pos = Vector3.new(0, 0.92, 0) },
				},
			},
			{
				time = 0.6875,
				pose = {
					Root = {
						rot = Vector3.new(-59.86, -16.87, -7.48),
						pos = Vector3.new(-0.1, -0.72, 0.5),
					},
					Neck = { rot = Vector3.new(50.4, 16.16, -8.39) },
					RightShoulder = { rot = Vector3.new(78.75, 0, 7.18) },
					LeftShoulder = { rot = Vector3.new(30.39, 0, -31.03) },
					RightHip = { rot = Vector3.new(50.31, 0, -4.93), pos = Vector3.new(0, 0.61, 0) },
					LeftHip = { rot = Vector3.new(84.17, 0, -14.9), pos = Vector3.new(0, 0.92, 0) },
				},
			},
			{
				time = 0.7188,
				pose = {
					Root = {
						rot = Vector3.new(-59.73, -17, -7.78),
						pos = Vector3.new(-0.1, -0.72, 0.5),
					},
					Neck = { rot = Vector3.new(50.23, 16.49, -8.25) },
					RightShoulder = { rot = Vector3.new(77.88, 0, 7.85) },
					LeftShoulder = { rot = Vector3.new(31.2, 0, -31.4) },
					RightHip = { rot = Vector3.new(51.85, 0, -5.26), pos = Vector3.new(0, 0.57, 0) },
					LeftHip = { rot = Vector3.new(86.72, 0, -15.76), pos = Vector3.new(0, 0.89, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(-59.57, -17.19, -8.14),
						pos = Vector3.new(-0.1, -0.72, 0.5),
					},
					Neck = { rot = Vector3.new(50.01, 16.9, -8.12) },
					RightShoulder = { rot = Vector3.new(76.55, 0, 8.69) },
					LeftShoulder = { rot = Vector3.new(32.62, 0, -32.31) },
					RightHip = { rot = Vector3.new(54.94, 0, -5.9), pos = Vector3.new(0, 0.49, 0) },
					LeftHip = { rot = Vector3.new(88.79, 0, -16.73), pos = Vector3.new(0, 0.87, 0) },
				},
			},
			{
				time = 0.7812,
				pose = {
					Root = {
						rot = Vector3.new(-59.36, -17.43, -8.52),
						pos = Vector3.new(-0.09, -0.71, 0.49),
					},
					Neck = { rot = Vector3.new(49.74, 17.37, -7.99) },
					RightShoulder = { rot = Vector3.new(74.79, 0, 9.66) },
					LeftShoulder = { rot = Vector3.new(34.58, 0, -33.61) },
					RightHip = { rot = Vector3.new(59.3, 0, -6.7), pos = Vector3.new(0, 0.36, 0) },
					LeftHip = { rot = Vector3.new(90.16, 0, -17.77), pos = Vector3.new(0, 0.84, 0) },
				},
			},
			{
				time = 0.8125,
				pose = {
					Root = {
						rot = Vector3.new(-59.16, -17.7, -8.92),
						pos = Vector3.new(-0.09, -0.7, 0.49),
					},
					Neck = { rot = Vector3.new(49.49, 17.87, -7.88) },
					RightShoulder = { rot = Vector3.new(72.71, 0, 10.7) },
					LeftShoulder = { rot = Vector3.new(37.13, 0, -35.18) },
					RightHip = { rot = Vector3.new(63.14, 0, -7.57), pos = Vector3.new(0, 0.28, 0) },
					LeftHip = { rot = Vector3.new(90.13, 0, -18.33), pos = Vector3.new(0, 0.87, 0) },
				},
			},
			{
				time = 0.8438,
				pose = {
					Root = {
						rot = Vector3.new(-59.11, -17.99, -9.35),
						pos = Vector3.new(-0.08, -0.67, 0.5),
					},
					Neck = { rot = Vector3.new(49.38, 18.37, -7.81) },
					RightShoulder = { rot = Vector3.new(70.52, 0, 11.75) },
					LeftShoulder = { rot = Vector3.new(40.33, 0, -36.88) },
					RightHip = { rot = Vector3.new(66.97, 0, -8.62), pos = Vector3.new(0, 0.23, 0) },
					LeftHip = { rot = Vector3.new(90.15, 0, -18.88), pos = Vector3.new(0, 0.88, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = {
						rot = Vector3.new(-59.19, -18.25, -9.84),
						pos = Vector3.new(-0.08, -0.64, 0.5),
					},
					Neck = { rot = Vector3.new(49.4, 18.9, -7.72) },
					RightShoulder = { rot = Vector3.new(68.24, 0, 12.8) },
					LeftShoulder = { rot = Vector3.new(44.1, 0, -38.51) },
					RightHip = { rot = Vector3.new(72.05, 0, -9.67), pos = Vector3.new(0, 0.16, 0) },
					LeftHip = { rot = Vector3.new(90.15, 0, -19.15), pos = Vector3.new(0, 0.83, 0) },
				},
			},
			{
				time = 0.9062,
				pose = {
					Root = {
						rot = Vector3.new(-59.35, -18.48, -10.31),
						pos = Vector3.new(-0.08, -0.62, 0.51),
					},
					Neck = { rot = Vector3.new(49.49, 19.37, -7.65) },
					RightShoulder = { rot = Vector3.new(65.86, 0, 13.84) },
					LeftShoulder = { rot = Vector3.new(48.28, 0, -39.95) },
					RightHip = {
						rot = Vector3.new(77.94, 0, -10.54),
						pos = Vector3.new(0, 0.06, 0),
					},
					LeftHip = { rot = Vector3.new(89.97, 0, -18.65), pos = Vector3.new(0, 0.71, 0) },
				},
			},
			{
				time = 0.9375,
				pose = {
					Root = {
						rot = Vector3.new(-59.54, -18.69, -10.62),
						pos = Vector3.new(-0.08, -0.6, 0.52),
					},
					Neck = { rot = Vector3.new(49.66, 19.71, -7.68) },
					RightShoulder = { rot = Vector3.new(63.39, 0, 14.84) },
					LeftShoulder = { rot = Vector3.new(52.76, 0, -41.16) },
					RightHip = { rot = Vector3.new(82.61, 0, -10.6) },
					LeftHip = { rot = Vector3.new(85.26, 0, -17.06), pos = Vector3.new(0, 0.71, 0) },
				},
			},
			{
				time = 0.9688,
				pose = {
					Root = {
						rot = Vector3.new(-59.73, -18.88, -10.76),
						pos = Vector3.new(-0.07, -0.6, 0.52),
					},
					Neck = { rot = Vector3.new(49.87, 19.91, -7.82) },
					RightShoulder = { rot = Vector3.new(60.88, 0, 15.67) },
					LeftShoulder = { rot = Vector3.new(57.28, 0, -42.05) },
					RightHip = { rot = Vector3.new(85.38, 0, -10.62) },
					LeftHip = { rot = Vector3.new(78.55, 0, -15.56), pos = Vector3.new(0, 0.77, 0) },
				},
			},
		},
	},
	-- ALS_CLF_Walk_L: phase clip (one cycle = 1), left foot plants at 0.4375; natural cycle 1.167 s, stride 1.95 studs per cycle
	CrouchWalkLeft = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-56.68, -21.95, -25.9),
						pos = Vector3.new(-0.3, -0.81, 0.44),
					},
					Neck = { rot = Vector3.new(53.31, 33.27, -1.75) },
					RightShoulder = { rot = Vector3.new(53.1, 0, 28.44) },
					LeftShoulder = { rot = Vector3.new(35.03, 0, -32.97) },
					RightHip = {
						rot = Vector3.new(59.09, 0, -19.12),
						pos = Vector3.new(0, 0.58, 0),
					},
					LeftHip = { rot = Vector3.new(87.22, 0, 11.2), pos = Vector3.new(0, 0.54, 0) },
				},
			},
			{
				time = 0.0312,
				pose = {
					Root = {
						rot = Vector3.new(-56.68, -22.41, -26.2),
						pos = Vector3.new(-0.3, -0.79, 0.44),
					},
					Neck = { rot = Vector3.new(53.21, 33.74, -1.93) },
					RightShoulder = { rot = Vector3.new(53.42, 0, 28.24) },
					LeftShoulder = { rot = Vector3.new(34.51, 0, -33.08) },
					RightHip = { rot = Vector3.new(60.1, 0, -17.24), pos = Vector3.new(0, 0.57, 0) },
					LeftHip = { rot = Vector3.new(89.31, 0, 10.56), pos = Vector3.new(0, 0.46, 0) },
				},
			},
			{
				time = 0.0625,
				pose = {
					Root = {
						rot = Vector3.new(-56.68, -22.83, -26.57),
						pos = Vector3.new(-0.3, -0.75, 0.45),
					},
					Neck = { rot = Vector3.new(53.07, 34.26, -2.02) },
					RightShoulder = { rot = Vector3.new(53.22, 0, 28.36) },
					LeftShoulder = { rot = Vector3.new(34.7, 0, -33.5) },
					RightHip = {
						rot = Vector3.new(61.64, 0, -14.89),
						pos = Vector3.new(0, 0.55, 0),
					},
					LeftHip = { rot = Vector3.new(89.83, 0, 9.31), pos = Vector3.new(0, 0.4, 0) },
				},
			},
			{
				time = 0.0938,
				pose = {
					Root = {
						rot = Vector3.new(-56.65, -23.22, -26.99),
						pos = Vector3.new(-0.3, -0.71, 0.44),
					},
					Neck = { rot = Vector3.new(52.87, 34.8, -2.03) },
					RightShoulder = { rot = Vector3.new(52.53, 0, 28.76) },
					LeftShoulder = { rot = Vector3.new(35.63, 0, -34.15) },
					RightHip = {
						rot = Vector3.new(63.45, 0, -12.32),
						pos = Vector3.new(0, 0.52, 0),
					},
					LeftHip = { rot = Vector3.new(88.22, 0, 7.39), pos = Vector3.new(0, 0.4, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = {
						rot = Vector3.new(-56.62, -23.57, -27.37),
						pos = Vector3.new(-0.3, -0.69, 0.44),
					},
					Neck = { rot = Vector3.new(52.68, 35.29, -2.03) },
					RightShoulder = { rot = Vector3.new(51.36, 0, 29.36) },
					LeftShoulder = { rot = Vector3.new(37.29, 0, -35.02) },
					RightHip = { rot = Vector3.new(65.28, 0, -9.58), pos = Vector3.new(0, 0.51, 0) },
					LeftHip = { rot = Vector3.new(82.56, 0, 4.22), pos = Vector3.new(0, 0.49, 0) },
				},
			},
			{
				time = 0.1562,
				pose = {
					Root = {
						rot = Vector3.new(-56.59, -23.88, -27.6),
						pos = Vector3.new(-0.3, -0.68, 0.44),
					},
					Neck = { rot = Vector3.new(52.57, 35.64, -2.12) },
					RightShoulder = { rot = Vector3.new(49.72, 0, 30.03) },
					LeftShoulder = { rot = Vector3.new(39.64, 0, -36.04) },
					RightHip = { rot = Vector3.new(67.03, 0, -6.84), pos = Vector3.new(0, 0.51, 0) },
					LeftHip = { rot = Vector3.new(75.09, 0, -0.1), pos = Vector3.new(0, 0.61, 0) },
				},
			},
			{
				time = 0.1875,
				pose = {
					Root = {
						rot = Vector3.new(-56.59, -24.14, -27.74),
						pos = Vector3.new(-0.31, -0.68, 0.43),
					},
					Neck = { rot = Vector3.new(52.52, 35.88, -2.25) },
					RightShoulder = { rot = Vector3.new(47.66, 0, 30.75) },
					LeftShoulder = { rot = Vector3.new(42.61, 0, -37.07) },
					RightHip = { rot = Vector3.new(68.83, 0, -4.24), pos = Vector3.new(0, 0.51, 0) },
					LeftHip = { rot = Vector3.new(66.6, 0, -5.13), pos = Vector3.new(0, 0.78, 0) },
				},
			},
			{
				time = 0.2188,
				pose = {
					Root = {
						rot = Vector3.new(-56.59, -24.35, -27.85),
						pos = Vector3.new(-0.31, -0.7, 0.43),
					},
					Neck = { rot = Vector3.new(52.5, 36.09, -2.37) },
					RightShoulder = { rot = Vector3.new(45.24, 0, 31.5) },
					LeftShoulder = { rot = Vector3.new(46.03, 0, -37.91) },
					RightHip = { rot = Vector3.new(70.08, 0, -2.3), pos = Vector3.new(0, 0.53, 0) },
					LeftHip = { rot = Vector3.new(58.75, 0, -10.64), pos = Vector3.new(0, 0.95, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(-56.6, -24.49, -27.95),
						pos = Vector3.new(-0.32, -0.72, 0.43),
					},
					Neck = { rot = Vector3.new(52.5, 36.24, -2.46) },
					RightShoulder = { rot = Vector3.new(42.52, 0, 32.21) },
					LeftShoulder = { rot = Vector3.new(49.77, 0, -38.46) },
					RightHip = { rot = Vector3.new(69.84, 0, -0.08), pos = Vector3.new(0, 0.63, 0) },
					LeftHip = { rot = Vector3.new(53.93, 0, -16), pos = Vector3.new(0, 1.02, 0) },
				},
			},
			{
				time = 0.2812,
				pose = {
					Root = {
						rot = Vector3.new(-56.63, -24.58, -28.02),
						pos = Vector3.new(-0.33, -0.75, 0.42),
					},
					Neck = { rot = Vector3.new(52.53, 36.35, -2.52) },
					RightShoulder = { rot = Vector3.new(39.55, 0, 32.86) },
					LeftShoulder = { rot = Vector3.new(53.61, 0, -38.62) },
					RightHip = { rot = Vector3.new(69.27, 0, 2.8), pos = Vector3.new(0, 0.73, 0) },
					LeftHip = { rot = Vector3.new(50.57, 0, -20.68), pos = Vector3.new(0, 1.03, 0) },
				},
			},
			{
				time = 0.3125,
				pose = {
					Root = {
						rot = Vector3.new(-56.74, -24.57, -28.14),
						pos = Vector3.new(-0.34, -0.78, 0.42),
					},
					Neck = { rot = Vector3.new(52.63, 36.44, -2.53) },
					RightShoulder = { rot = Vector3.new(36.41, 0, 33.53) },
					LeftShoulder = { rot = Vector3.new(57.36, 0, -38.36) },
					RightHip = { rot = Vector3.new(69.1, 0, 5.6), pos = Vector3.new(0, 0.83, 0) },
					LeftHip = { rot = Vector3.new(46.84, 0, -23.68), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.3438,
				pose = {
					Root = {
						rot = Vector3.new(-56.96, -24.41, -28.34),
						pos = Vector3.new(-0.35, -0.8, 0.42),
					},
					Neck = { rot = Vector3.new(52.83, 36.52, -2.43) },
					RightShoulder = { rot = Vector3.new(33.27, 0, 34.21) },
					LeftShoulder = { rot = Vector3.new(60.92, 0, -37.73) },
					RightHip = { rot = Vector3.new(69.48, 0, 8.51), pos = Vector3.new(0, 0.92, 0) },
					LeftHip = { rot = Vector3.new(44.02, 0, -24.44), pos = Vector3.new(0, 1.17, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = {
						rot = Vector3.new(-57.18, -24.1, -28.49),
						pos = Vector3.new(-0.37, -0.82, 0.42),
					},
					Neck = { rot = Vector3.new(53.05, 36.47, -2.23) },
					RightShoulder = { rot = Vector3.new(30.11, 0, 34.77) },
					LeftShoulder = { rot = Vector3.new(64.09, 0, -36.85) },
					RightHip = { rot = Vector3.new(70.33, 0, 11.45), pos = Vector3.new(0, 0.99, 0) },
					LeftHip = { rot = Vector3.new(42.93, 0, -23.75), pos = Vector3.new(0, 1.2, 0) },
				},
			},
			{
				time = 0.4062,
				pose = {
					Root = {
						rot = Vector3.new(-57.32, -23.7, -28.5),
						pos = Vector3.new(-0.38, -0.83, 0.42),
					},
					Neck = { rot = Vector3.new(53.22, 36.28, -2) },
					RightShoulder = { rot = Vector3.new(27.01, 0, 35.13) },
					LeftShoulder = { rot = Vector3.new(66.54, 0, -35.93) },
					RightHip = { rot = Vector3.new(71.59, 0, 14.29), pos = Vector3.new(0, 1.02, 0) },
					LeftHip = { rot = Vector3.new(43.48, 0, -22.01), pos = Vector3.new(0, 1.19, 0) },
				},
			},
			{
				time = 0.4375,
				pose = {
					Root = {
						rot = Vector3.new(-57.32, -23.29, -28.33),
						pos = Vector3.new(-0.39, -0.83, 0.42),
					},
					Neck = { rot = Vector3.new(53.3, 35.94, -1.79) },
					RightShoulder = { rot = Vector3.new(24.09, 0, 35.26) },
					LeftShoulder = { rot = Vector3.new(68.16, 0, -35.12) },
					RightHip = { rot = Vector3.new(72.8, 0, 16.74), pos = Vector3.new(0, 1.03, 0) },
					LeftHip = { rot = Vector3.new(44.83, 0, -20.37), pos = Vector3.new(0, 1.16, 0) },
				},
			},
			{
				time = 0.4688,
				pose = {
					Root = {
						rot = Vector3.new(-57.13, -22.92, -27.89),
						pos = Vector3.new(-0.4, -0.82, 0.41),
					},
					Neck = { rot = Vector3.new(53.25, 35.43, -1.68) },
					RightShoulder = { rot = Vector3.new(21.45, 0, 35.14) },
					LeftShoulder = { rot = Vector3.new(69.05, 0, -34.48) },
					RightHip = { rot = Vector3.new(73.47, 0, 18.85), pos = Vector3.new(0, 1.03, 0) },
					LeftHip = { rot = Vector3.new(46.84, 0, -18.73), pos = Vector3.new(0, 1.12, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-56.89, -22.64, -27.37),
						pos = Vector3.new(-0.4, -0.81, 0.41),
					},
					Neck = { rot = Vector3.new(53.17, 34.9, -1.66) },
					RightShoulder = { rot = Vector3.new(19.69, 0, 34.91) },
					LeftShoulder = { rot = Vector3.new(69.29, 0, -34.16) },
					RightHip = { rot = Vector3.new(73.53, 0, 19.86), pos = Vector3.new(0, 1.01, 0) },
					LeftHip = { rot = Vector3.new(49.56, 0, -17.16), pos = Vector3.new(0, 1.05, 0) },
				},
			},
			{
				time = 0.5312,
				pose = {
					Root = {
						rot = Vector3.new(-56.86, -22.6, -27.28),
						pos = Vector3.new(-0.4, -0.8, 0.41),
					},
					Neck = { rot = Vector3.new(53.17, 34.8, -1.67) },
					RightShoulder = { rot = Vector3.new(19.55, 0, 34.86) },
					LeftShoulder = { rot = Vector3.new(69.25, 0, -34.15) },
					RightHip = { rot = Vector3.new(73.66, 0, 19.94), pos = Vector3.new(0, 1.01, 0) },
					LeftHip = { rot = Vector3.new(49.51, 0, -17.02), pos = Vector3.new(0, 1.04, 0) },
				},
			},
			{
				time = 0.5625,
				pose = {
					Root = {
						rot = Vector3.new(-56.61, -22.23, -26.52),
						pos = Vector3.new(-0.39, -0.77, 0.4),
					},
					Neck = { rot = Vector3.new(53.17, 34.02, -1.75) },
					RightShoulder = { rot = Vector3.new(18.42, 0, 34.51) },
					LeftShoulder = { rot = Vector3.new(68.83, 0, -34.11) },
					RightHip = { rot = Vector3.new(74.03, 0, 20.27), pos = Vector3.new(0, 0.94, 0) },
					LeftHip = { rot = Vector3.new(51.58, 0, -15.07), pos = Vector3.new(0, 0.96, 0) },
				},
			},
			{
				time = 0.5938,
				pose = {
					Root = {
						rot = Vector3.new(-56.45, -21.94, -25.88),
						pos = Vector3.new(-0.39, -0.73, 0.4),
					},
					Neck = { rot = Vector3.new(53.22, 33.37, -1.87) },
					RightShoulder = { rot = Vector3.new(18.69, 0, 34.33) },
					LeftShoulder = { rot = Vector3.new(67.76, 0, -34.38) },
					RightHip = { rot = Vector3.new(73.06, 0, 18.44), pos = Vector3.new(0, 0.89, 0) },
					LeftHip = { rot = Vector3.new(54.69, 0, -12.9), pos = Vector3.new(0, 0.91, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = {
						rot = Vector3.new(-56.32, -21.68, -25.32),
						pos = Vector3.new(-0.38, -0.7, 0.39),
					},
					Neck = { rot = Vector3.new(53.26, 32.79, -1.95) },
					RightShoulder = { rot = Vector3.new(19.86, 0, 34.33) },
					LeftShoulder = { rot = Vector3.new(66.08, 0, -34.81) },
					RightHip = { rot = Vector3.new(70.92, 0, 13.82), pos = Vector3.new(0, 0.82, 0) },
					LeftHip = { rot = Vector3.new(57.79, 0, -10.7), pos = Vector3.new(0, 0.85, 0) },
				},
			},
			{
				time = 0.6562,
				pose = {
					Root = {
						rot = Vector3.new(-56.2, -21.44, -24.94),
						pos = Vector3.new(-0.37, -0.68, 0.39),
					},
					Neck = { rot = Vector3.new(53.24, 32.37, -1.94) },
					RightShoulder = { rot = Vector3.new(21.88, 0, 34.49) },
					LeftShoulder = { rot = Vector3.new(63.82, 0, -35.3) },
					RightHip = { rot = Vector3.new(68.76, 0, 7.26), pos = Vector3.new(0, 0.73, 0) },
					LeftHip = { rot = Vector3.new(60.8, 0, -8.33), pos = Vector3.new(0, 0.79, 0) },
				},
			},
			{
				time = 0.6875,
				pose = {
					Root = {
						rot = Vector3.new(-56.09, -21.24, -24.72),
						pos = Vector3.new(-0.36, -0.68, 0.39),
					},
					Neck = { rot = Vector3.new(53.17, 32.09, -1.83) },
					RightShoulder = { rot = Vector3.new(24.6, 0, 34.72) },
					LeftShoulder = { rot = Vector3.new(61.04, 0, -35.74) },
					RightHip = { rot = Vector3.new(68.92, 0, 0.13), pos = Vector3.new(0, 0.57, 0) },
					LeftHip = { rot = Vector3.new(63.78, 0, -5.85), pos = Vector3.new(0, 0.73, 0) },
				},
			},
			{
				time = 0.7188,
				pose = {
					Root = {
						rot = Vector3.new(-56, -21.06, -24.59),
						pos = Vector3.new(-0.35, -0.69, 0.39),
					},
					Neck = { rot = Vector3.new(53.09, 31.89, -1.7) },
					RightShoulder = { rot = Vector3.new(27.85, 0, 34.85) },
					LeftShoulder = { rot = Vector3.new(57.93, 0, -36.06) },
					RightHip = { rot = Vector3.new(63.53, 0, -6.6), pos = Vector3.new(0, 0.66, 0) },
					LeftHip = { rot = Vector3.new(66.94, 0, -3.19), pos = Vector3.new(0, 0.67, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(-55.95, -20.92, -24.52),
						pos = Vector3.new(-0.34, -0.7, 0.39),
					},
					Neck = { rot = Vector3.new(53.03, 31.75, -1.57) },
					RightShoulder = { rot = Vector3.new(31.45, 0, 34.78) },
					LeftShoulder = { rot = Vector3.new(54.6, 0, -36.2) },
					RightHip = {
						rot = Vector3.new(60.26, 0, -12.06),
						pos = Vector3.new(0, 0.74, 0),
					},
					LeftHip = { rot = Vector3.new(68.74, 0, -1.93), pos = Vector3.new(0, 0.67, 0) },
				},
			},
			{
				time = 0.7812,
				pose = {
					Root = {
						rot = Vector3.new(-55.92, -20.82, -24.5),
						pos = Vector3.new(-0.33, -0.73, 0.39),
					},
					Neck = { rot = Vector3.new(52.99, 31.67, -1.46) },
					RightShoulder = { rot = Vector3.new(35.22, 0, 34.45) },
					LeftShoulder = { rot = Vector3.new(51.21, 0, -36.12) },
					RightHip = {
						rot = Vector3.new(60.31, 0, -17.09),
						pos = Vector3.new(0, 0.67, 0),
					},
					LeftHip = { rot = Vector3.new(69.82, 0, 0.44), pos = Vector3.new(0, 0.7, 0) },
				},
			},
			{
				time = 0.8125,
				pose = {
					Root = {
						rot = Vector3.new(-55.92, -20.75, -24.52),
						pos = Vector3.new(-0.33, -0.76, 0.4),
					},
					Neck = { rot = Vector3.new(52.96, 31.64, -1.36) },
					RightShoulder = { rot = Vector3.new(38.97, 0, 33.85) },
					LeftShoulder = { rot = Vector3.new(47.9, 0, -35.82) },
					RightHip = {
						rot = Vector3.new(61.61, 0, -21.21),
						pos = Vector3.new(0, 0.55, 0),
					},
					LeftHip = { rot = Vector3.new(70.98, 0, 2.83), pos = Vector3.new(0, 0.73, 0) },
				},
			},
			{
				time = 0.8438,
				pose = {
					Root = {
						rot = Vector3.new(-56.01, -20.7, -24.62),
						pos = Vector3.new(-0.32, -0.79, 0.4),
					},
					Neck = { rot = Vector3.new(53.02, 31.67, -1.28) },
					RightShoulder = { rot = Vector3.new(42.57, 0, 33) },
					LeftShoulder = { rot = Vector3.new(44.86, 0, -35.34) },
					RightHip = {
						rot = Vector3.new(62.39, 0, -23.29),
						pos = Vector3.new(0, 0.49, 0),
					},
					LeftHip = { rot = Vector3.new(72.53, 0, 5.18), pos = Vector3.new(0, 0.75, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = {
						rot = Vector3.new(-56.18, -20.73, -24.8),
						pos = Vector3.new(-0.31, -0.81, 0.41),
					},
					Neck = { rot = Vector3.new(53.13, 31.81, -1.25) },
					RightShoulder = { rot = Vector3.new(45.9, 0, 31.97) },
					LeftShoulder = { rot = Vector3.new(42.14, 0, -34.75) },
					RightHip = {
						rot = Vector3.new(60.94, 0, -23.94),
						pos = Vector3.new(0, 0.51, 0),
					},
					LeftHip = { rot = Vector3.new(74.6, 0, 7.36), pos = Vector3.new(0, 0.75, 0) },
				},
			},
			{
				time = 0.9062,
				pose = {
					Root = {
						rot = Vector3.new(-56.36, -20.88, -25.05),
						pos = Vector3.new(-0.31, -0.83, 0.42),
					},
					Neck = { rot = Vector3.new(53.25, 32.08, -1.3) },
					RightShoulder = { rot = Vector3.new(48.73, 0, 30.85) },
					LeftShoulder = { rot = Vector3.new(39.74, 0, -34.14) },
					RightHip = {
						rot = Vector3.new(59.53, 0, -23.53),
						pos = Vector3.new(0, 0.53, 0),
					},
					LeftHip = { rot = Vector3.new(77.5, 0, 9.24), pos = Vector3.new(0, 0.73, 0) },
				},
			},
			{
				time = 0.9375,
				pose = {
					Root = {
						rot = Vector3.new(-56.53, -21.15, -25.35),
						pos = Vector3.new(-0.3, -0.83, 0.42),
					},
					Neck = { rot = Vector3.new(53.34, 32.43, -1.4) },
					RightShoulder = { rot = Vector3.new(50.81, 0, 29.85) },
					LeftShoulder = { rot = Vector3.new(37.73, 0, -33.57) },
					RightHip = {
						rot = Vector3.new(58.95, 0, -22.05),
						pos = Vector3.new(0, 0.55, 0),
					},
					LeftHip = { rot = Vector3.new(80.98, 0, 10.48), pos = Vector3.new(0, 0.67, 0) },
				},
			},
			{
				time = 0.9688,
				pose = {
					Root = {
						rot = Vector3.new(-56.64, -21.51, -25.64),
						pos = Vector3.new(-0.3, -0.83, 0.43),
					},
					Neck = { rot = Vector3.new(53.36, 32.84, -1.56) },
					RightShoulder = { rot = Vector3.new(52.25, 0, 29.01) },
					LeftShoulder = { rot = Vector3.new(36.14, 0, -33.16) },
					RightHip = {
						rot = Vector3.new(58.84, 0, -20.53),
						pos = Vector3.new(0, 0.57, 0),
					},
					LeftHip = { rot = Vector3.new(84.26, 0, 11.09), pos = Vector3.new(0, 0.61, 0) },
				},
			},
		},
	},
	-- ALS_CLF_Walk_R: phase clip (one cycle = 1), left foot plants at 0.4375; natural cycle 1.167 s, stride 3.66 studs per cycle
	CrouchWalkRight = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-56.8, -24.53, -28.26),
						pos = Vector3.new(-0.35, -0.8, 0.42),
					},
					Neck = { rot = Vector3.new(52.78, 36.56, -2.48) },
					RightShoulder = { rot = Vector3.new(33.03, 0, 35.87) },
					LeftShoulder = { rot = Vector3.new(81.81, 0, -35.24) },
					RightHip = { rot = Vector3.new(69.2, 0, 7.44), pos = Vector3.new(0, 0.89, 0) },
					LeftHip = { rot = Vector3.new(43.72, 0, -25.26), pos = Vector3.new(0, 1.17, 0) },
				},
			},
			{
				time = 0.0312,
				pose = {
					Root = {
						rot = Vector3.new(-56.63, -24.62, -28.11),
						pos = Vector3.new(-0.34, -0.77, 0.42),
					},
					Neck = { rot = Vector3.new(52.62, 36.47, -2.54) },
					RightShoulder = { rot = Vector3.new(36.85, 0, 35.22) },
					LeftShoulder = { rot = Vector3.new(77.43, 0, -37.87) },
					RightHip = { rot = Vector3.new(69.04, 0, 4.57), pos = Vector3.new(0, 0.8, 0) },
					LeftHip = { rot = Vector3.new(46.95, 0, -23.65), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.0625,
				pose = {
					Root = {
						rot = Vector3.new(-56.58, -24.58, -28.06),
						pos = Vector3.new(-0.33, -0.74, 0.42),
					},
					Neck = { rot = Vector3.new(52.55, 36.38, -2.51) },
					RightShoulder = { rot = Vector3.new(40.6, 0, 34.5) },
					LeftShoulder = { rot = Vector3.new(72.33, 0, -40.01) },
					RightHip = { rot = Vector3.new(69.38, 0, 1.79), pos = Vector3.new(0, 0.7, 0) },
					LeftHip = { rot = Vector3.new(50.33, 0, -19.68), pos = Vector3.new(0, 1.09, 0) },
				},
			},
			{
				time = 0.0938,
				pose = {
					Root = {
						rot = Vector3.new(-56.57, -24.47, -28),
						pos = Vector3.new(-0.32, -0.71, 0.43),
					},
					Neck = { rot = Vector3.new(52.53, 36.25, -2.43) },
					RightShoulder = { rot = Vector3.new(44.08, 0, 33.68) },
					LeftShoulder = { rot = Vector3.new(66.66, 0, -41.44) },
					RightHip = { rot = Vector3.new(69.99, 0, -1.02), pos = Vector3.new(0, 0.59, 0) },
					LeftHip = { rot = Vector3.new(54.46, 0, -14.59), pos = Vector3.new(0, 1.05, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = {
						rot = Vector3.new(-56.57, -24.29, -27.92),
						pos = Vector3.new(-0.31, -0.69, 0.43),
					},
					Neck = { rot = Vector3.new(52.53, 36.07, -2.34) },
					RightShoulder = { rot = Vector3.new(47.21, 0, 32.74) },
					LeftShoulder = { rot = Vector3.new(60.79, 0, -42.09) },
					RightHip = { rot = Vector3.new(69.56, 0, -2.87), pos = Vector3.new(0, 0.52, 0) },
					LeftHip = { rot = Vector3.new(60.37, 0, -9.03), pos = Vector3.new(0, 0.95, 0) },
				},
			},
			{
				time = 0.1562,
				pose = {
					Root = {
						rot = Vector3.new(-56.59, -24.05, -27.82),
						pos = Vector3.new(-0.31, -0.68, 0.44),
					},
					Neck = { rot = Vector3.new(52.56, 35.85, -2.21) },
					RightShoulder = { rot = Vector3.new(49.92, 0, 31.75) },
					LeftShoulder = { rot = Vector3.new(55.2, 0, -41.99) },
					RightHip = { rot = Vector3.new(68.36, 0, -4.91), pos = Vector3.new(0, 0.51, 0) },
					LeftHip = { rot = Vector3.new(69.24, 0, -3.51), pos = Vector3.new(0, 0.74, 0) },
				},
			},
			{
				time = 0.1875,
				pose = {
					Root = {
						rot = Vector3.new(-56.61, -23.77, -27.67),
						pos = Vector3.new(-0.3, -0.68, 0.44),
					},
					Neck = { rot = Vector3.new(52.62, 35.57, -2.08) },
					RightShoulder = { rot = Vector3.new(52.16, 0, 30.8) },
					LeftShoulder = { rot = Vector3.new(50.27, 0, -41.32) },
					RightHip = { rot = Vector3.new(66.81, 0, -7.47), pos = Vector3.new(0, 0.51, 0) },
					LeftHip = { rot = Vector3.new(78.28, 0, 1.45), pos = Vector3.new(0, 0.55, 0) },
				},
			},
			{
				time = 0.2188,
				pose = {
					Root = {
						rot = Vector3.new(-56.65, -23.44, -27.39),
						pos = Vector3.new(-0.3, -0.7, 0.44),
					},
					Neck = { rot = Vector3.new(52.76, 35.16, -2.03) },
					RightShoulder = { rot = Vector3.new(53.87, 0, 29.91) },
					LeftShoulder = { rot = Vector3.new(46.39, 0, -40.38) },
					RightHip = {
						rot = Vector3.new(65.28, 0, -10.01),
						pos = Vector3.new(0, 0.52, 0),
					},
					LeftHip = { rot = Vector3.new(85.15, 0, 5.49), pos = Vector3.new(0, 0.45, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(-56.7, -23.07, -26.99),
						pos = Vector3.new(-0.3, -0.73, 0.44),
					},
					Neck = { rot = Vector3.new(52.96, 34.63, -2.04) },
					RightShoulder = { rot = Vector3.new(55.02, 0, 29.19) },
					LeftShoulder = { rot = Vector3.new(43.68, 0, -39.44) },
					RightHip = {
						rot = Vector3.new(63.48, 0, -12.63),
						pos = Vector3.new(0, 0.54, 0),
					},
					LeftHip = { rot = Vector3.new(89.3, 0, 8.21), pos = Vector3.new(0, 0.39, 0) },
				},
			},
			{
				time = 0.2812,
				pose = {
					Root = {
						rot = Vector3.new(-56.72, -22.68, -26.59),
						pos = Vector3.new(-0.3, -0.76, 0.44),
					},
					Neck = { rot = Vector3.new(53.14, 34.11, -2.02) },
					RightShoulder = { rot = Vector3.new(55.64, 0, 28.75) },
					LeftShoulder = { rot = Vector3.new(42.14, 0, -38.68) },
					RightHip = {
						rot = Vector3.new(61.64, 0, -15.11),
						pos = Vector3.new(0, 0.57, 0),
					},
					LeftHip = { rot = Vector3.new(89.98, 0, 9.84), pos = Vector3.new(0, 0.42, 0) },
				},
			},
			{
				time = 0.3125,
				pose = {
					Root = {
						rot = Vector3.new(-56.72, -22.18, -26.22),
						pos = Vector3.new(-0.3, -0.8, 0.44),
					},
					Neck = { rot = Vector3.new(53.27, 33.55, -1.86) },
					RightShoulder = { rot = Vector3.new(55.61, 0, 28.75) },
					LeftShoulder = { rot = Vector3.new(42, 0, -38.24) },
					RightHip = {
						rot = Vector3.new(59.92, 0, -17.75),
						pos = Vector3.new(0, 0.59, 0),
					},
					LeftHip = { rot = Vector3.new(88.51, 0, 10.92), pos = Vector3.new(0, 0.49, 0) },
				},
			},
			{
				time = 0.3438,
				pose = {
					Root = {
						rot = Vector3.new(-56.72, -22.08, -26.15),
						pos = Vector3.new(-0.3, -0.81, 0.44),
					},
					Neck = { rot = Vector3.new(53.29, 33.45, -1.83) },
					RightShoulder = { rot = Vector3.new(55.58, 0, 28.77) },
					LeftShoulder = { rot = Vector3.new(42.02, 0, -38.18) },
					RightHip = {
						rot = Vector3.new(59.59, 0, -18.27),
						pos = Vector3.new(0, 0.59, 0),
					},
					LeftHip = { rot = Vector3.new(88.14, 0, 11.11), pos = Vector3.new(0, 0.51, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = {
						rot = Vector3.new(-56.7, -21.75, -25.96),
						pos = Vector3.new(-0.3, -0.82, 0.44),
					},
					Neck = { rot = Vector3.new(53.35, 33.12, -1.68) },
					RightShoulder = { rot = Vector3.new(55.08, 0, 29.15) },
					LeftShoulder = { rot = Vector3.new(42.92, 0, -38.24) },
					RightHip = {
						rot = Vector3.new(59.11, 0, -19.57),
						pos = Vector3.new(0, 0.59, 0),
					},
					LeftHip = { rot = Vector3.new(86.11, 0, 11.23), pos = Vector3.new(0, 0.57, 0) },
				},
			},
			{
				time = 0.4062,
				pose = {
					Root = {
						rot = Vector3.new(-56.63, -21.32, -25.67),
						pos = Vector3.new(-0.3, -0.83, 0.43),
					},
					Neck = { rot = Vector3.new(53.38, 32.69, -1.49) },
					RightShoulder = { rot = Vector3.new(53.85, 0, 30.02) },
					LeftShoulder = { rot = Vector3.new(44.99, 0, -38.56) },
					RightHip = { rot = Vector3.new(59, 0, -21.32), pos = Vector3.new(0, 0.57, 0) },
					LeftHip = { rot = Vector3.new(82.87, 0, 10.87), pos = Vector3.new(0, 0.64, 0) },
				},
			},
			{
				time = 0.4375,
				pose = {
					Root = {
						rot = Vector3.new(-56.48, -21.01, -25.36),
						pos = Vector3.new(-0.31, -0.83, 0.42),
					},
					Neck = { rot = Vector3.new(53.32, 32.31, -1.36) },
					RightShoulder = { rot = Vector3.new(51.95, 0, 31.16) },
					LeftShoulder = { rot = Vector3.new(47.97, 0, -39.03) },
					RightHip = {
						rot = Vector3.new(59.28, 0, -22.95),
						pos = Vector3.new(0, 0.54, 0),
					},
					LeftHip = { rot = Vector3.new(79.5, 0, 10.06), pos = Vector3.new(0, 0.7, 0) },
				},
			},
			{
				time = 0.4688,
				pose = {
					Root = {
						rot = Vector3.new(-56.28, -20.8, -25.08),
						pos = Vector3.new(-0.31, -0.82, 0.41),
					},
					Neck = { rot = Vector3.new(53.22, 32, -1.28) },
					RightShoulder = { rot = Vector3.new(49.24, 0, 32.5) },
					LeftShoulder = { rot = Vector3.new(51.76, 0, -39.44) },
					RightHip = {
						rot = Vector3.new(60.37, 0, -24.24),
						pos = Vector3.new(0, 0.52, 0),
					},
					LeftHip = { rot = Vector3.new(76.1, 0, 8.46), pos = Vector3.new(0, 0.74, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-56.09, -20.71, -24.84),
						pos = Vector3.new(-0.32, -0.8, 0.4),
					},
					Neck = { rot = Vector3.new(53.1, 31.8, -1.27) },
					RightShoulder = { rot = Vector3.new(45.72, 0, 33.89) },
					LeftShoulder = { rot = Vector3.new(56.21, 0, -39.6) },
					RightHip = {
						rot = Vector3.new(60.88, 0, -23.94),
						pos = Vector3.new(0, 0.54, 0),
					},
					LeftHip = { rot = Vector3.new(73.63, 0, 6.44), pos = Vector3.new(0, 0.75, 0) },
				},
			},
			{
				time = 0.5312,
				pose = {
					Root = {
						rot = Vector3.new(-55.94, -20.73, -24.69),
						pos = Vector3.new(-0.32, -0.78, 0.4),
					},
					Neck = { rot = Vector3.new(53.01, 31.72, -1.32) },
					RightShoulder = { rot = Vector3.new(41.7, 0, 35.08) },
					LeftShoulder = { rot = Vector3.new(61.11, 0, -39.33) },
					RightHip = {
						rot = Vector3.new(60.41, 0, -22.54),
						pos = Vector3.new(0, 0.57, 0),
					},
					LeftHip = { rot = Vector3.new(71.79, 0, 4.15), pos = Vector3.new(0, 0.74, 0) },
				},
			},
			{
				time = 0.5625,
				pose = {
					Root = {
						rot = Vector3.new(-55.89, -20.8, -24.6),
						pos = Vector3.new(-0.33, -0.75, 0.39),
					},
					Neck = { rot = Vector3.new(53, 31.73, -1.41) },
					RightShoulder = { rot = Vector3.new(37.36, 0, 35.97) },
					LeftShoulder = { rot = Vector3.new(66.26, 0, -38.54) },
					RightHip = {
						rot = Vector3.new(59.85, 0, -19.47),
						pos = Vector3.new(0, 0.64, 0),
					},
					LeftHip = { rot = Vector3.new(70.45, 0, 1.78), pos = Vector3.new(0, 0.72, 0) },
				},
			},
			{
				time = 0.5938,
				pose = {
					Root = {
						rot = Vector3.new(-55.89, -20.88, -24.57),
						pos = Vector3.new(-0.34, -0.72, 0.39),
					},
					Neck = { rot = Vector3.new(53.04, 31.78, -1.52) },
					RightShoulder = { rot = Vector3.new(32.85, 0, 36.49) },
					LeftShoulder = { rot = Vector3.new(71.34, 0, -37.15) },
					RightHip = {
						rot = Vector3.new(59.85, 0, -14.78),
						pos = Vector3.new(0, 0.72, 0),
					},
					LeftHip = { rot = Vector3.new(69.41, 0, -0.79), pos = Vector3.new(0, 0.68, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = {
						rot = Vector3.new(-55.92, -21.01, -24.59),
						pos = Vector3.new(-0.35, -0.69, 0.39),
					},
					Neck = { rot = Vector3.new(53.09, 31.89, -1.63) },
					RightShoulder = { rot = Vector3.new(28.38, 0, 36.62) },
					LeftShoulder = { rot = Vector3.new(76.02, 0, -35.26) },
					RightHip = { rot = Vector3.new(60.92, 0, -9.66), pos = Vector3.new(0, 0.73, 0) },
					LeftHip = { rot = Vector3.new(68.12, 0, -2.54), pos = Vector3.new(0, 0.67, 0) },
				},
			},
			{
				time = 0.6562,
				pose = {
					Root = {
						rot = Vector3.new(-55.98, -21.16, -24.66),
						pos = Vector3.new(-0.36, -0.68, 0.39),
					},
					Neck = { rot = Vector3.new(53.16, 32.05, -1.75) },
					RightShoulder = { rot = Vector3.new(24.21, 0, 36.41) },
					LeftShoulder = { rot = Vector3.new(80.13, 0, -33.01) },
					RightHip = { rot = Vector3.new(66.66, 0, -3.63), pos = Vector3.new(0, 0.58, 0) },
					LeftHip = { rot = Vector3.new(65.49, 0, -4.59), pos = Vector3.new(0, 0.71, 0) },
				},
			},
			{
				time = 0.6875,
				pose = {
					Root = {
						rot = Vector3.new(-56.07, -21.36, -24.79),
						pos = Vector3.new(-0.37, -0.68, 0.39),
					},
					Neck = { rot = Vector3.new(53.24, 32.28, -1.88) },
					RightShoulder = { rot = Vector3.new(20.58, 0, 35.97) },
					LeftShoulder = { rot = Vector3.new(83.56, 0, -30.62) },
					RightHip = { rot = Vector3.new(68.79, 0, 3.45), pos = Vector3.new(0, 0.64, 0) },
					LeftHip = { rot = Vector3.new(62.43, 0, -7.29), pos = Vector3.new(0, 0.77, 0) },
				},
			},
			{
				time = 0.7188,
				pose = {
					Root = {
						rot = Vector3.new(-56.18, -21.58, -25.04),
						pos = Vector3.new(-0.38, -0.69, 0.39),
					},
					Neck = { rot = Vector3.new(53.3, 32.61, -1.95) },
					RightShoulder = { rot = Vector3.new(17.67, 0, 35.5) },
					LeftShoulder = { rot = Vector3.new(86.27, 0, -28.32) },
					RightHip = { rot = Vector3.new(70.51, 0, 10.68), pos = Vector3.new(0, 0.77, 0) },
					LeftHip = { rot = Vector3.new(59.68, 0, -9.67), pos = Vector3.new(0, 0.82, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(-56.3, -21.83, -25.48),
						pos = Vector3.new(-0.38, -0.71, 0.39),
					},
					Neck = { rot = Vector3.new(53.29, 33.1, -1.91) },
					RightShoulder = { rot = Vector3.new(15.66, 0, 35.19) },
					LeftShoulder = { rot = Vector3.new(88.28, 0, -26.34) },
					RightHip = { rot = Vector3.new(73.08, 0, 16.55), pos = Vector3.new(0, 0.84, 0) },
					LeftHip = { rot = Vector3.new(56.87, 0, -11.81), pos = Vector3.new(0, 0.88, 0) },
				},
			},
			{
				time = 0.7812,
				pose = {
					Root = {
						rot = Vector3.new(-56.45, -22.1, -26.07),
						pos = Vector3.new(-0.39, -0.75, 0.4),
					},
					Neck = { rot = Vector3.new(53.24, 33.73, -1.8) },
					RightShoulder = { rot = Vector3.new(14.67, 0, 35.15) },
					LeftShoulder = { rot = Vector3.new(89.66, 0, -24.92) },
					RightHip = { rot = Vector3.new(73.8, 0, 19.63), pos = Vector3.new(0, 0.91, 0) },
					LeftHip = { rot = Vector3.new(54.05, 0, -13.79), pos = Vector3.new(0, 0.95, 0) },
				},
			},
			{
				time = 0.8125,
				pose = {
					Root = {
						rot = Vector3.new(-56.63, -22.42, -26.75),
						pos = Vector3.new(-0.39, -0.78, 0.4),
					},
					Neck = { rot = Vector3.new(53.2, 34.42, -1.69) },
					RightShoulder = { rot = Vector3.new(14.88, 0, 35.41) },
					LeftShoulder = { rot = Vector3.new(90.49, 0, -24.22) },
					RightHip = { rot = Vector3.new(73.76, 0, 20.27), pos = Vector3.new(0, 0.97, 0) },
					LeftHip = { rot = Vector3.new(51.51, 0, -15.68), pos = Vector3.new(0, 1.01, 0) },
				},
			},
			{
				time = 0.8438,
				pose = {
					Root = {
						rot = Vector3.new(-56.88, -22.75, -27.41),
						pos = Vector3.new(-0.4, -0.81, 0.41),
					},
					Neck = { rot = Vector3.new(53.23, 35.11, -1.65) },
					RightShoulder = { rot = Vector3.new(16.35, 0, 35.86) },
					LeftShoulder = { rot = Vector3.new(90.84, 0, -24.38) },
					RightHip = { rot = Vector3.new(73.42, 0, 19.62), pos = Vector3.new(0, 1.02, 0) },
					LeftHip = { rot = Vector3.new(49.55, 0, -17.34), pos = Vector3.new(0, 1.07, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = {
						rot = Vector3.new(-57.15, -23.08, -27.99),
						pos = Vector3.new(-0.39, -0.82, 0.41),
					},
					Neck = { rot = Vector3.new(53.32, 35.7, -1.69) },
					RightShoulder = { rot = Vector3.new(18.84, 0, 36.31) },
					LeftShoulder = { rot = Vector3.new(90.66, 0, -25.43) },
					RightHip = { rot = Vector3.new(73.29, 0, 18.17), pos = Vector3.new(0, 1.03, 0) },
					LeftHip = { rot = Vector3.new(46.99, 0, -19.07), pos = Vector3.new(0, 1.14, 0) },
				},
			},
			{
				time = 0.9062,
				pose = {
					Root = {
						rot = Vector3.new(-57.26, -23.47, -28.33),
						pos = Vector3.new(-0.39, -0.83, 0.42),
					},
					Neck = { rot = Vector3.new(53.33, 36.15, -1.86) },
					RightShoulder = { rot = Vector3.new(21.96, 0, 36.59) },
					LeftShoulder = { rot = Vector3.new(89.8, 0, -27.23) },
					RightHip = { rot = Vector3.new(72.44, 0, 15.93), pos = Vector3.new(0, 1.03, 0) },
					LeftHip = { rot = Vector3.new(45.15, 0, -20.92), pos = Vector3.new(0, 1.18, 0) },
				},
			},
			{
				time = 0.9375,
				pose = {
					Root = {
						rot = Vector3.new(-57.2, -23.89, -28.45),
						pos = Vector3.new(-0.38, -0.83, 0.42),
					},
					Neck = { rot = Vector3.new(53.21, 36.43, -2.09) },
					RightShoulder = { rot = Vector3.new(25.47, 0, 36.61) },
					LeftShoulder = { rot = Vector3.new(88.11, 0, -29.59) },
					RightHip = { rot = Vector3.new(71.14, 0, 13.34), pos = Vector3.new(0, 1.01, 0) },
					LeftHip = { rot = Vector3.new(43.31, 0, -23.08), pos = Vector3.new(0, 1.21, 0) },
				},
			},
			{
				time = 0.9688,
				pose = {
					Root = {
						rot = Vector3.new(-57.03, -24.27, -28.41),
						pos = Vector3.new(-0.36, -0.82, 0.42),
					},
					Neck = { rot = Vector3.new(53.01, 36.57, -2.31) },
					RightShoulder = { rot = Vector3.new(29.22, 0, 36.37) },
					LeftShoulder = { rot = Vector3.new(85.41, 0, -32.37) },
					RightHip = { rot = Vector3.new(69.93, 0, 10.39), pos = Vector3.new(0, 0.96, 0) },
					LeftHip = { rot = Vector3.new(42.66, 0, -24.79), pos = Vector3.new(0, 1.2, 0) },
				},
			},
		},
	},
	-- ALS_N_Pose: 0.07 s
	Stand = {
		length = 0.07,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(0, 0, 0) },
					Neck = { rot = Vector3.new(0, 0, 0) },
					RightShoulder = { rot = Vector3.new(7.08, 0, 15.63) },
					LeftShoulder = { rot = Vector3.new(7.08, 0, -15.8) },
					RightHip = { rot = Vector3.new(-1.67, 0, 4.07), pos = Vector3.new(0, 0.08, 0) },
					LeftHip = { rot = Vector3.new(-1.65, 0, -3.95), pos = Vector3.new(0, 0.07, 0) },
				},
			},
			{
				time = 0.0333,
				pose = {
					Root = { rot = Vector3.new(0, 0, 0) },
					Neck = { rot = Vector3.new(0, 0, 0) },
					RightShoulder = { rot = Vector3.new(7.08, 0, 15.63) },
					LeftShoulder = { rot = Vector3.new(7.08, 0, -15.8) },
					RightHip = { rot = Vector3.new(-1.67, 0, 4.07), pos = Vector3.new(0, 0.08, 0) },
					LeftHip = { rot = Vector3.new(-1.65, 0, -3.95), pos = Vector3.new(0, 0.07, 0) },
				},
			},
			{
				time = 0.0667,
				pose = {
					Root = { rot = Vector3.new(0, 0, 0) },
					Neck = { rot = Vector3.new(0, 0, 0) },
					RightShoulder = { rot = Vector3.new(7.08, 0, 15.63) },
					LeftShoulder = { rot = Vector3.new(7.08, 0, -15.8) },
					RightHip = { rot = Vector3.new(-1.67, 0, 4.07), pos = Vector3.new(0, 0.08, 0) },
					LeftHip = { rot = Vector3.new(-1.65, 0, -3.95), pos = Vector3.new(0, 0.07, 0) },
				},
			},
		},
	},
	-- ALS_CLF_Pose: 0.07 s
	Crouch = {
		length = 0.07,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-21.65, -7.4, -3.3),
						pos = Vector3.new(-0.04, -1.15, 0.27),
					},
					Neck = { rot = Vector3.new(18.53, 7.96, 0.74) },
					RightShoulder = { rot = Vector3.new(29.96, 0, 14.09) },
					LeftShoulder = { rot = Vector3.new(12.32, 0, -18.63) },
					RightHip = { rot = Vector3.new(4.21, 0, -4.07), pos = Vector3.new(0, 1.23, 0) },
					LeftHip = { rot = Vector3.new(38, 0, -2.72), pos = Vector3.new(0, 1.27, 0) },
				},
			},
			{
				time = 0.0333,
				pose = {
					Root = {
						rot = Vector3.new(-21.65, -7.4, -3.3),
						pos = Vector3.new(-0.04, -1.15, 0.27),
					},
					Neck = { rot = Vector3.new(18.53, 7.96, 0.74) },
					RightShoulder = { rot = Vector3.new(29.96, 0, 14.09) },
					LeftShoulder = { rot = Vector3.new(12.32, 0, -18.63) },
					RightHip = { rot = Vector3.new(4.21, 0, -4.07), pos = Vector3.new(0, 1.23, 0) },
					LeftHip = { rot = Vector3.new(38, 0, -2.72), pos = Vector3.new(0, 1.27, 0) },
				},
			},
			{
				time = 0.0667,
				pose = {
					Root = {
						rot = Vector3.new(-21.65, -7.4, -3.3),
						pos = Vector3.new(-0.04, -1.15, 0.27),
					},
					Neck = { rot = Vector3.new(18.53, 7.96, 0.74) },
					RightShoulder = { rot = Vector3.new(29.96, 0, 14.09) },
					LeftShoulder = { rot = Vector3.new(12.32, 0, -18.63) },
					RightHip = { rot = Vector3.new(4.21, 0, -4.07), pos = Vector3.new(0, 1.23, 0) },
					LeftHip = { rot = Vector3.new(38, 0, -2.72), pos = Vector3.new(0, 1.27, 0) },
				},
			},
		},
	},
	-- ALS_N_JumpLoop: 0.70 s
	JumpLoop = {
		length = 0.7,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-13, 0, -0.11), pos = Vector3.new(0, -0.33, 0.32) },
					Neck = { rot = Vector3.new(4.94, -0.02, -0.08) },
					RightShoulder = { rot = Vector3.new(77.96, 0, 37.36) },
					LeftShoulder = { rot = Vector3.new(62.7, 0, -37.28) },
					RightHip = { rot = Vector3.new(34.72, 0, 1.8), pos = Vector3.new(0, 0.37, 0) },
					LeftHip = { rot = Vector3.new(34.36, 0, -0.96), pos = Vector3.new(0, 0.36, 0) },
				},
			},
			{
				time = 0.0667,
				pose = {
					Root = {
						rot = Vector3.new(-14.26, -0.38, -0.08),
						pos = Vector3.new(0, -0.34, 0.31),
					},
					Neck = { rot = Vector3.new(6.02, 0.33, -0.09) },
					RightShoulder = { rot = Vector3.new(46.1, 0, 41.31) },
					LeftShoulder = { rot = Vector3.new(33.69, 0, -44.03) },
					RightHip = { rot = Vector3.new(25.68, 0, 0.97), pos = Vector3.new(0, 0.38, 0) },
					LeftHip = { rot = Vector3.new(27.8, 0, -0.46), pos = Vector3.new(0, 0.38, 0) },
				},
			},
			{
				time = 0.1333,
				pose = {
					Root = {
						rot = Vector3.new(-14.8, -1.27, -0.08),
						pos = Vector3.new(0, -0.35, 0.3),
					},
					Neck = { rot = Vector3.new(6.36, 1.23, -0.22) },
					RightShoulder = { rot = Vector3.new(17.39, 0, 44.36) },
					LeftShoulder = { rot = Vector3.new(5.82, 0, -50.03) },
					RightHip = { rot = Vector3.new(15.56, 0, 0.23), pos = Vector3.new(0, 0.33, 0) },
					LeftHip = { rot = Vector3.new(17.98, 0, -0.28), pos = Vector3.new(0, 0.34, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = {
						rot = Vector3.new(-14.68, -2.32, 0.06),
						pos = Vector3.new(0, -0.35, 0.29),
					},
					Neck = { rot = Vector3.new(6.05, 2.3, -0.4) },
					RightShoulder = { rot = Vector3.new(-11.52, 0, 51.63) },
					LeftShoulder = { rot = Vector3.new(-30.29, 0, -57.48) },
					RightHip = { rot = Vector3.new(8.83, 0, -0.65), pos = Vector3.new(0, 0.34, 0) },
					LeftHip = { rot = Vector3.new(11.12, 0, -0.65), pos = Vector3.new(0, 0.35, 0) },
				},
			},
			{
				time = 0.2667,
				pose = {
					Root = {
						rot = Vector3.new(-13.71, -3.21, 0.31),
						pos = Vector3.new(0, -0.34, 0.28),
					},
					Neck = { rot = Vector3.new(5.16, 3.21, -0.6) },
					RightShoulder = { rot = Vector3.new(-54.03, 0, 57.52) },
					LeftShoulder = { rot = Vector3.new(-83.32, 0, -60.88) },
					RightHip = { rot = Vector3.new(-1.51, 0, -0.83), pos = Vector3.new(0, 0.35, 0) },
					LeftHip = { rot = Vector3.new(-1.54, 0, -1.1), pos = Vector3.new(0, 0.4, 0) },
				},
			},
			{
				time = 0.3333,
				pose = {
					Root = {
						rot = Vector3.new(-12.25, -3.61, 0.5),
						pos = Vector3.new(0, -0.32, 0.28),
					},
					Neck = { rot = Vector3.new(3.83, 3.59, -0.67) },
					RightShoulder = { rot = Vector3.new(-100.4, 0, 62.05) },
					LeftShoulder = { rot = Vector3.new(-139.9, 0, -57.38) },
					RightHip = { rot = Vector3.new(-8.76, 0, 0.65), pos = Vector3.new(0, 0.46, 0) },
					LeftHip = { rot = Vector3.new(-9.18, 0, -1.68), pos = Vector3.new(0, 0.64, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = {
						rot = Vector3.new(-11.16, -3.25, 0.51),
						pos = Vector3.new(0, -0.31, 0.28),
					},
					Neck = { rot = Vector3.new(2.72, 3.19, -0.57) },
					RightShoulder = { rot = Vector3.new(-157.71, 0, 53.97) },
					LeftShoulder = { rot = Vector3.new(-175.04, 0, -47.46) },
					RightHip = { rot = Vector3.new(-6.53, 0, 0.76), pos = Vector3.new(0, 0.86, 0) },
					LeftHip = { rot = Vector3.new(-7, 0, -2.47), pos = Vector3.new(0, 0.95, 0) },
				},
			},
			{
				time = 0.4667,
				pose = {
					Root = {
						rot = Vector3.new(-10.86, -2.36, 0.35),
						pos = Vector3.new(0, -0.3, 0.29),
					},
					Neck = { rot = Vector3.new(2.35, 2.32, -0.39) },
					RightShoulder = { rot = Vector3.new(177.49, 0, 42.59) },
					LeftShoulder = { rot = Vector3.new(159.29, 0, -43.44) },
					RightHip = { rot = Vector3.new(5.38, 0, 0.86), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(4.44, 0, -3.28), pos = Vector3.new(0, 1.02, 0) },
				},
			},
			{
				time = 0.5333,
				pose = {
					Root = {
						rot = Vector3.new(-11.02, -1.28, 0.06),
						pos = Vector3.new(0, -0.3, 0.3),
					},
					Neck = { rot = Vector3.new(2.69, 1.36, -0.22) },
					RightShoulder = { rot = Vector3.new(148.94, 0, 43.19) },
					LeftShoulder = { rot = Vector3.new(122.57, 0, -40.21) },
					RightHip = { rot = Vector3.new(21.51, 0, 1.65), pos = Vector3.new(0, 0.9, 0) },
					LeftHip = { rot = Vector3.new(19.52, 0, -3.27), pos = Vector3.new(0, 0.77, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-11.63, -0.39, -0.13),
						pos = Vector3.new(0, -0.31, 0.31),
					},
					Neck = { rot = Vector3.new(3.57, 0.48, -0.14) },
					RightShoulder = { rot = Vector3.new(110.16, 0, 39.24) },
					LeftShoulder = { rot = Vector3.new(89.61, 0, -33.33) },
					RightHip = { rot = Vector3.new(35.14, 0, 2.58), pos = Vector3.new(0, 0.43, 0) },
					LeftHip = { rot = Vector3.new(32.56, 0, -2.39), pos = Vector3.new(0, 0.38, 0) },
				},
			},
			{
				time = 0.6667,
				pose = {
					Root = { rot = Vector3.new(-13, 0, -0.11), pos = Vector3.new(0, -0.33, 0.32) },
					Neck = { rot = Vector3.new(4.94, -0.02, -0.08) },
					RightShoulder = { rot = Vector3.new(77.96, 0, 37.36) },
					LeftShoulder = { rot = Vector3.new(62.7, 0, -37.28) },
					RightHip = { rot = Vector3.new(34.72, 0, 1.8), pos = Vector3.new(0, 0.37, 0) },
					LeftHip = { rot = Vector3.new(34.36, 0, -0.96), pos = Vector3.new(0, 0.36, 0) },
				},
			},
			{
				time = 0.7,
				pose = {
					Root = { rot = Vector3.new(-13, 0, -0.11), pos = Vector3.new(0, -0.33, 0.32) },
					Neck = { rot = Vector3.new(4.94, -0.02, -0.08) },
					RightShoulder = { rot = Vector3.new(77.96, 0, 37.36) },
					LeftShoulder = { rot = Vector3.new(62.7, 0, -37.28) },
					RightHip = { rot = Vector3.new(34.72, 0, 1.8), pos = Vector3.new(0, 0.37, 0) },
					LeftHip = { rot = Vector3.new(34.36, 0, -0.96), pos = Vector3.new(0, 0.36, 0) },
				},
			},
		},
	},
	-- ALS_N_FallLoop: 1.03 s
	FallLoop = {
		length = 1.03,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-19.86, -0.01, -0.19),
						pos = Vector3.new(0, 0.08, 0.24),
					},
					Neck = { rot = Vector3.new(20, 0.07, -0.03) },
					RightShoulder = { rot = Vector3.new(25.75, 0, 56.47) },
					LeftShoulder = { rot = Vector3.new(7.46, 0, -50.93) },
					RightHip = { rot = Vector3.new(31.81, 0, 3.53), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(26.77, 0, -2.92), pos = Vector3.new(0, 0.5, 0) },
				},
			},
			{
				time = 0.0667,
				pose = {
					Root = {
						rot = Vector3.new(-19.12, -0.01, -0.16),
						pos = Vector3.new(0, 0.05, 0.24),
					},
					Neck = { rot = Vector3.new(19.23, 0.07, -0.03) },
					RightShoulder = { rot = Vector3.new(17.34, 0, 58.15) },
					LeftShoulder = { rot = Vector3.new(0.6, 0, -51.59) },
					RightHip = { rot = Vector3.new(31.17, 0, 3.37), pos = Vector3.new(0, 0.14, 0) },
					LeftHip = { rot = Vector3.new(26.33, 0, -2.95), pos = Vector3.new(0, 0.43, 0) },
				},
			},
			{
				time = 0.1333,
				pose = {
					Root = {
						rot = Vector3.new(-18.1, -0.01, -0.15),
						pos = Vector3.new(0, 0.02, 0.24),
					},
					Neck = { rot = Vector3.new(18.2, 0.06, -0.03) },
					RightShoulder = { rot = Vector3.new(10.19, 0, 58.05) },
					LeftShoulder = { rot = Vector3.new(-4.27, 0, -50.74) },
					RightHip = { rot = Vector3.new(29.41, 0, 3.26), pos = Vector3.new(0, 0.12, 0) },
					LeftHip = { rot = Vector3.new(25.01, 0, -2.97), pos = Vector3.new(0, 0.38, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = { rot = Vector3.new(-16.96, 0, -0.14), pos = Vector3.new(0, 0, 0.23) },
					Neck = { rot = Vector3.new(17.04, 0.06, -0.03) },
					RightShoulder = { rot = Vector3.new(6.79, 0, 56.27) },
					LeftShoulder = { rot = Vector3.new(-5.75, 0, -48.73) },
					RightHip = { rot = Vector3.new(26.93, 0, 3.23), pos = Vector3.new(0, 0.13, 0) },
					LeftHip = { rot = Vector3.new(23.06, 0, -2.97), pos = Vector3.new(0, 0.35, 0) },
				},
			},
			{
				time = 0.2667,
				pose = {
					Root = {
						rot = Vector3.new(-15.82, 0, -0.14),
						pos = Vector3.new(0, -0.01, 0.22),
					},
					Neck = { rot = Vector3.new(15.89, 0.06, -0.03) },
					RightShoulder = { rot = Vector3.new(5.74, 0, 54.18) },
					LeftShoulder = { rot = Vector3.new(-5.42, 0, -46.6) },
					RightHip = { rot = Vector3.new(24.16, 0, 3.27), pos = Vector3.new(0, 0.18, 0) },
					LeftHip = { rot = Vector3.new(20.74, 0, -2.97), pos = Vector3.new(0, 0.35, 0) },
				},
			},
			{
				time = 0.3333,
				pose = {
					Root = {
						rot = Vector3.new(-14.81, 0, -0.14),
						pos = Vector3.new(0, -0.02, 0.22),
					},
					Neck = { rot = Vector3.new(14.88, 0.07, -0.02) },
					RightShoulder = { rot = Vector3.new(6.34, 0, 52.28) },
					LeftShoulder = { rot = Vector3.new(-3.95, 0, -44.78) },
					RightHip = { rot = Vector3.new(21.51, 0, 3.39), pos = Vector3.new(0, 0.26, 0) },
					LeftHip = { rot = Vector3.new(18.39, 0, -2.95), pos = Vector3.new(0, 0.38, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = {
						rot = Vector3.new(-14.08, -0.01, -0.14),
						pos = Vector3.new(0, -0.02, 0.21),
					},
					Neck = { rot = Vector3.new(14.14, 0.07, -0.02) },
					RightShoulder = { rot = Vector3.new(8.25, 0, 50.79) },
					LeftShoulder = { rot = Vector3.new(-1.69, 0, -43.42) },
					RightHip = { rot = Vector3.new(19.35, 0, 3.53), pos = Vector3.new(0, 0.35, 0) },
					LeftHip = { rot = Vector3.new(16.38, 0, -2.93), pos = Vector3.new(0, 0.44, 0) },
				},
			},
			{
				time = 0.4667,
				pose = {
					Root = {
						rot = Vector3.new(-13.74, -0.01, -0.15),
						pos = Vector3.new(0, -0.01, 0.21),
					},
					Neck = { rot = Vector3.new(13.8, 0.07, -0.02) },
					RightShoulder = { rot = Vector3.new(11.56, 0, 49.84) },
					LeftShoulder = { rot = Vector3.new(1.23, 0, -42.67) },
					RightHip = { rot = Vector3.new(18, 0, 3.69), pos = Vector3.new(0, 0.44, 0) },
					LeftHip = { rot = Vector3.new(15.08, 0, -2.91), pos = Vector3.new(0, 0.5, 0) },
				},
			},
			{
				time = 0.5333,
				pose = {
					Root = {
						rot = Vector3.new(-13.93, -0.01, -0.17),
						pos = Vector3.new(0, 0.01, 0.21),
					},
					Neck = { rot = Vector3.new(14.01, 0.08, -0.02) },
					RightShoulder = { rot = Vector3.new(16.51, 0, 49.41) },
					LeftShoulder = { rot = Vector3.new(5.05, 0, -42.65) },
					RightHip = { rot = Vector3.new(17.86, 0, 3.84), pos = Vector3.new(0, 0.52, 0) },
					LeftHip = { rot = Vector3.new(14.89, 0, -2.88), pos = Vector3.new(0, 0.56, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-14.7, -0.01, -0.18),
						pos = Vector3.new(0, 0.03, 0.21),
					},
					Neck = { rot = Vector3.new(14.79, 0.08, -0.01) },
					RightShoulder = { rot = Vector3.new(22.1, 0, 49.13) },
					LeftShoulder = { rot = Vector3.new(9.18, 0, -42.97) },
					RightHip = { rot = Vector3.new(18.9, 0, 3.97), pos = Vector3.new(0, 0.57, 0) },
					LeftHip = { rot = Vector3.new(15.79, 0, -2.86), pos = Vector3.new(0, 0.62, 0) },
				},
			},
			{
				time = 0.6667,
				pose = {
					Root = {
						rot = Vector3.new(-15.85, -0.01, -0.2),
						pos = Vector3.new(0, 0.06, 0.21),
					},
					Neck = { rot = Vector3.new(15.96, 0.09, -0.02) },
					RightShoulder = { rot = Vector3.new(26.83, 0, 49.02) },
					LeftShoulder = { rot = Vector3.new(12.59, 0, -43.46) },
					RightHip = { rot = Vector3.new(20.81, 0, 4.05), pos = Vector3.new(0, 0.6, 0) },
					LeftHip = { rot = Vector3.new(17.48, 0, -2.85), pos = Vector3.new(0, 0.66, 0) },
				},
			},
			{
				time = 0.7333,
				pose = {
					Root = {
						rot = Vector3.new(-17.17, -0.01, -0.21),
						pos = Vector3.new(0, 0.08, 0.22),
					},
					Neck = { rot = Vector3.new(17.3, 0.09, -0.02) },
					RightShoulder = { rot = Vector3.new(30.45, 0, 49.31) },
					LeftShoulder = { rot = Vector3.new(15.01, 0, -44.27) },
					RightHip = { rot = Vector3.new(23.29, 0, 4.06), pos = Vector3.new(0, 0.6, 0) },
					LeftHip = { rot = Vector3.new(19.62, 0, -2.84), pos = Vector3.new(0, 0.68, 0) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = {
						rot = Vector3.new(-18.44, -0.01, -0.22),
						pos = Vector3.new(0, 0.1, 0.23),
					},
					Neck = { rot = Vector3.new(18.6, 0.09, -0.02) },
					RightShoulder = { rot = Vector3.new(32.69, 0, 50.18) },
					LeftShoulder = { rot = Vector3.new(16.17, 0, -45.5) },
					RightHip = { rot = Vector3.new(26.07, 0, 4.01), pos = Vector3.new(0, 0.54, 0) },
					LeftHip = { rot = Vector3.new(21.95, 0, -2.85), pos = Vector3.new(0, 0.68, 0) },
				},
			},
			{
				time = 0.8667,
				pose = {
					Root = {
						rot = Vector3.new(-19.47, -0.01, -0.22),
						pos = Vector3.new(0, 0.1, 0.24),
					},
					Neck = { rot = Vector3.new(19.62, 0.09, -0.03) },
					RightShoulder = { rot = Vector3.new(33.17, 0, 51.75) },
					LeftShoulder = { rot = Vector3.new(15.71, 0, -47.14) },
					RightHip = { rot = Vector3.new(28.79, 0, 3.89), pos = Vector3.new(0, 0.45, 0) },
					LeftHip = { rot = Vector3.new(24.22, 0, -2.86), pos = Vector3.new(0, 0.64, 0) },
				},
			},
			{
				time = 0.9333,
				pose = {
					Root = {
						rot = Vector3.new(-20.01, -0.01, -0.21),
						pos = Vector3.new(0, 0.1, 0.24),
					},
					Neck = { rot = Vector3.new(20.16, 0.08, -0.03) },
					RightShoulder = { rot = Vector3.new(31.23, 0, 53.96) },
					LeftShoulder = { rot = Vector3.new(13.1, 0, -49.06) },
					RightHip = { rot = Vector3.new(30.91, 0, 3.73), pos = Vector3.new(0, 0.34, 0) },
					LeftHip = { rot = Vector3.new(26.01, 0, -2.88), pos = Vector3.new(0, 0.58, 0) },
				},
			},
			{
				time = 1,
				pose = {
					Root = {
						rot = Vector3.new(-19.86, -0.01, -0.19),
						pos = Vector3.new(0, 0.08, 0.24),
					},
					Neck = { rot = Vector3.new(20, 0.07, -0.03) },
					RightShoulder = { rot = Vector3.new(25.75, 0, 56.47) },
					LeftShoulder = { rot = Vector3.new(7.46, 0, -50.93) },
					RightHip = { rot = Vector3.new(31.81, 0, 3.53), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(26.77, 0, -2.92), pos = Vector3.new(0, 0.5, 0) },
				},
			},
			{
				time = 1.0333,
				pose = {
					Root = {
						rot = Vector3.new(-19.86, -0.01, -0.19),
						pos = Vector3.new(0, 0.08, 0.24),
					},
					Neck = { rot = Vector3.new(20, 0.07, -0.03) },
					RightShoulder = { rot = Vector3.new(25.75, 0, 56.47) },
					LeftShoulder = { rot = Vector3.new(7.46, 0, -50.93) },
					RightHip = { rot = Vector3.new(31.81, 0, 3.53), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(26.77, 0, -2.92), pos = Vector3.new(0, 0.5, 0) },
				},
			},
		},
	},
	-- ALS_N_FallLoop_Fast: 1.03 s
	FallFast = {
		length = 1.03,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-16.02, 0, -0.08), pos = Vector3.new(0, 0.08, 0.18) },
					Neck = { rot = Vector3.new(19.2, 0.04, -0.08) },
					RightShoulder = { rot = Vector3.new(134.22, 0, 80.89) },
					LeftShoulder = { rot = Vector3.new(55.88, 0, -87.75) },
					RightHip = { rot = Vector3.new(22.63, 0, 1.26), pos = Vector3.new(0, 0.13, 0) },
					LeftHip = { rot = Vector3.new(18.88, 0, -2.04), pos = Vector3.new(0, 0.37, 0) },
				},
			},
			{
				time = 0.0667,
				pose = {
					Root = { rot = Vector3.new(-15.24, 0, -0.06), pos = Vector3.new(0, 0.05, 0.18) },
					Neck = { rot = Vector3.new(18.4, 0.03, -0.08) },
					RightShoulder = { rot = Vector3.new(159.51, 0, 84.02) },
					LeftShoulder = { rot = Vector3.new(-63.4, 0, -87.19) },
					RightHip = { rot = Vector3.new(21.32, 0, 0.91), pos = Vector3.new(0, 0.07, 0) },
					LeftHip = { rot = Vector3.new(17.86, 0, -1.94), pos = Vector3.new(0, 0.31, 0) },
				},
			},
			{
				time = 0.1333,
				pose = {
					Root = { rot = Vector3.new(-14.21, 0, -0.04), pos = Vector3.new(0, 0.02, 0.18) },
					Neck = { rot = Vector3.new(17.35, 0.02, -0.08) },
					RightShoulder = { rot = Vector3.new(-157.28, 0, 85.52) },
					LeftShoulder = { rot = Vector3.new(-69.9, 0, -83.5) },
					RightHip = { rot = Vector3.new(19.26, 0, 0.65), pos = Vector3.new(0, 0.05, 0) },
					LeftHip = { rot = Vector3.new(16.06, 0, -1.84), pos = Vector3.new(0, 0.27, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = { rot = Vector3.new(-13.06, 0, -0.05), pos = Vector3.new(0, 0, 0.17) },
					Neck = { rot = Vector3.new(16.19, 0.03, -0.08) },
					RightShoulder = { rot = Vector3.new(-113.89, 0, 85.5) },
					LeftShoulder = { rot = Vector3.new(-62.26, 0, -80.71) },
					RightHip = { rot = Vector3.new(16.78, 0, 0.57), pos = Vector3.new(0, 0.06, 0) },
					LeftHip = { rot = Vector3.new(13.79, 0, -1.72), pos = Vector3.new(0, 0.24, 0) },
				},
			},
			{
				time = 0.2667,
				pose = {
					Root = {
						rot = Vector3.new(-11.93, 0, -0.05),
						pos = Vector3.new(0, -0.01, 0.16),
					},
					Neck = { rot = Vector3.new(15.05, 0.03, -0.08) },
					RightShoulder = { rot = Vector3.new(-84.67, 0, 84.45) },
					LeftShoulder = { rot = Vector3.new(-54.72, 0, -78.56) },
					RightHip = { rot = Vector3.new(14.25, 0, 0.62), pos = Vector3.new(0, 0.09, 0) },
					LeftHip = { rot = Vector3.new(11.35, 0, -1.64), pos = Vector3.new(0, 0.24, 0) },
				},
			},
			{
				time = 0.3333,
				pose = {
					Root = {
						rot = Vector3.new(-10.94, 0, -0.06),
						pos = Vector3.new(0, -0.02, 0.15),
					},
					Neck = { rot = Vector3.new(14.05, 0.04, -0.07) },
					RightShoulder = { rot = Vector3.new(-67.46, 0, 83.57) },
					LeftShoulder = { rot = Vector3.new(-47.6, 0, -77.2) },
					RightHip = { rot = Vector3.new(11.98, 0, 0.83), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(9.06, 0, -1.59), pos = Vector3.new(0, 0.27, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = {
						rot = Vector3.new(-10.22, 0, -0.08),
						pos = Vector3.new(0, -0.02, 0.15),
					},
					Neck = { rot = Vector3.new(13.32, 0.05, -0.07) },
					RightShoulder = { rot = Vector3.new(-54.25, 0, 83.55) },
					LeftShoulder = { rot = Vector3.new(-40.09, 0, -76.77) },
					RightHip = { rot = Vector3.new(10.27, 0, 1.12), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(7.25, 0, -1.59), pos = Vector3.new(0, 0.31, 0) },
				},
			},
			{
				time = 0.4667,
				pose = {
					Root = { rot = Vector3.new(-9.9, 0, -0.09), pos = Vector3.new(0, -0.01, 0.14) },
					Neck = { rot = Vector3.new(13.01, 0.05, -0.07) },
					RightShoulder = { rot = Vector3.new(-37.55, 0, 84.77) },
					LeftShoulder = { rot = Vector3.new(-30.79, 0, -77.43) },
					RightHip = { rot = Vector3.new(9.38, 0, 1.47), pos = Vector3.new(0, 0.3, 0) },
					LeftHip = { rot = Vector3.new(6.23, 0, -1.62), pos = Vector3.new(0, 0.36, 0) },
				},
			},
			{
				time = 0.5333,
				pose = {
					Root = { rot = Vector3.new(-10.11, 0, -0.11), pos = Vector3.new(0, 0.01, 0.14) },
					Neck = { rot = Vector3.new(13.23, 0.06, -0.07) },
					RightShoulder = { rot = Vector3.new(7.22, 0, 86.65) },
					LeftShoulder = { rot = Vector3.new(-15.91, 0, -79.19) },
					RightHip = { rot = Vector3.new(9.72, 0, 1.84), pos = Vector3.new(0, 0.37, 0) },
					LeftHip = { rot = Vector3.new(6.39, 0, -1.69), pos = Vector3.new(0, 0.42, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = { rot = Vector3.new(-10.9, 0, -0.13), pos = Vector3.new(0, 0.03, 0.15) },
					Neck = { rot = Vector3.new(14.04, 0.07, -0.07) },
					RightShoulder = { rot = Vector3.new(69.19, 0, 85.07) },
					LeftShoulder = { rot = Vector3.new(6.21, 0, -80.65) },
					RightHip = { rot = Vector3.new(11.21, 0, 2.17), pos = Vector3.new(0, 0.42, 0) },
					LeftHip = { rot = Vector3.new(7.7, 0, -1.79), pos = Vector3.new(0, 0.47, 0) },
				},
			},
			{
				time = 0.6667,
				pose = {
					Root = {
						rot = Vector3.new(-12.06, -0.01, -0.14),
						pos = Vector3.new(0, 0.06, 0.15),
					},
					Neck = { rot = Vector3.new(15.23, 0.07, -0.07) },
					RightShoulder = { rot = Vector3.new(90.26, 0, 81.96) },
					LeftShoulder = { rot = Vector3.new(28.2, 0, -80.98) },
					RightHip = { rot = Vector3.new(13.49, 0, 2.39), pos = Vector3.new(0, 0.44, 0) },
					LeftHip = { rot = Vector3.new(9.8, 0, -1.9), pos = Vector3.new(0, 0.5, 0) },
				},
			},
			{
				time = 0.7333,
				pose = {
					Root = {
						rot = Vector3.new(-13.39, -0.01, -0.15),
						pos = Vector3.new(0, 0.08, 0.16),
					},
					Neck = { rot = Vector3.new(16.58, 0.07, -0.07) },
					RightShoulder = { rot = Vector3.new(100.37, 0, 79.36) },
					LeftShoulder = { rot = Vector3.new(45.47, 0, -80.84) },
					RightHip = { rot = Vector3.new(16.14, 0, 2.47), pos = Vector3.new(0, 0.44, 0) },
					LeftHip = { rot = Vector3.new(12.3, 0, -2.01), pos = Vector3.new(0, 0.52, 0) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = {
						rot = Vector3.new(-14.67, -0.01, -0.15),
						pos = Vector3.new(0, 0.1, 0.17),
					},
					Neck = { rot = Vector3.new(17.87, 0.07, -0.08) },
					RightShoulder = { rot = Vector3.new(107.63, 0, 77.74) },
					LeftShoulder = { rot = Vector3.new(57.53, 0, -80.97) },
					RightHip = { rot = Vector3.new(18.81, 0, 2.34), pos = Vector3.new(0, 0.39, 0) },
					LeftHip = { rot = Vector3.new(14.85, 0, -2.09), pos = Vector3.new(0, 0.52, 0) },
				},
			},
			{
				time = 0.8667,
				pose = {
					Root = {
						rot = Vector3.new(-15.69, -0.01, -0.14),
						pos = Vector3.new(0, 0.1, 0.18),
					},
					Neck = { rot = Vector3.new(18.89, 0.06, -0.08) },
					RightShoulder = { rot = Vector3.new(114.36, 0, 77.34) },
					LeftShoulder = { rot = Vector3.new(65.47, 0, -81.94) },
					RightHip = { rot = Vector3.new(21.1, 0, 2.07), pos = Vector3.new(0, 0.31, 0) },
					LeftHip = { rot = Vector3.new(17.1, 0, -2.12), pos = Vector3.new(0, 0.49, 0) },
				},
			},
			{
				time = 0.9333,
				pose = {
					Root = { rot = Vector3.new(-16.21, 0, -0.11), pos = Vector3.new(0, 0.1, 0.18) },
					Neck = { rot = Vector3.new(19.4, 0.05, -0.08) },
					RightShoulder = { rot = Vector3.new(122.14, 0, 78.34) },
					LeftShoulder = { rot = Vector3.new(69.13, 0, -84.1) },
					RightHip = { rot = Vector3.new(22.55, 0, 1.69), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(18.61, 0, -2.1), pos = Vector3.new(0, 0.43, 0) },
				},
			},
			{
				time = 1,
				pose = {
					Root = { rot = Vector3.new(-16.02, 0, -0.08), pos = Vector3.new(0, 0.08, 0.18) },
					Neck = { rot = Vector3.new(19.2, 0.04, -0.08) },
					RightShoulder = { rot = Vector3.new(134.22, 0, 80.89) },
					LeftShoulder = { rot = Vector3.new(55.88, 0, -87.75) },
					RightHip = { rot = Vector3.new(22.63, 0, 1.26), pos = Vector3.new(0, 0.13, 0) },
					LeftHip = { rot = Vector3.new(18.88, 0, -2.04), pos = Vector3.new(0, 0.37, 0) },
				},
			},
			{
				time = 1.0333,
				pose = {
					Root = { rot = Vector3.new(-16.02, 0, -0.08), pos = Vector3.new(0, 0.08, 0.18) },
					Neck = { rot = Vector3.new(19.2, 0.04, -0.08) },
					RightShoulder = { rot = Vector3.new(134.22, 0, 80.89) },
					LeftShoulder = { rot = Vector3.new(55.88, 0, -87.75) },
					RightHip = { rot = Vector3.new(22.63, 0, 1.26), pos = Vector3.new(0, 0.13, 0) },
					LeftHip = { rot = Vector3.new(18.88, 0, -2.04), pos = Vector3.new(0, 0.37, 0) },
				},
			},
		},
	},
	-- ALS_Flail: 0.70 s
	Flail = {
		length = 0.7,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-9.45, 3.65, 4.15),
						pos = Vector3.new(0, -0.33, 0.14),
					},
					Neck = { rot = Vector3.new(0.82, -3.93, -3.89) },
					RightShoulder = { rot = Vector3.new(68.05, 0, 41.59) },
					LeftShoulder = { rot = Vector3.new(-151.58, 0, -56.85) },
					RightHip = { rot = Vector3.new(-19.94, 0, -5.5), pos = Vector3.new(0, 0.42, 0) },
					LeftHip = { rot = Vector3.new(28.4, 0, -3.33), pos = Vector3.new(0, 0.42, 0) },
				},
			},
			{
				time = 0.0667,
				pose = {
					Root = {
						rot = Vector3.new(-9.29, 1.36, 2.98),
						pos = Vector3.new(0, -0.33, 0.14),
					},
					Neck = { rot = Vector3.new(0.76, -1.57, -2.64) },
					RightShoulder = { rot = Vector3.new(30.93, 0, 43.19) },
					LeftShoulder = { rot = Vector3.new(179.9, 0, -44.52) },
					RightHip = { rot = Vector3.new(-14.7, 0, -2.94), pos = Vector3.new(0, 0.82, 0) },
					LeftHip = { rot = Vector3.new(19.74, 0, -2.77), pos = Vector3.new(0, 0.41, 0) },
				},
			},
			{
				time = 0.1333,
				pose = {
					Root = {
						rot = Vector3.new(-9.29, -1.39, 0.71),
						pos = Vector3.new(0, -0.33, 0.14),
					},
					Neck = { rot = Vector3.new(0.78, 1.31, -0.44) },
					RightShoulder = { rot = Vector3.new(3.38, 0, 44.16) },
					LeftShoulder = { rot = Vector3.new(157.36, 0, -41.23) },
					RightHip = { rot = Vector3.new(-1.19, 0, -0.7), pos = Vector3.new(0, 1.09, 0) },
					LeftHip = { rot = Vector3.new(9.29, 0, -0.92), pos = Vector3.new(0, 0.31, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = {
						rot = Vector3.new(-9.36, -3.68, -1.82),
						pos = Vector3.new(0, -0.33, 0.14),
					},
					Neck = { rot = Vector3.new(0.83, 3.81, 1.87) },
					RightShoulder = { rot = Vector3.new(-22.37, 0, 51.04) },
					LeftShoulder = { rot = Vector3.new(124.65, 0, -39.81) },
					RightHip = { rot = Vector3.new(15.03, 0, 0.26), pos = Vector3.new(0, 0.99, 0) },
					LeftHip = { rot = Vector3.new(-0.12, 0, 1.21), pos = Vector3.new(0, 0.33, 0) },
				},
			},
			{
				time = 0.2667,
				pose = {
					Root = {
						rot = Vector3.new(-9.28, -4.64, -3.7),
						pos = Vector3.new(0, -0.33, 0.14),
					},
					Neck = { rot = Vector3.new(0.8, 4.95, 3.43) },
					RightShoulder = { rot = Vector3.new(-66.13, 0, 57.69) },
					LeftShoulder = { rot = Vector3.new(88.6, 0, -35.47) },
					RightHip = { rot = Vector3.new(27.01, 0, 0.9), pos = Vector3.new(0, 0.61, 0) },
					LeftHip = { rot = Vector3.new(-11.61, 0, 4.18), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.3333,
				pose = {
					Root = {
						rot = Vector3.new(-9.24, -3.67, -4.16),
						pos = Vector3.new(0, -0.33, 0.14),
					},
					Neck = { rot = Vector3.new(0.71, 3.95, 3.74) },
					RightShoulder = { rot = Vector3.new(-118.55, 0, 54.57) },
					LeftShoulder = { rot = Vector3.new(52.35, 0, -39.57) },
					RightHip = { rot = Vector3.new(25.58, 0, 2.64), pos = Vector3.new(0, 0.43, 0) },
					LeftHip = { rot = Vector3.new(-17.12, 0, 5.03), pos = Vector3.new(0, 0.47, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = {
						rot = Vector3.new(-9.23, -1.36, -2.95),
						pos = Vector3.new(0, -0.33, 0.14),
					},
					Neck = { rot = Vector3.new(0.68, 1.56, 2.56) },
					RightShoulder = { rot = Vector3.new(-158.13, 0, 46.17) },
					LeftShoulder = { rot = Vector3.new(17.59, 0, -44.4) },
					RightHip = { rot = Vector3.new(14.43, 0, 2.7), pos = Vector3.new(0, 0.39, 0) },
					LeftHip = { rot = Vector3.new(-12.7, 0, 2.83), pos = Vector3.new(0, 0.84, 0) },
				},
			},
			{
				time = 0.4667,
				pose = {
					Root = {
						rot = Vector3.new(-9.33, 1.39, -0.8),
						pos = Vector3.new(0, -0.33, 0.14),
					},
					Neck = { rot = Vector3.new(0.71, -1.23, 0.41) },
					RightShoulder = { rot = Vector3.new(178.64, 0, 41.11) },
					LeftShoulder = { rot = Vector3.new(-5.5, 0, -48.14) },
					RightHip = { rot = Vector3.new(7.61, 0, 1.01), pos = Vector3.new(0, 0.33, 0) },
					LeftHip = { rot = Vector3.new(0.52, 0, 0.64), pos = Vector3.new(0, 0.99, 0) },
				},
			},
			{
				time = 0.5333,
				pose = {
					Root = {
						rot = Vector3.new(-9.54, 3.67, 1.68),
						pos = Vector3.new(0, -0.33, 0.14),
					},
					Neck = { rot = Vector3.new(0.82, -3.63, -1.89) },
					RightShoulder = { rot = Vector3.new(149.91, 0, 44.6) },
					LeftShoulder = { rot = Vector3.new(-33.9, 0, -59.26) },
					RightHip = { rot = Vector3.new(-4.51, 0, -1.08), pos = Vector3.new(0, 0.34, 0) },
					LeftHip = { rot = Vector3.new(16.53, 0, -0.55), pos = Vector3.new(0, 0.79, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-9.61, 4.61, 3.58),
						pos = Vector3.new(0, -0.33, 0.14),
					},
					Neck = { rot = Vector3.new(0.88, -4.77, -3.55) },
					RightShoulder = { rot = Vector3.new(108.56, 0, 43.08) },
					LeftShoulder = { rot = Vector3.new(-93.24, 0, -66.02) },
					RightHip = { rot = Vector3.new(-14.7, 0, -4.51), pos = Vector3.new(0, 0.29, 0) },
					LeftHip = { rot = Vector3.new(29.09, 0, -1.19), pos = Vector3.new(0, 0.42, 0) },
				},
			},
			{
				time = 0.6667,
				pose = {
					Root = {
						rot = Vector3.new(-9.45, 3.65, 4.15),
						pos = Vector3.new(0, -0.33, 0.14),
					},
					Neck = { rot = Vector3.new(0.82, -3.93, -3.89) },
					RightShoulder = { rot = Vector3.new(68.05, 0, 41.59) },
					LeftShoulder = { rot = Vector3.new(-151.58, 0, -56.85) },
					RightHip = { rot = Vector3.new(-19.94, 0, -5.5), pos = Vector3.new(0, 0.42, 0) },
					LeftHip = { rot = Vector3.new(28.4, 0, -3.33), pos = Vector3.new(0, 0.42, 0) },
				},
			},
			{
				time = 0.7,
				pose = {
					Root = {
						rot = Vector3.new(-9.45, 3.65, 4.15),
						pos = Vector3.new(0, -0.33, 0.14),
					},
					Neck = { rot = Vector3.new(0.82, -3.93, -3.89) },
					RightShoulder = { rot = Vector3.new(68.05, 0, 41.59) },
					LeftShoulder = { rot = Vector3.new(-151.58, 0, -56.85) },
					RightHip = { rot = Vector3.new(-19.94, 0, -5.5), pos = Vector3.new(0, 0.42, 0) },
					LeftHip = { rot = Vector3.new(28.4, 0, -3.33), pos = Vector3.new(0, 0.42, 0) },
				},
			},
		},
	},
	-- ALS_N_Land_Light: 1.20 s
	LandLight = {
		length = 1.2,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(0.59, -8.85, 0.09), pos = Vector3.new(0, 0.11, 0) },
					Neck = { rot = Vector3.new(-12.2, 8.7, 1.71) },
					RightShoulder = { rot = Vector3.new(83.34, 0, 54.46) },
					LeftShoulder = { rot = Vector3.new(93.59, 0, -58.1) },
					RightHip = { rot = Vector3.new(0.63, 0, 6.42), pos = Vector3.new(0, 0.06, 0) },
					LeftHip = { rot = Vector3.new(4.37, 0, -5.09), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.0667,
				pose = {
					Root = {
						rot = Vector3.new(-2.25, -9.99, -0.26),
						pos = Vector3.new(0, -0.16, 0.01),
					},
					Neck = { rot = Vector3.new(-9.29, 9.85, 1.79) },
					RightShoulder = { rot = Vector3.new(85.24, 0, 53.2) },
					LeftShoulder = { rot = Vector3.new(95.88, 0, -58.86) },
					RightHip = { rot = Vector3.new(1.28, 0, 5.43), pos = Vector3.new(0, 0.25, 0) },
					LeftHip = { rot = Vector3.new(3.11, 0, -4.6), pos = Vector3.new(0, 0.24, 0) },
				},
			},
			{
				time = 0.1333,
				pose = {
					Root = {
						rot = Vector3.new(-5.24, -10.76, -0.72),
						pos = Vector3.new(0, -0.35, 0.04),
					},
					Neck = { rot = Vector3.new(-6.04, 10.65, 1.76) },
					RightShoulder = { rot = Vector3.new(80.93, 0, 51.82) },
					LeftShoulder = { rot = Vector3.new(91.88, 0, -56.77) },
					RightHip = { rot = Vector3.new(5.15, 0, 5.34), pos = Vector3.new(0, 0.43, 0) },
					LeftHip = { rot = Vector3.new(7.18, 0, -4.67), pos = Vector3.new(0, 0.44, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = {
						rot = Vector3.new(-8.13, -11.21, -1.23),
						pos = Vector3.new(-0.01, -0.45, 0.08),
					},
					Neck = { rot = Vector3.new(-2.68, 11.18, 1.67) },
					RightShoulder = { rot = Vector3.new(72.19, 0, 49.22) },
					LeftShoulder = { rot = Vector3.new(84.29, 0, -52.5) },
					RightHip = { rot = Vector3.new(9.53, 0, 5.17), pos = Vector3.new(0, 0.54, 0) },
					LeftHip = { rot = Vector3.new(11.29, 0, -4.77), pos = Vector3.new(0, 0.55, 0) },
				},
			},
			{
				time = 0.2667,
				pose = {
					Root = {
						rot = Vector3.new(-10.73, -11.44, -1.72),
						pos = Vector3.new(-0.02, -0.49, 0.12),
					},
					Neck = { rot = Vector3.new(0.54, 11.49, 1.53) },
					RightShoulder = { rot = Vector3.new(62.29, 0, 44.7) },
					LeftShoulder = { rot = Vector3.new(75.7, 0, -47.66) },
					RightHip = { rot = Vector3.new(13.63, 0, 4.96), pos = Vector3.new(0, 0.58, 0) },
					LeftHip = { rot = Vector3.new(15.19, 0, -4.86), pos = Vector3.new(0, 0.59, 0) },
				},
			},
			{
				time = 0.3333,
				pose = {
					Root = {
						rot = Vector3.new(-12.82, -11.5, -2.13),
						pos = Vector3.new(-0.02, -0.49, 0.15),
					},
					Neck = { rot = Vector3.new(3.36, 11.65, 1.36) },
					RightShoulder = { rot = Vector3.new(53.64, 0, 38.81) },
					LeftShoulder = { rot = Vector3.new(66.64, 0, -43.98) },
					RightHip = { rot = Vector3.new(17.04, 0, 4.81), pos = Vector3.new(0, 0.59, 0) },
					LeftHip = { rot = Vector3.new(18.5, 0, -4.9), pos = Vector3.new(0, 0.6, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = {
						rot = Vector3.new(-14.28, -11.48, -2.41),
						pos = Vector3.new(-0.03, -0.47, 0.17),
					},
					Neck = { rot = Vector3.new(5.66, 11.71, 1.18) },
					RightShoulder = { rot = Vector3.new(47.02, 0, 33.1) },
					LeftShoulder = { rot = Vector3.new(58.12, 0, -40.8) },
					RightHip = { rot = Vector3.new(19.49, 0, 4.76), pos = Vector3.new(0, 0.57, 0) },
					LeftHip = { rot = Vector3.new(20.91, 0, -4.88), pos = Vector3.new(0, 0.58, 0) },
				},
			},
			{
				time = 0.4667,
				pose = {
					Root = {
						rot = Vector3.new(-15.08, -11.45, -2.58),
						pos = Vector3.new(-0.03, -0.43, 0.18),
					},
					Neck = { rot = Vector3.new(7.37, 11.72, 0.99) },
					RightShoulder = { rot = Vector3.new(41.9, 0, 28.66) },
					LeftShoulder = { rot = Vector3.new(50.37, 0, -37.95) },
					RightHip = { rot = Vector3.new(20.77, 0, 4.81), pos = Vector3.new(0, 0.53, 0) },
					LeftHip = { rot = Vector3.new(22.21, 0, -4.8), pos = Vector3.new(0, 0.54, 0) },
				},
			},
			{
				time = 0.5333,
				pose = {
					Root = {
						rot = Vector3.new(-15.29, -11.35, -2.63),
						pos = Vector3.new(-0.03, -0.38, 0.17),
					},
					Neck = { rot = Vector3.new(8.53, 11.65, 0.81) },
					RightShoulder = { rot = Vector3.new(37.48, 0, 25.27) },
					LeftShoulder = { rot = Vector3.new(43.34, 0, -35.28) },
					RightHip = { rot = Vector3.new(21.2, 0, 4.89), pos = Vector3.new(0, 0.47, 0) },
					LeftHip = { rot = Vector3.new(22.71, 0, -4.7), pos = Vector3.new(0, 0.48, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-15.02, -11.2, -2.56),
						pos = Vector3.new(-0.03, -0.32, 0.16),
					},
					Neck = { rot = Vector3.new(9.26, 11.49, 0.63) },
					RightShoulder = { rot = Vector3.new(33.39, 0, 22.66) },
					LeftShoulder = { rot = Vector3.new(37.12, 0, -32.74) },
					RightHip = { rot = Vector3.new(20.91, 0, 4.97), pos = Vector3.new(0, 0.41, 0) },
					LeftHip = { rot = Vector3.new(22.53, 0, -4.63), pos = Vector3.new(0, 0.42, 0) },
				},
			},
			{
				time = 0.6667,
				pose = {
					Root = {
						rot = Vector3.new(-14.35, -11.01, -2.43),
						pos = Vector3.new(-0.03, -0.26, 0.14),
					},
					Neck = { rot = Vector3.new(9.6, 11.28, 0.48) },
					RightShoulder = { rot = Vector3.new(29.58, 0, 20.74) },
					LeftShoulder = { rot = Vector3.new(31.75, 0, -30.34) },
					RightHip = { rot = Vector3.new(19.99, 0, 5.08), pos = Vector3.new(0, 0.36, 0) },
					LeftHip = { rot = Vector3.new(21.75, 0, -4.53), pos = Vector3.new(0, 0.36, 0) },
				},
			},
			{
				time = 0.7333,
				pose = {
					Root = {
						rot = Vector3.new(-13.39, -10.8, -2.26),
						pos = Vector3.new(-0.03, -0.21, 0.12),
					},
					Neck = { rot = Vector3.new(9.62, 11.04, 0.37) },
					RightShoulder = { rot = Vector3.new(25.99, 0, 19.45) },
					LeftShoulder = { rot = Vector3.new(27.32, 0, -28.08) },
					RightHip = { rot = Vector3.new(18.54, 0, 5.22), pos = Vector3.new(0, 0.3, 0) },
					LeftHip = { rot = Vector3.new(20.46, 0, -4.41), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = {
						rot = Vector3.new(-12.25, -10.58, -2.08),
						pos = Vector3.new(-0.03, -0.16, 0.1),
					},
					Neck = { rot = Vector3.new(9.41, 10.79, 0.29) },
					RightShoulder = { rot = Vector3.new(22.64, 0, 18.69) },
					LeftShoulder = { rot = Vector3.new(23.8, 0, -26.02) },
					RightHip = { rot = Vector3.new(16.69, 0, 5.4), pos = Vector3.new(0, 0.26, 0) },
					LeftHip = { rot = Vector3.new(18.78, 0, -4.28), pos = Vector3.new(0, 0.26, 0) },
				},
			},
			{
				time = 0.8667,
				pose = {
					Root = {
						rot = Vector3.new(-11.04, -10.36, -1.91),
						pos = Vector3.new(-0.02, -0.13, 0.08),
					},
					Neck = { rot = Vector3.new(9.03, 10.55, 0.24) },
					RightShoulder = { rot = Vector3.new(19.6, 0, 18.34) },
					LeftShoulder = { rot = Vector3.new(20.73, 0, -24.5) },
					RightHip = { rot = Vector3.new(14.66, 0, 5.6), pos = Vector3.new(0, 0.23, 0) },
					LeftHip = { rot = Vector3.new(16.92, 0, -4.13), pos = Vector3.new(0, 0.22, 0) },
				},
			},
			{
				time = 0.9333,
				pose = {
					Root = {
						rot = Vector3.new(-9.86, -10.16, -1.77),
						pos = Vector3.new(-0.02, -0.1, 0.07),
					},
					Neck = { rot = Vector3.new(8.57, 10.32, 0.22) },
					RightShoulder = { rot = Vector3.new(16.94, 0, 18.31) },
					LeftShoulder = { rot = Vector3.new(18.08, 0, -23.49) },
					RightHip = { rot = Vector3.new(12.64, 0, 5.8), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(15.05, 0, -3.99), pos = Vector3.new(0, 0.19, 0) },
				},
			},
			{
				time = 1,
				pose = {
					Root = {
						rot = Vector3.new(-8.82, -9.99, -1.66),
						pos = Vector3.new(-0.02, -0.08, 0.05),
					},
					Neck = { rot = Vector3.new(8.11, 10.14, 0.22) },
					RightShoulder = { rot = Vector3.new(14.76, 0, 18.45) },
					LeftShoulder = { rot = Vector3.new(15.92, 0, -22.87) },
					RightHip = { rot = Vector3.new(10.84, 0, 5.99), pos = Vector3.new(0, 0.18, 0) },
					LeftHip = { rot = Vector3.new(13.36, 0, -3.86), pos = Vector3.new(0, 0.17, 0) },
				},
			},
			{
				time = 1.0667,
				pose = {
					Root = {
						rot = Vector3.new(-8.02, -9.86, -1.58),
						pos = Vector3.new(-0.02, -0.07, 0.04),
					},
					Neck = { rot = Vector3.new(7.72, 10, 0.23) },
					RightShoulder = { rot = Vector3.new(13.19, 0, 18.67) },
					LeftShoulder = { rot = Vector3.new(14.36, 0, -22.56) },
					RightHip = { rot = Vector3.new(9.45, 0, 6.14), pos = Vector3.new(0, 0.17, 0) },
					LeftHip = { rot = Vector3.new(12.06, 0, -3.76), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 1.1333,
				pose = {
					Root = {
						rot = Vector3.new(-7.57, -9.79, -1.53),
						pos = Vector3.new(-0.02, -0.07, 0.03),
					},
					Neck = { rot = Vector3.new(7.49, 9.93, 0.24) },
					RightShoulder = { rot = Vector3.new(12.34, 0, 18.83) },
					LeftShoulder = { rot = Vector3.new(13.53, 0, -22.45) },
					RightHip = { rot = Vector3.new(8.66, 0, 6.22), pos = Vector3.new(0, 0.16, 0) },
					LeftHip = { rot = Vector3.new(11.31, 0, -3.71), pos = Vector3.new(0, 0.14, 0) },
				},
			},
			{
				time = 1.2,
				pose = {
					Root = {
						rot = Vector3.new(-7.51, -9.78, -1.53),
						pos = Vector3.new(-0.02, -0.07, 0.03),
					},
					Neck = { rot = Vector3.new(7.46, 9.92, 0.24) },
					RightShoulder = { rot = Vector3.new(12.23, 0, 18.85) },
					LeftShoulder = { rot = Vector3.new(13.42, 0, -22.44) },
					RightHip = { rot = Vector3.new(8.55, 0, 6.23), pos = Vector3.new(0, 0.16, 0) },
					LeftHip = { rot = Vector3.new(11.21, 0, -3.7), pos = Vector3.new(0, 0.14, 0) },
				},
			},
		},
	},
	-- ALS_N_Land_Heavy: 1.20 s
	LandHeavy = {
		length = 1.2,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(0.52, -8.84, 0.17), pos = Vector3.new(0, 0.11, 0) },
					Neck = { rot = Vector3.new(-12.12, 8.7, 1.65) },
					RightShoulder = { rot = Vector3.new(128.16, 0, 32.38) },
					LeftShoulder = { rot = Vector3.new(128.51, 0, -30.95) },
					RightHip = { rot = Vector3.new(-0.4, 0, 6.12), pos = Vector3.new(0, 0.06, 0) },
					LeftHip = { rot = Vector3.new(5.68, 0, -5.96), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.0667,
				pose = {
					Root = {
						rot = Vector3.new(-3.02, -10.01, -0.39),
						pos = Vector3.new(0, -0.25, 0.02),
					},
					Neck = { rot = Vector3.new(11.94, 9.88, -1.73) },
					RightShoulder = { rot = Vector3.new(129.91, 0, 32.85) },
					LeftShoulder = { rot = Vector3.new(131.35, 0, -33.5) },
					RightHip = { rot = Vector3.new(0.52, 0, 6.05), pos = Vector3.new(0, 0.35, 0) },
					LeftHip = { rot = Vector3.new(7.06, 0, -5.68), pos = Vector3.new(0, 0.36, 0) },
				},
			},
			{
				time = 0.1333,
				pose = {
					Root = {
						rot = Vector3.new(-8.53, -10.76, -1.28),
						pos = Vector3.new(-0.01, -0.5, 0.07),
					},
					Neck = { rot = Vector3.new(15.96, 10.7, -1.79) },
					RightShoulder = { rot = Vector3.new(124.37, 0, 41.28) },
					LeftShoulder = { rot = Vector3.new(127.07, 0, -43.65) },
					RightHip = { rot = Vector3.new(8.28, 0, 5.94), pos = Vector3.new(0, 0.59, 0) },
					LeftHip = { rot = Vector3.new(14.23, 0, -5.93), pos = Vector3.new(0, 0.63, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = {
						rot = Vector3.new(-15.07, -11.15, -2.43),
						pos = Vector3.new(-0.01, -0.64, 0.14),
					},
					Neck = { rot = Vector3.new(18.67, 11.33, -1.38) },
					RightShoulder = { rot = Vector3.new(106.58, 0, 51.48) },
					LeftShoulder = { rot = Vector3.new(109.06, 0, -53.96) },
					RightHip = { rot = Vector3.new(16.3, 0, 5.54), pos = Vector3.new(0, 0.72, 0) },
					LeftHip = { rot = Vector3.new(22.48, 0, -6.32), pos = Vector3.new(0, 0.77, 0) },
				},
			},
			{
				time = 0.2667,
				pose = {
					Root = {
						rot = Vector3.new(-21.5, -11.25, -3.63),
						pos = Vector3.new(-0.02, -0.68, 0.21),
					},
					Neck = { rot = Vector3.new(19.85, 11.82, -0.59) },
					RightShoulder = { rot = Vector3.new(78.23, 0, 53.38) },
					LeftShoulder = { rot = Vector3.new(82.5, 0, -54.11) },
					RightHip = { rot = Vector3.new(25.1, 0, 5.04), pos = Vector3.new(0, 0.77, 0) },
					LeftHip = { rot = Vector3.new(30.82, 0, -6.7), pos = Vector3.new(0, 0.82, 0) },
				},
			},
			{
				time = 0.3333,
				pose = {
					Root = {
						rot = Vector3.new(-26.69, -11.21, -4.46),
						pos = Vector3.new(-0.03, -0.67, 0.27),
					},
					Neck = { rot = Vector3.new(19.34, 12.05, 0.41) },
					RightShoulder = { rot = Vector3.new(58.53, 0, 45.3) },
					LeftShoulder = { rot = Vector3.new(67.12, 0, -46.75) },
					RightHip = { rot = Vector3.new(32.55, 0, 4.51), pos = Vector3.new(0, 0.76, 0) },
					LeftHip = { rot = Vector3.new(37.87, 0, -7.12), pos = Vector3.new(0, 0.82, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = {
						rot = Vector3.new(-29.72, -11.16, -4.92),
						pos = Vector3.new(-0.04, -0.64, 0.31),
					},
					Neck = { rot = Vector3.new(17.18, 12.1, 1.35) },
					RightShoulder = { rot = Vector3.new(50.63, 0, 36.63) },
					LeftShoulder = { rot = Vector3.new(59.5, 0, -39.66) },
					RightHip = { rot = Vector3.new(37.49, 0, 4.21), pos = Vector3.new(0, 0.71, 0) },
					LeftHip = { rot = Vector3.new(42.58, 0, -7.35), pos = Vector3.new(0, 0.77, 0) },
				},
			},
			{
				time = 0.4667,
				pose = {
					Root = {
						rot = Vector3.new(-30.15, -11.18, -4.92),
						pos = Vector3.new(-0.04, -0.57, 0.32),
					},
					Neck = { rot = Vector3.new(13.83, 12.01, 2.07) },
					RightShoulder = { rot = Vector3.new(46.66, 0, 31.01) },
					LeftShoulder = { rot = Vector3.new(53.6, 0, -33.53) },
					RightHip = { rot = Vector3.new(39.21, 0, 4.14), pos = Vector3.new(0, 0.64, 0) },
					LeftHip = { rot = Vector3.new(44.33, 0, -7.35), pos = Vector3.new(0, 0.7, 0) },
				},
			},
			{
				time = 0.5333,
				pose = {
					Root = {
						rot = Vector3.new(-29.35, -11.14, -4.72),
						pos = Vector3.new(-0.05, -0.49, 0.31),
					},
					Neck = { rot = Vector3.new(11.57, 11.84, 2.35) },
					RightShoulder = { rot = Vector3.new(43.85, 0, 26.57) },
					LeftShoulder = { rot = Vector3.new(48.62, 0, -28.92) },
					RightHip = { rot = Vector3.new(39.06, 0, 4.27), pos = Vector3.new(0, 0.55, 0) },
					LeftHip = { rot = Vector3.new(44.4, 0, -7.16), pos = Vector3.new(0, 0.61, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-27.81, -11.04, -4.41),
						pos = Vector3.new(-0.05, -0.41, 0.28),
					},
					Neck = { rot = Vector3.new(10.59, 11.63, 2.26) },
					RightShoulder = { rot = Vector3.new(40.66, 0, 23.2) },
					LeftShoulder = { rot = Vector3.new(43.67, 0, -26.2) },
					RightHip = { rot = Vector3.new(37.45, 0, 4.55), pos = Vector3.new(0, 0.47, 0) },
					LeftHip = { rot = Vector3.new(43.1, 0, -6.85), pos = Vector3.new(0, 0.51, 0) },
				},
			},
			{
				time = 0.6667,
				pose = {
					Root = {
						rot = Vector3.new(-25.8, -10.89, -4.03),
						pos = Vector3.new(-0.05, -0.33, 0.24),
					},
					Neck = { rot = Vector3.new(10.06, 11.4, 2.02) },
					RightShoulder = { rot = Vector3.new(36.89, 0, 20.98) },
					LeftShoulder = { rot = Vector3.new(38.5, 0, -24.79) },
					RightHip = { rot = Vector3.new(34.81, 0, 4.88), pos = Vector3.new(0, 0.39, 0) },
					LeftHip = { rot = Vector3.new(40.81, 0, -6.51), pos = Vector3.new(0, 0.42, 0) },
				},
			},
			{
				time = 0.7333,
				pose = {
					Root = {
						rot = Vector3.new(-23.45, -10.71, -3.63),
						pos = Vector3.new(-0.05, -0.26, 0.2),
					},
					Neck = { rot = Vector3.new(9.89, 11.14, 1.69) },
					RightShoulder = { rot = Vector3.new(33.09, 0, 19.49) },
					LeftShoulder = { rot = Vector3.new(33.73, 0, -23.87) },
					RightHip = { rot = Vector3.new(31.49, 0, 5.24), pos = Vector3.new(0, 0.33, 0) },
					LeftHip = { rot = Vector3.new(37.81, 0, -6.16), pos = Vector3.new(0, 0.35, 0) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = {
						rot = Vector3.new(-20.94, -10.5, -3.23),
						pos = Vector3.new(-0.05, -0.21, 0.17),
					},
					Neck = { rot = Vector3.new(9.98, 10.88, 1.33) },
					RightShoulder = { rot = Vector3.new(29.34, 0, 18.64) },
					LeftShoulder = { rot = Vector3.new(29.84, 0, -23.39) },
					RightHip = { rot = Vector3.new(27.67, 0, 5.61), pos = Vector3.new(0, 0.28, 0) },
					LeftHip = { rot = Vector3.new(34.28, 0, -5.81), pos = Vector3.new(0, 0.31, 0) },
				},
			},
			{
				time = 0.8667,
				pose = {
					Root = {
						rot = Vector3.new(-18.43, -10.3, -2.87),
						pos = Vector3.new(-0.04, -0.17, 0.14),
					},
					Neck = { rot = Vector3.new(10.25, 10.63, 0.98) },
					RightShoulder = { rot = Vector3.new(25.77, 0, 18.29) },
					LeftShoulder = { rot = Vector3.new(26.47, 0, -23.29) },
					RightHip = { rot = Vector3.new(23.72, 0, 5.99), pos = Vector3.new(0, 0.26, 0) },
					LeftHip = { rot = Vector3.new(30.58, 0, -5.48), pos = Vector3.new(0, 0.27, 0) },
				},
			},
			{
				time = 0.9333,
				pose = {
					Root = {
						rot = Vector3.new(-16.09, -10.11, -2.58),
						pos = Vector3.new(-0.04, -0.15, 0.11),
					},
					Neck = { rot = Vector3.new(10.63, 10.4, 0.67) },
					RightShoulder = { rot = Vector3.new(22.55, 0, 18.29) },
					LeftShoulder = { rot = Vector3.new(23.57, 0, -23.43) },
					RightHip = { rot = Vector3.new(19.98, 0, 6.35), pos = Vector3.new(0, 0.24, 0) },
					LeftHip = { rot = Vector3.new(27.05, 0, -5.18), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 1,
				pose = {
					Root = {
						rot = Vector3.new(-14.08, -9.95, -2.35),
						pos = Vector3.new(-0.04, -0.14, 0.09),
					},
					Neck = { rot = Vector3.new(11.02, 10.2, 0.41) },
					RightShoulder = { rot = Vector3.new(19.88, 0, 18.5) },
					LeftShoulder = { rot = Vector3.new(21.23, 0, -23.67) },
					RightHip = { rot = Vector3.new(16.75, 0, 6.67), pos = Vector3.new(0, 0.23, 0) },
					LeftHip = { rot = Vector3.new(23.99, 0, -4.92), pos = Vector3.new(0, 0.24, 0) },
				},
			},
			{
				time = 1.0667,
				pose = {
					Root = {
						rot = Vector3.new(-12.57, -9.83, -2.19),
						pos = Vector3.new(-0.04, -0.13, 0.07),
					},
					Neck = { rot = Vector3.new(11.37, 10.06, 0.23) },
					RightShoulder = { rot = Vector3.new(17.93, 0, 18.78) },
					LeftShoulder = { rot = Vector3.new(19.56, 0, -23.88) },
					RightHip = { rot = Vector3.new(14.33, 0, 6.91), pos = Vector3.new(0, 0.23, 0) },
					LeftHip = { rot = Vector3.new(21.68, 0, -4.73), pos = Vector3.new(0, 0.23, 0) },
				},
			},
			{
				time = 1.1333,
				pose = {
					Root = {
						rot = Vector3.new(-11.73, -9.76, -2.11),
						pos = Vector3.new(-0.03, -0.13, 0.07),
					},
					Neck = { rot = Vector3.new(11.57, 9.99, 0.14) },
					RightShoulder = { rot = Vector3.new(16.87, 0, 18.99) },
					LeftShoulder = { rot = Vector3.new(18.66, 0, -24.02) },
					RightHip = { rot = Vector3.new(12.98, 0, 7.04), pos = Vector3.new(0, 0.23, 0) },
					LeftHip = { rot = Vector3.new(20.39, 0, -4.62), pos = Vector3.new(0, 0.23, 0) },
				},
			},
			{
				time = 1.2,
				pose = {
					Root = {
						rot = Vector3.new(-11.62, -9.75, -2.1),
						pos = Vector3.new(-0.03, -0.13, 0.06),
					},
					Neck = { rot = Vector3.new(11.6, 9.98, 0.12) },
					RightShoulder = { rot = Vector3.new(16.73, 0, 19.02) },
					LeftShoulder = { rot = Vector3.new(18.55, 0, -24.04) },
					RightHip = { rot = Vector3.new(12.8, 0, 7.06), pos = Vector3.new(0, 0.23, 0) },
					LeftHip = { rot = Vector3.new(20.22, 0, -4.61), pos = Vector3.new(0, 0.23, 0) },
				},
			},
		},
	},
	-- ALS_N_LandRoll_F: 1.53 s
	LandRoll = {
		length = 1.53,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-15.69, -0.01, -0.2),
						pos = Vector3.new(0, 0.11, 0.17),
					},
					Neck = { rot = Vector3.new(-10.33, -0.04, -0.04) },
					RightShoulder = { rot = Vector3.new(60.21, 0, 9.33) },
					LeftShoulder = { rot = Vector3.new(60.41, 0, -20.11) },
					RightHip = { rot = Vector3.new(34.95, 0, 4.08) },
					LeftHip = { rot = Vector3.new(20.69, 0, -2.71) },
				},
			},
			{
				time = 0.0667,
				pose = {
					Root = {
						rot = Vector3.new(-22.8, 3.13, 1.22),
						pos = Vector3.new(0.02, -0.33, 0.05),
					},
					Neck = { rot = Vector3.new(-3.92, 0.26, 2.4) },
					RightShoulder = { rot = Vector3.new(65.32, 0, 2.89) },
					LeftShoulder = { rot = Vector3.new(62.78, 0, -16.62) },
					RightHip = { rot = Vector3.new(34.09, 0, 3.01), pos = Vector3.new(0, 0.39, 0) },
					LeftHip = { rot = Vector3.new(24.94, 0, -3.16), pos = Vector3.new(0, 0.35, 0) },
				},
			},
			{
				time = 0.1333,
				pose = {
					Root = {
						rot = Vector3.new(-42.94, 9.65, 6.71),
						pos = Vector3.new(0.06, -0.6, -0.14),
					},
					Neck = { rot = Vector3.new(11.44, -1.18, 7.93) },
					RightShoulder = { rot = Vector3.new(69.3, 0, -6.65) },
					LeftShoulder = { rot = Vector3.new(69.93, 0, -10.44) },
					RightHip = { rot = Vector3.new(48.02, 0, 3.69), pos = Vector3.new(0, 0.59, 0) },
					LeftHip = { rot = Vector3.new(43.49, 0, -4.15), pos = Vector3.new(0, 0.55, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = {
						rot = Vector3.new(-74.86, 13.5, 19.28),
						pos = Vector3.new(0.12, -0.72, -0.51),
					},
					Neck = { rot = Vector3.new(29.7, -9.31, 12.46) },
					RightShoulder = { rot = Vector3.new(76.59, 0, -11.69) },
					LeftShoulder = { rot = Vector3.new(84.7, 0, 0.29) },
					RightHip = { rot = Vector3.new(66.24, 0, 3.82), pos = Vector3.new(0, 0.7, 0) },
					LeftHip = { rot = Vector3.new(76.66, 0, -4.73), pos = Vector3.new(0, 0.37, 0) },
				},
			},
			{
				time = 0.2667,
				pose = {
					Root = {
						rot = Vector3.new(-111.86, 9.45, 34.05),
						pos = Vector3.new(0.2, -0.77, -1.12),
					},
					Neck = { rot = Vector3.new(9.03, 16.52, 0.86) },
					RightShoulder = { rot = Vector3.new(79.78, 0, -18.29) },
					LeftShoulder = { rot = Vector3.new(107.48, 0, 14.71) },
					RightHip = { rot = Vector3.new(90.32, 0, 4.73), pos = Vector3.new(0, 0.55, 0) },
					LeftHip = { rot = Vector3.new(90.09, 0, -4.72), pos = Vector3.new(0, 0.87, 0) },
				},
			},
			{
				time = 0.3333,
				pose = {
					Root = {
						rot = Vector3.new(-145.83, 1.32, 43.21),
						pos = Vector3.new(0.29, -0.78, -1.78),
					},
					Neck = { rot = Vector3.new(-26.59, 20.42, 43.05) },
					RightShoulder = { rot = Vector3.new(91.28, 0, -20.81) },
					LeftShoulder = { rot = Vector3.new(121.05, 0, 17.63) },
					RightHip = { rot = Vector3.new(100.44, 0, 9.05), pos = Vector3.new(0, 0.88, 0) },
					LeftHip = { rot = Vector3.new(90.27, 0, 0.01), pos = Vector3.new(0, 1.51, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = {
						rot = Vector3.new(-175.28, -2.57, 50.1),
						pos = Vector3.new(0.36, -0.85, -2.38),
					},
					Neck = { rot = Vector3.new(-20.95, 9.23, 35.05) },
					RightShoulder = { rot = Vector3.new(104.94, 0, -9.41) },
					LeftShoulder = { rot = Vector3.new(127.05, 0, 21.24) },
					RightHip = {
						rot = Vector3.new(114.52, 0, 22.79),
						pos = Vector3.new(0, 0.84, 0),
					},
					LeftHip = { rot = Vector3.new(104.26, 0, 10.29), pos = Vector3.new(0, 1.38, 0) },
				},
			},
			{
				time = 0.4667,
				pose = {
					Root = {
						rot = Vector3.new(161.7, -4.08, 59.17),
						pos = Vector3.new(0.42, -1.03, -2.92),
					},
					Neck = { rot = Vector3.new(-47.16, 3.9, 28.89) },
					RightShoulder = { rot = Vector3.new(92.04, 0, -4.23) },
					LeftShoulder = { rot = Vector3.new(112.04, 0, 16.49) },
					RightHip = { rot = Vector3.new(130.76, 0, 19.03) },
					LeftHip = { rot = Vector3.new(139.16, 0, 15.51), pos = Vector3.new(0, 0.56, 0) },
				},
			},
			{
				time = 0.5333,
				pose = {
					Root = {
						rot = Vector3.new(133.14, -6.21, 62.38),
						pos = Vector3.new(0.44, -1.31, -3.39),
					},
					Neck = { rot = Vector3.new(-73.41, 14.17, 26.52) },
					RightShoulder = { rot = Vector3.new(75.29, 0, -12.13) },
					LeftShoulder = { rot = Vector3.new(95.54, 0, 2.34) },
					RightHip = { rot = Vector3.new(144.73, 0, 10.91) },
					LeftHip = { rot = Vector3.new(148.97, 0, 15.91), pos = Vector3.new(0, 0.19, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(91.54, -10.86, 63.34),
						pos = Vector3.new(0.43, -1.68, -3.67),
					},
					Neck = { rot = Vector3.new(-59.02, 35.57, 7.17) },
					RightShoulder = { rot = Vector3.new(71.59, 0, -5.41) },
					LeftShoulder = { rot = Vector3.new(93.77, 0, -0.69) },
					RightHip = { rot = Vector3.new(148.97, 0, -36.7) },
					LeftHip = { rot = Vector3.new(148.97, 0, 10.52) },
				},
			},
			{
				time = 0.6667,
				pose = {
					Root = {
						rot = Vector3.new(50.63, -13.02, 58.73),
						pos = Vector3.new(0.41, -1.74, -3.83),
					},
					Neck = { rot = Vector3.new(-20.11, 30.42, -25.17) },
					RightShoulder = { rot = Vector3.new(61.9, 0, -3.24) },
					LeftShoulder = { rot = Vector3.new(87.28, 0, -14.51) },
					RightHip = { rot = Vector3.new(117.08, 0, -45.62) },
					LeftHip = { rot = Vector3.new(148.97, 0, -14.19) },
				},
			},
			{
				time = 0.7333,
				pose = {
					Root = {
						rot = Vector3.new(25.23, -7.17, 51.86),
						pos = Vector3.new(0.39, -1.72, -4),
					},
					Neck = { rot = Vector3.new(-5.94, 14.88, -33.8) },
					RightShoulder = { rot = Vector3.new(69.04, 0, -3.25) },
					LeftShoulder = { rot = Vector3.new(36.79, 0, -49.77) },
					RightHip = { rot = Vector3.new(102.87, 0, -39.77) },
					LeftHip = { rot = Vector3.new(120.33, 0, -37.63) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = {
						rot = Vector3.new(10.83, 1.95, 42.18),
						pos = Vector3.new(0.35, -1.61, -4.24),
					},
					Neck = { rot = Vector3.new(-2.6, 1.2, -29.85) },
					RightShoulder = { rot = Vector3.new(69.05, 0, -2.09) },
					LeftShoulder = { rot = Vector3.new(16.54, 0, -51.73) },
					RightHip = {
						rot = Vector3.new(61.77, 0, -31.69),
						pos = Vector3.new(0, 0.69, 0),
					},
					LeftHip = { rot = Vector3.new(100.23, 0, -12.41) },
				},
			},
			{
				time = 0.8667,
				pose = {
					Root = {
						rot = Vector3.new(-1.02, 10.31, 36.46),
						pos = Vector3.new(0.31, -1.45, -4.5),
					},
					Neck = { rot = Vector3.new(1.43, -11.91, -26.39) },
					RightShoulder = { rot = Vector3.new(63.3, 0, 6.94) },
					LeftShoulder = { rot = Vector3.new(6.84, 0, -51.56) },
					RightHip = { rot = Vector3.new(54.1, 0, -20.94), pos = Vector3.new(0, 0.84, 0) },
					LeftHip = { rot = Vector3.new(96.1, 0, 4.37) },
				},
			},
			{
				time = 0.9333,
				pose = {
					Root = {
						rot = Vector3.new(-10.56, 17.36, 32.54),
						pos = Vector3.new(0.27, -1.27, -4.77),
					},
					Neck = { rot = Vector3.new(6.19, -22.79, -22.01) },
					RightShoulder = { rot = Vector3.new(57.96, 0, 17.52) },
					LeftShoulder = { rot = Vector3.new(2.28, 0, -50.25) },
					RightHip = {
						rot = Vector3.new(47.78, 0, -12.25),
						pos = Vector3.new(0, 0.92, 0),
					},
					LeftHip = { rot = Vector3.new(94.31, 0, 13.78) },
				},
			},
			{
				time = 1,
				pose = {
					Root = {
						rot = Vector3.new(-18.51, 22.52, 29.34),
						pos = Vector3.new(0.24, -1.08, -5.01),
					},
					Neck = { rot = Vector3.new(11.52, -29.74, -16.55) },
					RightShoulder = { rot = Vector3.new(51, 0, 26.2) },
					LeftShoulder = { rot = Vector3.new(15.64, 0, -45.2) },
					RightHip = { rot = Vector3.new(43.36, 0, -6.47), pos = Vector3.new(0, 0.92, 0) },
					LeftHip = { rot = Vector3.new(93.3, 0, 16.82) },
				},
			},
			{
				time = 1.0667,
				pose = {
					Root = {
						rot = Vector3.new(-24.25, 25.54, 26.48),
						pos = Vector3.new(0.2, -0.9, -5.22),
					},
					Neck = { rot = Vector3.new(16.25, -33.06, -11.66) },
					RightShoulder = { rot = Vector3.new(41.66, 0, 31.17) },
					LeftShoulder = { rot = Vector3.new(17.86, 0, -42.35) },
					RightHip = { rot = Vector3.new(41.02, 0, -3.17), pos = Vector3.new(0, 0.83, 0) },
					LeftHip = { rot = Vector3.new(28.51, 0, -7.33), pos = Vector3.new(0, 1.26, 0) },
				},
			},
			{
				time = 1.1333,
				pose = {
					Root = {
						rot = Vector3.new(-27.37, 26.74, 23.16),
						pos = Vector3.new(0.17, -0.73, -5.39),
					},
					Neck = { rot = Vector3.new(19.44, -33.47, -7.75) },
					RightShoulder = { rot = Vector3.new(33.98, 0, 32.93) },
					LeftShoulder = { rot = Vector3.new(16.66, 0, -39.25) },
					RightHip = { rot = Vector3.new(39.78, 0, -0.6), pos = Vector3.new(0, 0.72, 0) },
					LeftHip = { rot = Vector3.new(32.87, 0, -11.81), pos = Vector3.new(0, 0.98, 0) },
				},
			},
			{
				time = 1.2,
				pose = {
					Root = {
						rot = Vector3.new(-28.14, 26.45, 19.14),
						pos = Vector3.new(0.14, -0.6, -5.5),
					},
					Neck = { rot = Vector3.new(20.75, -31.73, -4.9) },
					RightShoulder = { rot = Vector3.new(30.7, 0, 33.44) },
					LeftShoulder = { rot = Vector3.new(15.32, 0, -35.02) },
					RightHip = { rot = Vector3.new(39.05, 0, 1.96), pos = Vector3.new(0, 0.64, 0) },
					LeftHip = { rot = Vector3.new(33.05, 0, -12.23), pos = Vector3.new(0, 0.83, 0) },
				},
			},
			{
				time = 1.2667,
				pose = {
					Root = {
						rot = Vector3.new(-27.27, 25, 14.89),
						pos = Vector3.new(0.12, -0.52, -5.57),
					},
					Neck = { rot = Vector3.new(20.43, -28.71, -2.96) },
					RightShoulder = { rot = Vector3.new(30.22, 0, 33.02) },
					LeftShoulder = { rot = Vector3.new(13.15, 0, -31.22) },
					RightHip = { rot = Vector3.new(38.01, 0, 4.06), pos = Vector3.new(0, 0.59, 0) },
					LeftHip = { rot = Vector3.new(30.93, 0, -10.09), pos = Vector3.new(0, 0.68, 0) },
				},
			},
			{
				time = 1.3333,
				pose = {
					Root = {
						rot = Vector3.new(-25.62, 22.86, 11.04),
						pos = Vector3.new(0.1, -0.47, -5.62),
					},
					Neck = { rot = Vector3.new(19.1, -25.25, -1.73) },
					RightShoulder = { rot = Vector3.new(31.63, 0, 31.99) },
					LeftShoulder = { rot = Vector3.new(10.18, 0, -28.43) },
					RightHip = { rot = Vector3.new(36.79, 0, 5.52), pos = Vector3.new(0, 0.57, 0) },
					LeftHip = { rot = Vector3.new(28.08, 0, -8.29), pos = Vector3.new(0, 0.58, 0) },
				},
			},
			{
				time = 1.4,
				pose = {
					Root = {
						rot = Vector3.new(-23.94, 20.64, 8.15),
						pos = Vector3.new(0.09, -0.44, -5.64),
					},
					Neck = { rot = Vector3.new(17.49, -22.17, -1) },
					RightShoulder = { rot = Vector3.new(33.9, 0, 30.95) },
					LeftShoulder = { rot = Vector3.new(6.92, 0, -26.74) },
					RightHip = { rot = Vector3.new(35.72, 0, 6.37), pos = Vector3.new(0, 0.56, 0) },
					LeftHip = { rot = Vector3.new(25.35, 0, -6.97), pos = Vector3.new(0, 0.53, 0) },
				},
			},
			{
				time = 1.4667,
				pose = {
					Root = {
						rot = Vector3.new(-22.84, 19.14, 6.58),
						pos = Vector3.new(0.08, -0.44, -5.65),
					},
					Neck = { rot = Vector3.new(16.36, -20.25, -0.67) },
					RightShoulder = { rot = Vector3.new(35.65, 0, 30.17) },
					LeftShoulder = { rot = Vector3.new(4.64, 0, -25.92) },
					RightHip = { rot = Vector3.new(35.06, 0, 6.7), pos = Vector3.new(0, 0.56, 0) },
					LeftHip = { rot = Vector3.new(23.59, 0, -6.27), pos = Vector3.new(0, 0.5, 0) },
				},
			},
			{
				time = 1.5333,
				pose = {
					Root = {
						rot = Vector3.new(-22.68, 18.91, 6.37),
						pos = Vector3.new(0.08, -0.43, -5.66),
					},
					Neck = { rot = Vector3.new(16.19, -19.98, -0.63) },
					RightShoulder = { rot = Vector3.new(35.93, 0, 30.04) },
					LeftShoulder = { rot = Vector3.new(4.29, 0, -25.82) },
					RightHip = { rot = Vector3.new(34.97, 0, 6.73), pos = Vector3.new(0, 0.56, 0) },
					LeftHip = { rot = Vector3.new(23.33, 0, -6.18), pos = Vector3.new(0, 0.5, 0) },
				},
			},
		},
	},
	-- ALS_CLF_GetUp_Back: 1.53 s
	GetUpBack = {
		length = 1.53,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(84.72, 0, -0.14),
						pos = Vector3.new(0, -1.75, -0.05),
					},
					Neck = { rot = Vector3.new(45.63, 0.05, -0.1) },
					RightShoulder = { rot = Vector3.new(-16.81, 0, 48.83) },
					LeftShoulder = { rot = Vector3.new(-8.25, 0, -41.45) },
					RightHip = {
						rot = Vector3.new(-17.26, 0, 10.72),
						pos = Vector3.new(0, 1.17, 0),
					},
					LeftHip = { rot = Vector3.new(-18.13, 0, -6.34), pos = Vector3.new(0, 1.22, 0) },
				},
			},
			{
				time = 0.0667,
				pose = {
					Root = {
						rot = Vector3.new(78.36, -0.55, -1.17),
						pos = Vector3.new(0, -1.75, -0.06),
					},
					Neck = { rot = Vector3.new(10.12, -0.5, 0.87) },
					RightShoulder = { rot = Vector3.new(-16.43, 0, 44.02) },
					LeftShoulder = { rot = Vector3.new(3.95, 0, -35.68) },
					RightHip = {
						rot = Vector3.new(-11.34, 0, 11.74),
						pos = Vector3.new(0, 1.19, 0),
					},
					LeftHip = { rot = Vector3.new(-13.13, 0, -5.04), pos = Vector3.new(0, 1.25, 0) },
				},
			},
			{
				time = 0.1333,
				pose = {
					Root = {
						rot = Vector3.new(60.1, -1.11, -4.28),
						pos = Vector3.new(0, -1.75, -0.07),
					},
					Neck = { rot = Vector3.new(-23.6, -3.38, 0.69) },
					RightShoulder = { rot = Vector3.new(-15.85, 0, 33.97) },
					LeftShoulder = { rot = Vector3.new(30.92, 0, -19.37) },
					RightHip = { rot = Vector3.new(5, 0, 14.26), pos = Vector3.new(0, 1.25, 0) },
					LeftHip = { rot = Vector3.new(0.08, 0, -1.9), pos = Vector3.new(0, 1.33, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = {
						rot = Vector3.new(37.72, -0.19, -8.69),
						pos = Vector3.new(0, -1.75, -0.09),
					},
					Neck = { rot = Vector3.new(-23.49, -5.58, -0.33) },
					RightShoulder = { rot = Vector3.new(-16.18, 0, 28.02) },
					LeftShoulder = { rot = Vector3.new(59.78, 0, 0.14) },
					RightHip = { rot = Vector3.new(23.67, 0, 17.13), pos = Vector3.new(0, 1.36, 0) },
					LeftHip = { rot = Vector3.new(12.92, 0, 1.66), pos = Vector3.new(0, 1.45, 0) },
				},
			},
			{
				time = 0.2667,
				pose = {
					Root = {
						rot = Vector3.new(21.9, 1.06, -12.64),
						pos = Vector3.new(0, -1.75, -0.11),
					},
					Neck = { rot = Vector3.new(-18.2, -6.17, -0.73) },
					RightShoulder = { rot = Vector3.new(-17.98, 0, 27.62) },
					LeftShoulder = { rot = Vector3.new(79.17, 0, 14.15) },
					RightHip = { rot = Vector3.new(35.78, 0, 20.77), pos = Vector3.new(0, 1.5, 0) },
					LeftHip = { rot = Vector3.new(17.95, 0, 4.34), pos = Vector3.new(0, 1.57, 0) },
				},
			},
			{
				time = 0.3333,
				pose = {
					Root = {
						rot = Vector3.new(9.87, 1.89, -14.99),
						pos = Vector3.new(0, -1.75, -0.11),
					},
					Neck = { rot = Vector3.new(-12.72, -5.06, -1.5) },
					RightShoulder = { rot = Vector3.new(-18.37, 0, 27.63) },
					LeftShoulder = { rot = Vector3.new(90.84, 0, 22.56) },
					RightHip = { rot = Vector3.new(45.64, 0, 21.11), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(21.79, 0, 7.23), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = {
						rot = Vector3.new(-1.53, 3.01, -16.88),
						pos = Vector3.new(0, -1.73, -0.1),
					},
					Neck = { rot = Vector3.new(-4.66, -3.31, -1.97) },
					RightShoulder = { rot = Vector3.new(-16.47, 0, 27.98) },
					LeftShoulder = { rot = Vector3.new(95.42, 0, 23.21) },
					RightHip = { rot = Vector3.new(58.48, 0, 20.22), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(25.07, 0, 9.5), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.4667,
				pose = {
					Root = {
						rot = Vector3.new(-12.93, 4.84, -20.15),
						pos = Vector3.new(-0.01, -1.68, -0.05),
					},
					Neck = { rot = Vector3.new(5.71, -1.39, -0.5) },
					RightShoulder = { rot = Vector3.new(-11.64, 0, 29.88) },
					LeftShoulder = { rot = Vector3.new(97.19, 0, 16.58) },
					RightHip = { rot = Vector3.new(72.16, 0, 18.63), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(31.52, 0, 9.74), pos = Vector3.new(0, 1.58, 0) },
				},
			},
			{
				time = 0.5333,
				pose = {
					Root = {
						rot = Vector3.new(-22.35, 6.95, -26.09),
						pos = Vector3.new(-0.07, -1.6, 0.03),
					},
					Neck = { rot = Vector3.new(15.01, 1.4, 3.87) },
					RightShoulder = { rot = Vector3.new(-4.45, 0, 35.45) },
					LeftShoulder = { rot = Vector3.new(95.89, 0, 4.99) },
					RightHip = { rot = Vector3.new(84.19, 0, 13.85), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(42.67, 0, 14.48), pos = Vector3.new(0, 1.46, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-29.56, 8.44, -30.52),
						pos = Vector3.new(-0.14, -1.5, 0.13),
					},
					Neck = { rot = Vector3.new(21.83, 4.76, 6.67) },
					RightShoulder = { rot = Vector3.new(6.33, 0, 41.48) },
					LeftShoulder = { rot = Vector3.new(90.18, 0, -7.5) },
					RightHip = { rot = Vector3.new(88.69, 0, 7.43), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(55.3, 0, 18.03), pos = Vector3.new(0, 1.3, 0) },
				},
			},
			{
				time = 0.6667,
				pose = {
					Root = {
						rot = Vector3.new(-35.48, 10.01, -33.43),
						pos = Vector3.new(-0.21, -1.38, 0.25),
					},
					Neck = { rot = Vector3.new(27.48, 7.56, 8.2) },
					RightShoulder = { rot = Vector3.new(19.01, 0, 45.88) },
					LeftShoulder = { rot = Vector3.new(81.3, 0, -19.53) },
					RightHip = { rot = Vector3.new(87.01, 0, 0.95), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(69.52, 0, 19.61), pos = Vector3.new(0, 1.09, 0) },
				},
			},
			{
				time = 0.7333,
				pose = {
					Root = {
						rot = Vector3.new(-40.3, 12.02, -36.74),
						pos = Vector3.new(-0.23, -1.27, 0.36),
					},
					Neck = { rot = Vector3.new(32.12, 10.11, 10.7) },
					RightShoulder = { rot = Vector3.new(32.14, 0, 48.88) },
					LeftShoulder = { rot = Vector3.new(67.96, 0, -29.98) },
					RightHip = { rot = Vector3.new(78.91, 0, -4.52), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(84.63, 0, 19.15), pos = Vector3.new(0, 0.8, 0) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = {
						rot = Vector3.new(-43.56, 13.5, -39.39),
						pos = Vector3.new(-0.23, -1.17, 0.46),
					},
					Neck = { rot = Vector3.new(35.18, 12.18, 13) },
					RightShoulder = { rot = Vector3.new(42.81, 0, 49.94) },
					LeftShoulder = { rot = Vector3.new(49.98, 0, -35.59) },
					RightHip = { rot = Vector3.new(64.86, 0, -3.91), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(90.09, 0, 17.33), pos = Vector3.new(0, 0.74, 0) },
				},
			},
			{
				time = 0.8667,
				pose = {
					Root = {
						rot = Vector3.new(-45.98, 14.31, -40.09),
						pos = Vector3.new(-0.19, -1.1, 0.53),
					},
					Neck = { rot = Vector3.new(37.5, 13.25, 13.96) },
					RightShoulder = { rot = Vector3.new(47.87, 0, 49.37) },
					LeftShoulder = { rot = Vector3.new(32.72, 0, -36.55) },
					RightHip = { rot = Vector3.new(59.09, 0, -0.66), pos = Vector3.new(0, 1.55, 0) },
					LeftHip = { rot = Vector3.new(90.08, 0, 15.32), pos = Vector3.new(0, 0.83, 0) },
				},
			},
			{
				time = 0.9333,
				pose = {
					Root = {
						rot = Vector3.new(-47.63, 14.63, -38.23),
						pos = Vector3.new(-0.14, -1.08, 0.56),
					},
					Neck = { rot = Vector3.new(39.36, 12.68, 13.34) },
					RightShoulder = { rot = Vector3.new(45.38, 0, 48.7) },
					LeftShoulder = { rot = Vector3.new(20.94, 0, -35.54) },
					RightHip = { rot = Vector3.new(40.41, 0, -0.98), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(90.08, 0, 13.38), pos = Vector3.new(0, 0.86, 0) },
				},
			},
			{
				time = 1,
				pose = {
					Root = {
						rot = Vector3.new(-46.83, 12.83, -33.18),
						pos = Vector3.new(-0.09, -1.09, 0.56),
					},
					Neck = { rot = Vector3.new(38.85, 10.05, 10.47) },
					RightShoulder = { rot = Vector3.new(37.27, 0, 47.2) },
					LeftShoulder = { rot = Vector3.new(14.23, 0, -35.65) },
					RightHip = { rot = Vector3.new(24.46, 0, 3.8), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(90.07, 0, 11.42), pos = Vector3.new(0, 0.74, 0) },
				},
			},
			{
				time = 1.0667,
				pose = {
					Root = {
						rot = Vector3.new(-43.35, 9.28, -27.4),
						pos = Vector3.new(-0.06, -1.11, 0.54),
					},
					Neck = { rot = Vector3.new(35.56, 7.28, 7.43) },
					RightShoulder = { rot = Vector3.new(31.43, 0, 44.55) },
					LeftShoulder = { rot = Vector3.new(10.18, 0, -35.92) },
					RightHip = { rot = Vector3.new(21.66, 0, 4.16), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(87.36, 0, 9.51), pos = Vector3.new(0, 0.66, 0) },
				},
			},
			{
				time = 1.1333,
				pose = {
					Root = {
						rot = Vector3.new(-38.36, 4.56, -21.98),
						pos = Vector3.new(-0.05, -1.14, 0.49),
					},
					Neck = { rot = Vector3.new(30.66, 6.04, 4.79) },
					RightShoulder = { rot = Vector3.new(30.19, 0, 39.47) },
					LeftShoulder = { rot = Vector3.new(6.76, 0, -35.33) },
					RightHip = { rot = Vector3.new(19.73, 0, 6.08), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(76.23, 0, 7.07), pos = Vector3.new(0, 0.87, 0) },
				},
			},
			{
				time = 1.2,
				pose = {
					Root = {
						rot = Vector3.new(-34.04, 0.68, -17.08),
						pos = Vector3.new(-0.04, -1.15, 0.44),
					},
					Neck = { rot = Vector3.new(26.88, 5.89, 3.23) },
					RightShoulder = { rot = Vector3.new(31.02, 0, 33.86) },
					LeftShoulder = { rot = Vector3.new(6.12, 0, -33.57) },
					RightHip = { rot = Vector3.new(17.3, 0, 6.51), pos = Vector3.new(0, 1.55, 0) },
					LeftHip = { rot = Vector3.new(65.92, 0, 4.37), pos = Vector3.new(0, 1.03, 0) },
				},
			},
			{
				time = 1.2667,
				pose = {
					Root = {
						rot = Vector3.new(-30.23, -2.42, -12.5),
						pos = Vector3.new(-0.04, -1.16, 0.38),
					},
					Neck = { rot = Vector3.new(24, 6.3, 2.24) },
					RightShoulder = { rot = Vector3.new(31.57, 0, 28.09) },
					LeftShoulder = { rot = Vector3.new(7.74, 0, -30.84) },
					RightHip = { rot = Vector3.new(13.58, 0, 2.96), pos = Vector3.new(0, 1.43, 0) },
					LeftHip = { rot = Vector3.new(54.12, 0, 2.45), pos = Vector3.new(0, 1.15, 0) },
				},
			},
			{
				time = 1.3333,
				pose = {
					Root = {
						rot = Vector3.new(-26.57, -4.86, -8.45),
						pos = Vector3.new(-0.04, -1.16, 0.33),
					},
					Neck = { rot = Vector3.new(21.51, 6.92, 1.51) },
					RightShoulder = { rot = Vector3.new(31.5, 0, 22.1) },
					LeftShoulder = { rot = Vector3.new(9.9, 0, -26.71) },
					RightHip = { rot = Vector3.new(9.7, 0, -0.23), pos = Vector3.new(0, 1.33, 0) },
					LeftHip = { rot = Vector3.new(45.62, 0, 0.6), pos = Vector3.new(0, 1.21, 0) },
				},
			},
			{
				time = 1.4,
				pose = {
					Root = {
						rot = Vector3.new(-23.6, -6.49, -5.32),
						pos = Vector3.new(-0.04, -1.15, 0.29),
					},
					Neck = { rot = Vector3.new(19.67, 7.54, 1.02) },
					RightShoulder = { rot = Vector3.new(30.79, 0, 17.23) },
					LeftShoulder = { rot = Vector3.new(11.48, 0, -22.07) },
					RightHip = { rot = Vector3.new(6.43, 0, -2.6), pos = Vector3.new(0, 1.27, 0) },
					LeftHip = { rot = Vector3.new(40.74, 0, -1.24), pos = Vector3.new(0, 1.24, 0) },
				},
			},
			{
				time = 1.4667,
				pose = {
					Root = {
						rot = Vector3.new(-21.89, -7.3, -3.54),
						pos = Vector3.new(-0.04, -1.15, 0.27),
					},
					Neck = { rot = Vector3.new(18.67, 7.91, 0.77) },
					RightShoulder = { rot = Vector3.new(30.08, 0, 14.47) },
					LeftShoulder = { rot = Vector3.new(12.22, 0, -19.07) },
					RightHip = { rot = Vector3.new(4.48, 0, -3.9), pos = Vector3.new(0, 1.23, 0) },
					LeftHip = { rot = Vector3.new(38.32, 0, -2.55), pos = Vector3.new(0, 1.26, 0) },
				},
			},
			{
				time = 1.5333,
				pose = {
					Root = {
						rot = Vector3.new(-21.65, -7.4, -3.3),
						pos = Vector3.new(-0.04, -1.15, 0.27),
					},
					Neck = { rot = Vector3.new(18.53, 7.96, 0.74) },
					RightShoulder = { rot = Vector3.new(29.96, 0, 14.09) },
					LeftShoulder = { rot = Vector3.new(12.32, 0, -18.63) },
					RightHip = { rot = Vector3.new(4.21, 0, -4.07), pos = Vector3.new(0, 1.23, 0) },
					LeftHip = { rot = Vector3.new(38, 0, -2.72), pos = Vector3.new(0, 1.27, 0) },
				},
			},
		},
	},
	-- ALS_CLF_GetUp_Front: 1.53 s
	GetUpFront = {
		length = 1.53,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-83.78, -2.25, -5.72),
						pos = Vector3.new(-0.05, -1.76, -0.07),
					},
					Neck = { rot = Vector3.new(-8.53, -40.4, 1.76) },
					RightShoulder = { rot = Vector3.new(146.28, 0, 49.74) },
					LeftShoulder = { rot = Vector3.new(154.05, 0, -57.77) },
					RightHip = { rot = Vector3.new(16.95, 0, 9.85), pos = Vector3.new(0, 1.33, 0) },
					LeftHip = { rot = Vector3.new(15.92, 0, -0.53), pos = Vector3.new(0, 0.88, 0) },
				},
			},
			{
				time = 0.0667,
				pose = {
					Root = {
						rot = Vector3.new(-83.65, -1.74, -5.6),
						pos = Vector3.new(-0.05, -1.76, -0.07),
					},
					Neck = { rot = Vector3.new(-0.69, -35.37, 6.5) },
					RightShoulder = { rot = Vector3.new(117.19, 0, 54.77) },
					LeftShoulder = { rot = Vector3.new(137.26, 0, -61.17) },
					RightHip = { rot = Vector3.new(16.81, 0, 9.85), pos = Vector3.new(0, 1.34, 0) },
					LeftHip = { rot = Vector3.new(16.1, 0, -0.55), pos = Vector3.new(0, 0.88, 0) },
				},
			},
			{
				time = 0.1333,
				pose = {
					Root = {
						rot = Vector3.new(-83.42, -0.63, -5.19),
						pos = Vector3.new(-0.05, -1.76, -0.07),
					},
					Neck = { rot = Vector3.new(14.92, -22.17, 11.46) },
					RightShoulder = { rot = Vector3.new(49.47, 0, 32.12) },
					LeftShoulder = { rot = Vector3.new(78.1, 0, -54.27) },
					RightHip = { rot = Vector3.new(16.57, 0, 9.74), pos = Vector3.new(0, 1.36, 0) },
					LeftHip = { rot = Vector3.new(16.53, 0, -0.08), pos = Vector3.new(0, 0.89, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = {
						rot = Vector3.new(-83.16, 0.46, -4.51),
						pos = Vector3.new(-0.05, -1.76, -0.06),
					},
					Neck = { rot = Vector3.new(31.9, -7.74, 8.38) },
					RightShoulder = { rot = Vector3.new(42.77, 0, 25.3) },
					LeftShoulder = { rot = Vector3.new(50.65, 0, -31.26) },
					RightHip = { rot = Vector3.new(16.37, 0, 9.39), pos = Vector3.new(0, 1.38, 0) },
					LeftHip = { rot = Vector3.new(16.38, 0, -0.05), pos = Vector3.new(0, 0.92, 0) },
				},
			},
			{
				time = 0.2667,
				pose = {
					Root = {
						rot = Vector3.new(-81.26, 0.95, -3.32),
						pos = Vector3.new(-0.05, -1.77, -0.06),
					},
					Neck = { rot = Vector3.new(45.64, 0.28, -0.28) },
					RightShoulder = { rot = Vector3.new(42.98, 0, 25.35) },
					LeftShoulder = { rot = Vector3.new(53.57, 0, -25.51) },
					RightHip = { rot = Vector3.new(15.02, 0, 8.5), pos = Vector3.new(0, 1.39, 0) },
					LeftHip = { rot = Vector3.new(14.21, 0, -2.13), pos = Vector3.new(0, 0.97, 0) },
				},
			},
			{
				time = 0.3333,
				pose = {
					Root = {
						rot = Vector3.new(-72.1, 0.45, -1.94),
						pos = Vector3.new(-0.06, -1.76, -0.06),
					},
					Neck = { rot = Vector3.new(43.57, 1.46, -5.88) },
					RightShoulder = { rot = Vector3.new(43.59, 0, 23.41) },
					LeftShoulder = { rot = Vector3.new(57.79, 0, -19.65) },
					RightHip = { rot = Vector3.new(8.17, 0, 7.44), pos = Vector3.new(0, 1.38, 0) },
					LeftHip = { rot = Vector3.new(5.05, 0, -4.29), pos = Vector3.new(0, 1.02, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = {
						rot = Vector3.new(-60.9, -0.61, -1.19),
						pos = Vector3.new(-0.07, -1.73, -0.06),
					},
					Neck = { rot = Vector3.new(28.87, 1.96, -6.72) },
					RightShoulder = { rot = Vector3.new(41.75, 0, 20.96) },
					LeftShoulder = { rot = Vector3.new(55.93, 0, -14.96) },
					RightHip = { rot = Vector3.new(1.05, 0, 6.08), pos = Vector3.new(0, 1.39, 0) },
					LeftHip = { rot = Vector3.new(-5.02, 0, -4.93), pos = Vector3.new(0, 1.03, 0) },
				},
			},
			{
				time = 0.4667,
				pose = {
					Root = {
						rot = Vector3.new(-55.18, -2.22, -0.76),
						pos = Vector3.new(-0.08, -1.65, -0.04),
					},
					Neck = { rot = Vector3.new(14.25, 4.19, -6.94) },
					RightShoulder = { rot = Vector3.new(41.84, 0, 19.02) },
					LeftShoulder = { rot = Vector3.new(53.27, 0, -14.31) },
					RightHip = { rot = Vector3.new(0.74, 0, 3.37), pos = Vector3.new(0, 1.4, 0) },
					LeftHip = { rot = Vector3.new(-8.41, 0, -4.74), pos = Vector3.new(0, 1.02, 0) },
				},
			},
			{
				time = 0.5333,
				pose = {
					Root = {
						rot = Vector3.new(-57.87, -3.69, -0.58),
						pos = Vector3.new(-0.08, -1.52, 0),
					},
					Neck = { rot = Vector3.new(5.29, 6.74, -6.22) },
					RightShoulder = { rot = Vector3.new(47.56, 0, 16.81) },
					LeftShoulder = { rot = Vector3.new(55.4, 0, -16.2) },
					RightHip = { rot = Vector3.new(9.69, 0, -0.7), pos = Vector3.new(0, 1.38, 0) },
					LeftHip = { rot = Vector3.new(-1.84, 0, -5.56), pos = Vector3.new(0, 1, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-66.17, -4.75, -0.54),
						pos = Vector3.new(-0.07, -1.36, 0.06),
					},
					Neck = { rot = Vector3.new(1.94, 8.6, -5.18) },
					RightShoulder = { rot = Vector3.new(58.42, 0, 13.94) },
					LeftShoulder = { rot = Vector3.new(62.91, 0, -18.47) },
					RightHip = { rot = Vector3.new(25.17, 0, -5.45), pos = Vector3.new(0, 1.3, 0) },
					LeftHip = { rot = Vector3.new(11.41, 0, -7.11), pos = Vector3.new(0, 0.98, 0) },
				},
			},
			{
				time = 0.6667,
				pose = {
					Root = {
						rot = Vector3.new(-74.08, -5.51, -0.19),
						pos = Vector3.new(-0.05, -1.23, 0.14),
					},
					Neck = { rot = Vector3.new(0.95, 9.63, -4.8) },
					RightShoulder = { rot = Vector3.new(70.08, 0, 11.1) },
					LeftShoulder = { rot = Vector3.new(72.15, 0, -20.82) },
					RightHip = { rot = Vector3.new(41.7, 0, -8.35), pos = Vector3.new(0, 1.3, 0) },
					LeftHip = { rot = Vector3.new(24.28, 0, -8.08), pos = Vector3.new(0, 0.94, 0) },
				},
			},
			{
				time = 0.7333,
				pose = {
					Root = {
						rot = Vector3.new(-79.96, -5.21, 0.6),
						pos = Vector3.new(-0.03, -1.16, 0.22),
					},
					Neck = { rot = Vector3.new(3.4, 8.77, -5.43) },
					RightShoulder = { rot = Vector3.new(80.14, 0, 10.27) },
					LeftShoulder = { rot = Vector3.new(81.95, 0, -22.18) },
					RightHip = { rot = Vector3.new(52.88, 0, -12.1), pos = Vector3.new(0, 1.33, 0) },
					LeftHip = { rot = Vector3.new(33.09, 0, -9.57), pos = Vector3.new(0, 0.98, 0) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = {
						rot = Vector3.new(-83.26, -1.69, 1.36),
						pos = Vector3.new(0, -1.15, 0.3),
					},
					Neck = { rot = Vector3.new(9.17, 3.62, -5.05) },
					RightShoulder = { rot = Vector3.new(86.78, 0, 14.02) },
					LeftShoulder = { rot = Vector3.new(92.2, 0, -19.05) },
					RightHip = {
						rot = Vector3.new(52.61, 0, -10.52),
						pos = Vector3.new(0, 1.53, 0),
					},
					LeftHip = { rot = Vector3.new(38.31, 0, -8.71), pos = Vector3.new(0, 1.03, 0) },
				},
			},
			{
				time = 0.8667,
				pose = {
					Root = {
						rot = Vector3.new(-84.12, 3.02, 1.61),
						pos = Vector3.new(0.03, -1.13, 0.38),
					},
					Neck = { rot = Vector3.new(16.71, -2.75, -1.73) },
					RightShoulder = { rot = Vector3.new(89.48, 0, 19.7) },
					LeftShoulder = { rot = Vector3.new(100.42, 0, -15.79) },
					RightHip = { rot = Vector3.new(50.32, 0, -8.25), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(42.72, 0, -6.73), pos = Vector3.new(0, 1.07, 0) },
				},
			},
			{
				time = 0.9333,
				pose = {
					Root = {
						rot = Vector3.new(-79.22, 6.38, 0.65),
						pos = Vector3.new(0.05, -1.12, 0.43),
					},
					Neck = { rot = Vector3.new(21.83, -6.36, 3.85) },
					RightShoulder = { rot = Vector3.new(85.84, 0, 22.83) },
					LeftShoulder = { rot = Vector3.new(97.7, 0, -19.43) },
					RightHip = { rot = Vector3.new(46.54, 0, -5.49), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(44.11, 0, -6.21), pos = Vector3.new(0, 1.35, 0) },
				},
			},
			{
				time = 1,
				pose = {
					Root = {
						rot = Vector3.new(-68.97, 6.84, -0.88),
						pos = Vector3.new(0.06, -1.11, 0.46),
					},
					Neck = { rot = Vector3.new(23.41, -5.62, 8) },
					RightShoulder = { rot = Vector3.new(76.63, 0, 21.07) },
					LeftShoulder = { rot = Vector3.new(84.33, 0, -27.04) },
					RightHip = { rot = Vector3.new(42.28, 0, -3.29), pos = Vector3.new(0, 1.55, 0) },
					LeftHip = { rot = Vector3.new(47.34, 0, -5.53), pos = Vector3.new(0, 1.52, 0) },
				},
			},
			{
				time = 1.0667,
				pose = {
					Root = {
						rot = Vector3.new(-56.99, 4.1, -2.34),
						pos = Vector3.new(0.05, -1.12, 0.46),
					},
					Neck = { rot = Vector3.new(23.53, -1.27, 8.99) },
					RightShoulder = { rot = Vector3.new(63.95, 0, 17.04) },
					LeftShoulder = { rot = Vector3.new(62.58, 0, -33.17) },
					RightHip = { rot = Vector3.new(36.23, 0, -4.6), pos = Vector3.new(0, 1.39, 0) },
					LeftHip = { rot = Vector3.new(57.45, 0, -3.31), pos = Vector3.new(0, 1.41, 0) },
				},
			},
			{
				time = 1.1333,
				pose = {
					Root = {
						rot = Vector3.new(-46.27, 0.98, -3.24),
						pos = Vector3.new(0.03, -1.13, 0.42),
					},
					Neck = { rot = Vector3.new(24.2, 2.66, 7.49) },
					RightShoulder = { rot = Vector3.new(52.32, 0, 14.87) },
					LeftShoulder = { rot = Vector3.new(41.4, 0, -31.97) },
					RightHip = { rot = Vector3.new(27.92, 0, -5.26), pos = Vector3.new(0, 1.3, 0) },
					LeftHip = { rot = Vector3.new(62.97, 0, -1.05), pos = Vector3.new(0, 1.28, 0) },
				},
			},
			{
				time = 1.2,
				pose = {
					Root = {
						rot = Vector3.new(-37.22, -1.77, -3.84),
						pos = Vector3.new(0, -1.14, 0.36),
					},
					Neck = { rot = Vector3.new(24.85, 4.88, 4.89) },
					RightShoulder = { rot = Vector3.new(45.09, 0, 13.59) },
					LeftShoulder = { rot = Vector3.new(26.87, 0, -28.81) },
					RightHip = { rot = Vector3.new(19.45, 0, -5.04), pos = Vector3.new(0, 1.27, 0) },
					LeftHip = { rot = Vector3.new(55.84, 0, -1.46), pos = Vector3.new(0, 1.26, 0) },
				},
			},
			{
				time = 1.2667,
				pose = {
					Root = {
						rot = Vector3.new(-30.05, -4.21, -4.15),
						pos = Vector3.new(-0.02, -1.15, 0.31),
					},
					Neck = { rot = Vector3.new(24.4, 6.03, 2.57) },
					RightShoulder = { rot = Vector3.new(39.73, 0, 13.31) },
					LeftShoulder = { rot = Vector3.new(17.91, 0, -25.06) },
					RightHip = { rot = Vector3.new(12.35, 0, -4.38), pos = Vector3.new(0, 1.25, 0) },
					LeftHip = { rot = Vector3.new(47.54, 0, -1.76), pos = Vector3.new(0, 1.26, 0) },
				},
			},
			{
				time = 1.3333,
				pose = {
					Root = {
						rot = Vector3.new(-25.03, -6.12, -3.99),
						pos = Vector3.new(-0.04, -1.15, 0.28),
					},
					Neck = { rot = Vector3.new(21.88, 7.01, 1.31) },
					RightShoulder = { rot = Vector3.new(35.41, 0, 13.54) },
					LeftShoulder = { rot = Vector3.new(13.55, 0, -21.77) },
					RightHip = { rot = Vector3.new(7.47, 0, -3.93), pos = Vector3.new(0, 1.24, 0) },
					LeftHip = { rot = Vector3.new(41.81, 0, -2.1), pos = Vector3.new(0, 1.26, 0) },
				},
			},
			{
				time = 1.4,
				pose = {
					Root = {
						rot = Vector3.new(-22.51, -7.12, -3.44),
						pos = Vector3.new(-0.04, -1.15, 0.27),
					},
					Neck = { rot = Vector3.new(19.37, 7.73, 0.8) },
					RightShoulder = { rot = Vector3.new(31.96, 0, 13.71) },
					LeftShoulder = { rot = Vector3.new(12.23, 0, -19.77) },
					RightHip = { rot = Vector3.new(5.05, 0, -4.1), pos = Vector3.new(0, 1.23, 0) },
					LeftHip = { rot = Vector3.new(38.94, 0, -2.64), pos = Vector3.new(0, 1.26, 0) },
				},
			},
			{
				time = 1.4667,
				pose = {
					Root = {
						rot = Vector3.new(-21.76, -7.39, -3.3),
						pos = Vector3.new(-0.04, -1.15, 0.27),
					},
					Neck = { rot = Vector3.new(18.64, 7.95, 0.72) },
					RightShoulder = { rot = Vector3.new(30.19, 0, 14.02) },
					LeftShoulder = { rot = Vector3.new(12.27, 0, -18.75) },
					RightHip = { rot = Vector3.new(4.33, 0, -4.1), pos = Vector3.new(0, 1.22, 0) },
					LeftHip = { rot = Vector3.new(38.11, 0, -2.74), pos = Vector3.new(0, 1.26, 0) },
				},
			},
			{
				time = 1.5333,
				pose = {
					Root = {
						rot = Vector3.new(-21.73, -7.39, -3.3),
						pos = Vector3.new(-0.04, -1.15, 0.27),
					},
					Neck = { rot = Vector3.new(18.61, 7.96, 0.73) },
					RightShoulder = { rot = Vector3.new(29.96, 0, 14.08) },
					LeftShoulder = { rot = Vector3.new(12.34, 0, -18.6) },
					RightHip = { rot = Vector3.new(4.3, 0, -4.08), pos = Vector3.new(0, 1.22, 0) },
					LeftHip = { rot = Vector3.new(38.08, 0, -2.72), pos = Vector3.new(0, 1.26, 0) },
				},
			},
		},
	},
	-- END generated ALS clips
}

return table.freeze(clips)
