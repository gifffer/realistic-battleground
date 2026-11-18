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
	-- ALS_N_Walk_F: phase clip (one cycle = 1), left foot plants at 0.4375; natural cycle 1.133 s, stride 3.62 studs per cycle
	Walk = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-3.92, -2.77, -1.8),
						pos = Vector3.new(0.04, -0.15, -0.08),
					},
					Neck = { rot = Vector3.new(3.85, 2.92, 1.53) },
					RightShoulder = { rot = Vector3.new(0.1, 0, 16.41) },
					LeftShoulder = { rot = Vector3.new(15.29, 0, -15.37) },
					RightHip = { rot = Vector3.new(16.26, 0, -1.02), pos = Vector3.new(0, 0.23, 0) },
					LeftHip = { rot = Vector3.new(-27.23, 0, 5.02), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.0312,
				pose = {
					Root = {
						rot = Vector3.new(-3.94, -2.59, -2.1),
						pos = Vector3.new(0.05, -0.13, -0.08),
					},
					Neck = { rot = Vector3.new(3.85, 2.73, 1.87) },
					RightShoulder = { rot = Vector3.new(2.96, 0, 16.26) },
					LeftShoulder = { rot = Vector3.new(12.25, 0, -15.83) },
					RightHip = { rot = Vector3.new(13, 0, -0.9), pos = Vector3.new(0, 0.21, 0) },
					LeftHip = { rot = Vector3.new(-26.73, 0, 5.02), pos = Vector3.new(0, 0.07, 0) },
				},
			},
			{
				time = 0.0625,
				pose = {
					Root = {
						rot = Vector3.new(-3.96, -2.3, -2.29),
						pos = Vector3.new(0.06, -0.11, -0.08),
					},
					Neck = { rot = Vector3.new(3.85, 2.44, 2.11) },
					RightShoulder = { rot = Vector3.new(6, 0, 15.95) },
					LeftShoulder = { rot = Vector3.new(9.01, 0, -16.1) },
					RightHip = { rot = Vector3.new(9.83, 0, -0.87), pos = Vector3.new(0, 0.18, 0) },
					LeftHip = { rot = Vector3.new(-24.02, 0, 4.9), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.0938,
				pose = {
					Root = {
						rot = Vector3.new(-3.96, -1.92, -2.38),
						pos = Vector3.new(0.07, -0.09, -0.08),
					},
					Neck = { rot = Vector3.new(3.85, 2.06, 2.26) },
					RightShoulder = { rot = Vector3.new(9.13, 0, 15.47) },
					LeftShoulder = { rot = Vector3.new(5.71, 0, -16.16) },
					RightHip = { rot = Vector3.new(6.68, 0, -0.93), pos = Vector3.new(0, 0.14, 0) },
					LeftHip = { rot = Vector3.new(-19.52, 0, 4.58), pos = Vector3.new(0, 0.16, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = {
						rot = Vector3.new(-3.95, -1.47, -2.41),
						pos = Vector3.new(0.07, -0.06, -0.08),
					},
					Neck = { rot = Vector3.new(3.86, 1.59, 2.35) },
					RightShoulder = { rot = Vector3.new(12.22, 0, 14.83) },
					LeftShoulder = { rot = Vector3.new(2.5, 0, -16.03) },
					RightHip = { rot = Vector3.new(3.74, 0, -1), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(-13.43, 0, 4.16), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.1562,
				pose = {
					Root = {
						rot = Vector3.new(-3.93, -0.96, -2.36),
						pos = Vector3.new(0.08, -0.04, -0.08),
					},
					Neck = { rot = Vector3.new(3.86, 1.06, 2.37) },
					RightShoulder = { rot = Vector3.new(15.14, 0, 14.07) },
					LeftShoulder = { rot = Vector3.new(-0.52, 0, -15.75) },
					RightHip = { rot = Vector3.new(0.92, 0, -0.96), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(-5.8, 0, 3.64), pos = Vector3.new(0, 0.21, 0) },
				},
			},
			{
				time = 0.1875,
				pose = {
					Root = {
						rot = Vector3.new(-3.91, -0.41, -2.25),
						pos = Vector3.new(0.08, -0.03, -0.07),
					},
					Neck = { rot = Vector3.new(3.86, 0.49, 2.32) },
					RightShoulder = { rot = Vector3.new(17.78, 0, 13.25) },
					LeftShoulder = { rot = Vector3.new(-3.21, 0, -15.4) },
					RightHip = { rot = Vector3.new(-2.23, 0, -0.94), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(2.22, 0, 3.21), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 0.2188,
				pose = {
					Root = {
						rot = Vector3.new(-3.89, 0.16, -2.07),
						pos = Vector3.new(0.08, -0.03, -0.07),
					},
					Neck = { rot = Vector3.new(3.87, -0.11, 2.21) },
					RightShoulder = { rot = Vector3.new(20.06, 0, 12.48) },
					LeftShoulder = { rot = Vector3.new(-5.48, 0, -15.07) },
					RightHip = { rot = Vector3.new(-5.32, 0, -1.04), pos = Vector3.new(0, 0.11, 0) },
					LeftHip = { rot = Vector3.new(10.65, 0, 2.96), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(-3.87, 0.72, -1.82),
						pos = Vector3.new(0.07, -0.05, -0.06),
					},
					Neck = { rot = Vector3.new(3.88, -0.69, 2.02) },
					RightShoulder = { rot = Vector3.new(21.91, 0, 11.86) },
					LeftShoulder = { rot = Vector3.new(-7.25, 0, -14.85) },
					RightHip = { rot = Vector3.new(-8.46, 0, -1.24), pos = Vector3.new(0, 0.13, 0) },
					LeftHip = { rot = Vector3.new(18.13, 0, 2.52), pos = Vector3.new(0, 0.07, 0) },
				},
			},
			{
				time = 0.2812,
				pose = {
					Root = {
						rot = Vector3.new(-3.86, 1.25, -1.51),
						pos = Vector3.new(0.07, -0.07, -0.06),
					},
					Neck = { rot = Vector3.new(3.88, -1.25, 1.75) },
					RightShoulder = { rot = Vector3.new(23.24, 0, 11.5) },
					LeftShoulder = { rot = Vector3.new(-8.45, 0, -14.84) },
					RightHip = {
						rot = Vector3.new(-11.63, 0, -1.56),
						pos = Vector3.new(0, 0.15, 0),
					},
					LeftHip = { rot = Vector3.new(23.73, 0, 2.2), pos = Vector3.new(0, 0.09, 0) },
				},
			},
			{
				time = 0.3125,
				pose = {
					Root = {
						rot = Vector3.new(-3.86, 1.73, -1.13),
						pos = Vector3.new(0.06, -0.1, -0.06),
					},
					Neck = { rot = Vector3.new(3.89, -1.76, 1.42) },
					RightShoulder = { rot = Vector3.new(23.97, 0, 11.51) },
					LeftShoulder = { rot = Vector3.new(-9, 0, -15.09) },
					RightHip = {
						rot = Vector3.new(-14.74, 0, -1.96),
						pos = Vector3.new(0, 0.16, 0),
					},
					LeftHip = { rot = Vector3.new(27.68, 0, 2.24), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.3438,
				pose = {
					Root = {
						rot = Vector3.new(-3.86, 2.14, -0.7),
						pos = Vector3.new(0.04, -0.13, -0.06),
					},
					Neck = { rot = Vector3.new(3.89, -2.19, 1.02) },
					RightShoulder = { rot = Vector3.new(24.01, 0, 11.89) },
					LeftShoulder = { rot = Vector3.new(-8.85, 0, -15.52) },
					RightHip = {
						rot = Vector3.new(-17.81, 0, -2.35),
						pos = Vector3.new(0, 0.17, 0),
					},
					LeftHip = { rot = Vector3.new(29.62, 0, 2.27), pos = Vector3.new(0, 0.12, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = {
						rot = Vector3.new(-3.88, 2.47, -0.23),
						pos = Vector3.new(0.03, -0.15, -0.06),
					},
					Neck = { rot = Vector3.new(3.9, -2.54, 0.56) },
					RightShoulder = { rot = Vector3.new(23.4, 0, 12.47) },
					LeftShoulder = { rot = Vector3.new(-8.05, 0, -15.88) },
					RightHip = { rot = Vector3.new(-20.7, 0, -2.85), pos = Vector3.new(0, 0.17, 0) },
					LeftHip = { rot = Vector3.new(28.57, 0, 2.09), pos = Vector3.new(0, 0.16, 0) },
				},
			},
			{
				time = 0.4062,
				pose = {
					Root = {
						rot = Vector3.new(-3.9, 2.7, 0.28),
						pos = Vector3.new(0.01, -0.16, -0.07),
					},
					Neck = { rot = Vector3.new(3.89, -2.79, 0.06) },
					RightShoulder = { rot = Vector3.new(22.17, 0, 13.16) },
					LeftShoulder = { rot = Vector3.new(-6.68, 0, -16.18) },
					RightHip = { rot = Vector3.new(-23.16, 0, -3.5), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(25.67, 0, 1.8), pos = Vector3.new(0, 0.19, 0) },
				},
			},
			{
				time = 0.4375,
				pose = {
					Root = {
						rot = Vector3.new(-3.93, 2.83, 0.83),
						pos = Vector3.new(0, -0.16, -0.07),
					},
					Neck = { rot = Vector3.new(3.89, -2.95, -0.5) },
					RightShoulder = { rot = Vector3.new(20.36, 0, 13.88) },
					LeftShoulder = { rot = Vector3.new(-4.81, 0, -16.42) },
					RightHip = {
						rot = Vector3.new(-25.17, 0, -4.14),
						pos = Vector3.new(0, 0.13, 0),
					},
					LeftHip = { rot = Vector3.new(22.7, 0, 1.58), pos = Vector3.new(0, 0.21, 0) },
				},
			},
			{
				time = 0.4688,
				pose = {
					Root = {
						rot = Vector3.new(-3.95, 2.85, 1.37),
						pos = Vector3.new(-0.02, -0.16, -0.08),
					},
					Neck = { rot = Vector3.new(3.88, -2.99, -1.07) },
					RightShoulder = { rot = Vector3.new(18.05, 0, 14.57) },
					LeftShoulder = { rot = Vector3.new(-2.52, 0, -16.57) },
					RightHip = {
						rot = Vector3.new(-26.54, 0, -4.65),
						pos = Vector3.new(0, 0.11, 0),
					},
					LeftHip = { rot = Vector3.new(19.58, 0, 1.31), pos = Vector3.new(0, 0.23, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-3.96, 2.77, 1.81),
						pos = Vector3.new(-0.04, -0.15, -0.08),
					},
					Neck = { rot = Vector3.new(3.87, -2.92, -1.53) },
					RightShoulder = { rot = Vector3.new(15.31, 0, 15.16) },
					LeftShoulder = { rot = Vector3.new(0.09, 0, -16.58) },
					RightHip = { rot = Vector3.new(-27.23, 0, -4.9), pos = Vector3.new(0, 0.08, 0) },
					LeftHip = { rot = Vector3.new(16.32, 0, 1.11), pos = Vector3.new(0, 0.23, 0) },
				},
			},
			{
				time = 0.5312,
				pose = {
					Root = {
						rot = Vector3.new(-3.96, 2.59, 2.11),
						pos = Vector3.new(-0.05, -0.13, -0.08),
					},
					Neck = { rot = Vector3.new(3.86, -2.73, -1.87) },
					RightShoulder = { rot = Vector3.new(12.27, 0, 15.63) },
					LeftShoulder = { rot = Vector3.new(2.94, 0, -16.43) },
					RightHip = {
						rot = Vector3.new(-26.75, 0, -4.93),
						pos = Vector3.new(0, 0.07, 0),
					},
					LeftHip = { rot = Vector3.new(13.04, 0, 1), pos = Vector3.new(0, 0.21, 0) },
				},
			},
			{
				time = 0.5625,
				pose = {
					Root = {
						rot = Vector3.new(-3.95, 2.3, 2.29),
						pos = Vector3.new(-0.06, -0.11, -0.08),
					},
					Neck = { rot = Vector3.new(3.86, -2.44, -2.11) },
					RightShoulder = { rot = Vector3.new(9.03, 0, 15.9) },
					LeftShoulder = { rot = Vector3.new(5.98, 0, -16.13) },
					RightHip = { rot = Vector3.new(-24.07, 0, -4.78), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(9.84, 0, 0.96), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 0.5938,
				pose = {
					Root = {
						rot = Vector3.new(-3.93, 1.93, 2.39),
						pos = Vector3.new(-0.07, -0.09, -0.08),
					},
					Neck = { rot = Vector3.new(3.85, -2.06, -2.26) },
					RightShoulder = { rot = Vector3.new(5.74, 0, 15.97) },
					LeftShoulder = { rot = Vector3.new(9.11, 0, -15.66) },
					RightHip = {
						rot = Vector3.new(-19.61, 0, -4.41),
						pos = Vector3.new(0, 0.16, 0),
					},
					LeftHip = { rot = Vector3.new(6.66, 0, 0.99), pos = Vector3.new(0, 0.14, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = {
						rot = Vector3.new(-3.9, 1.48, 2.42),
						pos = Vector3.new(-0.07, -0.06, -0.08),
					},
					Neck = { rot = Vector3.new(3.84, -1.59, -2.35) },
					RightShoulder = { rot = Vector3.new(2.52, 0, 15.84) },
					LeftShoulder = { rot = Vector3.new(12.2, 0, -15.02) },
					RightHip = { rot = Vector3.new(-13.55, 0, -3.94), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(3.69, 0, 1.02), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.6562,
				pose = {
					Root = {
						rot = Vector3.new(-3.86, 0.97, 2.38),
						pos = Vector3.new(-0.08, -0.04, -0.08),
					},
					Neck = { rot = Vector3.new(3.84, -1.07, -2.37) },
					RightShoulder = { rot = Vector3.new(-0.49, 0, 15.56) },
					LeftShoulder = { rot = Vector3.new(15.12, 0, -14.26) },
					RightHip = { rot = Vector3.new(-5.94, 0, -3.41), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(0.85, 0, 0.95), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.6875,
				pose = {
					Root = {
						rot = Vector3.new(-3.82, 0.41, 2.27),
						pos = Vector3.new(-0.08, -0.03, -0.07),
					},
					Neck = { rot = Vector3.new(3.84, -0.5, -2.33) },
					RightShoulder = { rot = Vector3.new(-3.19, 0, 15.22) },
					LeftShoulder = { rot = Vector3.new(17.76, 0, -13.45) },
					RightHip = { rot = Vector3.new(2.06, 0, -3.01), pos = Vector3.new(0, 0.18, 0) },
					LeftHip = { rot = Vector3.new(-2.31, 0, 0.98), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.7188,
				pose = {
					Root = {
						rot = Vector3.new(-3.78, -0.15, 2.1),
						pos = Vector3.new(-0.08, -0.03, -0.06),
					},
					Neck = { rot = Vector3.new(3.84, 0.09, -2.21) },
					RightShoulder = { rot = Vector3.new(-5.46, 0, 14.89) },
					LeftShoulder = { rot = Vector3.new(20.04, 0, -12.68) },
					RightHip = { rot = Vector3.new(10.49, 0, -2.81), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(-5.41, 0, 1.1), pos = Vector3.new(0, 0.11, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(-3.75, -0.72, 1.86),
						pos = Vector3.new(-0.07, -0.05, -0.06),
					},
					Neck = { rot = Vector3.new(3.84, 0.68, -2.02) },
					RightShoulder = { rot = Vector3.new(-7.24, 0, 14.68) },
					LeftShoulder = { rot = Vector3.new(21.89, 0, -12.06) },
					RightHip = { rot = Vector3.new(17.99, 0, -2.47), pos = Vector3.new(0, 0.07, 0) },
					LeftHip = { rot = Vector3.new(-8.56, 0, 1.3), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 0.7812,
				pose = {
					Root = {
						rot = Vector3.new(-3.73, -1.25, 1.54),
						pos = Vector3.new(-0.07, -0.07, -0.06),
					},
					Neck = { rot = Vector3.new(3.84, 1.23, -1.76) },
					RightShoulder = { rot = Vector3.new(-8.44, 0, 14.67) },
					LeftShoulder = { rot = Vector3.new(23.23, 0, -11.7) },
					RightHip = { rot = Vector3.new(23.61, 0, -2.21), pos = Vector3.new(0, 0.09, 0) },
					LeftHip = { rot = Vector3.new(-11.75, 0, 1.57), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.8125,
				pose = {
					Root = {
						rot = Vector3.new(-3.72, -1.73, 1.17),
						pos = Vector3.new(-0.06, -0.1, -0.06),
					},
					Neck = { rot = Vector3.new(3.84, 1.74, -1.42) },
					RightShoulder = { rot = Vector3.new(-8.99, 0, 14.93) },
					LeftShoulder = { rot = Vector3.new(23.95, 0, -11.71) },
					RightHip = { rot = Vector3.new(27.55, 0, -2.22), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(-14.86, 0, 1.96), pos = Vector3.new(0, 0.16, 0) },
				},
			},
			{
				time = 0.8438,
				pose = {
					Root = {
						rot = Vector3.new(-3.73, -2.14, 0.74),
						pos = Vector3.new(-0.04, -0.13, -0.06),
					},
					Neck = { rot = Vector3.new(3.85, 2.18, -1.02) },
					RightShoulder = { rot = Vector3.new(-8.84, 0, 15.36) },
					LeftShoulder = { rot = Vector3.new(24, 0, -12.09) },
					RightHip = { rot = Vector3.new(29.48, 0, -2.2), pos = Vector3.new(0, 0.12, 0) },
					LeftHip = { rot = Vector3.new(-17.93, 0, 2.39), pos = Vector3.new(0, 0.17, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = {
						rot = Vector3.new(-3.76, -2.47, 0.26),
						pos = Vector3.new(-0.03, -0.15, -0.06),
					},
					Neck = { rot = Vector3.new(3.85, 2.52, -0.57) },
					RightShoulder = { rot = Vector3.new(-8.04, 0, 15.73) },
					LeftShoulder = { rot = Vector3.new(23.39, 0, -12.67) },
					RightHip = { rot = Vector3.new(28.44, 0, -2.02), pos = Vector3.new(0, 0.16, 0) },
					LeftHip = { rot = Vector3.new(-20.8, 0, 2.92), pos = Vector3.new(0, 0.17, 0) },
				},
			},
			{
				time = 0.9062,
				pose = {
					Root = {
						rot = Vector3.new(-3.79, -2.7, -0.26),
						pos = Vector3.new(-0.01, -0.16, -0.06),
					},
					Neck = { rot = Vector3.new(3.85, 2.78, -0.06) },
					RightShoulder = { rot = Vector3.new(-6.67, 0, 16.02) },
					LeftShoulder = { rot = Vector3.new(22.15, 0, -13.36) },
					RightHip = { rot = Vector3.new(25.58, 0, -1.79), pos = Vector3.new(0, 0.19, 0) },
					LeftHip = { rot = Vector3.new(-23.23, 0, 3.61), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.9375,
				pose = {
					Root = {
						rot = Vector3.new(-3.83, -2.83, -0.81),
						pos = Vector3.new(0, -0.16, -0.07),
					},
					Neck = { rot = Vector3.new(3.85, 2.94, 0.5) },
					RightShoulder = { rot = Vector3.new(-4.8, 0, 16.25) },
					LeftShoulder = { rot = Vector3.new(20.35, 0, -14.09) },
					RightHip = { rot = Vector3.new(22.62, 0, -1.55), pos = Vector3.new(0, 0.21, 0) },
					LeftHip = { rot = Vector3.new(-25.22, 0, 4.28), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 0.9688,
				pose = {
					Root = {
						rot = Vector3.new(-3.88, -2.85, -1.36),
						pos = Vector3.new(0.02, -0.16, -0.08),
					},
					Neck = { rot = Vector3.new(3.85, 2.98, 1.07) },
					RightShoulder = { rot = Vector3.new(-2.51, 0, 16.4) },
					LeftShoulder = { rot = Vector3.new(18.03, 0, -14.77) },
					RightHip = { rot = Vector3.new(19.51, 0, -1.25), pos = Vector3.new(0, 0.23, 0) },
					LeftHip = { rot = Vector3.new(-26.57, 0, 4.78), pos = Vector3.new(0, 0.11, 0) },
				},
			},
		},
	},
	-- ALS_N_Walk_B: phase clip (one cycle = 1), left foot plants at 0.4375; natural cycle 1.133 s, stride 3.65 studs per cycle
	WalkBack = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(2.23, 1.12, -2.2),
						pos = Vector3.new(0.08, -0.08, 0.03),
					},
					Neck = { rot = Vector3.new(-2.24, -1.29, 2.32) },
					RightShoulder = { rot = Vector3.new(14.52, 0, 12.03) },
					LeftShoulder = { rot = Vector3.new(-12.33, 0, -16.4) },
					RightHip = { rot = Vector3.new(-9.46, 0, -1.23), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(-0.15, 0, 3.09), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.0312,
				pose = {
					Root = {
						rot = Vector3.new(2.21, 0.57, -2.37),
						pos = Vector3.new(0.08, -0.06, 0.03),
					},
					Neck = { rot = Vector3.new(-2.25, -0.73, 2.49) },
					RightShoulder = { rot = Vector3.new(12.18, 0, 12.77) },
					LeftShoulder = { rot = Vector3.new(-9.67, 0, -16.76) },
					RightHip = { rot = Vector3.new(-6.38, 0, -1.01), pos = Vector3.new(0, 0.12, 0) },
					LeftHip = { rot = Vector3.new(-8.16, 0, 3.36), pos = Vector3.new(0, 0.23, 0) },
				},
			},
			{
				time = 0.0625,
				pose = {
					Root = {
						rot = Vector3.new(2.19, -0.01, -2.47),
						pos = Vector3.new(0.08, -0.04, 0.02),
					},
					Neck = { rot = Vector3.new(-2.25, -0.14, 2.58) },
					RightShoulder = { rot = Vector3.new(9.49, 0, 13.5) },
					LeftShoulder = { rot = Vector3.new(-6.59, 0, -17.02) },
					RightHip = { rot = Vector3.new(-3.34, 0, -0.85), pos = Vector3.new(0, 0.09, 0) },
					LeftHip = { rot = Vector3.new(-15.87, 0, 3.73), pos = Vector3.new(0, 0.21, 0) },
				},
			},
			{
				time = 0.0938,
				pose = {
					Root = {
						rot = Vector3.new(2.18, -0.58, -2.51),
						pos = Vector3.new(0.07, -0.04, 0.02),
					},
					Neck = { rot = Vector3.new(-2.26, 0.45, 2.61) },
					RightShoulder = { rot = Vector3.new(6.56, 0, 14.15) },
					LeftShoulder = { rot = Vector3.new(-3.22, 0, -17.09) },
					RightHip = { rot = Vector3.new(-0.41, 0, -0.65), pos = Vector3.new(0, 0.09, 0) },
					LeftHip = { rot = Vector3.new(-22.7, 0, 4.18), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = {
						rot = Vector3.new(2.17, -1.14, -2.48),
						pos = Vector3.new(0.07, -0.05, 0.03),
					},
					Neck = { rot = Vector3.new(-2.27, 1.03, 2.57) },
					RightShoulder = { rot = Vector3.new(3.52, 0, 14.67) },
					LeftShoulder = { rot = Vector3.new(0.29, 0, -16.93) },
					RightHip = { rot = Vector3.new(3, 0, -0.41), pos = Vector3.new(0, 0.12, 0) },
					LeftHip = { rot = Vector3.new(-27.73, 0, 4.55), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.1562,
				pose = {
					Root = {
						rot = Vector3.new(2.16, -1.66, -2.39),
						pos = Vector3.new(0.06, -0.07, 0.03),
					},
					Neck = { rot = Vector3.new(-2.27, 1.57, 2.47) },
					RightShoulder = { rot = Vector3.new(0.45, 0, 15.1) },
					LeftShoulder = { rot = Vector3.new(3.81, 0, -16.5) },
					RightHip = { rot = Vector3.new(6.39, 0, -0.3), pos = Vector3.new(0, 0.16, 0) },
					LeftHip = { rot = Vector3.new(-31.28, 0, 4.9), pos = Vector3.new(0, 0.03, 0) },
				},
			},
			{
				time = 0.1875,
				pose = {
					Root = {
						rot = Vector3.new(2.17, -2.11, -2.22),
						pos = Vector3.new(0.05, -0.1, 0.04),
					},
					Neck = { rot = Vector3.new(-2.28, 2.05, 2.29) },
					RightShoulder = { rot = Vector3.new(-2.69, 0, 15.53) },
					LeftShoulder = { rot = Vector3.new(7.17, 0, -15.84) },
					RightHip = { rot = Vector3.new(9.92, 0, -0.27), pos = Vector3.new(0, 0.19, 0) },
					LeftHip = { rot = Vector3.new(-32.45, 0, 5.17), pos = Vector3.new(0, 0.04, 0) },
				},
			},
			{
				time = 0.2188,
				pose = {
					Root = {
						rot = Vector3.new(2.18, -2.47, -1.96),
						pos = Vector3.new(0.03, -0.13, 0.05),
					},
					Neck = { rot = Vector3.new(-2.28, 2.44, 2.01) },
					RightShoulder = { rot = Vector3.new(-5.88, 0, 15.92) },
					LeftShoulder = { rot = Vector3.new(10.27, 0, -15.01) },
					RightHip = { rot = Vector3.new(13.45, 0, -0.37), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(-31.9, 0, 5.28), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(2.21, -2.74, -1.59),
						pos = Vector3.new(0.02, -0.15, 0.05),
					},
					Neck = { rot = Vector3.new(-2.28, 2.74, 1.62) },
					RightShoulder = { rot = Vector3.new(-8.98, 0, 16.2) },
					LeftShoulder = { rot = Vector3.new(12.99, 0, -14.09) },
					RightHip = { rot = Vector3.new(16.77, 0, -0.61), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(-30.78, 0, 5.13), pos = Vector3.new(0, 0.11, 0) },
				},
			},
			{
				time = 0.2812,
				pose = {
					Root = {
						rot = Vector3.new(2.24, -2.89, -1.07),
						pos = Vector3.new(0, -0.16, 0.06),
					},
					Neck = { rot = Vector3.new(-2.28, 2.92, 1.09) },
					RightShoulder = { rot = Vector3.new(-11.82, 0, 16.3) },
					LeftShoulder = { rot = Vector3.new(15.25, 0, -13.17) },
					RightHip = { rot = Vector3.new(19.75, 0, -0.91), pos = Vector3.new(0, 0.21, 0) },
					LeftHip = { rot = Vector3.new(-29.1, 0, 4.69), pos = Vector3.new(0, 0.14, 0) },
				},
			},
			{
				time = 0.3125,
				pose = {
					Root = {
						rot = Vector3.new(2.29, -2.93, -0.45),
						pos = Vector3.new(-0.02, -0.17, 0.06),
					},
					Neck = { rot = Vector3.new(-2.28, 3, 0.45) },
					RightShoulder = { rot = Vector3.new(-14.19, 0, 16.23) },
					LeftShoulder = { rot = Vector3.new(17, 0, -12.32) },
					RightHip = { rot = Vector3.new(22.69, 0, -1.35), pos = Vector3.new(0, 0.19, 0) },
					LeftHip = { rot = Vector3.new(-26.93, 0, 4.02), pos = Vector3.new(0, 0.17, 0) },
				},
			},
			{
				time = 0.3438,
				pose = {
					Root = {
						rot = Vector3.new(2.33, -2.85, 0.19),
						pos = Vector3.new(-0.03, -0.16, 0.06),
					},
					Neck = { rot = Vector3.new(-2.28, 2.96, -0.21) },
					RightShoulder = { rot = Vector3.new(-15.92, 0, 16.05) },
					LeftShoulder = { rot = Vector3.new(18.17, 0, -11.62) },
					RightHip = { rot = Vector3.new(24.69, 0, -1.84), pos = Vector3.new(0, 0.16, 0) },
					LeftHip = { rot = Vector3.new(-24.3, 0, 3.38), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = {
						rot = Vector3.new(2.36, -2.68, 0.76),
						pos = Vector3.new(-0.05, -0.16, 0.06),
					},
					Neck = { rot = Vector3.new(-2.28, 2.81, -0.8) },
					RightShoulder = { rot = Vector3.new(-16.81, 0, 15.77) },
					LeftShoulder = { rot = Vector3.new(18.74, 0, -11.09) },
					RightHip = { rot = Vector3.new(23.85, 0, -2.09), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(-21.42, 0, 2.9), pos = Vector3.new(0, 0.21, 0) },
				},
			},
			{
				time = 0.4062,
				pose = {
					Root = {
						rot = Vector3.new(2.38, -2.41, 1.25),
						pos = Vector3.new(-0.06, -0.15, 0.05),
					},
					Neck = { rot = Vector3.new(-2.28, 2.56, -1.31) },
					RightShoulder = { rot = Vector3.new(-16.79, 0, 15.57) },
					LeftShoulder = { rot = Vector3.new(18.62, 0, -10.89) },
					RightHip = { rot = Vector3.new(20.24, 0, -2.14), pos = Vector3.new(0, 0.16, 0) },
					LeftHip = { rot = Vector3.new(-18.53, 0, 2.41), pos = Vector3.new(0, 0.21, 0) },
				},
			},
			{
				time = 0.4375,
				pose = {
					Root = {
						rot = Vector3.new(2.38, -2.05, 1.65),
						pos = Vector3.new(-0.07, -0.13, 0.05),
					},
					Neck = { rot = Vector3.new(-2.28, 2.22, -1.73) },
					RightShoulder = { rot = Vector3.new(-15.97, 0, 15.62) },
					LeftShoulder = { rot = Vector3.new(17.82, 0, -11.08) },
					RightHip = { rot = Vector3.new(14.78, 0, -2.3), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(-15.57, 0, 1.98), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.4688,
				pose = {
					Root = {
						rot = Vector3.new(2.36, -1.62, 1.97),
						pos = Vector3.new(-0.08, -0.1, 0.04),
					},
					Neck = { rot = Vector3.new(-2.28, 1.79, -2.07) },
					RightShoulder = { rot = Vector3.new(-14.45, 0, 15.88) },
					LeftShoulder = { rot = Vector3.new(16.42, 0, -11.56) },
					RightHip = { rot = Vector3.new(7.86, 0, -2.8), pos = Vector3.new(0, 0.14, 0) },
					LeftHip = { rot = Vector3.new(-12.58, 0, 1.6), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(2.33, -1.11, 2.21),
						pos = Vector3.new(-0.08, -0.08, 0.03),
					},
					Neck = { rot = Vector3.new(-2.28, 1.29, -2.31) },
					RightShoulder = { rot = Vector3.new(-12.31, 0, 16.23) },
					LeftShoulder = { rot = Vector3.new(14.51, 0, -12.23) },
					RightHip = { rot = Vector3.new(-0.31, 0, -2.86), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(-9.56, 0, 1.26), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.5312,
				pose = {
					Root = {
						rot = Vector3.new(2.3, -0.57, 2.37),
						pos = Vector3.new(-0.08, -0.05, 0.03),
					},
					Neck = { rot = Vector3.new(-2.28, 0.74, -2.48) },
					RightShoulder = { rot = Vector3.new(-9.65, 0, 16.59) },
					LeftShoulder = { rot = Vector3.new(12.16, 0, -12.98) },
					RightHip = { rot = Vector3.new(-8.31, 0, -3.11), pos = Vector3.new(0, 0.23, 0) },
					LeftHip = { rot = Vector3.new(-6.47, 0, 1.01), pos = Vector3.new(0, 0.12, 0) },
				},
			},
			{
				time = 0.5625,
				pose = {
					Root = {
						rot = Vector3.new(2.26, 0.01, 2.46),
						pos = Vector3.new(-0.08, -0.04, 0.03),
					},
					Neck = { rot = Vector3.new(-2.28, 0.15, -2.57) },
					RightShoulder = { rot = Vector3.new(-6.57, 0, 16.84) },
					LeftShoulder = { rot = Vector3.new(9.47, 0, -13.7) },
					RightHip = { rot = Vector3.new(-15.99, 0, -3.5), pos = Vector3.new(0, 0.21, 0) },
					LeftHip = { rot = Vector3.new(-3.4, 0, 0.87), pos = Vector3.new(0, 0.09, 0) },
				},
			},
			{
				time = 0.5938,
				pose = {
					Root = {
						rot = Vector3.new(2.22, 0.59, 2.5),
						pos = Vector3.new(-0.07, -0.04, 0.02),
					},
					Neck = { rot = Vector3.new(-2.28, -0.45, -2.6) },
					RightShoulder = { rot = Vector3.new(-3.2, 0, 16.9) },
					LeftShoulder = { rot = Vector3.new(6.54, 0, -14.34) },
					RightHip = {
						rot = Vector3.new(-22.78, 0, -3.99),
						pos = Vector3.new(0, 0.15, 0),
					},
					LeftHip = { rot = Vector3.new(-0.45, 0, 0.68), pos = Vector3.new(0, 0.09, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = {
						rot = Vector3.new(2.18, 1.14, 2.47),
						pos = Vector3.new(-0.07, -0.05, 0.03),
					},
					Neck = { rot = Vector3.new(-2.27, -1.02, -2.56) },
					RightShoulder = { rot = Vector3.new(0.31, 0, 16.73) },
					LeftShoulder = { rot = Vector3.new(3.5, 0, -14.86) },
					RightHip = {
						rot = Vector3.new(-27.78, 0, -4.42),
						pos = Vector3.new(0, 0.09, 0),
					},
					LeftHip = { rot = Vector3.new(2.98, 0, 0.43), pos = Vector3.new(0, 0.12, 0) },
				},
			},
			{
				time = 0.6562,
				pose = {
					Root = {
						rot = Vector3.new(2.15, 1.66, 2.38),
						pos = Vector3.new(-0.06, -0.07, 0.03),
					},
					Neck = { rot = Vector3.new(-2.27, -1.56, -2.46) },
					RightShoulder = { rot = Vector3.new(3.83, 0, 16.3) },
					LeftShoulder = { rot = Vector3.new(0.44, 0, -15.28) },
					RightHip = { rot = Vector3.new(-31.29, 0, -4.8), pos = Vector3.new(0, 0.03, 0) },
					LeftHip = { rot = Vector3.new(6.4, 0, 0.32), pos = Vector3.new(0, 0.16, 0) },
				},
			},
			{
				time = 0.6875,
				pose = {
					Root = {
						rot = Vector3.new(2.13, 2.11, 2.21),
						pos = Vector3.new(-0.05, -0.1, 0.04),
					},
					Neck = { rot = Vector3.new(-2.27, -2.04, -2.28) },
					RightShoulder = { rot = Vector3.new(7.19, 0, 15.64) },
					LeftShoulder = { rot = Vector3.new(-2.7, 0, -15.7) },
					RightHip = {
						rot = Vector3.new(-32.44, 0, -5.07),
						pos = Vector3.new(0, 0.04, 0),
					},
					LeftHip = { rot = Vector3.new(9.95, 0, 0.31), pos = Vector3.new(0, 0.19, 0) },
				},
			},
			{
				time = 0.7188,
				pose = {
					Root = {
						rot = Vector3.new(2.12, 2.47, 1.95),
						pos = Vector3.new(-0.03, -0.13, 0.04),
					},
					Neck = { rot = Vector3.new(-2.26, -2.43, -2) },
					RightShoulder = { rot = Vector3.new(10.28, 0, 14.81) },
					LeftShoulder = { rot = Vector3.new(-5.89, 0, -16.09) },
					RightHip = {
						rot = Vector3.new(-31.88, 0, -5.15),
						pos = Vector3.new(0, 0.08, 0),
					},
					LeftHip = { rot = Vector3.new(13.51, 0, 0.41), pos = Vector3.new(0, 0.22, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(2.12, 2.74, 1.58),
						pos = Vector3.new(-0.02, -0.15, 0.05),
					},
					Neck = { rot = Vector3.new(-2.25, -2.73, -1.61) },
					RightShoulder = { rot = Vector3.new(13, 0, 13.88) },
					LeftShoulder = { rot = Vector3.new(-8.99, 0, -16.36) },
					RightHip = {
						rot = Vector3.new(-30.73, 0, -4.98),
						pos = Vector3.new(0, 0.11, 0),
					},
					LeftHip = { rot = Vector3.new(16.84, 0, 0.62), pos = Vector3.new(0, 0.22, 0) },
				},
			},
			{
				time = 0.7812,
				pose = {
					Root = {
						rot = Vector3.new(2.13, 2.89, 1.08),
						pos = Vector3.new(0, -0.16, 0.05),
					},
					Neck = { rot = Vector3.new(-2.25, -2.92, -1.08) },
					RightShoulder = { rot = Vector3.new(15.27, 0, 12.96) },
					LeftShoulder = { rot = Vector3.new(-11.82, 0, -16.46) },
					RightHip = {
						rot = Vector3.new(-29.02, 0, -4.53),
						pos = Vector3.new(0, 0.14, 0),
					},
					LeftHip = { rot = Vector3.new(19.85, 0, 0.94), pos = Vector3.new(0, 0.21, 0) },
				},
			},
			{
				time = 0.8125,
				pose = {
					Root = {
						rot = Vector3.new(2.16, 2.92, 0.46),
						pos = Vector3.new(0.02, -0.17, 0.06),
					},
					Neck = { rot = Vector3.new(-2.24, -3, -0.44) },
					RightShoulder = { rot = Vector3.new(17.01, 0, 12.12) },
					LeftShoulder = { rot = Vector3.new(-14.2, 0, -16.39) },
					RightHip = {
						rot = Vector3.new(-26.83, 0, -3.88),
						pos = Vector3.new(0, 0.17, 0),
					},
					LeftHip = { rot = Vector3.new(22.82, 0, 1.42), pos = Vector3.new(0, 0.19, 0) },
				},
			},
			{
				time = 0.8438,
				pose = {
					Root = {
						rot = Vector3.new(2.19, 2.85, -0.18),
						pos = Vector3.new(0.03, -0.16, 0.06),
					},
					Neck = { rot = Vector3.new(-2.23, -2.96, 0.22) },
					RightShoulder = { rot = Vector3.new(18.19, 0, 11.41) },
					LeftShoulder = { rot = Vector3.new(-15.93, 0, -16.2) },
					RightHip = { rot = Vector3.new(-24.2, 0, -3.26), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(24.82, 0, 1.89), pos = Vector3.new(0, 0.16, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = {
						rot = Vector3.new(2.21, 2.68, -0.74),
						pos = Vector3.new(0.05, -0.16, 0.05),
					},
					Neck = { rot = Vector3.new(-2.23, -2.82, 0.81) },
					RightShoulder = { rot = Vector3.new(18.75, 0, 10.88) },
					LeftShoulder = { rot = Vector3.new(-16.82, 0, -15.92) },
					RightHip = {
						rot = Vector3.new(-21.31, 0, -2.78),
						pos = Vector3.new(0, 0.21, 0),
					},
					LeftHip = { rot = Vector3.new(23.98, 0, 2.1), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.9062,
				pose = {
					Root = {
						rot = Vector3.new(2.23, 2.41, -1.23),
						pos = Vector3.new(0.06, -0.15, 0.05),
					},
					Neck = { rot = Vector3.new(-2.23, -2.57, 1.32) },
					RightShoulder = { rot = Vector3.new(18.64, 0, 10.68) },
					LeftShoulder = { rot = Vector3.new(-16.8, 0, -15.72) },
					RightHip = {
						rot = Vector3.new(-18.43, 0, -2.31),
						pos = Vector3.new(0, 0.21, 0),
					},
					LeftHip = { rot = Vector3.new(20.39, 0, 2.19), pos = Vector3.new(0, 0.16, 0) },
				},
			},
			{
				time = 0.9375,
				pose = {
					Root = {
						rot = Vector3.new(2.24, 2.06, -1.63),
						pos = Vector3.new(0.07, -0.13, 0.04),
					},
					Neck = { rot = Vector3.new(-2.23, -2.22, 1.74) },
					RightShoulder = { rot = Vector3.new(17.83, 0, 10.87) },
					LeftShoulder = { rot = Vector3.new(-15.98, 0, -15.78) },
					RightHip = {
						rot = Vector3.new(-15.47, 0, -1.89),
						pos = Vector3.new(0, 0.21, 0),
					},
					LeftHip = { rot = Vector3.new(14.94, 0, 2.42), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.9688,
				pose = {
					Root = {
						rot = Vector3.new(2.24, 1.62, -1.96),
						pos = Vector3.new(0.08, -0.11, 0.04),
					},
					Neck = { rot = Vector3.new(-2.24, -1.79, 2.07) },
					RightShoulder = { rot = Vector3.new(16.43, 0, 11.36) },
					LeftShoulder = { rot = Vector3.new(-14.47, 0, -16.04) },
					RightHip = {
						rot = Vector3.new(-12.48, 0, -1.53),
						pos = Vector3.new(0, 0.18, 0),
					},
					LeftHip = { rot = Vector3.new(8.03, 0, 2.98), pos = Vector3.new(0, 0.14, 0) },
				},
			},
		},
	},
	-- ALS_N_Walk_LF: phase clip (one cycle = 1), left foot plants at 0.4375; natural cycle 1.133 s, stride 3.59 studs per cycle
	WalkLeft = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-4.83, 34.23, 3.21),
						pos = Vector3.new(-0.04, -0.18, -0.06),
					},
					Neck = { rot = Vector3.new(3.59, -34.35, -0.78) },
					RightShoulder = { rot = Vector3.new(-1.78, 0, 18.13) },
					LeftShoulder = { rot = Vector3.new(15.96, 0, -20.07) },
					RightHip = { rot = Vector3.new(9.57, 0, -15.11), pos = Vector3.new(0, 0.13, 0) },
					LeftHip = { rot = Vector3.new(-10.15, 0, 19.72), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 0.0312,
				pose = {
					Root = {
						rot = Vector3.new(-4.94, 34.39, 2.98),
						pos = Vector3.new(-0.04, -0.17, -0.07),
					},
					Neck = { rot = Vector3.new(3.88, -34.51, -0.39) },
					RightShoulder = { rot = Vector3.new(1.02, 0, 18.56) },
					LeftShoulder = { rot = Vector3.new(14.11, 0, -21.48) },
					RightHip = { rot = Vector3.new(7.76, 0, -12.43), pos = Vector3.new(0, 0.14, 0) },
					LeftHip = { rot = Vector3.new(-9.88, 0, 20.13), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.0625,
				pose = {
					Root = {
						rot = Vector3.new(-5.01, 34.64, 2.83),
						pos = Vector3.new(-0.04, -0.15, -0.07),
					},
					Neck = { rot = Vector3.new(4.08, -34.75, -0.12) },
					RightShoulder = { rot = Vector3.new(4.02, 0, 18.83) },
					LeftShoulder = { rot = Vector3.new(12.01, 0, -22.8) },
					RightHip = { rot = Vector3.new(6.01, 0, -9.83), pos = Vector3.new(0, 0.13, 0) },
					LeftHip = { rot = Vector3.new(-9.08, 0, 18.93), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.0938,
				pose = {
					Root = {
						rot = Vector3.new(-5.06, 34.97, 2.75),
						pos = Vector3.new(-0.04, -0.12, -0.08),
					},
					Neck = { rot = Vector3.new(4.2, -35.09, 0.07) },
					RightShoulder = { rot = Vector3.new(7.16, 0, 18.91) },
					LeftShoulder = { rot = Vector3.new(9.74, 0, -23.97) },
					RightHip = { rot = Vector3.new(4.29, 0, -7.32), pos = Vector3.new(0, 0.11, 0) },
					LeftHip = { rot = Vector3.new(-7.39, 0, 15.97), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = {
						rot = Vector3.new(-5.09, 35.38, 2.73),
						pos = Vector3.new(-0.04, -0.1, -0.08),
					},
					Neck = { rot = Vector3.new(4.27, -35.5, 0.18) },
					RightShoulder = { rot = Vector3.new(10.3, 0, 18.78) },
					LeftShoulder = { rot = Vector3.new(7.38, 0, -24.97) },
					RightHip = { rot = Vector3.new(3.15, 0, -4.74), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(-5.02, 0, 11.81), pos = Vector3.new(0, 0.22, 0) },
				},
			},
			{
				time = 0.1562,
				pose = {
					Root = {
						rot = Vector3.new(-5.11, 35.84, 2.76),
						pos = Vector3.new(-0.04, -0.08, -0.08),
					},
					Neck = { rot = Vector3.new(4.28, -35.97, 0.22) },
					RightShoulder = { rot = Vector3.new(13.32, 0, 18.46) },
					LeftShoulder = { rot = Vector3.new(5.03, 0, -25.77) },
					RightHip = { rot = Vector3.new(1.12, 0, -2.21), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(-1.49, 0, 6.66), pos = Vector3.new(0, 0.27, 0) },
				},
			},
			{
				time = 0.1875,
				pose = {
					Root = {
						rot = Vector3.new(-5.1, 36.34, 2.84),
						pos = Vector3.new(-0.05, -0.07, -0.08),
					},
					Neck = { rot = Vector3.new(4.24, -36.49, 0.19) },
					RightShoulder = { rot = Vector3.new(16.12, 0, 17.97) },
					LeftShoulder = { rot = Vector3.new(2.78, 0, -26.39) },
					RightHip = { rot = Vector3.new(-0.89, 0, 0.19), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(2.4, 0, 1.27), pos = Vector3.new(0, 0.28, 0) },
				},
			},
			{
				time = 0.2188,
				pose = {
					Root = {
						rot = Vector3.new(-5.09, 36.87, 2.96),
						pos = Vector3.new(-0.05, -0.06, -0.08),
					},
					Neck = { rot = Vector3.new(4.14, -37.03, 0.09) },
					RightShoulder = { rot = Vector3.new(18.59, 0, 17.42) },
					LeftShoulder = { rot = Vector3.new(0.74, 0, -26.86) },
					RightHip = { rot = Vector3.new(-2.73, 0, 1.78), pos = Vector3.new(0, 0.13, 0) },
					LeftHip = { rot = Vector3.new(6.73, 0, -4.15), pos = Vector3.new(0, 0.26, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(-5.06, 37.41, 3.15),
						pos = Vector3.new(-0.06, -0.07, -0.07),
					},
					Neck = { rot = Vector3.new(3.98, -37.58, -0.1) },
					RightShoulder = { rot = Vector3.new(20.66, 0, 16.88) },
					LeftShoulder = { rot = Vector3.new(-1, 0, -27.24) },
					RightHip = { rot = Vector3.new(-4.57, 0, 3.86), pos = Vector3.new(0, 0.17, 0) },
					LeftHip = { rot = Vector3.new(11.2, 0, -9.15), pos = Vector3.new(0, 0.24, 0) },
				},
			},
			{
				time = 0.2812,
				pose = {
					Root = {
						rot = Vector3.new(-5.02, 37.93, 3.38),
						pos = Vector3.new(-0.07, -0.08, -0.07),
					},
					Neck = { rot = Vector3.new(3.76, -38.12, -0.37) },
					RightShoulder = { rot = Vector3.new(22.27, 0, 16.49) },
					LeftShoulder = { rot = Vector3.new(-2.35, 0, -27.55) },
					RightHip = { rot = Vector3.new(-6.42, 0, 5.89), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(14.81, 0, -13.03), pos = Vector3.new(0, 0.31, 0) },
				},
			},
			{
				time = 0.3125,
				pose = {
					Root = {
						rot = Vector3.new(-4.97, 38.42, 3.67),
						pos = Vector3.new(-0.07, -0.11, -0.06),
					},
					Neck = { rot = Vector3.new(3.47, -38.63, -0.73) },
					RightShoulder = { rot = Vector3.new(23.33, 0, 16.34) },
					LeftShoulder = { rot = Vector3.new(-3.22, 0, -27.86) },
					RightHip = { rot = Vector3.new(-8.24, 0, 7.93), pos = Vector3.new(0, 0.27, 0) },
					LeftHip = { rot = Vector3.new(17.76, 0, -16.1), pos = Vector3.new(0, 0.36, 0) },
				},
			},
			{
				time = 0.3438,
				pose = {
					Root = {
						rot = Vector3.new(-4.91, 38.86, 4.01),
						pos = Vector3.new(-0.08, -0.14, -0.05),
					},
					Neck = { rot = Vector3.new(3.12, -39.08, -1.18) },
					RightShoulder = { rot = Vector3.new(23.75, 0, 16.53) },
					LeftShoulder = { rot = Vector3.new(-3.54, 0, -28.17) },
					RightHip = { rot = Vector3.new(-9.94, 0, 10.04), pos = Vector3.new(0, 0.32, 0) },
					LeftHip = { rot = Vector3.new(19.92, 0, -18.24), pos = Vector3.new(0, 0.4, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = {
						rot = Vector3.new(-4.85, 39.23, 4.39),
						pos = Vector3.new(-0.09, -0.16, -0.04),
					},
					Neck = { rot = Vector3.new(2.73, -39.46, -1.69) },
					RightShoulder = { rot = Vector3.new(23.51, 0, 17) },
					LeftShoulder = { rot = Vector3.new(-3.35, 0, -28.35) },
					RightHip = {
						rot = Vector3.new(-11.57, 0, 12.14),
						pos = Vector3.new(0, 0.36, 0),
					},
					LeftHip = { rot = Vector3.new(21.03, 0, -19.06), pos = Vector3.new(0, 0.43, 0) },
				},
			},
			{
				time = 0.4062,
				pose = {
					Root = {
						rot = Vector3.new(-4.78, 39.53, 4.81),
						pos = Vector3.new(-0.1, -0.18, -0.03),
					},
					Neck = { rot = Vector3.new(2.28, -39.77, -2.27) },
					RightShoulder = { rot = Vector3.new(22.63, 0, 17.62) },
					LeftShoulder = { rot = Vector3.new(-2.74, 0, -28.29) },
					RightHip = {
						rot = Vector3.new(-12.97, 0, 13.98),
						pos = Vector3.new(0, 0.39, 0),
					},
					LeftHip = { rot = Vector3.new(20.58, 0, -18.21), pos = Vector3.new(0, 0.45, 0) },
				},
			},
			{
				time = 0.4375,
				pose = {
					Root = {
						rot = Vector3.new(-4.71, 39.74, 5.24),
						pos = Vector3.new(-0.1, -0.19, -0.02),
					},
					Neck = { rot = Vector3.new(1.8, -39.98, -2.91) },
					RightShoulder = { rot = Vector3.new(21.17, 0, 18.3) },
					LeftShoulder = { rot = Vector3.new(-1.76, 0, -28) },
					RightHip = { rot = Vector3.new(-13.98, 0, 15.44), pos = Vector3.new(0, 0.4, 0) },
					LeftHip = { rot = Vector3.new(19.27, 0, -16.57), pos = Vector3.new(0, 0.45, 0) },
				},
			},
			{
				time = 0.4688,
				pose = {
					Root = {
						rot = Vector3.new(-4.6, 39.89, 5.77),
						pos = Vector3.new(-0.11, -0.19, -0.01),
					},
					Neck = { rot = Vector3.new(1.2, -40.12, -3.69) },
					RightShoulder = { rot = Vector3.new(18.87, 0, 19.03) },
					LeftShoulder = { rot = Vector3.new(-0.24, 0, -27.46) },
					RightHip = { rot = Vector3.new(-14.72, 0, 16.87), pos = Vector3.new(0, 0.4, 0) },
					LeftHip = { rot = Vector3.new(17.72, 0, -14.87), pos = Vector3.new(0, 0.45, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-4.48, 39.91, 6.25),
						pos = Vector3.new(-0.12, -0.19, 0),
					},
					Neck = { rot = Vector3.new(0.61, -40.12, -4.45) },
					RightShoulder = { rot = Vector3.new(16.01, 0, 19.6) },
					LeftShoulder = { rot = Vector3.new(1.63, 0, -26.69) },
					RightHip = {
						rot = Vector3.new(-15.02, 0, 18.33),
						pos = Vector3.new(0, 0.39, 0),
					},
					LeftHip = { rot = Vector3.new(16.05, 0, -13.01), pos = Vector3.new(0, 0.43, 0) },
				},
			},
			{
				time = 0.5312,
				pose = {
					Root = {
						rot = Vector3.new(-4.38, 39.81, 6.62),
						pos = Vector3.new(-0.13, -0.18, 0.01),
					},
					Neck = { rot = Vector3.new(0.16, -40.01, -5.04) },
					RightShoulder = { rot = Vector3.new(12.71, 0, 19.96) },
					LeftShoulder = { rot = Vector3.new(3.79, 0, -25.65) },
					RightHip = {
						rot = Vector3.new(-14.98, 0, 19.81),
						pos = Vector3.new(0, 0.38, 0),
					},
					LeftHip = { rot = Vector3.new(14.18, 0, -10.99), pos = Vector3.new(0, 0.4, 0) },
				},
			},
			{
				time = 0.5625,
				pose = {
					Root = {
						rot = Vector3.new(-4.28, 39.6, 6.84),
						pos = Vector3.new(-0.13, -0.16, 0.02),
					},
					Neck = { rot = Vector3.new(-0.14, -39.77, -5.43) },
					RightShoulder = { rot = Vector3.new(9.15, 0, 20.04) },
					LeftShoulder = { rot = Vector3.new(6.17, 0, -24.36) },
					RightHip = {
						rot = Vector3.new(-14.16, 0, 19.84),
						pos = Vector3.new(0, 0.36, 0),
					},
					LeftHip = { rot = Vector3.new(12.24, 0, -8.93), pos = Vector3.new(0, 0.35, 0) },
				},
			},
			{
				time = 0.5938,
				pose = {
					Root = {
						rot = Vector3.new(-4.2, 39.28, 6.95),
						pos = Vector3.new(-0.13, -0.14, 0.03),
					},
					Neck = { rot = Vector3.new(-0.31, -39.43, -5.67) },
					RightShoulder = { rot = Vector3.new(5.49, 0, 19.78) },
					LeftShoulder = { rot = Vector3.new(8.67, 0, -22.88) },
					RightHip = { rot = Vector3.new(-12, 0, 17.33), pos = Vector3.new(0, 0.34, 0) },
					LeftHip = { rot = Vector3.new(10.32, 0, -6.82), pos = Vector3.new(0, 0.29, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = {
						rot = Vector3.new(-4.11, 38.85, 6.97),
						pos = Vector3.new(-0.13, -0.11, 0.03),
					},
					Neck = { rot = Vector3.new(-0.39, -38.99, -5.78) },
					RightShoulder = { rot = Vector3.new(1.91, 0, 19.19) },
					LeftShoulder = { rot = Vector3.new(11.14, 0, -21.25) },
					RightHip = { rot = Vector3.new(-8.89, 0, 13.04), pos = Vector3.new(0, 0.29, 0) },
					LeftHip = { rot = Vector3.new(8.37, 0, -4.82), pos = Vector3.new(0, 0.22, 0) },
				},
			},
			{
				time = 0.6562,
				pose = {
					Root = {
						rot = Vector3.new(-4.03, 38.35, 6.92),
						pos = Vector3.new(-0.12, -0.09, 0.03),
					},
					Neck = { rot = Vector3.new(-0.39, -38.47, -5.79) },
					RightShoulder = { rot = Vector3.new(-1.43, 0, 18.33) },
					LeftShoulder = { rot = Vector3.new(13.44, 0, -19.54) },
					RightHip = { rot = Vector3.new(-4.23, 0, 7.06), pos = Vector3.new(0, 0.26, 0) },
					LeftHip = { rot = Vector3.new(6.19, 0, -2.98), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 0.6875,
				pose = {
					Root = {
						rot = Vector3.new(-3.97, 37.78, 6.79),
						pos = Vector3.new(-0.12, -0.07, 0.03),
					},
					Neck = { rot = Vector3.new(-0.31, -37.9, -5.71) },
					RightShoulder = { rot = Vector3.new(-4.41, 0, 17.32) },
					LeftShoulder = { rot = Vector3.new(15.49, 0, -17.83) },
					RightHip = { rot = Vector3.new(0.85, 0, 0), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(3.9, 0, -0.71), pos = Vector3.new(0, 0.14, 0) },
				},
			},
			{
				time = 0.7188,
				pose = {
					Root = {
						rot = Vector3.new(-3.92, 37.18, 6.61),
						pos = Vector3.new(-0.11, -0.06, 0.03),
					},
					Neck = { rot = Vector3.new(-0.15, -37.3, -5.52) },
					RightShoulder = { rot = Vector3.new(-6.9, 0, 16.31) },
					LeftShoulder = { rot = Vector3.new(17.23, 0, -16.24) },
					RightHip = { rot = Vector3.new(6.05, 0, -7.59), pos = Vector3.new(0, 0.09, 0) },
					LeftHip = { rot = Vector3.new(2.13, 0, 1.5), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(-3.9, 36.58, 6.36),
						pos = Vector3.new(-0.11, -0.07, 0.03),
					},
					Neck = { rot = Vector3.new(0.08, -36.69, -5.24) },
					RightShoulder = { rot = Vector3.new(-8.85, 0, 15.44) },
					LeftShoulder = { rot = Vector3.new(18.63, 0, -14.93) },
					RightHip = { rot = Vector3.new(10.9, 0, -14.72) },
					LeftHip = { rot = Vector3.new(0.01, 0, 3.51), pos = Vector3.new(0, 0.14, 0) },
				},
			},
			{
				time = 0.7812,
				pose = {
					Root = {
						rot = Vector3.new(-3.91, 35.99, 6.06),
						pos = Vector3.new(-0.1, -0.09, 0.02),
					},
					Neck = { rot = Vector3.new(0.38, -36.11, -4.87) },
					RightShoulder = { rot = Vector3.new(-10.19, 0, 14.87) },
					LeftShoulder = { rot = Vector3.new(19.69, 0, -14.02) },
					RightHip = { rot = Vector3.new(14.1, 0, -20.11) },
					LeftHip = { rot = Vector3.new(-1.96, 0, 5.51), pos = Vector3.new(0, 0.16, 0) },
				},
			},
			{
				time = 0.8125,
				pose = {
					Root = {
						rot = Vector3.new(-3.96, 35.45, 5.71),
						pos = Vector3.new(-0.09, -0.12, 0.01),
					},
					Neck = { rot = Vector3.new(0.76, -35.58, -4.41) },
					RightShoulder = { rot = Vector3.new(-10.87, 0, 14.75) },
					LeftShoulder = { rot = Vector3.new(20.34, 0, -13.68) },
					RightHip = { rot = Vector3.new(16.06, 0, -23.65) },
					LeftHip = { rot = Vector3.new(-4.21, 0, 8.03), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 0.8438,
				pose = {
					Root = {
						rot = Vector3.new(-4.05, 34.99, 5.31),
						pos = Vector3.new(-0.08, -0.16, 0),
					},
					Neck = { rot = Vector3.new(1.18, -35.12, -3.88) },
					RightShoulder = { rot = Vector3.new(-10.83, 0, 15.05) },
					LeftShoulder = { rot = Vector3.new(20.55, 0, -13.98) },
					RightHip = { rot = Vector3.new(16.87, 0, -26.22) },
					LeftHip = { rot = Vector3.new(-6.4, 0, 10.69), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = {
						rot = Vector3.new(-4.17, 34.62, 4.89),
						pos = Vector3.new(-0.07, -0.18, -0.01),
					},
					Neck = { rot = Vector3.new(1.65, -34.75, -3.29) },
					RightShoulder = { rot = Vector3.new(-10.04, 0, 15.56) },
					LeftShoulder = { rot = Vector3.new(20.36, 0, -14.77) },
					RightHip = { rot = Vector3.new(15.9, 0, -25.54), pos = Vector3.new(0, 0.02, 0) },
					LeftHip = { rot = Vector3.new(-8.06, 0, 13.12), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.9062,
				pose = {
					Root = {
						rot = Vector3.new(-4.33, 34.35, 4.44),
						pos = Vector3.new(-0.06, -0.19, -0.03),
					},
					Neck = { rot = Vector3.new(2.16, -34.49, -2.64) },
					RightShoulder = { rot = Vector3.new(-8.59, 0, 16.19) },
					LeftShoulder = { rot = Vector3.new(19.77, 0, -15.92) },
					RightHip = {
						rot = Vector3.new(14.05, 0, -22.51),
						pos = Vector3.new(0, 0.07, 0),
					},
					LeftHip = { rot = Vector3.new(-9.26, 0, 15.47), pos = Vector3.new(0, 0.19, 0) },
				},
			},
			{
				time = 0.9375,
				pose = {
					Root = {
						rot = Vector3.new(-4.51, 34.2, 3.96),
						pos = Vector3.new(-0.05, -0.19, -0.04),
					},
					Neck = { rot = Vector3.new(2.71, -34.33, -1.93) },
					RightShoulder = { rot = Vector3.new(-6.54, 0, 16.91) },
					LeftShoulder = { rot = Vector3.new(18.77, 0, -17.31) },
					RightHip = { rot = Vector3.new(12.6, 0, -19.93), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(-9.99, 0, 17.37), pos = Vector3.new(0, 0.17, 0) },
				},
			},
			{
				time = 0.9688,
				pose = {
					Root = {
						rot = Vector3.new(-4.68, 34.17, 3.55),
						pos = Vector3.new(-0.05, -0.19, -0.05),
					},
					Neck = { rot = Vector3.new(3.19, -34.29, -1.31) },
					RightShoulder = { rot = Vector3.new(-4.32, 0, 17.56) },
					LeftShoulder = { rot = Vector3.new(17.53, 0, -18.66) },
					RightHip = {
						rot = Vector3.new(11.23, 0, -17.65),
						pos = Vector3.new(0, 0.12, 0),
					},
					LeftHip = { rot = Vector3.new(-10.19, 0, 18.69), pos = Vector3.new(0, 0.15, 0) },
				},
			},
		},
	},
	-- ALS_N_Walk_RF: phase clip (one cycle = 1), left foot plants at 0.4375; natural cycle 1.133 s, stride 3.56 studs per cycle
	WalkRight = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-4.51, -39.91, -6.38),
						pos = Vector3.new(0.12, -0.19, 0),
					},
					Neck = { rot = Vector3.new(0.62, 40.14, 4.48) },
					RightShoulder = { rot = Vector3.new(1.64, 0, 26.55) },
					LeftShoulder = { rot = Vector3.new(16, 0, -19.78) },
					RightHip = { rot = Vector3.new(16, 0, 13.19), pos = Vector3.new(0, 0.43, 0) },
					LeftHip = {
						rot = Vector3.new(-14.98, 0, -18.15),
						pos = Vector3.new(0, 0.39, 0),
					},
				},
			},
			{
				time = 0.0312,
				pose = {
					Root = {
						rot = Vector3.new(-4.43, -39.81, -6.76),
						pos = Vector3.new(0.13, -0.18, 0.01),
					},
					Neck = { rot = Vector3.new(0.18, 40.03, 5.07) },
					RightShoulder = { rot = Vector3.new(3.8, 0, 25.5) },
					LeftShoulder = { rot = Vector3.new(12.7, 0, -20.13) },
					RightHip = { rot = Vector3.new(14.14, 0, 11.19), pos = Vector3.new(0, 0.4, 0) },
					LeftHip = {
						rot = Vector3.new(-14.93, 0, -19.68),
						pos = Vector3.new(0, 0.38, 0),
					},
				},
			},
			{
				time = 0.0625,
				pose = {
					Root = {
						rot = Vector3.new(-4.36, -39.6, -6.98),
						pos = Vector3.new(0.13, -0.16, 0.02),
					},
					Neck = { rot = Vector3.new(-0.11, 39.79, 5.46) },
					RightShoulder = { rot = Vector3.new(6.17, 0, 24.21) },
					LeftShoulder = { rot = Vector3.new(9.14, 0, -20.2) },
					RightHip = { rot = Vector3.new(12.21, 0, 9.13), pos = Vector3.new(0, 0.35, 0) },
					LeftHip = {
						rot = Vector3.new(-14.09, 0, -19.72),
						pos = Vector3.new(0, 0.36, 0),
					},
				},
			},
			{
				time = 0.0938,
				pose = {
					Root = {
						rot = Vector3.new(-4.29, -39.27, -7.1),
						pos = Vector3.new(0.13, -0.14, 0.03),
					},
					Neck = { rot = Vector3.new(-0.27, 39.45, 5.69) },
					RightShoulder = { rot = Vector3.new(8.67, 0, 22.73) },
					LeftShoulder = { rot = Vector3.new(5.49, 0, -19.94) },
					RightHip = { rot = Vector3.new(10.31, 0, 7.02), pos = Vector3.new(0, 0.29, 0) },
					LeftHip = { rot = Vector3.new(-11.9, 0, -17.18), pos = Vector3.new(0, 0.33, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = {
						rot = Vector3.new(-4.23, -38.85, -7.11),
						pos = Vector3.new(0.13, -0.11, 0.03),
					},
					Neck = { rot = Vector3.new(-0.35, 39.01, 5.8) },
					RightShoulder = { rot = Vector3.new(11.14, 0, 21.1) },
					LeftShoulder = { rot = Vector3.new(1.91, 0, -19.35) },
					RightHip = { rot = Vector3.new(8.4, 0, 4.9), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(-8.74, 0, -12.85), pos = Vector3.new(0, 0.29, 0) },
				},
			},
			{
				time = 0.1562,
				pose = {
					Root = {
						rot = Vector3.new(-4.16, -38.34, -7.06),
						pos = Vector3.new(0.13, -0.09, 0.03),
					},
					Neck = { rot = Vector3.new(-0.34, 38.49, 5.81) },
					RightShoulder = { rot = Vector3.new(13.44, 0, 19.38) },
					LeftShoulder = { rot = Vector3.new(-1.44, 0, -18.49) },
					RightHip = { rot = Vector3.new(6.25, 0, 3.08), pos = Vector3.new(0, 0.18, 0) },
					LeftHip = { rot = Vector3.new(-4.03, 0, -6.84), pos = Vector3.new(0, 0.26, 0) },
				},
			},
			{
				time = 0.1875,
				pose = {
					Root = {
						rot = Vector3.new(-4.11, -37.77, -6.93),
						pos = Vector3.new(0.12, -0.07, 0.03),
					},
					Neck = { rot = Vector3.new(-0.25, 37.91, 5.72) },
					RightShoulder = { rot = Vector3.new(15.49, 0, 17.67) },
					LeftShoulder = { rot = Vector3.new(-4.41, 0, -17.48) },
					RightHip = { rot = Vector3.new(3.99, 0, 0.79), pos = Vector3.new(0, 0.14, 0) },
					LeftHip = { rot = Vector3.new(1.08, 0, 0.22), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.2188,
				pose = {
					Root = {
						rot = Vector3.new(-4.07, -37.17, -6.74),
						pos = Vector3.new(0.12, -0.06, 0.03),
					},
					Neck = { rot = Vector3.new(-0.08, 37.31, 5.53) },
					RightShoulder = { rot = Vector3.new(17.23, 0, 16.08) },
					LeftShoulder = { rot = Vector3.new(-6.9, 0, -16.46) },
					RightHip = { rot = Vector3.new(2.22, 0, -1.45), pos = Vector3.new(0, 0.13, 0) },
					LeftHip = { rot = Vector3.new(6.29, 0, 7.79), pos = Vector3.new(0, 0.09, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(-4.06, -36.56, -6.49),
						pos = Vector3.new(0.11, -0.07, 0.02),
					},
					Neck = { rot = Vector3.new(0.15, 36.7, 5.25) },
					RightShoulder = { rot = Vector3.new(18.63, 0, 14.76) },
					LeftShoulder = { rot = Vector3.new(-8.85, 0, -15.59) },
					RightHip = { rot = Vector3.new(-0.03, 0, -3.63), pos = Vector3.new(0, 0.14, 0) },
					LeftHip = { rot = Vector3.new(11.11, 0, 14.83) },
				},
			},
			{
				time = 0.2812,
				pose = {
					Root = {
						rot = Vector3.new(-4.07, -35.98, -6.19),
						pos = Vector3.new(0.1, -0.09, 0.02),
					},
					Neck = { rot = Vector3.new(0.46, 36.11, 4.88) },
					RightShoulder = { rot = Vector3.new(19.69, 0, 13.85) },
					LeftShoulder = { rot = Vector3.new(-10.19, 0, -15.02) },
					RightHip = { rot = Vector3.new(-2.23, 0, -5.85), pos = Vector3.new(0, 0.16, 0) },
					LeftHip = { rot = Vector3.new(14.26, 0, 20.11) },
				},
			},
			{
				time = 0.3125,
				pose = {
					Root = {
						rot = Vector3.new(-4.12, -35.44, -5.84),
						pos = Vector3.new(0.09, -0.12, 0.01),
					},
					Neck = { rot = Vector3.new(0.83, 35.58, 4.42) },
					RightShoulder = { rot = Vector3.new(20.34, 0, 13.51) },
					LeftShoulder = { rot = Vector3.new(-10.87, 0, -14.9) },
					RightHip = { rot = Vector3.new(-4.35, 0, -8.12), pos = Vector3.new(0, 0.18, 0) },
					LeftHip = { rot = Vector3.new(16.22, 0, 23.68) },
				},
			},
			{
				time = 0.3438,
				pose = {
					Root = {
						rot = Vector3.new(-4.21, -34.98, -5.44),
						pos = Vector3.new(0.08, -0.16, 0),
					},
					Neck = { rot = Vector3.new(1.26, 35.13, 3.89) },
					RightShoulder = { rot = Vector3.new(20.55, 0, 13.81) },
					LeftShoulder = { rot = Vector3.new(-10.82, 0, -15.2) },
					RightHip = { rot = Vector3.new(-6.32, 0, -10.44), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(17.05, 0, 26.24) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = {
						rot = Vector3.new(-4.32, -34.61, -5.02),
						pos = Vector3.new(0.07, -0.18, -0.01),
					},
					Neck = { rot = Vector3.new(1.73, 34.76, 3.3) },
					RightShoulder = { rot = Vector3.new(20.36, 0, 14.6) },
					LeftShoulder = { rot = Vector3.new(-10.03, 0, -15.71) },
					RightHip = { rot = Vector3.new(-8.04, 0, -12.87), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(16.05, 0, 25.61), pos = Vector3.new(0, 0.02, 0) },
				},
			},
			{
				time = 0.4062,
				pose = {
					Root = {
						rot = Vector3.new(-4.47, -34.34, -4.57),
						pos = Vector3.new(0.07, -0.19, -0.03),
					},
					Neck = { rot = Vector3.new(2.23, 34.5, 2.66) },
					RightShoulder = { rot = Vector3.new(19.77, 0, 15.75) },
					LeftShoulder = { rot = Vector3.new(-8.58, 0, -16.34) },
					RightHip = {
						rot = Vector3.new(-9.25, 0, -15.17),
						pos = Vector3.new(0, 0.19, 0),
					},
					LeftHip = { rot = Vector3.new(14.17, 0, 22.58), pos = Vector3.new(0, 0.07, 0) },
				},
			},
			{
				time = 0.4375,
				pose = {
					Root = {
						rot = Vector3.new(-4.63, -34.2, -4.1),
						pos = Vector3.new(0.06, -0.19, -0.04),
					},
					Neck = { rot = Vector3.new(2.78, 34.35, 1.95) },
					RightShoulder = { rot = Vector3.new(18.77, 0, 17.14) },
					LeftShoulder = { rot = Vector3.new(-6.54, 0, -17.06) },
					RightHip = {
						rot = Vector3.new(-9.97, 0, -17.06),
						pos = Vector3.new(0, 0.17, 0),
					},
					LeftHip = { rot = Vector3.new(12.73, 0, 20.04), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.4688,
				pose = {
					Root = {
						rot = Vector3.new(-4.79, -34.17, -3.69),
						pos = Vector3.new(0.05, -0.19, -0.05),
					},
					Neck = { rot = Vector3.new(3.25, 34.31, 1.33) },
					RightShoulder = { rot = Vector3.new(17.53, 0, 18.5) },
					LeftShoulder = { rot = Vector3.new(-4.32, 0, -17.71) },
					RightHip = {
						rot = Vector3.new(-10.16, 0, -18.39),
						pos = Vector3.new(0, 0.15, 0),
					},
					LeftHip = { rot = Vector3.new(11.36, 0, 17.77), pos = Vector3.new(0, 0.12, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-4.92, -34.23, -3.35),
						pos = Vector3.new(0.04, -0.18, -0.06),
					},
					Neck = { rot = Vector3.new(3.65, 34.38, 0.8) },
					RightShoulder = { rot = Vector3.new(15.97, 0, 19.91) },
					LeftShoulder = { rot = Vector3.new(-1.78, 0, -18.28) },
					RightHip = {
						rot = Vector3.new(-10.09, 0, -19.45),
						pos = Vector3.new(0, 0.13, 0),
					},
					LeftHip = { rot = Vector3.new(9.69, 0, 15.25), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 0.5312,
				pose = {
					Root = {
						rot = Vector3.new(-5.01, -34.39, -3.11),
						pos = Vector3.new(0.04, -0.17, -0.07),
					},
					Neck = { rot = Vector3.new(3.93, 34.53, 0.41) },
					RightShoulder = { rot = Vector3.new(14.12, 0, 21.32) },
					LeftShoulder = { rot = Vector3.new(1.02, 0, -18.72) },
					RightHip = { rot = Vector3.new(-9.8, 0, -19.89), pos = Vector3.new(0, 0.11, 0) },
					LeftHip = { rot = Vector3.new(7.87, 0, 12.6), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 0.5625,
				pose = {
					Root = {
						rot = Vector3.new(-5.06, -34.65, -2.96),
						pos = Vector3.new(0.04, -0.15, -0.07),
					},
					Neck = { rot = Vector3.new(4.12, 34.78, 0.14) },
					RightShoulder = { rot = Vector3.new(12.02, 0, 22.64) },
					LeftShoulder = { rot = Vector3.new(4.02, 0, -18.99) },
					RightHip = { rot = Vector3.new(-9.03, 0, -18.68), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(6.09, 0, 10.02), pos = Vector3.new(0, 0.12, 0) },
				},
			},
			{
				time = 0.5938,
				pose = {
					Root = {
						rot = Vector3.new(-5.09, -34.98, -2.87),
						pos = Vector3.new(0.04, -0.12, -0.08),
					},
					Neck = { rot = Vector3.new(4.23, 35.12, -0.05) },
					RightShoulder = { rot = Vector3.new(9.75, 0, 23.82) },
					LeftShoulder = { rot = Vector3.new(7.16, 0, -19.08) },
					RightHip = {
						rot = Vector3.new(-7.39, 0, -15.67),
						pos = Vector3.new(0, 0.15, 0),
					},
					LeftHip = { rot = Vector3.new(4.35, 0, 7.51), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = {
						rot = Vector3.new(-5.1, -35.38, -2.84),
						pos = Vector3.new(0.04, -0.1, -0.08),
					},
					Neck = { rot = Vector3.new(4.29, 35.53, -0.16) },
					RightShoulder = { rot = Vector3.new(7.39, 0, 24.82) },
					LeftShoulder = { rot = Vector3.new(10.3, 0, -18.95) },
					RightHip = {
						rot = Vector3.new(-5.07, 0, -11.46),
						pos = Vector3.new(0, 0.22, 0),
					},
					LeftHip = { rot = Vector3.new(3.19, 0, 4.92), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.6562,
				pose = {
					Root = {
						rot = Vector3.new(-5.1, -35.84, -2.85),
						pos = Vector3.new(0.04, -0.08, -0.08),
					},
					Neck = { rot = Vector3.new(4.3, 36, -0.2) },
					RightShoulder = { rot = Vector3.new(5.04, 0, 25.62) },
					LeftShoulder = { rot = Vector3.new(13.32, 0, -18.62) },
					RightHip = { rot = Vector3.new(-1.59, 0, -6.3), pos = Vector3.new(0, 0.27, 0) },
					LeftHip = { rot = Vector3.new(1.13, 0, 2.37), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.6875,
				pose = {
					Root = {
						rot = Vector3.new(-5.07, -36.35, -2.92),
						pos = Vector3.new(0.05, -0.07, -0.08),
					},
					Neck = { rot = Vector3.new(4.25, 36.51, -0.17) },
					RightShoulder = { rot = Vector3.new(2.8, 0, 26.25) },
					LeftShoulder = { rot = Vector3.new(16.11, 0, -18.14) },
					RightHip = { rot = Vector3.new(2.26, 0, -0.92), pos = Vector3.new(0, 0.28, 0) },
					LeftHip = { rot = Vector3.new(-0.9, 0, -0.05), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.7188,
				pose = {
					Root = {
						rot = Vector3.new(-5.04, -36.88, -3.04),
						pos = Vector3.new(0.05, -0.06, -0.08),
					},
					Neck = { rot = Vector3.new(4.14, 37.05, -0.06) },
					RightShoulder = { rot = Vector3.new(0.75, 0, 26.73) },
					LeftShoulder = { rot = Vector3.new(18.59, 0, -17.59) },
					RightHip = { rot = Vector3.new(6.58, 0, 4.45), pos = Vector3.new(0, 0.26, 0) },
					LeftHip = { rot = Vector3.new(-2.77, 0, -1.65), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(-5, -37.42, -3.22),
						pos = Vector3.new(0.06, -0.07, -0.07),
					},
					Neck = { rot = Vector3.new(3.97, 37.6, 0.12) },
					RightShoulder = { rot = Vector3.new(-0.98, 0, 27.1) },
					LeftShoulder = { rot = Vector3.new(20.66, 0, -17.06) },
					RightHip = { rot = Vector3.new(11.07, 0, 9.39), pos = Vector3.new(0, 0.25, 0) },
					LeftHip = { rot = Vector3.new(-4.61, 0, -3.73), pos = Vector3.new(0, 0.17, 0) },
				},
			},
			{
				time = 0.7812,
				pose = {
					Root = {
						rot = Vector3.new(-4.95, -37.94, -3.45),
						pos = Vector3.new(0.07, -0.08, -0.07),
					},
					Neck = { rot = Vector3.new(3.75, 38.14, 0.4) },
					RightShoulder = { rot = Vector3.new(-2.33, 0, 27.42) },
					LeftShoulder = { rot = Vector3.new(22.26, 0, -16.67) },
					RightHip = { rot = Vector3.new(14.71, 0, 13.2), pos = Vector3.new(0, 0.31, 0) },
					LeftHip = { rot = Vector3.new(-6.46, 0, -5.75), pos = Vector3.new(0, 0.22, 0) },
				},
			},
			{
				time = 0.8125,
				pose = {
					Root = {
						rot = Vector3.new(-4.9, -38.43, -3.74),
						pos = Vector3.new(0.07, -0.11, -0.06),
					},
					Neck = { rot = Vector3.new(3.46, 38.64, 0.76) },
					RightShoulder = { rot = Vector3.new(-3.21, 0, 27.73) },
					LeftShoulder = { rot = Vector3.new(23.32, 0, -16.52) },
					RightHip = { rot = Vector3.new(17.69, 0, 16.22), pos = Vector3.new(0, 0.36, 0) },
					LeftHip = { rot = Vector3.new(-8.27, 0, -7.76), pos = Vector3.new(0, 0.27, 0) },
				},
			},
			{
				time = 0.8438,
				pose = {
					Root = {
						rot = Vector3.new(-4.84, -38.87, -4.08),
						pos = Vector3.new(0.08, -0.14, -0.05),
					},
					Neck = { rot = Vector3.new(3.11, 39.09, 1.21) },
					RightShoulder = { rot = Vector3.new(-3.52, 0, 28.04) },
					LeftShoulder = { rot = Vector3.new(23.74, 0, -16.71) },
					RightHip = { rot = Vector3.new(19.87, 0, 18.34), pos = Vector3.new(0, 0.4, 0) },
					LeftHip = { rot = Vector3.new(-9.96, 0, -9.83), pos = Vector3.new(0, 0.32, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = {
						rot = Vector3.new(-4.79, -39.24, -4.47),
						pos = Vector3.new(0.09, -0.16, -0.04),
					},
					Neck = { rot = Vector3.new(2.71, 39.48, 1.73) },
					RightShoulder = { rot = Vector3.new(-3.33, 0, 28.23) },
					LeftShoulder = { rot = Vector3.new(23.5, 0, -17.18) },
					RightHip = { rot = Vector3.new(21.01, 0, 19.15), pos = Vector3.new(0, 0.43, 0) },
					LeftHip = {
						rot = Vector3.new(-11.59, 0, -11.92),
						pos = Vector3.new(0, 0.36, 0),
					},
				},
			},
			{
				time = 0.9062,
				pose = {
					Root = {
						rot = Vector3.new(-4.74, -39.54, -4.89),
						pos = Vector3.new(0.1, -0.18, -0.03),
					},
					Neck = { rot = Vector3.new(2.27, 39.78, 2.31) },
					RightShoulder = { rot = Vector3.new(-2.73, 0, 28.16) },
					LeftShoulder = { rot = Vector3.new(22.62, 0, -17.8) },
					RightHip = { rot = Vector3.new(20.55, 0, 18.3), pos = Vector3.new(0, 0.45, 0) },
					LeftHip = {
						rot = Vector3.new(-12.98, 0, -13.75),
						pos = Vector3.new(0, 0.38, 0),
					},
				},
			},
			{
				time = 0.9375,
				pose = {
					Root = {
						rot = Vector3.new(-4.68, -39.75, -5.34),
						pos = Vector3.new(0.11, -0.19, -0.02),
					},
					Neck = { rot = Vector3.new(1.79, 40, 2.95) },
					RightShoulder = { rot = Vector3.new(-1.75, 0, 27.87) },
					LeftShoulder = { rot = Vector3.new(21.16, 0, -18.48) },
					RightHip = { rot = Vector3.new(19.23, 0, 16.7), pos = Vector3.new(0, 0.45, 0) },
					LeftHip = {
						rot = Vector3.new(-13.98, 0, -15.21),
						pos = Vector3.new(0, 0.39, 0),
					},
				},
			},
			{
				time = 0.9688,
				pose = {
					Root = {
						rot = Vector3.new(-4.59, -39.89, -5.88),
						pos = Vector3.new(0.11, -0.19, -0.01),
					},
					Neck = { rot = Vector3.new(1.2, 40.13, 3.73) },
					RightShoulder = { rot = Vector3.new(-0.24, 0, 27.33) },
					LeftShoulder = { rot = Vector3.new(18.86, 0, -19.2) },
					RightHip = { rot = Vector3.new(17.68, 0, 15.04), pos = Vector3.new(0, 0.45, 0) },
					LeftHip = { rot = Vector3.new(-14.7, 0, -16.66), pos = Vector3.new(0, 0.4, 0) },
				},
			},
		},
	},
	-- ALS_N_Run_F: phase clip (one cycle = 1), left foot plants at 0.4375; natural cycle 0.800 s, stride 6.08 studs per cycle
	Jog = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-11.24, -5.01, -1.44),
						pos = Vector3.new(0.04, -0.28, -0.17),
					},
					Neck = { rot = Vector3.new(3.04, 5.22, 1.01) },
					RightShoulder = { rot = Vector3.new(6.43, 0, 19.63) },
					LeftShoulder = { rot = Vector3.new(38.97, 0, -9.98) },
					RightHip = { rot = Vector3.new(14.44, 0, -3.26), pos = Vector3.new(0, 0.28, 0) },
					LeftHip = { rot = Vector3.new(-23.51, 0, 5.97), pos = Vector3.new(0, 0.71, 0) },
				},
			},
			{
				time = 0.0312,
				pose = {
					Root = {
						rot = Vector3.new(-11.3, -4.37, -1.84),
						pos = Vector3.new(0.06, -0.3, -0.16),
					},
					Neck = { rot = Vector3.new(3.05, 4.56, 1.47) },
					RightShoulder = { rot = Vector3.new(12.57, 0, 19.52) },
					LeftShoulder = { rot = Vector3.new(33.96, 0, -12.56) },
					RightHip = { rot = Vector3.new(9.58, 0, -2.53), pos = Vector3.new(0, 0.3, 0) },
					LeftHip = { rot = Vector3.new(-17.99, 0, 5.48), pos = Vector3.new(0, 0.78, 0) },
				},
			},
			{
				time = 0.0625,
				pose = {
					Root = {
						rot = Vector3.new(-11.33, -3.47, -2.16),
						pos = Vector3.new(0.06, -0.3, -0.15),
					},
					Neck = { rot = Vector3.new(3.05, 3.63, 1.88) },
					RightShoulder = { rot = Vector3.new(19.99, 0, 18.08) },
					LeftShoulder = { rot = Vector3.new(27.01, 0, -14.91) },
					RightHip = { rot = Vector3.new(4.36, 0, -1.55), pos = Vector3.new(0, 0.35, 0) },
					LeftHip = { rot = Vector3.new(-12.34, 0, 5.04), pos = Vector3.new(0, 0.79, 0) },
				},
			},
			{
				time = 0.0938,
				pose = {
					Root = {
						rot = Vector3.new(-11.34, -2.26, -2.37),
						pos = Vector3.new(0.07, -0.3, -0.15),
					},
					Neck = { rot = Vector3.new(3.06, 2.38, 2.19) },
					RightShoulder = { rot = Vector3.new(26.78, 0, 15.39) },
					LeftShoulder = { rot = Vector3.new(19.49, 0, -15.9) },
					RightHip = { rot = Vector3.new(-1.05, 0, -0.79), pos = Vector3.new(0, 0.37, 0) },
					LeftHip = { rot = Vector3.new(-6.55, 0, 4.71), pos = Vector3.new(0, 0.74, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = {
						rot = Vector3.new(-11.3, -0.73, -2.51),
						pos = Vector3.new(0.08, -0.28, -0.15),
					},
					Neck = { rot = Vector3.new(3.07, 0.82, 2.44) },
					RightShoulder = { rot = Vector3.new(31.79, 0, 12.75) },
					LeftShoulder = { rot = Vector3.new(13.26, 0, -15.69) },
					RightHip = { rot = Vector3.new(-6.47, 0, -0.49), pos = Vector3.new(0, 0.35, 0) },
					LeftHip = { rot = Vector3.new(-0.55, 0, 4.61), pos = Vector3.new(0, 0.64, 0) },
				},
			},
			{
				time = 0.1562,
				pose = {
					Root = {
						rot = Vector3.new(-11.25, 0.98, -2.59),
						pos = Vector3.new(0.08, -0.24, -0.16),
					},
					Neck = { rot = Vector3.new(3.09, -0.9, 2.64) },
					RightShoulder = { rot = Vector3.new(35.21, 0, 10.84) },
					LeftShoulder = { rot = Vector3.new(8.76, 0, -14.99) },
					RightHip = { rot = Vector3.new(-11.5, 0, -0.72), pos = Vector3.new(0, 0.3, 0) },
					LeftHip = { rot = Vector3.new(5.75, 0, 4.81), pos = Vector3.new(0, 0.48, 0) },
				},
			},
			{
				time = 0.1875,
				pose = {
					Root = {
						rot = Vector3.new(-11.2, 2.58, -2.59),
						pos = Vector3.new(0.08, -0.18, -0.17),
					},
					Neck = { rot = Vector3.new(3.11, -2.52, 2.75) },
					RightShoulder = { rot = Vector3.new(37.77, 0, 9.56) },
					LeftShoulder = { rot = Vector3.new(5.43, 0, -14.42) },
					RightHip = {
						rot = Vector3.new(-15.58, 0, -1.27),
						pos = Vector3.new(0, 0.21, 0),
					},
					LeftHip = { rot = Vector3.new(12.35, 0, 5.34), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.2188,
				pose = {
					Root = {
						rot = Vector3.new(-11.16, 3.86, -2.52),
						pos = Vector3.new(0.07, -0.11, -0.18),
					},
					Neck = { rot = Vector3.new(3.13, -3.82, 2.75) },
					RightShoulder = { rot = Vector3.new(39.81, 0, 8.58) },
					LeftShoulder = { rot = Vector3.new(2.88, 0, -14.16) },
					RightHip = {
						rot = Vector3.new(-18.48, 0, -1.77),
						pos = Vector3.new(0, 0.13, 0),
					},
					LeftHip = { rot = Vector3.new(18.96, 0, 6.04), pos = Vector3.new(0, 0.12, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(-11.14, 4.78, -2.33),
						pos = Vector3.new(0.07, -0.07, -0.19),
					},
					Neck = { rot = Vector3.new(3.15, -4.76, 2.63) },
					RightShoulder = { rot = Vector3.new(41.45, 0, 7.75) },
					LeftShoulder = { rot = Vector3.new(0.88, 0, -14.19) },
					RightHip = {
						rot = Vector3.new(-21.52, 0, -2.48),
						pos = Vector3.new(0, 0.05, 0),
					},
					LeftHip = { rot = Vector3.new(24.14, 0, 6.24), pos = Vector3.new(0, 0.04, 0) },
				},
			},
			{
				time = 0.2812,
				pose = {
					Root = {
						rot = Vector3.new(-11.15, 5.4, -2.04),
						pos = Vector3.new(0.06, -0.06, -0.2),
					},
					Neck = { rot = Vector3.new(3.16, -5.4, 2.37) },
					RightShoulder = { rot = Vector3.new(42.78, 0, 7) },
					LeftShoulder = { rot = Vector3.new(-0.67, 0, -14.5) },
					RightHip = { rot = Vector3.new(-25.04, 0, -3.38) },
					LeftHip = { rot = Vector3.new(27.93, 0, 6.21), pos = Vector3.new(0, 0.04, 0) },
				},
			},
			{
				time = 0.3125,
				pose = {
					Root = {
						rot = Vector3.new(-11.18, 5.77, -1.64),
						pos = Vector3.new(0.04, -0.05, -0.21),
					},
					Neck = { rot = Vector3.new(3.17, -5.79, 1.99) },
					RightShoulder = { rot = Vector3.new(43.81, 0, 6.31) },
					LeftShoulder = { rot = Vector3.new(-1.79, 0, -15.04) },
					RightHip = { rot = Vector3.new(-28.59, 0, -4.37) },
					LeftHip = { rot = Vector3.new(30.71, 0, 6.37), pos = Vector3.new(0, 0.03, 0) },
				},
			},
			{
				time = 0.3438,
				pose = {
					Root = {
						rot = Vector3.new(-11.22, 5.94, -1.15),
						pos = Vector3.new(0.03, -0.06, -0.21),
					},
					Neck = { rot = Vector3.new(3.17, -5.99, 1.51) },
					RightShoulder = { rot = Vector3.new(44.55, 0, 5.71) },
					LeftShoulder = { rot = Vector3.new(-2.48, 0, -15.76) },
					RightHip = {
						rot = Vector3.new(-31.57, 0, -5.43),
						pos = Vector3.new(0, 0.01, 0),
					},
					LeftHip = { rot = Vector3.new(31.87, 0, 6.31), pos = Vector3.new(0, 0.04, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = {
						rot = Vector3.new(-11.27, 5.97, -0.62),
						pos = Vector3.new(0.01, -0.07, -0.21),
					},
					Neck = { rot = Vector3.new(3.17, -6.05, 0.98) },
					RightShoulder = { rot = Vector3.new(44.9, 0, 5.34) },
					LeftShoulder = { rot = Vector3.new(-2.62, 0, -16.6) },
					RightHip = {
						rot = Vector3.new(-32.65, 0, -6.08),
						pos = Vector3.new(0, 0.09, 0),
					},
					LeftHip = { rot = Vector3.new(31.56, 0, 5.89), pos = Vector3.new(0, 0.06, 0) },
				},
			},
			{
				time = 0.4062,
				pose = {
					Root = {
						rot = Vector3.new(-11.32, 5.89, -0.11),
						pos = Vector3.new(0, -0.11, -0.2),
					},
					Neck = { rot = Vector3.new(3.17, -5.99, 0.46) },
					RightShoulder = { rot = Vector3.new(44.72, 0, 5.4) },
					LeftShoulder = { rot = Vector3.new(-2.05, 0, -17.5) },
					RightHip = {
						rot = Vector3.new(-32.24, 0, -6.29),
						pos = Vector3.new(0, 0.23, 0),
					},
					LeftHip = { rot = Vector3.new(29.17, 0, 5.26), pos = Vector3.new(0, 0.12, 0) },
				},
			},
			{
				time = 0.4375,
				pose = {
					Root = {
						rot = Vector3.new(-11.36, 5.72, 0.35),
						pos = Vector3.new(-0.01, -0.18, -0.19),
					},
					Neck = { rot = Vector3.new(3.16, -5.83, -0.01) },
					RightShoulder = { rot = Vector3.new(43.84, 0, 6.04) },
					LeftShoulder = { rot = Vector3.new(-0.56, 0, -18.4) },
					RightHip = { rot = Vector3.new(-30.99, 0, -6.27), pos = Vector3.new(0, 0.4, 0) },
					LeftHip = { rot = Vector3.new(24.65, 0, 4.66), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.4688,
				pose = {
					Root = {
						rot = Vector3.new(-11.39, 5.43, 0.75),
						pos = Vector3.new(-0.03, -0.24, -0.18),
					},
					Neck = { rot = Vector3.new(3.15, -5.55, -0.45) },
					RightShoulder = { rot = Vector3.new(42.01, 0, 7.36) },
					LeftShoulder = { rot = Vector3.new(2.13, 0, -19.25) },
					RightHip = {
						rot = Vector3.new(-28.08, 0, -5.97),
						pos = Vector3.new(0, 0.58, 0),
					},
					LeftHip = { rot = Vector3.new(19.56, 0, 4.21), pos = Vector3.new(0, 0.26, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-11.41, 4.99, 1.16),
						pos = Vector3.new(-0.04, -0.28, -0.17),
					},
					Neck = { rot = Vector3.new(3.14, -5.1, -0.9) },
					RightShoulder = { rot = Vector3.new(38.92, 0, 9.42) },
					LeftShoulder = { rot = Vector3.new(6.37, 0, -19.9) },
					RightHip = { rot = Vector3.new(-23.5, 0, -5.5), pos = Vector3.new(0, 0.71, 0) },
					LeftHip = { rot = Vector3.new(14.62, 0, 3.79), pos = Vector3.new(0, 0.27, 0) },
				},
			},
			{
				time = 0.5312,
				pose = {
					Root = {
						rot = Vector3.new(-11.4, 4.36, 1.54),
						pos = Vector3.new(-0.05, -0.3, -0.16),
					},
					Neck = { rot = Vector3.new(3.11, -4.44, -1.35) },
					RightShoulder = { rot = Vector3.new(33.93, 0, 12.03) },
					LeftShoulder = { rot = Vector3.new(12.52, 0, -19.82) },
					RightHip = {
						rot = Vector3.new(-18.06, 0, -4.99),
						pos = Vector3.new(0, 0.79, 0),
					},
					LeftHip = { rot = Vector3.new(9.7, 0, 3.11), pos = Vector3.new(0, 0.29, 0) },
				},
			},
			{
				time = 0.5625,
				pose = {
					Root = {
						rot = Vector3.new(-11.35, 3.46, 1.86),
						pos = Vector3.new(-0.06, -0.3, -0.16),
					},
					Neck = { rot = Vector3.new(3.08, -3.51, -1.75) },
					RightShoulder = { rot = Vector3.new(27, 0, 14.41) },
					LeftShoulder = { rot = Vector3.new(19.96, 0, -18.41) },
					RightHip = { rot = Vector3.new(-12.47, 0, -4.55), pos = Vector3.new(0, 0.8, 0) },
					LeftHip = { rot = Vector3.new(4.43, 0, 2.15), pos = Vector3.new(0, 0.34, 0) },
				},
			},
			{
				time = 0.5938,
				pose = {
					Root = {
						rot = Vector3.new(-11.28, 2.25, 2.08),
						pos = Vector3.new(-0.07, -0.3, -0.15),
					},
					Neck = { rot = Vector3.new(3.05, -2.27, -2.06) },
					RightShoulder = { rot = Vector3.new(19.51, 0, 15.45) },
					LeftShoulder = { rot = Vector3.new(26.77, 0, -15.73) },
					RightHip = { rot = Vector3.new(-6.75, 0, -4.2), pos = Vector3.new(0, 0.75, 0) },
					LeftHip = { rot = Vector3.new(-1.1, 0, 1.33), pos = Vector3.new(0, 0.36, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = {
						rot = Vector3.new(-11.18, 0.72, 2.23),
						pos = Vector3.new(-0.07, -0.28, -0.15),
					},
					Neck = { rot = Vector3.new(3.03, -0.71, -2.32) },
					RightShoulder = { rot = Vector3.new(13.31, 0, 15.27) },
					LeftShoulder = { rot = Vector3.new(31.79, 0, -13.12) },
					RightHip = { rot = Vector3.new(-0.78, 0, -4.08), pos = Vector3.new(0, 0.64, 0) },
					LeftHip = { rot = Vector3.new(-6.28, 0, 1.03), pos = Vector3.new(0, 0.35, 0) },
				},
			},
			{
				time = 0.6562,
				pose = {
					Root = {
						rot = Vector3.new(-11.09, -0.98, 2.32),
						pos = Vector3.new(-0.07, -0.24, -0.16),
					},
					Neck = { rot = Vector3.new(3.02, 1.01, -2.52) },
					RightShoulder = { rot = Vector3.new(8.82, 0, 14.61) },
					LeftShoulder = { rot = Vector3.new(35.22, 0, -11.23) },
					RightHip = { rot = Vector3.new(5.49, 0, -4.26), pos = Vector3.new(0, 0.49, 0) },
					LeftHip = { rot = Vector3.new(-11.26, 0, 1.21), pos = Vector3.new(0, 0.29, 0) },
				},
			},
			{
				time = 0.6875,
				pose = {
					Root = {
						rot = Vector3.new(-11, -2.58, 2.35),
						pos = Vector3.new(-0.07, -0.18, -0.16),
					},
					Neck = { rot = Vector3.new(3.02, 2.62, -2.63) },
					RightShoulder = { rot = Vector3.new(5.51, 0, 14.07) },
					LeftShoulder = { rot = Vector3.new(37.79, 0, -9.97) },
					RightHip = { rot = Vector3.new(12.08, 0, -4.81), pos = Vector3.new(0, 0.3, 0) },
					LeftHip = { rot = Vector3.new(-15.76, 0, 1.59), pos = Vector3.new(0, 0.21, 0) },
				},
			},
			{
				time = 0.7188,
				pose = {
					Root = {
						rot = Vector3.new(-10.94, -3.86, 2.28),
						pos = Vector3.new(-0.07, -0.11, -0.17),
					},
					Neck = { rot = Vector3.new(3.02, 3.91, -2.64) },
					RightShoulder = { rot = Vector3.new(2.96, 0, 13.83) },
					LeftShoulder = { rot = Vector3.new(39.83, 0, -9.02) },
					RightHip = { rot = Vector3.new(18.68, 0, -5.6), pos = Vector3.new(0, 0.12, 0) },
					LeftHip = { rot = Vector3.new(-18.73, 0, 2.03), pos = Vector3.new(0, 0.12, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(-10.9, -4.78, 2.1),
						pos = Vector3.new(-0.06, -0.07, -0.18),
					},
					Neck = { rot = Vector3.new(3.03, 4.86, -2.52) },
					RightShoulder = { rot = Vector3.new(0.96, 0, 13.88) },
					LeftShoulder = { rot = Vector3.new(41.48, 0, -8.21) },
					RightHip = { rot = Vector3.new(23.86, 0, -5.93), pos = Vector3.new(0, 0.05, 0) },
					LeftHip = { rot = Vector3.new(-21.78, 0, 2.73), pos = Vector3.new(0, 0.04, 0) },
				},
			},
			{
				time = 0.7812,
				pose = {
					Root = {
						rot = Vector3.new(-10.9, -5.4, 1.82),
						pos = Vector3.new(-0.05, -0.06, -0.19),
					},
					Neck = { rot = Vector3.new(3.03, 5.49, -2.27) },
					RightShoulder = { rot = Vector3.new(-0.59, 0, 14.21) },
					LeftShoulder = { rot = Vector3.new(42.81, 0, -7.49) },
					RightHip = { rot = Vector3.new(27.64, 0, -5.98), pos = Vector3.new(0, 0.04, 0) },
					LeftHip = { rot = Vector3.new(-25.32, 0, 3.62), pos = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.8125,
				pose = {
					Root = {
						rot = Vector3.new(-10.92, -5.77, 1.42),
						pos = Vector3.new(-0.04, -0.05, -0.2),
					},
					Neck = { rot = Vector3.new(3.04, 5.89, -1.89) },
					RightShoulder = { rot = Vector3.new(-1.72, 0, 14.76) },
					LeftShoulder = { rot = Vector3.new(43.85, 0, -6.82) },
					RightHip = { rot = Vector3.new(30.41, 0, -6.13), pos = Vector3.new(0, 0.03, 0) },
					LeftHip = { rot = Vector3.new(-28.82, 0, 4.59) },
				},
			},
			{
				time = 0.8438,
				pose = {
					Root = {
						rot = Vector3.new(-10.96, -5.95, 0.92),
						pos = Vector3.new(-0.03, -0.06, -0.2),
					},
					Neck = { rot = Vector3.new(3.04, 6.09, -1.41) },
					RightShoulder = { rot = Vector3.new(-2.41, 0, 15.49) },
					LeftShoulder = { rot = Vector3.new(44.6, 0, -6.25) },
					RightHip = { rot = Vector3.new(31.56, 0, -6.07), pos = Vector3.new(0, 0.04, 0) },
					LeftHip = { rot = Vector3.new(-31.85, 0, 5.73), pos = Vector3.new(0, 0.01, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = {
						rot = Vector3.new(-11.01, -5.98, 0.39),
						pos = Vector3.new(-0.01, -0.07, -0.2),
					},
					Neck = { rot = Vector3.new(3.04, 6.15, -0.88) },
					RightShoulder = { rot = Vector3.new(-2.55, 0, 16.34) },
					LeftShoulder = { rot = Vector3.new(44.95, 0, -5.91) },
					RightHip = { rot = Vector3.new(31.26, 0, -5.67), pos = Vector3.new(0, 0.07, 0) },
					LeftHip = { rot = Vector3.new(-32.93, 0, 6.43), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.9062,
				pose = {
					Root = {
						rot = Vector3.new(-11.07, -5.9, -0.13),
						pos = Vector3.new(0, -0.11, -0.2),
					},
					Neck = { rot = Vector3.new(3.04, 6.09, -0.36) },
					RightShoulder = { rot = Vector3.new(-1.99, 0, 17.25) },
					LeftShoulder = { rot = Vector3.new(44.78, 0, -5.98) },
					RightHip = { rot = Vector3.new(28.89, 0, -5.02), pos = Vector3.new(0, 0.12, 0) },
					LeftHip = { rot = Vector3.new(-32.46, 0, 6.67), pos = Vector3.new(0, 0.22, 0) },
				},
			},
			{
				time = 0.9375,
				pose = {
					Root = {
						rot = Vector3.new(-11.13, -5.73, -0.6),
						pos = Vector3.new(0.02, -0.17, -0.19),
					},
					Neck = { rot = Vector3.new(3.04, 5.94, 0.12) },
					RightShoulder = { rot = Vector3.new(-0.5, 0, 18.15) },
					LeftShoulder = { rot = Vector3.new(43.9, 0, -6.62) },
					RightHip = { rot = Vector3.new(24.38, 0, -4.32), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(-31.14, 0, 6.69), pos = Vector3.new(0, 0.4, 0) },
				},
			},
			{
				time = 0.9688,
				pose = {
					Root = {
						rot = Vector3.new(-11.18, -5.45, -1.02),
						pos = Vector3.new(0.03, -0.24, -0.18),
					},
					Neck = { rot = Vector3.new(3.04, 5.66, 0.56) },
					RightShoulder = { rot = Vector3.new(2.19, 0, 18.98) },
					LeftShoulder = { rot = Vector3.new(42.07, 0, -7.94) },
					RightHip = { rot = Vector3.new(19.3, 0, -3.75), pos = Vector3.new(0, 0.27, 0) },
					LeftHip = { rot = Vector3.new(-28.17, 0, 6.42), pos = Vector3.new(0, 0.57, 0) },
				},
			},
		},
	},
	-- ALS_N_Run_B: phase clip (one cycle = 1), left foot plants at 0.4375; natural cycle 0.667 s, stride 5.00 studs per cycle
	JogBack = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(0.13, 1.43, -1.1),
						pos = Vector3.new(0.05, -0.25, 0.09),
					},
					Neck = { rot = Vector3.new(-6.44, -1.48, 0.89) },
					RightShoulder = { rot = Vector3.new(12.65, 0, 12.17) },
					LeftShoulder = { rot = Vector3.new(18.77, 0, -7.43) },
					RightHip = { rot = Vector3.new(-3.92, 0, -3.34), pos = Vector3.new(0, 0.29, 0) },
					LeftHip = { rot = Vector3.new(-3.93, 0, 1.64), pos = Vector3.new(0, 0.54, 0) },
				},
			},
			{
				time = 0.0312,
				pose = {
					Root = {
						rot = Vector3.new(0.12, 0.24, -1.08),
						pos = Vector3.new(0.04, -0.22, 0.07),
					},
					Neck = { rot = Vector3.new(-6.45, -0.28, 1) },
					RightShoulder = { rot = Vector3.new(10.47, 0, 12.62) },
					LeftShoulder = { rot = Vector3.new(20.85, 0, -6.49) },
					RightHip = { rot = Vector3.new(0.05, 0, -3.31), pos = Vector3.new(0, 0.24, 0) },
					LeftHip = { rot = Vector3.new(-8.2, 0, 1.72), pos = Vector3.new(0, 0.53, 0) },
				},
			},
			{
				time = 0.0625,
				pose = {
					Root = {
						rot = Vector3.new(0.1, -0.99, -1.04),
						pos = Vector3.new(0.04, -0.18, 0.06),
					},
					Neck = { rot = Vector3.new(-6.46, 0.96, 1.09) },
					RightShoulder = { rot = Vector3.new(8.67, 0, 12.96) },
					LeftShoulder = { rot = Vector3.new(22.63, 0, -5.87) },
					RightHip = { rot = Vector3.new(4.12, 0, -3.18), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(-12.1, 0, 2.03), pos = Vector3.new(0, 0.48, 0) },
				},
			},
			{
				time = 0.0938,
				pose = {
					Root = {
						rot = Vector3.new(0.09, -2.08, -0.99),
						pos = Vector3.new(0.03, -0.14, 0.05),
					},
					Neck = { rot = Vector3.new(-6.46, 2.05, 1.15) },
					RightShoulder = { rot = Vector3.new(7.35, 0, 13.18) },
					LeftShoulder = { rot = Vector3.new(23.95, 0, -5.54) },
					RightHip = { rot = Vector3.new(8.55, 0, -3.05), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(-15.43, 0, 2.49), pos = Vector3.new(0, 0.43, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = {
						rot = Vector3.new(0.09, -2.91, -0.94),
						pos = Vector3.new(0.03, -0.11, 0.04),
					},
					Neck = { rot = Vector3.new(-6.47, 2.89, 1.19) },
					RightShoulder = { rot = Vector3.new(6.58, 0, 13.27) },
					LeftShoulder = { rot = Vector3.new(24.71, 0, -5.46) },
					RightHip = { rot = Vector3.new(13.19, 0, -3.05), pos = Vector3.new(0, 0.18, 0) },
					LeftHip = { rot = Vector3.new(-18.02, 0, 3.03), pos = Vector3.new(0, 0.37, 0) },
				},
			},
			{
				time = 0.1562,
				pose = {
					Root = {
						rot = Vector3.new(0.09, -3.51, -0.9),
						pos = Vector3.new(0.02, -0.09, 0.03),
					},
					Neck = { rot = Vector3.new(-6.47, 3.49, 1.21) },
					RightShoulder = { rot = Vector3.new(6.15, 0, 13.29) },
					LeftShoulder = { rot = Vector3.new(25.12, 0, -5.52) },
					RightHip = { rot = Vector3.new(17.09, 0, -3.03), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(-19.85, 0, 3.58), pos = Vector3.new(0, 0.32, 0) },
				},
			},
			{
				time = 0.1875,
				pose = {
					Root = {
						rot = Vector3.new(0.09, -3.92, -0.85),
						pos = Vector3.new(0.01, -0.09, 0.03),
					},
					Neck = { rot = Vector3.new(-6.48, 3.9, 1.21) },
					RightShoulder = { rot = Vector3.new(5.91, 0, 13.26) },
					LeftShoulder = { rot = Vector3.new(25.3, 0, -5.63) },
					RightHip = { rot = Vector3.new(19.78, 0, -2.95), pos = Vector3.new(0, 0.14, 0) },
					LeftHip = { rot = Vector3.new(-21.01, 0, 4.1), pos = Vector3.new(0, 0.28, 0) },
				},
			},
			{
				time = 0.2188,
				pose = {
					Root = {
						rot = Vector3.new(0.1, -4.18, -0.78),
						pos = Vector3.new(0.01, -0.09, 0.03),
					},
					Neck = { rot = Vector3.new(-6.48, 4.17, 1.17) },
					RightShoulder = { rot = Vector3.new(5.83, 0, 13.19) },
					LeftShoulder = { rot = Vector3.new(25.3, 0, -5.8) },
					RightHip = { rot = Vector3.new(21.22, 0, -2.83), pos = Vector3.new(0, 0.14, 0) },
					LeftHip = { rot = Vector3.new(-21.67, 0, 4.57), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(0.1, -4.32, -0.71),
						pos = Vector3.new(0, -0.11, 0.04),
					},
					Neck = { rot = Vector3.new(-6.48, 4.32, 1.11) },
					RightShoulder = { rot = Vector3.new(5.91, 0, 13.1) },
					LeftShoulder = { rot = Vector3.new(25.16, 0, -6.01) },
					RightHip = { rot = Vector3.new(21.46, 0, -2.64), pos = Vector3.new(0, 0.16, 0) },
					LeftHip = { rot = Vector3.new(-21.85, 0, 4.95), pos = Vector3.new(0, 0.22, 0) },
				},
			},
			{
				time = 0.2812,
				pose = {
					Root = {
						rot = Vector3.new(0.11, -4.37, -0.57),
						pos = Vector3.new(-0.01, -0.14, 0.05),
					},
					Neck = { rot = Vector3.new(-6.47, 4.39, 0.98) },
					RightShoulder = { rot = Vector3.new(6.17, 0, 12.96) },
					LeftShoulder = { rot = Vector3.new(24.86, 0, -6.31) },
					RightHip = { rot = Vector3.new(20.59, 0, -2.46), pos = Vector3.new(0, 0.19, 0) },
					LeftHip = { rot = Vector3.new(-21.73, 0, 5.21), pos = Vector3.new(0, 0.21, 0) },
				},
			},
			{
				time = 0.3125,
				pose = {
					Root = {
						rot = Vector3.new(0.13, -4.35, -0.27),
						pos = Vector3.new(-0.02, -0.18, 0.06),
					},
					Neck = { rot = Vector3.new(-6.47, 4.39, 0.68) },
					RightShoulder = { rot = Vector3.new(6.67, 0, 12.72) },
					LeftShoulder = { rot = Vector3.new(24.37, 0, -6.71) },
					RightHip = { rot = Vector3.new(18.75, 0, -2.44), pos = Vector3.new(0, 0.23, 0) },
					LeftHip = { rot = Vector3.new(-21.64, 0, 5.34), pos = Vector3.new(0, 0.22, 0) },
				},
			},
			{
				time = 0.3438,
				pose = {
					Root = {
						rot = Vector3.new(0.16, -4.24, 0.13),
						pos = Vector3.new(-0.03, -0.22, 0.08),
					},
					Neck = { rot = Vector3.new(-6.46, 4.32, 0.26) },
					RightShoulder = { rot = Vector3.new(7.49, 0, 12.39) },
					LeftShoulder = { rot = Vector3.new(23.64, 0, -7.27) },
					RightHip = { rot = Vector3.new(16.13, 0, -2.5), pos = Vector3.new(0, 0.28, 0) },
					LeftHip = { rot = Vector3.new(-21.24, 0, 5.22), pos = Vector3.new(0, 0.26, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = {
						rot = Vector3.new(0.18, -4.03, 0.51),
						pos = Vector3.new(-0.04, -0.25, 0.09),
					},
					Neck = { rot = Vector3.new(-6.46, 4.14, -0.14) },
					RightShoulder = { rot = Vector3.new(8.79, 0, 11.91) },
					LeftShoulder = { rot = Vector3.new(22.52, 0, -8.08) },
					RightHip = { rot = Vector3.new(12.88, 0, -2.45), pos = Vector3.new(0, 0.33, 0) },
					LeftHip = { rot = Vector3.new(-19.82, 0, 4.84), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.4062,
				pose = {
					Root = {
						rot = Vector3.new(0.17, -3.68, 0.73),
						pos = Vector3.new(-0.04, -0.27, 0.09),
					},
					Neck = { rot = Vector3.new(-6.46, 3.81, -0.4) },
					RightShoulder = { rot = Vector3.new(10.91, 0, 11.09) },
					LeftShoulder = { rot = Vector3.new(20.64, 0, -9.28) },
					RightHip = { rot = Vector3.new(9.05, 0, -2.12), pos = Vector3.new(0, 0.41, 0) },
					LeftHip = { rot = Vector3.new(-16.62, 0, 4.45), pos = Vector3.new(0, 0.33, 0) },
				},
			},
			{
				time = 0.4375,
				pose = {
					Root = {
						rot = Vector3.new(0.15, -3.16, 0.81),
						pos = Vector3.new(-0.05, -0.28, 0.1),
					},
					Neck = { rot = Vector3.new(-6.45, 3.28, -0.53) },
					RightShoulder = { rot = Vector3.new(13.61, 0, 9.88) },
					LeftShoulder = { rot = Vector3.new(18.08, 0, -10.66) },
					RightHip = { rot = Vector3.new(4.8, 0, -1.63), pos = Vector3.new(0, 0.48, 0) },
					LeftHip = { rot = Vector3.new(-12.2, 0, 4.14), pos = Vector3.new(0, 0.34, 0) },
				},
			},
			{
				time = 0.4688,
				pose = {
					Root = {
						rot = Vector3.new(0.12, -2.43, 0.86),
						pos = Vector3.new(-0.05, -0.27, 0.09),
					},
					Neck = { rot = Vector3.new(-6.44, 2.54, -0.65) },
					RightShoulder = { rot = Vector3.new(16.32, 0, 8.43) },
					LeftShoulder = { rot = Vector3.new(15.25, 0, -11.78) },
					RightHip = { rot = Vector3.new(0.4, 0, -1.29), pos = Vector3.new(0, 0.53, 0) },
					LeftHip = { rot = Vector3.new(-7.86, 0, 3.93), pos = Vector3.new(0, 0.33, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(0.09, -1.44, 0.88),
						pos = Vector3.new(-0.04, -0.25, 0.08),
					},
					Neck = { rot = Vector3.new(-6.44, 1.54, -0.77) },
					RightShoulder = { rot = Vector3.new(18.76, 0, 7.12) },
					LeftShoulder = { rot = Vector3.new(12.64, 0, -12.51) },
					RightHip = { rot = Vector3.new(-4, 0, -1.16), pos = Vector3.new(0, 0.54, 0) },
					LeftHip = { rot = Vector3.new(-3.79, 0, 3.82), pos = Vector3.new(0, 0.29, 0) },
				},
			},
			{
				time = 0.5312,
				pose = {
					Root = {
						rot = Vector3.new(0.05, -0.24, 0.87),
						pos = Vector3.new(-0.04, -0.22, 0.07),
					},
					Neck = { rot = Vector3.new(-6.43, 0.34, -0.88) },
					RightShoulder = { rot = Vector3.new(20.83, 0, 6.16) },
					LeftShoulder = { rot = Vector3.new(10.45, 0, -12.94) },
					RightHip = { rot = Vector3.new(-8.23, 0, -1.25), pos = Vector3.new(0, 0.53, 0) },
					LeftHip = { rot = Vector3.new(0.17, 0, 3.75), pos = Vector3.new(0, 0.24, 0) },
				},
			},
			{
				time = 0.5625,
				pose = {
					Root = {
						rot = Vector3.new(0.03, 0.98, 0.83),
						pos = Vector3.new(-0.04, -0.18, 0.06),
					},
					Neck = { rot = Vector3.new(-6.42, -0.9, -0.97) },
					RightShoulder = { rot = Vector3.new(22.6, 0, 5.52) },
					LeftShoulder = { rot = Vector3.new(8.64, 0, -13.26) },
					RightHip = {
						rot = Vector3.new(-12.11, 0, -1.57),
						pos = Vector3.new(0, 0.49, 0),
					},
					LeftHip = { rot = Vector3.new(4.25, 0, 3.56), pos = Vector3.new(0, 0.21, 0) },
				},
			},
			{
				time = 0.5938,
				pose = {
					Root = {
						rot = Vector3.new(0, 2.07, 0.78),
						pos = Vector3.new(-0.03, -0.14, 0.05),
					},
					Neck = { rot = Vector3.new(-6.42, -1.99, -1.03) },
					RightShoulder = { rot = Vector3.new(23.92, 0, 5.17) },
					LeftShoulder = { rot = Vector3.new(7.32, 0, -13.47) },
					RightHip = {
						rot = Vector3.new(-15.41, 0, -2.06),
						pos = Vector3.new(0, 0.43, 0),
					},
					LeftHip = { rot = Vector3.new(8.68, 0, 3.35), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = {
						rot = Vector3.new(-0.01, 2.9, 0.74),
						pos = Vector3.new(-0.02, -0.11, 0.04),
					},
					Neck = { rot = Vector3.new(-6.41, -2.82, -1.08) },
					RightShoulder = { rot = Vector3.new(24.68, 0, 5.09) },
					LeftShoulder = { rot = Vector3.new(6.55, 0, -13.55) },
					RightHip = {
						rot = Vector3.new(-17.98, 0, -2.61),
						pos = Vector3.new(0, 0.37, 0),
					},
					LeftHip = { rot = Vector3.new(13.31, 0, 3.28), pos = Vector3.new(0, 0.17, 0) },
				},
			},
			{
				time = 0.6562,
				pose = {
					Root = {
						rot = Vector3.new(-0.02, 3.5, 0.69),
						pos = Vector3.new(-0.02, -0.09, 0.03),
					},
					Neck = { rot = Vector3.new(-6.41, -3.43, -1.1) },
					RightShoulder = { rot = Vector3.new(25.08, 0, 5.13) },
					LeftShoulder = { rot = Vector3.new(6.12, 0, -13.56) },
					RightHip = {
						rot = Vector3.new(-19.79, 0, -3.18),
						pos = Vector3.new(0, 0.32, 0),
					},
					LeftHip = { rot = Vector3.new(17.22, 0, 3.24), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.6875,
				pose = {
					Root = {
						rot = Vector3.new(-0.02, 3.91, 0.64),
						pos = Vector3.new(-0.01, -0.09, 0.03),
					},
					Neck = { rot = Vector3.new(-6.41, -3.84, -1.09) },
					RightShoulder = { rot = Vector3.new(25.25, 0, 5.24) },
					LeftShoulder = { rot = Vector3.new(5.88, 0, -13.54) },
					RightHip = {
						rot = Vector3.new(-20.95, 0, -3.71),
						pos = Vector3.new(0, 0.28, 0),
					},
					LeftHip = { rot = Vector3.new(19.91, 0, 3.16), pos = Vector3.new(0, 0.14, 0) },
				},
			},
			{
				time = 0.7188,
				pose = {
					Root = {
						rot = Vector3.new(-0.02, 4.17, 0.57),
						pos = Vector3.new(0, -0.09, 0.03),
					},
					Neck = { rot = Vector3.new(-6.41, -4.11, -1.05) },
					RightShoulder = { rot = Vector3.new(25.26, 0, 5.4) },
					LeftShoulder = { rot = Vector3.new(5.8, 0, -13.47) },
					RightHip = { rot = Vector3.new(-21.6, 0, -4.17), pos = Vector3.new(0, 0.25, 0) },
					LeftHip = { rot = Vector3.new(21.35, 0, 3.03), pos = Vector3.new(0, 0.14, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(-0.01, 4.31, 0.49),
						pos = Vector3.new(0, -0.11, 0.04),
					},
					Neck = { rot = Vector3.new(-6.41, -4.26, -0.99) },
					RightShoulder = { rot = Vector3.new(25.11, 0, 5.62) },
					LeftShoulder = { rot = Vector3.new(5.88, 0, -13.38) },
					RightHip = {
						rot = Vector3.new(-21.78, 0, -4.55),
						pos = Vector3.new(0, 0.23, 0),
					},
					LeftHip = { rot = Vector3.new(21.6, 0, 2.85), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.7812,
				pose = {
					Root = {
						rot = Vector3.new(0, 4.36, 0.35),
						pos = Vector3.new(0.01, -0.14, 0.05),
					},
					Neck = { rot = Vector3.new(-6.41, -4.33, -0.86) },
					RightShoulder = { rot = Vector3.new(24.81, 0, 5.91) },
					LeftShoulder = { rot = Vector3.new(6.14, 0, -13.24) },
					RightHip = { rot = Vector3.new(-21.66, 0, -4.8), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(20.75, 0, 2.71), pos = Vector3.new(0, 0.19, 0) },
				},
			},
			{
				time = 0.8125,
				pose = {
					Root = {
						rot = Vector3.new(0.02, 4.34, 0.05),
						pos = Vector3.new(0.02, -0.18, 0.06),
					},
					Neck = { rot = Vector3.new(-6.4, -4.33, -0.56) },
					RightShoulder = { rot = Vector3.new(24.32, 0, 6.31) },
					LeftShoulder = { rot = Vector3.new(6.64, 0, -13) },
					RightHip = {
						rot = Vector3.new(-21.59, 0, -4.91),
						pos = Vector3.new(0, 0.23, 0),
					},
					LeftHip = { rot = Vector3.new(18.92, 0, 2.75), pos = Vector3.new(0, 0.23, 0) },
				},
			},
			{
				time = 0.8438,
				pose = {
					Root = {
						rot = Vector3.new(0.05, 4.23, -0.36),
						pos = Vector3.new(0.03, -0.22, 0.07),
					},
					Neck = { rot = Vector3.new(-6.4, -4.27, -0.14) },
					RightShoulder = { rot = Vector3.new(23.6, 0, 6.87) },
					LeftShoulder = { rot = Vector3.new(7.46, 0, -12.67) },
					RightHip = {
						rot = Vector3.new(-21.21, 0, -4.76),
						pos = Vector3.new(0, 0.26, 0),
					},
					LeftHip = { rot = Vector3.new(16.31, 0, 2.86), pos = Vector3.new(0, 0.27, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = {
						rot = Vector3.new(0.09, 4.02, -0.73),
						pos = Vector3.new(0.04, -0.25, 0.08),
					},
					Neck = { rot = Vector3.new(-6.4, -4.09, 0.26) },
					RightShoulder = { rot = Vector3.new(22.48, 0, 7.68) },
					LeftShoulder = { rot = Vector3.new(8.77, 0, -12.19) },
					RightHip = {
						rot = Vector3.new(-19.81, 0, -4.36),
						pos = Vector3.new(0, 0.31, 0),
					},
					LeftHip = { rot = Vector3.new(13.07, 0, 2.86), pos = Vector3.new(0, 0.33, 0) },
				},
			},
			{
				time = 0.9062,
				pose = {
					Root = {
						rot = Vector3.new(0.11, 3.67, -0.95),
						pos = Vector3.new(0.05, -0.27, 0.09),
					},
					Neck = { rot = Vector3.new(-6.41, -3.75, 0.52) },
					RightShoulder = { rot = Vector3.new(20.62, 0, 8.9) },
					LeftShoulder = { rot = Vector3.new(10.89, 0, -11.37) },
					RightHip = {
						rot = Vector3.new(-16.64, 0, -3.95),
						pos = Vector3.new(0, 0.33, 0),
					},
					LeftHip = { rot = Vector3.new(9.21, 0, 2.56), pos = Vector3.new(0, 0.4, 0) },
				},
			},
			{
				time = 0.9375,
				pose = {
					Root = {
						rot = Vector3.new(0.13, 3.15, -1.04),
						pos = Vector3.new(0.05, -0.28, 0.1),
					},
					Neck = { rot = Vector3.new(-6.42, -3.22, 0.65) },
					RightShoulder = { rot = Vector3.new(18.06, 0, 10.29) },
					LeftShoulder = { rot = Vector3.new(13.6, 0, -10.17) },
					RightHip = {
						rot = Vector3.new(-12.27, 0, -3.64),
						pos = Vector3.new(0, 0.34, 0),
					},
					LeftHip = { rot = Vector3.new(4.93, 0, 2.08), pos = Vector3.new(0, 0.48, 0) },
				},
			},
			{
				time = 0.9688,
				pose = {
					Root = {
						rot = Vector3.new(0.13, 2.42, -1.08),
						pos = Vector3.new(0.05, -0.27, 0.09),
					},
					Neck = { rot = Vector3.new(-6.43, -2.48, 0.77) },
					RightShoulder = { rot = Vector3.new(15.25, 0, 11.42) },
					LeftShoulder = { rot = Vector3.new(16.32, 0, -8.73) },
					RightHip = { rot = Vector3.new(-7.97, 0, -3.42), pos = Vector3.new(0, 0.33, 0) },
					LeftHip = { rot = Vector3.new(0.49, 0, 1.76), pos = Vector3.new(0, 0.52, 0) },
				},
			},
		},
	},
	-- ALS_N_Run_LF: phase clip (one cycle = 1), left foot plants at 0.4375; natural cycle 0.800 s, stride 5.90 studs per cycle
	JogLeft = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-9.82, 31.43, 5.85),
						pos = Vector3.new(0.02, -0.28, -0.17),
					},
					Neck = { rot = Vector3.new(-2.91, -31.97, -2.55) },
					RightShoulder = { rot = Vector3.new(19.8, 0, 12.67) },
					LeftShoulder = { rot = Vector3.new(15.25, 0, -24.08) },
					RightHip = { rot = Vector3.new(0.93, 0, -4.41), pos = Vector3.new(0, 0.29, 0) },
					LeftHip = { rot = Vector3.new(-6.47, 0, 5.85), pos = Vector3.new(0, 0.74, 0) },
				},
			},
			{
				time = 0.0312,
				pose = {
					Root = {
						rot = Vector3.new(-9.97, 32.5, 5.78),
						pos = Vector3.new(0.03, -0.27, -0.17),
					},
					Neck = { rot = Vector3.new(-2.82, -33.08, -2.4) },
					RightShoulder = { rot = Vector3.new(23.89, 0, 10.69) },
					LeftShoulder = { rot = Vector3.new(9.62, 0, -25.84) },
					RightHip = { rot = Vector3.new(-1.75, 0, -0.95), pos = Vector3.new(0, 0.31, 0) },
					LeftHip = { rot = Vector3.new(-3.52, 0, 3.31), pos = Vector3.new(0, 0.74, 0) },
				},
			},
			{
				time = 0.0625,
				pose = {
					Root = {
						rot = Vector3.new(-10.13, 33.79, 5.77),
						pos = Vector3.new(0.03, -0.26, -0.18),
					},
					Neck = { rot = Vector3.new(-2.8, -34.41, -2.36) },
					RightShoulder = { rot = Vector3.new(27.07, 0, 8.97) },
					LeftShoulder = { rot = Vector3.new(4.92, 0, -26.59) },
					RightHip = { rot = Vector3.new(-4.39, 0, 1.96), pos = Vector3.new(0, 0.33, 0) },
					LeftHip = { rot = Vector3.new(-0.27, 0, 1), pos = Vector3.new(0, 0.69, 0) },
				},
			},
			{
				time = 0.0938,
				pose = {
					Root = {
						rot = Vector3.new(-10.3, 35.2, 5.83),
						pos = Vector3.new(0.02, -0.23, -0.18),
					},
					Neck = { rot = Vector3.new(-2.83, -35.84, -2.39) },
					RightShoulder = { rot = Vector3.new(29.44, 0, 7.7) },
					LeftShoulder = { rot = Vector3.new(1.34, 0, -26.69) },
					RightHip = { rot = Vector3.new(-7.03, 0, 4.68), pos = Vector3.new(0, 0.35, 0) },
					LeftHip = { rot = Vector3.new(3.25, 0, -1.48), pos = Vector3.new(0, 0.6, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = {
						rot = Vector3.new(-10.46, 36.58, 5.94),
						pos = Vector3.new(0.02, -0.19, -0.18),
					},
					Neck = { rot = Vector3.new(-2.9, -37.23, -2.47) },
					RightShoulder = { rot = Vector3.new(31.37, 0, 6.84) },
					LeftShoulder = { rot = Vector3.new(-1.41, 0, -26.61) },
					RightHip = { rot = Vector3.new(-9.55, 0, 7.51), pos = Vector3.new(0, 0.34, 0) },
					LeftHip = { rot = Vector3.new(6.8, 0, -4.4), pos = Vector3.new(0, 0.5, 0) },
				},
			},
			{
				time = 0.1562,
				pose = {
					Root = {
						rot = Vector3.new(-10.61, 37.77, 6.07),
						pos = Vector3.new(0.02, -0.14, -0.17),
					},
					Neck = { rot = Vector3.new(-2.99, -38.44, -2.59) },
					RightShoulder = { rot = Vector3.new(33, 0, 6.2) },
					LeftShoulder = { rot = Vector3.new(-3.62, 0, -26.5) },
					RightHip = {
						rot = Vector3.new(-11.68, 0, 10.19),
						pos = Vector3.new(0, 0.31, 0),
					},
					LeftHip = { rot = Vector3.new(10.39, 0, -7.65), pos = Vector3.new(0, 0.38, 0) },
				},
			},
			{
				time = 0.1875,
				pose = {
					Root = {
						rot = Vector3.new(-10.72, 38.73, 6.22),
						pos = Vector3.new(0.01, -0.09, -0.17),
					},
					Neck = { rot = Vector3.new(-3.1, -39.4, -2.75) },
					RightShoulder = { rot = Vector3.new(34.39, 0, 5.68) },
					LeftShoulder = { rot = Vector3.new(-5.43, 0, -26.41) },
					RightHip = {
						rot = Vector3.new(-13.37, 0, 12.71),
						pos = Vector3.new(0, 0.29, 0),
					},
					LeftHip = { rot = Vector3.new(13.65, 0, -10.71), pos = Vector3.new(0, 0.29, 0) },
				},
			},
			{
				time = 0.2188,
				pose = {
					Root = {
						rot = Vector3.new(-10.81, 39.45, 6.4),
						pos = Vector3.new(0, -0.07, -0.17),
					},
					Neck = { rot = Vector3.new(-3.24, -40.12, -2.96) },
					RightShoulder = { rot = Vector3.new(35.58, 0, 5.21) },
					LeftShoulder = { rot = Vector3.new(-6.96, 0, -26.39) },
					RightHip = {
						rot = Vector3.new(-14.78, 0, 15.28),
						pos = Vector3.new(0, 0.27, 0),
					},
					LeftHip = { rot = Vector3.new(16.16, 0, -13), pos = Vector3.new(0, 0.27, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(-10.87, 39.97, 6.61),
						pos = Vector3.new(0, -0.06, -0.16),
					},
					Neck = { rot = Vector3.new(-3.43, -40.64, -3.23) },
					RightShoulder = { rot = Vector3.new(36.6, 0, 4.8) },
					LeftShoulder = { rot = Vector3.new(-8.23, 0, -26.43) },
					RightHip = {
						rot = Vector3.new(-15.85, 0, 17.74),
						pos = Vector3.new(0, 0.27, 0),
					},
					LeftHip = { rot = Vector3.new(18.06, 0, -14.7), pos = Vector3.new(0, 0.28, 0) },
				},
			},
			{
				time = 0.2812,
				pose = {
					Root = {
						rot = Vector3.new(-10.9, 40.32, 6.86),
						pos = Vector3.new(-0.01, -0.05, -0.15),
					},
					Neck = { rot = Vector3.new(-3.65, -40.99, -3.55) },
					RightShoulder = { rot = Vector3.new(37.44, 0, 4.43) },
					LeftShoulder = { rot = Vector3.new(-9.24, 0, -26.56) },
					RightHip = {
						rot = Vector3.new(-16.58, 0, 19.88),
						pos = Vector3.new(0, 0.27, 0),
					},
					LeftHip = { rot = Vector3.new(19.5, 0, -15.97), pos = Vector3.new(0, 0.29, 0) },
				},
			},
			{
				time = 0.3125,
				pose = {
					Root = {
						rot = Vector3.new(-10.92, 40.55, 7.13),
						pos = Vector3.new(-0.02, -0.05, -0.15),
					},
					Neck = { rot = Vector3.new(-3.92, -41.2, -3.93) },
					RightShoulder = { rot = Vector3.new(38.11, 0, 4.1) },
					LeftShoulder = { rot = Vector3.new(-10.01, 0, -26.76) },
					RightHip = {
						rot = Vector3.new(-17.06, 0, 21.64),
						pos = Vector3.new(0, 0.28, 0),
					},
					LeftHip = { rot = Vector3.new(20.39, 0, -16.71), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.3438,
				pose = {
					Root = {
						rot = Vector3.new(-10.91, 40.67, 7.43),
						pos = Vector3.new(-0.02, -0.06, -0.14),
					},
					Neck = { rot = Vector3.new(-4.21, -41.29, -4.34) },
					RightShoulder = { rot = Vector3.new(38.55, 0, 3.9) },
					LeftShoulder = { rot = Vector3.new(-10.43, 0, -27.03) },
					RightHip = { rot = Vector3.new(-17.27, 0, 22.84), pos = Vector3.new(0, 0.3, 0) },
					LeftHip = { rot = Vector3.new(20.7, 0, -16.88), pos = Vector3.new(0, 0.31, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = {
						rot = Vector3.new(-10.89, 40.69, 7.72),
						pos = Vector3.new(-0.02, -0.08, -0.13),
					},
					Neck = { rot = Vector3.new(-4.5, -41.29, -4.76) },
					RightShoulder = { rot = Vector3.new(38.72, 0, 3.9) },
					LeftShoulder = { rot = Vector3.new(-10.41, 0, -27.35) },
					RightHip = {
						rot = Vector3.new(-17.27, 0, 23.41),
						pos = Vector3.new(0, 0.35, 0),
					},
					LeftHip = { rot = Vector3.new(20.36, 0, -16.38), pos = Vector3.new(0, 0.33, 0) },
				},
			},
			{
				time = 0.4062,
				pose = {
					Root = {
						rot = Vector3.new(-10.86, 40.67, 7.99),
						pos = Vector3.new(-0.02, -0.12, -0.12),
					},
					Neck = { rot = Vector3.new(-4.77, -41.24, -5.14) },
					RightShoulder = { rot = Vector3.new(38.63, 0, 4.1) },
					LeftShoulder = { rot = Vector3.new(-10.03, 0, -27.67) },
					RightHip = {
						rot = Vector3.new(-17.27, 0, 23.57),
						pos = Vector3.new(0, 0.42, 0),
					},
					LeftHip = { rot = Vector3.new(19.26, 0, -14.99), pos = Vector3.new(0, 0.35, 0) },
				},
			},
			{
				time = 0.4375,
				pose = {
					Root = {
						rot = Vector3.new(-10.81, 40.55, 8.26),
						pos = Vector3.new(-0.02, -0.17, -0.11),
					},
					Neck = { rot = Vector3.new(-5.05, -41.08, -5.53) },
					RightShoulder = { rot = Vector3.new(37.99, 0, 4.78) },
					LeftShoulder = { rot = Vector3.new(-8.74, 0, -28.01) },
					RightHip = { rot = Vector3.new(-16.95, 0, 22.98), pos = Vector3.new(0, 0.5, 0) },
					LeftHip = { rot = Vector3.new(17.11, 0, -12.44), pos = Vector3.new(0, 0.38, 0) },
				},
			},
			{
				time = 0.4688,
				pose = {
					Root = {
						rot = Vector3.new(-10.71, 40.26, 8.59),
						pos = Vector3.new(-0.02, -0.23, -0.1),
					},
					Neck = { rot = Vector3.new(-5.42, -40.73, -6.05) },
					RightShoulder = { rot = Vector3.new(36.25, 0, 6.34) },
					LeftShoulder = { rot = Vector3.new(-5.66, 0, -28.36) },
					RightHip = { rot = Vector3.new(-15.62, 0, 20.91), pos = Vector3.new(0, 0.6, 0) },
					LeftHip = { rot = Vector3.new(13.85, 0, -8.76), pos = Vector3.new(0, 0.39, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-10.54, 39.75, 8.96),
						pos = Vector3.new(-0.02, -0.27, -0.09),
					},
					Neck = { rot = Vector3.new(-5.84, -40.13, -6.63) },
					RightShoulder = { rot = Vector3.new(33.08, 0, 8.79) },
					LeftShoulder = { rot = Vector3.new(-0.49, 0, -28.24) },
					RightHip = {
						rot = Vector3.new(-12.88, 0, 17.13),
						pos = Vector3.new(0, 0.67, 0),
					},
					LeftHip = { rot = Vector3.new(10.42, 0, -4.99), pos = Vector3.new(0, 0.35, 0) },
				},
			},
			{
				time = 0.5312,
				pose = {
					Root = {
						rot = Vector3.new(-10.29, 38.94, 9.26),
						pos = Vector3.new(-0.02, -0.28, -0.08),
					},
					Neck = { rot = Vector3.new(-6.23, -39.21, -7.16) },
					RightShoulder = { rot = Vector3.new(27.87, 0, 11.78) },
					LeftShoulder = { rot = Vector3.new(6.9, 0, -26.61) },
					RightHip = { rot = Vector3.new(-9.17, 0, 12.23), pos = Vector3.new(0, 0.67, 0) },
					LeftHip = { rot = Vector3.new(6.95, 0, -1.4), pos = Vector3.new(0, 0.33, 0) },
				},
			},
			{
				time = 0.5625,
				pose = {
					Root = {
						rot = Vector3.new(-9.96, 37.74, 9.37),
						pos = Vector3.new(-0.02, -0.28, -0.07),
					},
					Neck = { rot = Vector3.new(-6.44, -37.91, -7.42) },
					RightShoulder = { rot = Vector3.new(21.36, 0, 14) },
					LeftShoulder = { rot = Vector3.new(14.42, 0, -23.06) },
					RightHip = { rot = Vector3.new(-4.79, 0, 6.69), pos = Vector3.new(0, 0.63, 0) },
					LeftHip = { rot = Vector3.new(3.21, 0, 2.3), pos = Vector3.new(0, 0.35, 0) },
				},
			},
			{
				time = 0.5938,
				pose = {
					Root = {
						rot = Vector3.new(-9.57, 36.08, 9.3),
						pos = Vector3.new(-0.02, -0.26, -0.06),
					},
					Neck = { rot = Vector3.new(-6.44, -36.18, -7.4) },
					RightShoulder = { rot = Vector3.new(15.53, 0, 14.62) },
					LeftShoulder = { rot = Vector3.new(19.83, 0, -19.08) },
					RightHip = { rot = Vector3.new(0.22, 0, 0.61), pos = Vector3.new(0, 0.54, 0) },
					LeftHip = { rot = Vector3.new(-0.59, 0, 6.2), pos = Vector3.new(0, 0.34, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = {
						rot = Vector3.new(-9.19, 34.13, 9.14),
						pos = Vector3.new(-0.03, -0.22, -0.06),
					},
					Neck = { rot = Vector3.new(-6.31, -34.19, -7.22) },
					RightShoulder = { rot = Vector3.new(11.39, 0, 14.23) },
					LeftShoulder = { rot = Vector3.new(23.14, 0, -16.16) },
					RightHip = { rot = Vector3.new(5.58, 0, -5.94), pos = Vector3.new(0, 0.4, 0) },
					LeftHip = { rot = Vector3.new(-4.11, 0, 10.15), pos = Vector3.new(0, 0.28, 0) },
				},
			},
			{
				time = 0.6562,
				pose = {
					Root = {
						rot = Vector3.new(-8.88, 32.3, 8.96),
						pos = Vector3.new(-0.04, -0.16, -0.07),
					},
					Neck = { rot = Vector3.new(-6.12, -32.34, -6.96) },
					RightShoulder = { rot = Vector3.new(8.39, 0, 13.7) },
					LeftShoulder = { rot = Vector3.new(25.47, 0, -14.2) },
					RightHip = {
						rot = Vector3.new(11.04, 0, -12.88),
						pos = Vector3.new(0, 0.19, 0),
					},
					LeftHip = { rot = Vector3.new(-7.21, 0, 14.2), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 0.6875,
				pose = {
					Root = {
						rot = Vector3.new(-8.69, 30.9, 8.77),
						pos = Vector3.new(-0.05, -0.1, -0.07),
					},
					Neck = { rot = Vector3.new(-5.92, -30.94, -6.7) },
					RightShoulder = { rot = Vector3.new(6.05, 0, 13.33) },
					LeftShoulder = { rot = Vector3.new(27.32, 0, -12.76) },
					RightHip = { rot = Vector3.new(15.94, 0, -19.22) },
					LeftHip = { rot = Vector3.new(-9.83, 0, 18.02), pos = Vector3.new(0, 0.07, 0) },
				},
			},
			{
				time = 0.7188,
				pose = {
					Root = {
						rot = Vector3.new(-8.59, 29.94, 8.55),
						pos = Vector3.new(-0.06, -0.06, -0.08),
					},
					Neck = { rot = Vector3.new(-5.69, -30, -6.39) },
					RightShoulder = { rot = Vector3.new(4.19, 0, 13.19) },
					LeftShoulder = { rot = Vector3.new(28.84, 0, -11.63) },
					RightHip = { rot = Vector3.new(18.57, 0, -22.41), pos = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(-11.84, 0, 20.4) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(-8.58, 29.35, 8.28),
						pos = Vector3.new(-0.06, -0.05, -0.09),
					},
					Neck = { rot = Vector3.new(-5.41, -29.43, -6.02) },
					RightShoulder = { rot = Vector3.new(2.78, 0, 13.26) },
					LeftShoulder = { rot = Vector3.new(30.09, 0, -10.76) },
					RightHip = { rot = Vector3.new(20.26, 0, -24.54) },
					LeftHip = { rot = Vector3.new(-13.85, 0, 23.03) },
				},
			},
			{
				time = 0.7812,
				pose = {
					Root = {
						rot = Vector3.new(-8.65, 29.02, 7.95),
						pos = Vector3.new(-0.07, -0.06, -0.1),
					},
					Neck = { rot = Vector3.new(-5.09, -29.15, -5.57) },
					RightShoulder = { rot = Vector3.new(1.85, 0, 13.53) },
					LeftShoulder = { rot = Vector3.new(31.05, 0, -10.12) },
					RightHip = { rot = Vector3.new(21.04, 0, -25.85) },
					LeftHip = { rot = Vector3.new(-16.1, 0, 25.31), pos = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.8125,
				pose = {
					Root = {
						rot = Vector3.new(-8.76, 28.9, 7.6),
						pos = Vector3.new(-0.06, -0.07, -0.11),
					},
					Neck = { rot = Vector3.new(-4.74, -29.07, -5.09) },
					RightShoulder = { rot = Vector3.new(1.5, 0, 13.94) },
					LeftShoulder = { rot = Vector3.new(31.63, 0, -9.89) },
					RightHip = { rot = Vector3.new(20.96, 0, -25.57) },
					LeftHip = {
						rot = Vector3.new(-18.38, 0, 27.26),
						pos = Vector3.new(0, -0.01, 0),
					},
				},
			},
			{
				time = 0.8438,
				pose = {
					Root = {
						rot = Vector3.new(-8.9, 28.92, 7.25),
						pos = Vector3.new(-0.05, -0.12, -0.12),
					},
					Neck = { rot = Vector3.new(-4.39, -29.15, -4.62) },
					RightShoulder = { rot = Vector3.new(1.96, 0, 14.41) },
					LeftShoulder = { rot = Vector3.new(31.64, 0, -10.35) },
					RightHip = { rot = Vector3.new(18.62, 0, -24.42) },
					LeftHip = { rot = Vector3.new(-19.79, 0, 27.46), pos = Vector3.new(0, 0.05, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = {
						rot = Vector3.new(-9.05, 29.08, 6.93),
						pos = Vector3.new(-0.03, -0.19, -0.13),
					},
					Neck = { rot = Vector3.new(-4.07, -29.36, -4.18) },
					RightShoulder = { rot = Vector3.new(3.42, 0, 14.89) },
					LeftShoulder = { rot = Vector3.new(30.86, 0, -11.73) },
					RightHip = {
						rot = Vector3.new(13.48, 0, -22.17),
						pos = Vector3.new(0, 0.04, 0),
					},
					LeftHip = { rot = Vector3.new(-17.53, 0, 23.83), pos = Vector3.new(0, 0.26, 0) },
				},
			},
			{
				time = 0.9062,
				pose = {
					Root = {
						rot = Vector3.new(-9.24, 29.43, 6.61),
						pos = Vector3.new(-0.02, -0.24, -0.15),
					},
					Neck = { rot = Vector3.new(-3.73, -29.78, -3.71) },
					RightShoulder = { rot = Vector3.new(6.35, 0, 15.22) },
					LeftShoulder = { rot = Vector3.new(28.82, 0, -14.34) },
					RightHip = { rot = Vector3.new(8.64, 0, -17.66), pos = Vector3.new(0, 0.13, 0) },
					LeftHip = { rot = Vector3.new(-12.86, 0, 17.86), pos = Vector3.new(0, 0.49, 0) },
				},
			},
			{
				time = 0.9375,
				pose = {
					Root = {
						rot = Vector3.new(-9.48, 30, 6.24),
						pos = Vector3.new(0, -0.27, -0.16),
					},
					Neck = { rot = Vector3.new(-3.34, -30.43, -3.17) },
					RightShoulder = { rot = Vector3.new(10.91, 0, 15.08) },
					LeftShoulder = { rot = Vector3.new(25.04, 0, -18.13) },
					RightHip = { rot = Vector3.new(6.28, 0, -12.51), pos = Vector3.new(0, 0.21, 0) },
					LeftHip = { rot = Vector3.new(-11.88, 0, 12.89), pos = Vector3.new(0, 0.63, 0) },
				},
			},
			{
				time = 0.9688,
				pose = {
					Root = {
						rot = Vector3.new(-9.66, 30.64, 5.99),
						pos = Vector3.new(0.01, -0.28, -0.17),
					},
					Neck = { rot = Vector3.new(-3.07, -31.13, -2.79) },
					RightShoulder = { rot = Vector3.new(15.43, 0, 14.24) },
					LeftShoulder = { rot = Vector3.new(20.54, 0, -21.48) },
					RightHip = { rot = Vector3.new(3.73, 0, -8.18), pos = Vector3.new(0, 0.27, 0) },
					LeftHip = { rot = Vector3.new(-9.61, 0, 8.97), pos = Vector3.new(0, 0.71, 0) },
				},
			},
		},
	},
	-- ALS_N_Run_RF: phase clip (one cycle = 1), left foot plants at 0.4375; natural cycle 0.800 s, stride 5.90 studs per cycle
	JogRight = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-10.38, -39.78, -9.15),
						pos = Vector3.new(0.02, -0.27, -0.08),
					},
					Neck = { rot = Vector3.new(-6.01, 40.21, 6.79) },
					RightShoulder = { rot = Vector3.new(-0.44, 0, 28.01) },
					LeftShoulder = { rot = Vector3.new(33.12, 0, -9.33) },
					RightHip = { rot = Vector3.new(10.16, 0, 5.5), pos = Vector3.new(0, 0.36, 0) },
					LeftHip = {
						rot = Vector3.new(-12.94, 0, -16.64),
						pos = Vector3.new(0, 0.65, 0),
					},
				},
			},
			{
				time = 0.0312,
				pose = {
					Root = {
						rot = Vector3.new(-10.21, -38.97, -9.5),
						pos = Vector3.new(0.02, -0.28, -0.07),
					},
					Neck = { rot = Vector3.new(-6.36, 39.3, 7.32) },
					RightShoulder = { rot = Vector3.new(6.95, 0, 26.35) },
					LeftShoulder = { rot = Vector3.new(27.89, 0, -12.29) },
					RightHip = { rot = Vector3.new(6.7, 0, 1.93), pos = Vector3.new(0, 0.34, 0) },
					LeftHip = { rot = Vector3.new(-9.16, 0, -11.68), pos = Vector3.new(0, 0.66, 0) },
				},
			},
			{
				time = 0.0625,
				pose = {
					Root = {
						rot = Vector3.new(-9.97, -37.75, -9.66),
						pos = Vector3.new(0.02, -0.28, -0.07),
					},
					Neck = { rot = Vector3.new(-6.53, 37.99, 7.58) },
					RightShoulder = { rot = Vector3.new(14.44, 0, 22.77) },
					LeftShoulder = { rot = Vector3.new(21.35, 0, -14.46) },
					RightHip = { rot = Vector3.new(3.03, 0, -1.78), pos = Vector3.new(0, 0.35, 0) },
					LeftHip = { rot = Vector3.new(-4.69, 0, -6.09), pos = Vector3.new(0, 0.62, 0) },
				},
			},
			{
				time = 0.0938,
				pose = {
					Root = {
						rot = Vector3.new(-9.65, -36.08, -9.61),
						pos = Vector3.new(0.03, -0.26, -0.06),
					},
					Neck = { rot = Vector3.new(-6.49, 36.26, 7.55) },
					RightShoulder = { rot = Vector3.new(19.84, 0, 18.77) },
					LeftShoulder = { rot = Vector3.new(15.5, 0, -15.04) },
					RightHip = { rot = Vector3.new(-0.71, 0, -5.7), pos = Vector3.new(0, 0.34, 0) },
					LeftHip = { rot = Vector3.new(0.38, 0, -0.01), pos = Vector3.new(0, 0.53, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = {
						rot = Vector3.new(-9.32, -34.12, -9.47),
						pos = Vector3.new(0.03, -0.22, -0.06),
					},
					Neck = { rot = Vector3.new(-6.33, 34.26, 7.36) },
					RightShoulder = { rot = Vector3.new(23.12, 0, 15.83) },
					LeftShoulder = { rot = Vector3.new(11.34, 0, -14.62) },
					RightHip = { rot = Vector3.new(-4.15, 0, -9.7), pos = Vector3.new(0, 0.28, 0) },
					LeftHip = { rot = Vector3.new(5.79, 0, 6.49), pos = Vector3.new(0, 0.39, 0) },
				},
			},
			{
				time = 0.1562,
				pose = {
					Root = {
						rot = Vector3.new(-9.05, -32.28, -9.29),
						pos = Vector3.new(0.04, -0.16, -0.07),
					},
					Neck = { rot = Vector3.new(-6.12, 32.41, 7.1) },
					RightShoulder = { rot = Vector3.new(25.44, 0, 13.84) },
					LeftShoulder = { rot = Vector3.new(8.33, 0, -14.06) },
					RightHip = {
						rot = Vector3.new(-7.16, 0, -13.83),
						pos = Vector3.new(0, 0.18, 0),
					},
					LeftHip = { rot = Vector3.new(11.27, 0, 13.34), pos = Vector3.new(0, 0.19, 0) },
				},
			},
			{
				time = 0.1875,
				pose = {
					Root = {
						rot = Vector3.new(-8.88, -30.88, -9.1),
						pos = Vector3.new(0.05, -0.1, -0.07),
					},
					Neck = { rot = Vector3.new(-5.9, 31.01, 6.82) },
					RightShoulder = { rot = Vector3.new(27.28, 0, 12.38) },
					LeftShoulder = { rot = Vector3.new(5.99, 0, -13.66) },
					RightHip = {
						rot = Vector3.new(-9.67, 0, -17.73),
						pos = Vector3.new(0, 0.07, 0),
					},
					LeftHip = { rot = Vector3.new(16.16, 0, 19.53) },
				},
			},
			{
				time = 0.2188,
				pose = {
					Root = {
						rot = Vector3.new(-8.8, -29.93, -8.89),
						pos = Vector3.new(0.06, -0.06, -0.08),
					},
					Neck = { rot = Vector3.new(-5.65, 30.07, 6.51) },
					RightShoulder = { rot = Vector3.new(28.78, 0, 11.24) },
					LeftShoulder = { rot = Vector3.new(4.14, 0, -13.5) },
					RightHip = { rot = Vector3.new(-11.66, 0, -20.21), pos = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(18.8, 0, 22.64), pos = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(-8.8, -29.33, -8.62),
						pos = Vector3.new(0.07, -0.05, -0.09),
					},
					Neck = { rot = Vector3.new(-5.37, 29.5, 6.13) },
					RightShoulder = { rot = Vector3.new(30.01, 0, 10.33) },
					LeftShoulder = { rot = Vector3.new(2.72, 0, -13.55) },
					RightHip = { rot = Vector3.new(-13.67, 0, -22.82) },
					LeftHip = { rot = Vector3.new(20.49, 0, 24.72) },
				},
			},
			{
				time = 0.2812,
				pose = {
					Root = {
						rot = Vector3.new(-8.87, -29, -8.29),
						pos = Vector3.new(0.07, -0.06, -0.1),
					},
					Neck = { rot = Vector3.new(-5.04, 29.22, 5.69) },
					RightShoulder = { rot = Vector3.new(30.97, 0, 9.67) },
					LeftShoulder = { rot = Vector3.new(1.79, 0, -13.81) },
					RightHip = {
						rot = Vector3.new(-15.88, 0, -25.05),
						pos = Vector3.new(0, 0.01, 0),
					},
					LeftHip = { rot = Vector3.new(21.27, 0, 26.01) },
				},
			},
			{
				time = 0.3125,
				pose = {
					Root = {
						rot = Vector3.new(-8.99, -28.88, -7.94),
						pos = Vector3.new(0.06, -0.07, -0.11),
					},
					Neck = { rot = Vector3.new(-4.69, 29.15, 5.21) },
					RightShoulder = { rot = Vector3.new(31.55, 0, 9.42) },
					LeftShoulder = { rot = Vector3.new(1.45, 0, -14.21) },
					RightHip = {
						rot = Vector3.new(-18.28, 0, -27.02),
						pos = Vector3.new(0, -0.02, 0),
					},
					LeftHip = { rot = Vector3.new(21.18, 0, 25.73) },
				},
			},
			{
				time = 0.3438,
				pose = {
					Root = {
						rot = Vector3.new(-9.12, -28.9, -7.6),
						pos = Vector3.new(0.05, -0.12, -0.12),
					},
					Neck = { rot = Vector3.new(-4.35, 29.23, 4.74) },
					RightShoulder = { rot = Vector3.new(31.54, 0, 9.87) },
					LeftShoulder = { rot = Vector3.new(1.91, 0, -14.68) },
					RightHip = {
						rot = Vector3.new(-19.3, 0, -26.94),
						pos = Vector3.new(0, 0.06, 0),
					},
					LeftHip = { rot = Vector3.new(18.87, 0, 24.66) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = {
						rot = Vector3.new(-9.25, -29.07, -7.28),
						pos = Vector3.new(0.04, -0.19, -0.13),
					},
					Neck = { rot = Vector3.new(-4.03, 29.44, 4.3) },
					RightShoulder = { rot = Vector3.new(30.78, 0, 11.25) },
					LeftShoulder = { rot = Vector3.new(3.37, 0, -15.16) },
					RightHip = {
						rot = Vector3.new(-17.98, 0, -23.67),
						pos = Vector3.new(0, 0.26, 0),
					},
					LeftHip = { rot = Vector3.new(13.75, 0, 22.55), pos = Vector3.new(0, 0.04, 0) },
				},
			},
			{
				time = 0.4062,
				pose = {
					Root = {
						rot = Vector3.new(-9.41, -29.42, -6.94),
						pos = Vector3.new(0.02, -0.24, -0.15),
					},
					Neck = { rot = Vector3.new(-3.71, 29.86, 3.83) },
					RightShoulder = { rot = Vector3.new(28.75, 0, 13.88) },
					LeftShoulder = { rot = Vector3.new(6.3, 0, -15.5) },
					RightHip = {
						rot = Vector3.new(-15.23, 0, -18.58),
						pos = Vector3.new(0, 0.47, 0),
					},
					LeftHip = { rot = Vector3.new(8.86, 0, 18.11), pos = Vector3.new(0, 0.12, 0) },
				},
			},
			{
				time = 0.4375,
				pose = {
					Root = {
						rot = Vector3.new(-9.59, -30, -6.55),
						pos = Vector3.new(0, -0.27, -0.16),
					},
					Neck = { rot = Vector3.new(-3.35, 30.51, 3.3) },
					RightShoulder = { rot = Vector3.new(25, 0, 17.7) },
					LeftShoulder = { rot = Vector3.new(10.87, 0, -15.38) },
					RightHip = {
						rot = Vector3.new(-11.7, 0, -12.41),
						pos = Vector3.new(0, 0.63, 0),
					},
					LeftHip = { rot = Vector3.new(6.44, 0, 13.03), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.4688,
				pose = {
					Root = {
						rot = Vector3.new(-9.72, -30.64, -6.28),
						pos = Vector3.new(-0.01, -0.28, -0.16),
					},
					Neck = { rot = Vector3.new(-3.11, 31.2, 2.92) },
					RightShoulder = { rot = Vector3.new(20.52, 0, 21.08) },
					LeftShoulder = { rot = Vector3.new(15.41, 0, -14.55) },
					RightHip = { rot = Vector3.new(-8.99, 0, -8.25), pos = Vector3.new(0, 0.71, 0) },
					LeftHip = { rot = Vector3.new(3.84, 0, 8.75), pos = Vector3.new(0, 0.26, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-9.83, -31.44, -6.11),
						pos = Vector3.new(-0.02, -0.28, -0.17),
					},
					Neck = { rot = Vector3.new(-2.97, 32.05, 2.69) },
					RightShoulder = { rot = Vector3.new(15.26, 0, 23.7) },
					LeftShoulder = { rot = Vector3.new(19.79, 0, -13) },
					RightHip = { rot = Vector3.new(-6.48, 0, -5.39), pos = Vector3.new(0, 0.74, 0) },
					LeftHip = { rot = Vector3.new(1, 0, 4.87), pos = Vector3.new(0, 0.29, 0) },
				},
			},
			{
				time = 0.5312,
				pose = {
					Root = {
						rot = Vector3.new(-9.93, -32.51, -6),
						pos = Vector3.new(-0.02, -0.27, -0.17),
					},
					Neck = { rot = Vector3.new(-2.91, 33.15, 2.54) },
					RightShoulder = { rot = Vector3.new(9.65, 0, 25.49) },
					LeftShoulder = { rot = Vector3.new(23.9, 0, -11.04) },
					RightHip = { rot = Vector3.new(-3.56, 0, -2.82), pos = Vector3.new(0, 0.74, 0) },
					LeftHip = { rot = Vector3.new(-1.69, 0, 1.21), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.5625,
				pose = {
					Root = {
						rot = Vector3.new(-10.04, -33.81, -5.97),
						pos = Vector3.new(-0.02, -0.26, -0.17),
					},
					Neck = { rot = Vector3.new(-2.91, 34.48, 2.49) },
					RightShoulder = { rot = Vector3.new(4.97, 0, 26.26) },
					LeftShoulder = { rot = Vector3.new(27.08, 0, -9.33) },
					RightHip = { rot = Vector3.new(-0.36, 0, -0.5), pos = Vector3.new(0, 0.7, 0) },
					LeftHip = { rot = Vector3.new(-4.39, 0, -1.63), pos = Vector3.new(0, 0.33, 0) },
				},
			},
			{
				time = 0.5938,
				pose = {
					Root = {
						rot = Vector3.new(-10.16, -35.22, -6),
						pos = Vector3.new(-0.02, -0.23, -0.17),
					},
					Neck = { rot = Vector3.new(-2.96, 35.91, 2.53) },
					RightShoulder = { rot = Vector3.new(1.41, 0, 26.38) },
					LeftShoulder = { rot = Vector3.new(29.46, 0, -8.08) },
					RightHip = { rot = Vector3.new(3.02, 0, 1.94), pos = Vector3.new(0, 0.61, 0) },
					LeftHip = { rot = Vector3.new(-7.1, 0, -4.21), pos = Vector3.new(0, 0.34, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = {
						rot = Vector3.new(-10.29, -36.6, -6.08),
						pos = Vector3.new(-0.02, -0.19, -0.17),
					},
					Neck = { rot = Vector3.new(-3.05, 37.3, 2.61) },
					RightShoulder = { rot = Vector3.new(-1.34, 0, 26.32) },
					LeftShoulder = { rot = Vector3.new(31.4, 0, -7.24) },
					RightHip = { rot = Vector3.new(6.54, 0, 4.85), pos = Vector3.new(0, 0.5, 0) },
					LeftHip = { rot = Vector3.new(-9.65, 0, -7.1), pos = Vector3.new(0, 0.33, 0) },
				},
			},
			{
				time = 0.6562,
				pose = {
					Root = {
						rot = Vector3.new(-10.41, -37.8, -6.19),
						pos = Vector3.new(-0.01, -0.14, -0.17),
					},
					Neck = { rot = Vector3.new(-3.15, 38.51, 2.74) },
					RightShoulder = { rot = Vector3.new(-3.54, 0, 26.22) },
					LeftShoulder = { rot = Vector3.new(33.03, 0, -6.62) },
					RightHip = { rot = Vector3.new(10.12, 0, 8.09), pos = Vector3.new(0, 0.38, 0) },
					LeftHip = { rot = Vector3.new(-11.8, 0, -9.87), pos = Vector3.new(0, 0.31, 0) },
				},
			},
			{
				time = 0.6875,
				pose = {
					Root = {
						rot = Vector3.new(-10.5, -38.75, -6.33),
						pos = Vector3.new(-0.01, -0.09, -0.17),
					},
					Neck = { rot = Vector3.new(-3.27, 39.47, 2.9) },
					RightShoulder = { rot = Vector3.new(-5.36, 0, 26.15) },
					LeftShoulder = { rot = Vector3.new(34.42, 0, -6.12) },
					RightHip = { rot = Vector3.new(13.41, 0, 11.11), pos = Vector3.new(0, 0.3, 0) },
					LeftHip = {
						rot = Vector3.new(-13.52, 0, -12.44),
						pos = Vector3.new(0, 0.28, 0),
					},
				},
			},
			{
				time = 0.7188,
				pose = {
					Root = {
						rot = Vector3.new(-10.57, -39.48, -6.5),
						pos = Vector3.new(0, -0.07, -0.16),
					},
					Neck = { rot = Vector3.new(-3.42, 40.19, 3.11) },
					RightShoulder = { rot = Vector3.new(-6.89, 0, 26.14) },
					LeftShoulder = { rot = Vector3.new(35.63, 0, -5.68) },
					RightHip = { rot = Vector3.new(15.94, 0, 13.35), pos = Vector3.new(0, 0.28, 0) },
					LeftHip = {
						rot = Vector3.new(-14.94, 0, -15.03),
						pos = Vector3.new(0, 0.27, 0),
					},
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(-10.62, -40, -6.7),
						pos = Vector3.new(0.01, -0.06, -0.16),
					},
					Neck = { rot = Vector3.new(-3.61, 40.71, 3.37) },
					RightShoulder = { rot = Vector3.new(-8.16, 0, 26.2) },
					LeftShoulder = { rot = Vector3.new(36.65, 0, -5.29) },
					RightHip = { rot = Vector3.new(17.87, 0, 14.98), pos = Vector3.new(0, 0.29, 0) },
					LeftHip = {
						rot = Vector3.new(-16.01, 0, -17.48),
						pos = Vector3.new(0, 0.27, 0),
					},
				},
			},
			{
				time = 0.7812,
				pose = {
					Root = {
						rot = Vector3.new(-10.64, -40.36, -6.94),
						pos = Vector3.new(0.01, -0.05, -0.15),
					},
					Neck = { rot = Vector3.new(-3.85, 41.06, 3.7) },
					RightShoulder = { rot = Vector3.new(-9.18, 0, 26.33) },
					LeftShoulder = { rot = Vector3.new(37.49, 0, -4.94) },
					RightHip = { rot = Vector3.new(19.33, 0, 16.2), pos = Vector3.new(0, 0.29, 0) },
					LeftHip = {
						rot = Vector3.new(-16.75, 0, -19.61),
						pos = Vector3.new(0, 0.27, 0),
					},
				},
			},
			{
				time = 0.8125,
				pose = {
					Root = {
						rot = Vector3.new(-10.64, -40.59, -7.22),
						pos = Vector3.new(0.02, -0.05, -0.14),
					},
					Neck = { rot = Vector3.new(-4.11, 41.27, 4.07) },
					RightShoulder = { rot = Vector3.new(-9.95, 0, 26.54) },
					LeftShoulder = { rot = Vector3.new(38.17, 0, -4.64) },
					RightHip = { rot = Vector3.new(20.23, 0, 16.93), pos = Vector3.new(0, 0.3, 0) },
					LeftHip = {
						rot = Vector3.new(-17.22, 0, -21.36),
						pos = Vector3.new(0, 0.27, 0),
					},
				},
			},
			{
				time = 0.8438,
				pose = {
					Root = {
						rot = Vector3.new(-10.63, -40.7, -7.52),
						pos = Vector3.new(0.02, -0.06, -0.13),
					},
					Neck = { rot = Vector3.new(-4.4, 41.36, 4.48) },
					RightShoulder = { rot = Vector3.new(-10.37, 0, 26.82) },
					LeftShoulder = { rot = Vector3.new(38.61, 0, -4.46) },
					RightHip = { rot = Vector3.new(20.53, 0, 17.09), pos = Vector3.new(0, 0.32, 0) },
					LeftHip = {
						rot = Vector3.new(-17.43, 0, -22.55),
						pos = Vector3.new(0, 0.29, 0),
					},
				},
			},
			{
				time = 0.875,
				pose = {
					Root = {
						rot = Vector3.new(-10.61, -40.73, -7.82),
						pos = Vector3.new(0.02, -0.08, -0.12),
					},
					Neck = { rot = Vector3.new(-4.7, 41.37, 4.9) },
					RightShoulder = { rot = Vector3.new(-10.36, 0, 27.14) },
					LeftShoulder = { rot = Vector3.new(38.78, 0, -4.47) },
					RightHip = { rot = Vector3.new(20.21, 0, 16.59), pos = Vector3.new(0, 0.33, 0) },
					LeftHip = {
						rot = Vector3.new(-17.42, 0, -23.11),
						pos = Vector3.new(0, 0.35, 0),
					},
				},
			},
			{
				time = 0.9062,
				pose = {
					Root = {
						rot = Vector3.new(-10.59, -40.71, -8.09),
						pos = Vector3.new(0.03, -0.12, -0.11),
					},
					Neck = { rot = Vector3.new(-4.97, 41.31, 5.28) },
					RightShoulder = { rot = Vector3.new(-9.98, 0, 27.47) },
					LeftShoulder = { rot = Vector3.new(38.7, 0, -4.68) },
					RightHip = { rot = Vector3.new(19.09, 0, 15.23), pos = Vector3.new(0, 0.36, 0) },
					LeftHip = {
						rot = Vector3.new(-17.42, 0, -23.25),
						pos = Vector3.new(0, 0.41, 0),
					},
				},
			},
			{
				time = 0.9375,
				pose = {
					Root = {
						rot = Vector3.new(-10.56, -40.59, -8.37),
						pos = Vector3.new(0.03, -0.17, -0.11),
					},
					Neck = { rot = Vector3.new(-5.24, 41.16, 5.68) },
					RightShoulder = { rot = Vector3.new(-8.69, 0, 27.81) },
					LeftShoulder = { rot = Vector3.new(38.05, 0, -5.36) },
					RightHip = { rot = Vector3.new(16.9, 0, 12.77), pos = Vector3.new(0, 0.38, 0) },
					LeftHip = {
						rot = Vector3.new(-17.09, 0, -22.63),
						pos = Vector3.new(0, 0.49, 0),
					},
				},
			},
			{
				time = 0.9688,
				pose = {
					Root = {
						rot = Vector3.new(-10.49, -40.3, -8.74),
						pos = Vector3.new(0.02, -0.23, -0.09),
					},
					Neck = { rot = Vector3.new(-5.6, 40.81, 6.2) },
					RightShoulder = { rot = Vector3.new(-5.61, 0, 28.15) },
					LeftShoulder = { rot = Vector3.new(36.3, 0, -6.91) },
					RightHip = { rot = Vector3.new(13.6, 0, 9.19), pos = Vector3.new(0, 0.4, 0) },
					LeftHip = { rot = Vector3.new(-15.73, 0, -20.5), pos = Vector3.new(0, 0.59, 0) },
				},
			},
		},
	},
	-- ALS_N_Sprint_F: phase clip (one cycle = 1), left foot plants at 0.4375; natural cycle 0.600 s, stride 7.64 studs per cycle
	Sprint = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-17.82, -3.14, -2.87),
						pos = Vector3.new(0.05, -0.28, -0.37),
					},
					Neck = { rot = Vector3.new(13.41, 3.66, 2.02) },
					RightShoulder = { rot = Vector3.new(45.82, 0, 12.16) },
					LeftShoulder = { rot = Vector3.new(33.09, 0, -20.54) },
					RightHip = { rot = Vector3.new(10.47, 0, -1.14), pos = Vector3.new(0, 0.31, 0) },
					LeftHip = { rot = Vector3.new(-14.31, 0, 2.92), pos = Vector3.new(0, 0.97, 0) },
				},
			},
			{
				time = 0.0312,
				pose = {
					Root = {
						rot = Vector3.new(-18.4, -1.74, -3.19),
						pos = Vector3.new(0.06, -0.29, -0.37),
					},
					Neck = { rot = Vector3.new(13.99, 2.33, 2.64) },
					RightShoulder = { rot = Vector3.new(53.6, 0, 8.68) },
					LeftShoulder = { rot = Vector3.new(19.56, 0, -22.93) },
					RightHip = { rot = Vector3.new(4.1, 0, -0.08), pos = Vector3.new(0, 0.34, 0) },
					LeftHip = { rot = Vector3.new(-8.03, 0, 2.52), pos = Vector3.new(0, 1.02, 0) },
				},
			},
			{
				time = 0.0625,
				pose = {
					Root = {
						rot = Vector3.new(-18.49, -0.32, -3.34),
						pos = Vector3.new(0.06, -0.29, -0.38),
					},
					Neck = { rot = Vector3.new(14.11, 0.94, 3.15) },
					RightShoulder = { rot = Vector3.new(60.02, 0, 5.72) },
					LeftShoulder = { rot = Vector3.new(5.65, 0, -24.69) },
					RightHip = { rot = Vector3.new(-2.72, 0, 0.41), pos = Vector3.new(0, 0.34, 0) },
					LeftHip = { rot = Vector3.new(-2.11, 0, 2.44), pos = Vector3.new(0, 1.01, 0) },
				},
			},
			{
				time = 0.0938,
				pose = {
					Root = {
						rot = Vector3.new(-18.1, 1.09, -3.34),
						pos = Vector3.new(0.06, -0.28, -0.37),
					},
					Neck = { rot = Vector3.new(13.8, -0.49, 3.52) },
					RightShoulder = { rot = Vector3.new(65.74, 0, 2.91) },
					LeftShoulder = { rot = Vector3.new(-7.36, 0, -26.03) },
					RightHip = { rot = Vector3.new(-9.52, 0, 0.25), pos = Vector3.new(0, 0.3, 0) },
					LeftHip = { rot = Vector3.new(3.07, 0, 2.75), pos = Vector3.new(0, 0.96, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = {
						rot = Vector3.new(-17.4, 2.45, -3.22),
						pos = Vector3.new(0.06, -0.27, -0.37),
					},
					Neck = { rot = Vector3.new(13.19, -1.91, 3.73) },
					RightShoulder = { rot = Vector3.new(70.97, 0, 0.05) },
					LeftShoulder = { rot = Vector3.new(-18.88, 0, -27.49) },
					RightHip = {
						rot = Vector3.new(-15.88, 0, -0.35),
						pos = Vector3.new(0, 0.23, 0),
					},
					LeftHip = { rot = Vector3.new(7.49, 0, 3.4), pos = Vector3.new(0, 0.89, 0) },
				},
			},
			{
				time = 0.1562,
				pose = {
					Root = {
						rot = Vector3.new(-16.51, 3.74, -3),
						pos = Vector3.new(0.05, -0.25, -0.37),
					},
					Neck = { rot = Vector3.new(12.39, -3.28, 3.77) },
					RightShoulder = { rot = Vector3.new(75.46, 0, -2.52) },
					LeftShoulder = { rot = Vector3.new(-28.43, 0, -29.16) },
					RightHip = {
						rot = Vector3.new(-21.54, 0, -1.22),
						pos = Vector3.new(0, 0.15, 0),
					},
					LeftHip = { rot = Vector3.new(11.54, 0, 4.31), pos = Vector3.new(0, 0.8, 0) },
				},
			},
			{
				time = 0.1875,
				pose = {
					Root = {
						rot = Vector3.new(-15.52, 4.92, -2.68),
						pos = Vector3.new(0.05, -0.23, -0.36),
					},
					Neck = { rot = Vector3.new(11.47, -4.55, 3.64) },
					RightShoulder = { rot = Vector3.new(78.63, 0, -4.18) },
					LeftShoulder = { rot = Vector3.new(-35.55, 0, -30.75) },
					RightHip = { rot = Vector3.new(-26.4, 0, -2.21), pos = Vector3.new(0, 0.06, 0) },
					LeftHip = { rot = Vector3.new(15.83, 0, 5.36), pos = Vector3.new(0, 0.67, 0) },
				},
			},
			{
				time = 0.2188,
				pose = {
					Root = {
						rot = Vector3.new(-14.56, 5.94, -2.28),
						pos = Vector3.new(0.04, -0.2, -0.35),
					},
					Neck = { rot = Vector3.new(10.53, -5.68, 3.36) },
					RightShoulder = { rot = Vector3.new(79.84, 0, -4.33) },
					LeftShoulder = { rot = Vector3.new(-39.38, 0, -32) },
					RightHip = {
						rot = Vector3.new(-30.95, 0, -3.26),
						pos = Vector3.new(0, -0.01, 0),
					},
					LeftHip = { rot = Vector3.new(20.6, 0, 6.51), pos = Vector3.new(0, 0.5, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(-13.73, 6.78, -1.83),
						pos = Vector3.new(0.03, -0.17, -0.35),
					},
					Neck = { rot = Vector3.new(9.67, -6.62, 2.96) },
					RightShoulder = { rot = Vector3.new(78.72, 0, -2.71) },
					LeftShoulder = { rot = Vector3.new(-39.25, 0, -32.74) },
					RightHip = {
						rot = Vector3.new(-35.4, 0, -4.29),
						pos = Vector3.new(0, -0.02, 0),
					},
					LeftHip = { rot = Vector3.new(25.61, 0, 7.57), pos = Vector3.new(0, 0.31, 0) },
				},
			},
			{
				time = 0.2812,
				pose = {
					Root = {
						rot = Vector3.new(-13.11, 7.38, -1.33),
						pos = Vector3.new(0.02, -0.15, -0.34),
					},
					Neck = { rot = Vector3.new(8.98, -7.3, 2.46) },
					RightShoulder = { rot = Vector3.new(75.83, 0, 0.01) },
					LeftShoulder = { rot = Vector3.new(-35.33, 0, -33.09) },
					RightHip = {
						rot = Vector3.new(-38.67, 0, -5.14),
						pos = Vector3.new(0, 0.02, 0),
					},
					LeftHip = { rot = Vector3.new(29.47, 0, 8.04), pos = Vector3.new(0, 0.17, 0) },
				},
			},
			{
				time = 0.3125,
				pose = {
					Root = {
						rot = Vector3.new(-12.8, 7.69, -0.79),
						pos = Vector3.new(0.01, -0.14, -0.34),
					},
					Neck = { rot = Vector3.new(8.58, -7.67, 1.89) },
					RightShoulder = { rot = Vector3.new(71.91, 0, 3.11) },
					LeftShoulder = { rot = Vector3.new(-27.97, 0, -33.04) },
					RightHip = { rot = Vector3.new(-39.84, 0, -5.66), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(31.61, 0, 7.71), pos = Vector3.new(0, 0.12, 0) },
				},
			},
			{
				time = 0.3438,
				pose = {
					Root = {
						rot = Vector3.new(-12.96, 7.65, -0.23),
						pos = Vector3.new(0, -0.14, -0.34),
					},
					Neck = { rot = Vector3.new(8.64, -7.69, 1.3) },
					RightShoulder = { rot = Vector3.new(67.71, 0, 6.08) },
					LeftShoulder = { rot = Vector3.new(-17.6, 0, -32.33) },
					RightHip = {
						rot = Vector3.new(-38.59, 0, -5.73),
						pos = Vector3.new(0, 0.22, 0),
					},
					LeftHip = { rot = Vector3.new(32.87, 0, 7.06), pos = Vector3.new(0, 0.12, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = {
						rot = Vector3.new(-13.58, 7.27, 0.35),
						pos = Vector3.new(-0.01, -0.16, -0.35),
					},
					Neck = { rot = Vector3.new(9.2, -7.36, 0.7) },
					RightShoulder = { rot = Vector3.new(63.47, 0, 8.79) },
					LeftShoulder = { rot = Vector3.new(-4.87, 0, -30.44) },
					RightHip = { rot = Vector3.new(-35.33, 0, -5.4), pos = Vector3.new(0, 0.38, 0) },
					LeftHip = { rot = Vector3.new(32.35, 0, 6.28), pos = Vector3.new(0, 0.16, 0) },
				},
			},
			{
				time = 0.4062,
				pose = {
					Root = {
						rot = Vector3.new(-14.54, 6.57, 0.94),
						pos = Vector3.new(-0.02, -0.2, -0.35),
					},
					Neck = { rot = Vector3.new(10.13, -6.72, 0.09) },
					RightShoulder = { rot = Vector3.new(58.91, 0, 11.42) },
					LeftShoulder = { rot = Vector3.new(9.3, 0, -26.8) },
					RightHip = { rot = Vector3.new(-31, 0, -4.85), pos = Vector3.new(0, 0.55, 0) },
					LeftHip = { rot = Vector3.new(28.03, 0, 5.32), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.4375,
				pose = {
					Root = {
						rot = Vector3.new(-15.67, 5.61, 1.52),
						pos = Vector3.new(-0.03, -0.23, -0.36),
					},
					Neck = { rot = Vector3.new(11.27, -5.84, -0.55) },
					RightShoulder = { rot = Vector3.new(52.96, 0, 14.17) },
					LeftShoulder = { rot = Vector3.new(23.36, 0, -21.96) },
					RightHip = {
						rot = Vector3.new(-25.98, 0, -4.21),
						pos = Vector3.new(0, 0.71, 0),
					},
					LeftHip = { rot = Vector3.new(21.68, 0, 4.18), pos = Vector3.new(0, 0.24, 0) },
				},
			},
			{
				time = 0.4688,
				pose = {
					Root = {
						rot = Vector3.new(-16.77, 4.45, 2.08),
						pos = Vector3.new(-0.04, -0.26, -0.36),
					},
					Neck = { rot = Vector3.new(12.4, -4.76, -1.23) },
					RightShoulder = { rot = Vector3.new(44.43, 0, 17.15) },
					LeftShoulder = { rot = Vector3.new(35.7, 0, -16.96) },
					RightHip = {
						rot = Vector3.new(-20.41, 0, -3.55),
						pos = Vector3.new(0, 0.86, 0),
					},
					LeftHip = { rot = Vector3.new(16, 0, 2.95), pos = Vector3.new(0, 0.27, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-17.65, 3.13, 2.55),
						pos = Vector3.new(-0.04, -0.28, -0.37),
					},
					Neck = { rot = Vector3.new(13.33, -3.54, -1.9) },
					RightShoulder = { rot = Vector3.new(33.13, 0, 20.04) },
					LeftShoulder = { rot = Vector3.new(45.73, 0, -12.56) },
					RightHip = { rot = Vector3.new(-14.38, 0, -3), pos = Vector3.new(0, 0.98, 0) },
					LeftHip = { rot = Vector3.new(10.38, 0, 1.7), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.5312,
				pose = {
					Root = {
						rot = Vector3.new(-18.15, 1.74, 2.88),
						pos = Vector3.new(-0.05, -0.28, -0.37),
					},
					Neck = { rot = Vector3.new(13.9, -2.22, -2.53) },
					RightShoulder = { rot = Vector3.new(19.68, 0, 22.51) },
					LeftShoulder = { rot = Vector3.new(53.51, 0, -9.12) },
					RightHip = { rot = Vector3.new(-8.15, 0, -2.67), pos = Vector3.new(0, 1.03, 0) },
					LeftHip = { rot = Vector3.new(3.94, 0, 0.61), pos = Vector3.new(0, 0.33, 0) },
				},
			},
			{
				time = 0.5625,
				pose = {
					Root = {
						rot = Vector3.new(-18.17, 0.32, 3.06),
						pos = Vector3.new(-0.05, -0.29, -0.37),
					},
					Neck = { rot = Vector3.new(14, -0.83, -3.07) },
					RightShoulder = { rot = Vector3.new(5.81, 0, 24.36) },
					LeftShoulder = { rot = Vector3.new(59.91, 0, -6.21) },
					RightHip = { rot = Vector3.new(-2.28, 0, -2.64), pos = Vector3.new(0, 1.01, 0) },
					LeftHip = { rot = Vector3.new(-2.96, 0, 0.05), pos = Vector3.new(0, 0.33, 0) },
				},
			},
			{
				time = 0.5938,
				pose = {
					Root = {
						rot = Vector3.new(-17.73, -1.08, 3.09),
						pos = Vector3.new(-0.05, -0.28, -0.37),
					},
					Neck = { rot = Vector3.new(13.68, 0.58, -3.47) },
					RightShoulder = { rot = Vector3.new(-7.19, 0, 25.78) },
					LeftShoulder = { rot = Vector3.new(65.59, 0, -3.43) },
					RightHip = { rot = Vector3.new(2.86, 0, -2.93), pos = Vector3.new(0, 0.96, 0) },
					LeftHip = { rot = Vector3.new(-9.82, 0, 0.13), pos = Vector3.new(0, 0.29, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = {
						rot = Vector3.new(-17.02, -2.44, 3.01),
						pos = Vector3.new(-0.05, -0.27, -0.37),
					},
					Neck = { rot = Vector3.new(13.09, 1.99, -3.7) },
					RightShoulder = { rot = Vector3.new(-18.72, 0, 27.33) },
					LeftShoulder = { rot = Vector3.new(70.8, 0, -0.61) },
					RightHip = { rot = Vector3.new(7.24, 0, -3.51), pos = Vector3.new(0, 0.89, 0) },
					LeftHip = { rot = Vector3.new(-16.23, 0, 0.63), pos = Vector3.new(0, 0.23, 0) },
				},
			},
			{
				time = 0.6562,
				pose = {
					Root = {
						rot = Vector3.new(-16.16, -3.73, 2.82),
						pos = Vector3.new(-0.05, -0.25, -0.36),
					},
					Neck = { rot = Vector3.new(12.33, 3.34, -3.77) },
					RightShoulder = { rot = Vector3.new(-28.3, 0, 29.05) },
					LeftShoulder = { rot = Vector3.new(75.28, 0, 1.93) },
					RightHip = { rot = Vector3.new(11.27, 0, -4.3), pos = Vector3.new(0, 0.8, 0) },
					LeftHip = { rot = Vector3.new(-21.89, 0, 1.41), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.6875,
				pose = {
					Root = {
						rot = Vector3.new(-15.22, -4.91, 2.52),
						pos = Vector3.new(-0.04, -0.23, -0.36),
					},
					Neck = { rot = Vector3.new(11.47, 4.61, -3.66) },
					RightShoulder = { rot = Vector3.new(-35.43, 0, 30.68) },
					LeftShoulder = { rot = Vector3.new(78.49, 0, 3.57) },
					RightHip = { rot = Vector3.new(15.55, 0, -5.22), pos = Vector3.new(0, 0.68, 0) },
					LeftHip = { rot = Vector3.new(-26.71, 0, 2.36), pos = Vector3.new(0, 0.06, 0) },
				},
			},
			{
				time = 0.7188,
				pose = {
					Root = {
						rot = Vector3.new(-14.32, -5.94, 2.14),
						pos = Vector3.new(-0.04, -0.2, -0.35),
					},
					Neck = { rot = Vector3.new(10.59, 5.74, -3.4) },
					RightShoulder = { rot = Vector3.new(-39.25, 0, 31.94) },
					LeftShoulder = { rot = Vector3.new(79.75, 0, 3.71) },
					RightHip = { rot = Vector3.new(20.33, 0, -6.23), pos = Vector3.new(0, 0.51, 0) },
					LeftHip = { rot = Vector3.new(-31.18, 0, 3.41), pos = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(-13.55, -6.78, 1.67),
						pos = Vector3.new(-0.03, -0.17, -0.35),
					},
					Neck = { rot = Vector3.new(9.79, 6.69, -3) },
					RightShoulder = { rot = Vector3.new(-39.1, 0, 32.68) },
					LeftShoulder = { rot = Vector3.new(78.69, 0, 2.08) },
					RightHip = { rot = Vector3.new(25.35, 0, -7.22), pos = Vector3.new(0, 0.32, 0) },
					LeftHip = { rot = Vector3.new(-35.54, 0, 4.46), pos = Vector3.new(0, -0.02, 0) },
				},
			},
			{
				time = 0.7812,
				pose = {
					Root = {
						rot = Vector3.new(-12.98, -7.38, 1.15),
						pos = Vector3.new(-0.02, -0.15, -0.34),
					},
					Neck = { rot = Vector3.new(9.14, 7.39, -2.5) },
					RightShoulder = { rot = Vector3.new(-35.13, 0, 33) },
					LeftShoulder = { rot = Vector3.new(75.88, 0, -0.65) },
					RightHip = { rot = Vector3.new(29.26, 0, -7.67), pos = Vector3.new(0, 0.18, 0) },
					LeftHip = { rot = Vector3.new(-38.77, 0, 5.35), pos = Vector3.new(0, 0.02, 0) },
				},
			},
			{
				time = 0.8125,
				pose = {
					Root = {
						rot = Vector3.new(-12.73, -7.69, 0.58),
						pos = Vector3.new(-0.01, -0.14, -0.34),
					},
					Neck = { rot = Vector3.new(8.77, 7.78, -1.91) },
					RightShoulder = { rot = Vector3.new(-27.71, 0, 32.93) },
					LeftShoulder = { rot = Vector3.new(72.03, 0, -3.76) },
					RightHip = { rot = Vector3.new(31.47, 0, -7.41), pos = Vector3.new(0, 0.12, 0) },
					LeftHip = { rot = Vector3.new(-39.94, 0, 5.9), pos = Vector3.new(0, 0.09, 0) },
				},
			},
			{
				time = 0.8438,
				pose = {
					Root = {
						rot = Vector3.new(-12.92, -7.66, -0.01),
						pos = Vector3.new(0, -0.14, -0.34),
					},
					Neck = { rot = Vector3.new(8.84, 7.81, -1.3) },
					RightShoulder = { rot = Vector3.new(-17.3, 0, 32.18) },
					LeftShoulder = { rot = Vector3.new(67.86, 0, -6.74) },
					RightHip = { rot = Vector3.new(32.78, 0, -6.82), pos = Vector3.new(0, 0.13, 0) },
					LeftHip = { rot = Vector3.new(-38.68, 0, 5.96), pos = Vector3.new(0, 0.22, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = {
						rot = Vector3.new(-13.57, -7.28, -0.62),
						pos = Vector3.new(0.01, -0.16, -0.35),
					},
					Neck = { rot = Vector3.new(9.39, 7.48, -0.67) },
					RightShoulder = { rot = Vector3.new(-4.56, 0, 30.24) },
					LeftShoulder = { rot = Vector3.new(63.63, 0, -9.45) },
					RightHip = { rot = Vector3.new(32.29, 0, -6.04), pos = Vector3.new(0, 0.16, 0) },
					LeftHip = { rot = Vector3.new(-35.39, 0, 5.58), pos = Vector3.new(0, 0.38, 0) },
				},
			},
			{
				time = 0.9062,
				pose = {
					Root = {
						rot = Vector3.new(-14.57, -6.58, -1.23),
						pos = Vector3.new(0.02, -0.2, -0.35),
					},
					Neck = { rot = Vector3.new(10.3, 6.84, -0.02) },
					RightShoulder = { rot = Vector3.new(9.57, 0, 26.55) },
					LeftShoulder = { rot = Vector3.new(59.05, 0, -12.06) },
					RightHip = { rot = Vector3.new(28, 0, -4.99), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(-31.02, 0, 4.97), pos = Vector3.new(0, 0.55, 0) },
				},
			},
			{
				time = 0.9375,
				pose = {
					Root = {
						rot = Vector3.new(-15.73, -5.62, -1.83),
						pos = Vector3.new(0.03, -0.23, -0.36),
					},
					Neck = { rot = Vector3.new(11.4, 5.96, 0.65) },
					RightShoulder = { rot = Vector3.new(23.56, 0, 21.66) },
					LeftShoulder = { rot = Vector3.new(53.06, 0, -14.78) },
					RightHip = { rot = Vector3.new(21.67, 0, -3.72), pos = Vector3.new(0, 0.24, 0) },
					LeftHip = { rot = Vector3.new(-25.97, 0, 4.26), pos = Vector3.new(0, 0.71, 0) },
				},
			},
			{
				time = 0.9688,
				pose = {
					Root = {
						rot = Vector3.new(-16.87, -4.45, -2.4),
						pos = Vector3.new(0.04, -0.26, -0.36),
					},
					Neck = { rot = Vector3.new(12.5, 4.88, 1.34) },
					RightShoulder = { rot = Vector3.new(35.84, 0, 16.6) },
					LeftShoulder = { rot = Vector3.new(44.46, 0, -17.71) },
					RightHip = { rot = Vector3.new(16.03, 0, -2.41), pos = Vector3.new(0, 0.28, 0) },
					LeftHip = { rot = Vector3.new(-20.37, 0, 3.54), pos = Vector3.new(0, 0.86, 0) },
				},
			},
		},
	},
	-- ALS_CLF_Walk_F: phase clip (one cycle = 1), left foot plants at 0.4375; natural cycle 1.133 s, stride 3.68 studs per cycle
	CrouchWalk = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-53.98, -18.77, -10.9),
						pos = Vector3.new(0.09, -1.19, -0.3),
					},
					Neck = { rot = Vector3.new(43.69, 20.64, -5.49) },
					RightShoulder = { rot = Vector3.new(51.98, 0, 18.77) },
					LeftShoulder = { rot = Vector3.new(54.29, 0, -40.26) },
					RightHip = { rot = Vector3.new(54.66, 0, -13.73), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(7.95, 0, 2.73), pos = Vector3.new(0, 1.15, 0) },
				},
			},
			{
				time = 0.0312,
				pose = {
					Root = {
						rot = Vector3.new(-53.7, -18.9, -10.91),
						pos = Vector3.new(0.1, -1.17, -0.31),
					},
					Neck = { rot = Vector3.new(43.38, 20.75, -5.46) },
					RightShoulder = { rot = Vector3.new(54.2, 0, 18.04) },
					LeftShoulder = { rot = Vector3.new(50, 0, -39.87) },
					RightHip = {
						rot = Vector3.new(51.98, 0, -13.13),
						pos = Vector3.new(0, 1.05, 0),
					},
					LeftHip = { rot = Vector3.new(8.8, 0, 1.84), pos = Vector3.new(0, 1.17, 0) },
				},
			},
			{
				time = 0.0625,
				pose = {
					Root = {
						rot = Vector3.new(-53.46, -18.96, -10.85),
						pos = Vector3.new(0.1, -1.15, -0.31),
					},
					Neck = { rot = Vector3.new(43.12, 20.76, -5.43) },
					RightShoulder = { rot = Vector3.new(56.57, 0, 17.02) },
					LeftShoulder = { rot = Vector3.new(45.56, 0, -39.09) },
					RightHip = { rot = Vector3.new(49.59, 0, -12.35), pos = Vector3.new(0, 1, 0) },
					LeftHip = { rot = Vector3.new(10.73, 0, 0.65), pos = Vector3.new(0, 1.2, 0) },
				},
			},
			{
				time = 0.0938,
				pose = {
					Root = {
						rot = Vector3.new(-53.36, -18.95, -10.82),
						pos = Vector3.new(0.11, -1.12, -0.31),
					},
					Neck = { rot = Vector3.new(42.99, 20.75, -5.38) },
					RightShoulder = { rot = Vector3.new(59.1, 0, 15.86) },
					LeftShoulder = { rot = Vector3.new(41.22, 0, -37.91) },
					RightHip = { rot = Vector3.new(46.63, 0, -11.12), pos = Vector3.new(0, 1, 0) },
					LeftHip = { rot = Vector3.new(14.11, 0, -0.97), pos = Vector3.new(0, 1.26, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = {
						rot = Vector3.new(-53.37, -18.9, -10.83),
						pos = Vector3.new(0.11, -1.1, -0.31),
					},
					Neck = { rot = Vector3.new(42.96, 20.72, -5.32) },
					RightShoulder = { rot = Vector3.new(61.66, 0, 14.65) },
					LeftShoulder = { rot = Vector3.new(37.15, 0, -36.38) },
					RightHip = { rot = Vector3.new(43.7, 0, -9.87), pos = Vector3.new(0, 0.99, 0) },
					LeftHip = { rot = Vector3.new(17.53, 0, -2.61), pos = Vector3.new(0, 1.34, 0) },
				},
			},
			{
				time = 0.1562,
				pose = {
					Root = {
						rot = Vector3.new(-53.4, -18.83, -10.79),
						pos = Vector3.new(0.11, -1.07, -0.31),
					},
					Neck = { rot = Vector3.new(42.98, 20.65, -5.29) },
					RightShoulder = { rot = Vector3.new(64.08, 0, 13.4) },
					LeftShoulder = { rot = Vector3.new(33.45, 0, -34.62) },
					RightHip = { rot = Vector3.new(41.17, 0, -8.69), pos = Vector3.new(0, 0.97, 0) },
					LeftHip = { rot = Vector3.new(21.72, 0, -4.54), pos = Vector3.new(0, 1.41, 0) },
				},
			},
			{
				time = 0.1875,
				pose = {
					Root = {
						rot = Vector3.new(-53.46, -18.74, -10.73),
						pos = Vector3.new(0.11, -1.06, -0.31),
					},
					Neck = { rot = Vector3.new(43.05, 20.53, -5.27) },
					RightShoulder = { rot = Vector3.new(66.33, 0, 12.12) },
					LeftShoulder = { rot = Vector3.new(30.24, 0, -32.75) },
					RightHip = { rot = Vector3.new(38.71, 0, -8.37), pos = Vector3.new(0, 0.95, 0) },
					LeftHip = { rot = Vector3.new(27.86, 0, -6.9), pos = Vector3.new(0, 1.44, 0) },
				},
			},
			{
				time = 0.2188,
				pose = {
					Root = {
						rot = Vector3.new(-53.55, -18.62, -10.64),
						pos = Vector3.new(0.11, -1.06, -0.3),
					},
					Neck = { rot = Vector3.new(43.14, 20.38, -5.27) },
					RightShoulder = { rot = Vector3.new(68.34, 0, 10.89) },
					LeftShoulder = { rot = Vector3.new(27.56, 0, -30.91) },
					RightHip = { rot = Vector3.new(35.52, 0, -8.14), pos = Vector3.new(0, 0.96, 0) },
					LeftHip = { rot = Vector3.new(35.13, 0, -9.35), pos = Vector3.new(0, 1.46, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(-53.66, -18.47, -10.48),
						pos = Vector3.new(0.1, -1.07, -0.3),
					},
					Neck = { rot = Vector3.new(43.28, 20.16, -5.32) },
					RightShoulder = { rot = Vector3.new(70.05, 0, 9.75) },
					LeftShoulder = { rot = Vector3.new(25.47, 0, -29.32) },
					RightHip = { rot = Vector3.new(32.14, 0, -7.21), pos = Vector3.new(0, 0.99, 0) },
					LeftHip = { rot = Vector3.new(41.66, 0, -11.76), pos = Vector3.new(0, 1.5, 0) },
				},
			},
			{
				time = 0.2812,
				pose = {
					Root = {
						rot = Vector3.new(-53.79, -18.32, -10.15),
						pos = Vector3.new(0.1, -1.09, -0.29),
					},
					Neck = { rot = Vector3.new(43.49, 19.82, -5.5) },
					RightShoulder = { rot = Vector3.new(71.43, 0, 8.75) },
					LeftShoulder = { rot = Vector3.new(23.98, 0, -28.18) },
					RightHip = { rot = Vector3.new(28.76, 0, -6.26), pos = Vector3.new(0, 1.02, 0) },
					LeftHip = { rot = Vector3.new(45.71, 0, -13.52), pos = Vector3.new(0, 1.58, 0) },
				},
			},
			{
				time = 0.3125,
				pose = {
					Root = {
						rot = Vector3.new(-53.93, -18.15, -9.69),
						pos = Vector3.new(0.09, -1.12, -0.29),
					},
					Neck = { rot = Vector3.new(43.75, 19.38, -5.78) },
					RightShoulder = { rot = Vector3.new(72.41, 0, 8) },
					LeftShoulder = { rot = Vector3.new(23.11, 0, -27.6) },
					RightHip = { rot = Vector3.new(25.33, 0, -5.26), pos = Vector3.new(0, 1.06, 0) },
					LeftHip = { rot = Vector3.new(48.56, 0, -14.09), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.3438,
				pose = {
					Root = {
						rot = Vector3.new(-54.07, -17.95, -9.22),
						pos = Vector3.new(0.07, -1.15, -0.29),
					},
					Neck = { rot = Vector3.new(44, 18.9, -6.05) },
					RightShoulder = { rot = Vector3.new(72.97, 0, 7.55) },
					LeftShoulder = { rot = Vector3.new(22.88, 0, -27.63) },
					RightHip = { rot = Vector3.new(22.05, 0, -4.14), pos = Vector3.new(0, 1.09, 0) },
					LeftHip = { rot = Vector3.new(50.24, 0, -13), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = {
						rot = Vector3.new(-54.21, -17.74, -8.81),
						pos = Vector3.new(0.06, -1.18, -0.3),
					},
					Neck = { rot = Vector3.new(44.24, 18.46, -6.26) },
					RightShoulder = { rot = Vector3.new(73.07, 0, 7.51) },
					LeftShoulder = { rot = Vector3.new(23.34, 0, -28.27) },
					RightHip = { rot = Vector3.new(19.2, 0, -3.02), pos = Vector3.new(0, 1.11, 0) },
					LeftHip = { rot = Vector3.new(50.69, 0, -11.39), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.4062,
				pose = {
					Root = {
						rot = Vector3.new(-54.35, -17.54, -8.44),
						pos = Vector3.new(0.05, -1.2, -0.3),
					},
					Neck = { rot = Vector3.new(44.47, 18.04, -6.45) },
					RightShoulder = { rot = Vector3.new(72.87, 0, 7.83) },
					LeftShoulder = { rot = Vector3.new(24.67, 0, -29.34) },
					RightHip = { rot = Vector3.new(17.08, 0, -1.97), pos = Vector3.new(0, 1.11, 0) },
					LeftHip = { rot = Vector3.new(49.92, 0, -9.83), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.4375,
				pose = {
					Root = {
						rot = Vector3.new(-54.4, -17.36, -8.09),
						pos = Vector3.new(0.04, -1.2, -0.31),
					},
					Neck = { rot = Vector3.new(44.61, 17.67, -6.62) },
					RightShoulder = { rot = Vector3.new(72.42, 0, 8.37) },
					LeftShoulder = { rot = Vector3.new(26.78, 0, -30.6) },
					RightHip = { rot = Vector3.new(15.93, 0, -0.71), pos = Vector3.new(0, 1.12, 0) },
					LeftHip = { rot = Vector3.new(50.23, 0, -9.11), pos = Vector3.new(0, 1.57, 0) },
				},
			},
			{
				time = 0.4688,
				pose = {
					Root = {
						rot = Vector3.new(-54.32, -17.22, -7.75),
						pos = Vector3.new(0.03, -1.21, -0.32),
					},
					Neck = { rot = Vector3.new(44.62, 17.36, -6.77) },
					RightShoulder = { rot = Vector3.new(71.69, 0, 9.09) },
					LeftShoulder = { rot = Vector3.new(29.51, 0, -31.92) },
					RightHip = { rot = Vector3.new(15.21, 0, 0.59), pos = Vector3.new(0, 1.13, 0) },
					LeftHip = { rot = Vector3.new(50.03, 0, -9.2), pos = Vector3.new(0, 1.55, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-54.16, -17.13, -7.46),
						pos = Vector3.new(0.02, -1.2, -0.33),
					},
					Neck = { rot = Vector3.new(44.53, 17.11, -6.9) },
					RightShoulder = { rot = Vector3.new(70.55, 0, 10.02) },
					LeftShoulder = { rot = Vector3.new(32.74, 0, -33.15) },
					RightHip = { rot = Vector3.new(14.56, 0, 1.64), pos = Vector3.new(0, 1.13, 0) },
					LeftHip = { rot = Vector3.new(44.12, 0, -9.28), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.5312,
				pose = {
					Root = {
						rot = Vector3.new(-53.96, -17.08, -7.24),
						pos = Vector3.new(0.01, -1.19, -0.33),
					},
					Neck = { rot = Vector3.new(44.39, 16.96, -6.99) },
					RightShoulder = { rot = Vector3.new(68.99, 0, 11.15) },
					LeftShoulder = { rot = Vector3.new(36.33, 0, -34.21) },
					RightHip = { rot = Vector3.new(14.92, 0, 2.15), pos = Vector3.new(0, 1.13, 0) },
					LeftHip = { rot = Vector3.new(40.06, 0, -8.62), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.5625,
				pose = {
					Root = {
						rot = Vector3.new(-53.77, -17.09, -7.11),
						pos = Vector3.new(0.01, -1.17, -0.34),
					},
					Neck = { rot = Vector3.new(44.25, 16.91, -7.06) },
					RightShoulder = { rot = Vector3.new(67.23, 0, 12.31) },
					LeftShoulder = { rot = Vector3.new(40.14, 0, -35.03) },
					RightHip = { rot = Vector3.new(15.85, 0, 1.99), pos = Vector3.new(0, 1.11, 0) },
					LeftHip = { rot = Vector3.new(35.98, 0, -7.79), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.5938,
				pose = {
					Root = {
						rot = Vector3.new(-53.67, -17.13, -7.04),
						pos = Vector3.new(0, -1.14, -0.34),
					},
					Neck = { rot = Vector3.new(44.19, 16.9, -7.13) },
					RightShoulder = { rot = Vector3.new(65.33, 0, 13.44) },
					LeftShoulder = { rot = Vector3.new(44.05, 0, -35.67) },
					RightHip = { rot = Vector3.new(18.35, 0, 0.71), pos = Vector3.new(0, 1.11, 0) },
					LeftHip = { rot = Vector3.new(33.78, 0, -7.22), pos = Vector3.new(0, 1.57, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = {
						rot = Vector3.new(-53.64, -17.18, -7.01),
						pos = Vector3.new(0, -1.12, -0.34),
					},
					Neck = { rot = Vector3.new(44.19, 16.92, -7.2) },
					RightShoulder = { rot = Vector3.new(63.28, 0, 14.5) },
					LeftShoulder = { rot = Vector3.new(47.88, 0, -36.18) },
					RightHip = { rot = Vector3.new(22.9, 0, -1.39), pos = Vector3.new(0, 1.11, 0) },
					LeftHip = { rot = Vector3.new(31.88, 0, -6.36), pos = Vector3.new(0, 1.51, 0) },
				},
			},
			{
				time = 0.6562,
				pose = {
					Root = {
						rot = Vector3.new(-53.62, -17.25, -7.01),
						pos = Vector3.new(0, -1.09, -0.34),
					},
					Neck = { rot = Vector3.new(44.21, 16.98, -7.26) },
					RightShoulder = { rot = Vector3.new(61.08, 0, 15.44) },
					LeftShoulder = { rot = Vector3.new(51.49, 0, -36.58) },
					RightHip = { rot = Vector3.new(29.54, 0, -4.09), pos = Vector3.new(0, 1.11, 0) },
					LeftHip = { rot = Vector3.new(29.93, 0, -5.56), pos = Vector3.new(0, 1.46, 0) },
				},
			},
			{
				time = 0.6875,
				pose = {
					Root = {
						rot = Vector3.new(-53.63, -17.34, -7.07),
						pos = Vector3.new(-0.01, -1.08, -0.33),
					},
					Neck = { rot = Vector3.new(44.24, 17.08, -7.3) },
					RightShoulder = { rot = Vector3.new(58.79, 0, 16.22) },
					LeftShoulder = { rot = Vector3.new(54.82, 0, -36.88) },
					RightHip = { rot = Vector3.new(37.82, 0, -6.92), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(27.79, 0, -4.71), pos = Vector3.new(0, 1.41, 0) },
				},
			},
			{
				time = 0.7188,
				pose = {
					Root = {
						rot = Vector3.new(-53.67, -17.44, -7.18),
						pos = Vector3.new(-0.01, -1.08, -0.33),
					},
					Neck = { rot = Vector3.new(44.27, 17.22, -7.31) },
					RightShoulder = { rot = Vector3.new(56.45, 0, 16.81) },
					LeftShoulder = { rot = Vector3.new(57.78, 0, -37.16) },
					RightHip = { rot = Vector3.new(48.31, 0, -9.63), pos = Vector3.new(0, 1.01, 0) },
					LeftHip = { rot = Vector3.new(25.44, 0, -3.81), pos = Vector3.new(0, 1.38, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(-53.72, -17.56, -7.39),
						pos = Vector3.new(0, -1.08, -0.32),
					},
					Neck = { rot = Vector3.new(44.3, 17.44, -7.26) },
					RightShoulder = { rot = Vector3.new(54.11, 0, 17.25) },
					LeftShoulder = { rot = Vector3.new(60.29, 0, -37.47) },
					RightHip = { rot = Vector3.new(58.02, 0, -12), pos = Vector3.new(0, 0.95, 0) },
					LeftHip = { rot = Vector3.new(22.98, 0, -2.84), pos = Vector3.new(0, 1.35, 0) },
				},
			},
			{
				time = 0.7812,
				pose = {
					Root = {
						rot = Vector3.new(-53.78, -17.67, -7.78),
						pos = Vector3.new(0, -1.1, -0.31),
					},
					Neck = { rot = Vector3.new(44.3, 17.79, -7.08) },
					RightShoulder = { rot = Vector3.new(51.88, 0, 17.69) },
					LeftShoulder = { rot = Vector3.new(62.21, 0, -37.89) },
					RightHip = {
						rot = Vector3.new(63.81, 0, -13.95),
						pos = Vector3.new(0, 0.98, 0),
					},
					LeftHip = { rot = Vector3.new(20.33, 0, -1.78), pos = Vector3.new(0, 1.32, 0) },
				},
			},
			{
				time = 0.8125,
				pose = {
					Root = {
						rot = Vector3.new(-53.87, -17.8, -8.32),
						pos = Vector3.new(0.01, -1.12, -0.3),
					},
					Neck = { rot = Vector3.new(44.27, 18.23, -6.78) },
					RightShoulder = { rot = Vector3.new(49.97, 0, 18.17) },
					LeftShoulder = { rot = Vector3.new(63.47, 0, -38.41) },
					RightHip = {
						rot = Vector3.new(66.33, 0, -15.42),
						pos = Vector3.new(0, 1.02, 0),
					},
					LeftHip = { rot = Vector3.new(17.56, 0, -0.64), pos = Vector3.new(0, 1.29, 0) },
				},
			},
			{
				time = 0.8438,
				pose = {
					Root = {
						rot = Vector3.new(-53.97, -17.93, -8.95),
						pos = Vector3.new(0.02, -1.15, -0.3),
					},
					Neck = { rot = Vector3.new(44.23, 18.75, -6.44) },
					RightShoulder = { rot = Vector3.new(48.61, 0, 18.67) },
					LeftShoulder = { rot = Vector3.new(64.01, 0, -38.9) },
					RightHip = {
						rot = Vector3.new(66.07, 0, -16.02),
						pos = Vector3.new(0, 1.06, 0),
					},
					LeftHip = { rot = Vector3.new(14.81, 0, 0.49), pos = Vector3.new(0, 1.27, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = {
						rot = Vector3.new(-54.1, -18.09, -9.58),
						pos = Vector3.new(0.04, -1.17, -0.29),
					},
					Neck = { rot = Vector3.new(44.21, 19.27, -6.11) },
					RightShoulder = { rot = Vector3.new(47.97, 0, 19.11) },
					LeftShoulder = { rot = Vector3.new(63.73, 0, -39.35) },
					RightHip = {
						rot = Vector3.new(64.36, 0, -15.93),
						pos = Vector3.new(0, 1.11, 0),
					},
					LeftHip = { rot = Vector3.new(12.27, 0, 1.56), pos = Vector3.new(0, 1.23, 0) },
				},
			},
			{
				time = 0.9062,
				pose = {
					Root = {
						rot = Vector3.new(-54.27, -18.24, -10.13),
						pos = Vector3.new(0.05, -1.19, -0.29),
					},
					Neck = { rot = Vector3.new(44.25, 19.74, -5.85) },
					RightShoulder = { rot = Vector3.new(48.1, 0, 19.35) },
					LeftShoulder = { rot = Vector3.new(62.67, 0, -39.78) },
					RightHip = {
						rot = Vector3.new(62.24, 0, -15.61),
						pos = Vector3.new(0, 1.13, 0),
					},
					LeftHip = { rot = Vector3.new(10.2, 0, 2.47), pos = Vector3.new(0, 1.19, 0) },
				},
			},
			{
				time = 0.9375,
				pose = {
					Root = {
						rot = Vector3.new(-54.34, -18.42, -10.54),
						pos = Vector3.new(0.07, -1.19, -0.29),
					},
					Neck = { rot = Vector3.new(44.2, 20.13, -5.66) },
					RightShoulder = { rot = Vector3.new(48.85, 0, 19.38) },
					LeftShoulder = { rot = Vector3.new(60.73, 0, -40.13) },
					RightHip = { rot = Vector3.new(60.26, 0, -14.9), pos = Vector3.new(0, 1.14, 0) },
					LeftHip = { rot = Vector3.new(8.74, 0, 3.09), pos = Vector3.new(0, 1.16, 0) },
				},
			},
			{
				time = 0.9688,
				pose = {
					Root = {
						rot = Vector3.new(-54.21, -18.6, -10.79),
						pos = Vector3.new(0.08, -1.19, -0.3),
					},
					Neck = { rot = Vector3.new(43.99, 20.43, -5.55) },
					RightShoulder = { rot = Vector3.new(50.13, 0, 19.2) },
					LeftShoulder = { rot = Vector3.new(57.94, 0, -40.31) },
					RightHip = { rot = Vector3.new(57.6, 0, -14.31), pos = Vector3.new(0, 1.13, 0) },
					LeftHip = { rot = Vector3.new(7.93, 0, 3.23), pos = Vector3.new(0, 1.15, 0) },
				},
			},
		},
	},
	-- ALS_CLF_Walk_B: phase clip (one cycle = 1), left foot plants at 0.4375; natural cycle 1.133 s, stride 3.69 studs per cycle
	CrouchWalkBack = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-59.36, -18.5, -10.34),
						pos = Vector3.new(0.09, -1.06, -0.31),
					},
					Neck = { rot = Vector3.new(49.5, 19.41, -7.64) },
					RightShoulder = { rot = Vector3.new(65.66, 0, 13.93) },
					LeftShoulder = { rot = Vector3.new(48.65, 0, -40.06) },
					RightHip = { rot = Vector3.new(33.43, 0, -7.57), pos = Vector3.new(0, 0.93, 0) },
					LeftHip = { rot = Vector3.new(47.93, 0, -13.13), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.0312,
				pose = {
					Root = {
						rot = Vector3.new(-59.58, -18.74, -10.67),
						pos = Vector3.new(0.1, -1.05, -0.3),
					},
					Neck = { rot = Vector3.new(49.71, 19.77, -7.7) },
					RightShoulder = { rot = Vector3.new(62.82, 0, 15.05) },
					LeftShoulder = { rot = Vector3.new(53.8, 0, -41.39) },
					RightHip = { rot = Vector3.new(38.49, 0, -9.16), pos = Vector3.new(0, 0.9, 0) },
					LeftHip = { rot = Vector3.new(41.71, 0, -12.12), pos = Vector3.new(0, 1.57, 0) },
				},
			},
			{
				time = 0.0625,
				pose = {
					Root = {
						rot = Vector3.new(-59.79, -18.95, -10.79),
						pos = Vector3.new(0.1, -1.05, -0.29),
					},
					Neck = { rot = Vector3.new(49.94, 19.97, -7.87) },
					RightShoulder = { rot = Vector3.new(59.96, 0, 15.92) },
					LeftShoulder = { rot = Vector3.new(58.9, 0, -42.29) },
					RightHip = {
						rot = Vector3.new(43.41, 0, -10.63),
						pos = Vector3.new(0, 0.86, 0),
					},
					LeftHip = { rot = Vector3.new(34.82, 0, -9.97), pos = Vector3.new(0, 1.52, 0) },
				},
			},
			{
				time = 0.0938,
				pose = {
					Root = {
						rot = Vector3.new(-59.92, -19.11, -10.84),
						pos = Vector3.new(0.11, -1.06, -0.29),
					},
					Neck = { rot = Vector3.new(50.09, 20.1, -8) },
					RightShoulder = { rot = Vector3.new(57.26, 0, 16.45) },
					LeftShoulder = { rot = Vector3.new(63.42, 0, -42.67) },
					RightHip = {
						rot = Vector3.new(47.29, 0, -10.78),
						pos = Vector3.new(0, 0.86, 0),
					},
					LeftHip = { rot = Vector3.new(27.57, 0, -7.37), pos = Vector3.new(0, 1.5, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = {
						rot = Vector3.new(-59.9, -19.22, -10.84),
						pos = Vector3.new(0.11, -1.09, -0.29),
					},
					Neck = { rot = Vector3.new(50.1, 20.18, -8.08) },
					RightShoulder = { rot = Vector3.new(55.2, 0, 16.7) },
					LeftShoulder = { rot = Vector3.new(66.66, 0, -42.65) },
					RightHip = {
						rot = Vector3.new(50.17, 0, -11.81),
						pos = Vector3.new(0, 0.89, 0),
					},
					LeftHip = { rot = Vector3.new(22.59, 0, -5.15), pos = Vector3.new(0, 1.42, 0) },
				},
			},
			{
				time = 0.1562,
				pose = {
					Root = {
						rot = Vector3.new(-59.76, -19.28, -10.8),
						pos = Vector3.new(0.1, -1.12, -0.3),
					},
					Neck = { rot = Vector3.new(49.98, 20.22, -8.11) },
					RightShoulder = { rot = Vector3.new(54.06, 0, 16.77) },
					LeftShoulder = { rot = Vector3.new(68.69, 0, -42.35) },
					RightHip = {
						rot = Vector3.new(53.39, 0, -13.22),
						pos = Vector3.new(0, 0.91, 0),
					},
					LeftHip = { rot = Vector3.new(18.58, 0, -3.25), pos = Vector3.new(0, 1.32, 0) },
				},
			},
			{
				time = 0.1875,
				pose = {
					Root = {
						rot = Vector3.new(-59.66, -19.28, -10.8),
						pos = Vector3.new(0.1, -1.15, -0.3),
					},
					Neck = { rot = Vector3.new(49.89, 20.24, -8.07) },
					RightShoulder = { rot = Vector3.new(54.02, 0, 16.7) },
					LeftShoulder = { rot = Vector3.new(69.65, 0, -41.87) },
					RightHip = { rot = Vector3.new(56.2, 0, -14.33), pos = Vector3.new(0, 0.92, 0) },
					LeftHip = { rot = Vector3.new(14.79, 0, -1.27), pos = Vector3.new(0, 1.24, 0) },
				},
			},
			{
				time = 0.2188,
				pose = {
					Root = {
						rot = Vector3.new(-59.66, -19.17, -10.84),
						pos = Vector3.new(0.09, -1.17, -0.31),
					},
					Neck = { rot = Vector3.new(49.88, 20.19, -7.97) },
					RightShoulder = { rot = Vector3.new(55.16, 0, 16.44) },
					LeftShoulder = { rot = Vector3.new(69.57, 0, -41.25) },
					RightHip = { rot = Vector3.new(58.3, 0, -14.89), pos = Vector3.new(0, 0.99, 0) },
					LeftHip = { rot = Vector3.new(12.91, 0, 0.17), pos = Vector3.new(0, 1.2, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(-59.65, -18.96, -10.77),
						pos = Vector3.new(0.08, -1.17, -0.31),
					},
					Neck = { rot = Vector3.new(49.88, 20, -7.85) },
					RightShoulder = { rot = Vector3.new(57.21, 0, 16.13) },
					LeftShoulder = { rot = Vector3.new(68.5, 0, -40.45) },
					RightHip = {
						rot = Vector3.new(60.87, 0, -15.44),
						pos = Vector3.new(0, 1.03, 0),
					},
					LeftHip = { rot = Vector3.new(12.16, 0, 1.26), pos = Vector3.new(0, 1.17, 0) },
				},
			},
			{
				time = 0.2812,
				pose = {
					Root = {
						rot = Vector3.new(-59.57, -18.68, -10.53),
						pos = Vector3.new(0.07, -1.17, -0.32),
					},
					Neck = { rot = Vector3.new(49.82, 19.67, -7.77) },
					RightShoulder = { rot = Vector3.new(59.76, 0, 15.75) },
					LeftShoulder = { rot = Vector3.new(66.6, 0, -39.61) },
					RightHip = {
						rot = Vector3.new(63.42, 0, -15.97),
						pos = Vector3.new(0, 1.05, 0),
					},
					LeftHip = { rot = Vector3.new(12.53, 0, 1.53), pos = Vector3.new(0, 1.16, 0) },
				},
			},
			{
				time = 0.3125,
				pose = {
					Root = {
						rot = Vector3.new(-59.34, -18.4, -10.06),
						pos = Vector3.new(0.05, -1.16, -0.32),
					},
					Neck = { rot = Vector3.new(49.66, 19.18, -7.79) },
					RightShoulder = { rot = Vector3.new(62.34, 0, 15.28) },
					LeftShoulder = { rot = Vector3.new(63.94, 0, -38.98) },
					RightHip = {
						rot = Vector3.new(65.93, 0, -16.43),
						pos = Vector3.new(0, 1.05, 0),
					},
					LeftHip = { rot = Vector3.new(13.83, 0, 1), pos = Vector3.new(0, 1.19, 0) },
				},
			},
			{
				time = 0.3438,
				pose = {
					Root = {
						rot = Vector3.new(-59.1, -18.12, -9.42),
						pos = Vector3.new(0.04, -1.14, -0.33),
					},
					Neck = { rot = Vector3.new(49.51, 18.55, -7.93) },
					RightShoulder = { rot = Vector3.new(64.83, 0, 14.62) },
					LeftShoulder = { rot = Vector3.new(60.76, 0, -38.55) },
					RightHip = { rot = Vector3.new(68.16, 0, -16.8), pos = Vector3.new(0, 1.02, 0) },
					LeftHip = { rot = Vector3.new(16.09, 0, -0.05), pos = Vector3.new(0, 1.23, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = {
						rot = Vector3.new(-59.11, -17.84, -8.69),
						pos = Vector3.new(0.03, -1.12, -0.33),
					},
					Neck = { rot = Vector3.new(49.63, 17.83, -8.19) },
					RightShoulder = { rot = Vector3.new(67.42, 0, 13.68) },
					LeftShoulder = { rot = Vector3.new(57.39, 0, -38.27) },
					RightHip = {
						rot = Vector3.new(70.14, 0, -16.84),
						pos = Vector3.new(0, 0.97, 0),
					},
					LeftHip = { rot = Vector3.new(19.14, 0, -1.45), pos = Vector3.new(0, 1.28, 0) },
				},
			},
			{
				time = 0.4062,
				pose = {
					Root = {
						rot = Vector3.new(-59.29, -17.61, -8.01),
						pos = Vector3.new(0.02, -1.09, -0.33),
					},
					Neck = { rot = Vector3.new(49.92, 17.13, -8.52) },
					RightShoulder = { rot = Vector3.new(70, 0, 12.52) },
					LeftShoulder = { rot = Vector3.new(53.78, 0, -38.04) },
					RightHip = {
						rot = Vector3.new(69.49, 0, -16.18),
						pos = Vector3.new(0, 0.92, 0),
					},
					LeftHip = { rot = Vector3.new(22.51, 0, -2.99), pos = Vector3.new(0, 1.33, 0) },
				},
			},
			{
				time = 0.4375,
				pose = {
					Root = {
						rot = Vector3.new(-59.58, -17.41, -7.48),
						pos = Vector3.new(0.02, -1.07, -0.33),
					},
					Neck = { rot = Vector3.new(50.28, 16.56, -8.79) },
					RightShoulder = { rot = Vector3.new(72.51, 0, 11.23) },
					LeftShoulder = { rot = Vector3.new(49.77, 0, -37.72) },
					RightHip = {
						rot = Vector3.new(63.52, 0, -14.47),
						pos = Vector3.new(0, 0.91, 0),
					},
					LeftHip = { rot = Vector3.new(25.88, 0, -4.51), pos = Vector3.new(0, 1.38, 0) },
				},
			},
			{
				time = 0.4688,
				pose = {
					Root = {
						rot = Vector3.new(-59.8, -17.28, -7.25),
						pos = Vector3.new(0.02, -1.07, -0.32),
					},
					Neck = { rot = Vector3.new(50.52, 16.27, -8.9) },
					RightShoulder = { rot = Vector3.new(74.14, 0, 10.3) },
					LeftShoulder = { rot = Vector3.new(46.74, 0, -37.35) },
					RightHip = {
						rot = Vector3.new(56.81, 0, -12.77),
						pos = Vector3.new(0, 0.93, 0),
					},
					LeftHip = { rot = Vector3.new(28.08, 0, -5.48), pos = Vector3.new(0, 1.42, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-59.99, -17.16, -7.14),
						pos = Vector3.new(0.02, -1.07, -0.32),
					},
					Neck = { rot = Vector3.new(50.71, 16.08, -8.93) },
					RightShoulder = { rot = Vector3.new(75.56, 0, 9.41) },
					LeftShoulder = { rot = Vector3.new(43.74, 0, -36.83) },
					RightHip = {
						rot = Vector3.new(49.52, 0, -10.98),
						pos = Vector3.new(0, 0.97, 0),
					},
					LeftHip = { rot = Vector3.new(30.06, 0, -6.35), pos = Vector3.new(0, 1.46, 0) },
				},
			},
			{
				time = 0.5312,
				pose = {
					Root = {
						rot = Vector3.new(-60.15, -17.07, -7.07),
						pos = Vector3.new(0.02, -1.08, -0.32),
					},
					Neck = { rot = Vector3.new(50.87, 15.93, -8.94) },
					RightShoulder = { rot = Vector3.new(76.84, 0, 8.55) },
					LeftShoulder = { rot = Vector3.new(40.73, 0, -36.14) },
					RightHip = { rot = Vector3.new(42.37, 0, -9.19), pos = Vector3.new(0, 0.99, 0) },
					LeftHip = { rot = Vector3.new(31.93, 0, -7.14), pos = Vector3.new(0, 1.51, 0) },
				},
			},
			{
				time = 0.5625,
				pose = {
					Root = {
						rot = Vector3.new(-60.25, -16.99, -7.03),
						pos = Vector3.new(0.02, -1.09, -0.32),
					},
					Neck = { rot = Vector3.new(50.95, 15.83, -8.91) },
					RightShoulder = { rot = Vector3.new(77.78, 0, 7.84) },
					LeftShoulder = { rot = Vector3.new(37.94, 0, -35.32) },
					RightHip = { rot = Vector3.new(35.26, 0, -7.22), pos = Vector3.new(0, 1.01, 0) },
					LeftHip = { rot = Vector3.new(33.61, 0, -7.89), pos = Vector3.new(0, 1.56, 0) },
				},
			},
			{
				time = 0.5938,
				pose = {
					Root = {
						rot = Vector3.new(-60.27, -16.92, -7.03),
						pos = Vector3.new(0.02, -1.11, -0.32),
					},
					Neck = { rot = Vector3.new(50.95, 15.79, -8.86) },
					RightShoulder = { rot = Vector3.new(78.38, 0, 7.31) },
					LeftShoulder = { rot = Vector3.new(35.4, 0, -34.4) },
					RightHip = { rot = Vector3.new(28.78, 0, -5.05), pos = Vector3.new(0, 1.02, 0) },
					LeftHip = { rot = Vector3.new(34.76, 0, -8.26), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = {
						rot = Vector3.new(-60.21, -16.87, -7.05),
						pos = Vector3.new(0.02, -1.13, -0.32),
					},
					Neck = { rot = Vector3.new(50.86, 15.78, -8.78) },
					RightShoulder = { rot = Vector3.new(78.73, 0, 6.95) },
					LeftShoulder = { rot = Vector3.new(33.25, 0, -33.43) },
					RightHip = { rot = Vector3.new(23.79, 0, -3.01), pos = Vector3.new(0, 1, 0) },
					LeftHip = { rot = Vector3.new(35.57, 0, -8.13), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.6562,
				pose = {
					Root = {
						rot = Vector3.new(-60.1, -16.83, -7.1),
						pos = Vector3.new(0.02, -1.15, -0.32),
					},
					Neck = { rot = Vector3.new(50.73, 15.81, -8.68) },
					RightShoulder = { rot = Vector3.new(78.95, 0, 6.72) },
					LeftShoulder = { rot = Vector3.new(31.6, 0, -32.51) },
					RightHip = { rot = Vector3.new(19.93, 0, -1.35), pos = Vector3.new(0, 0.97, 0) },
					LeftHip = { rot = Vector3.new(36.43, 0, -7.77), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.6875,
				pose = {
					Root = {
						rot = Vector3.new(-60.01, -16.81, -7.18),
						pos = Vector3.new(0.03, -1.17, -0.33),
					},
					Neck = { rot = Vector3.new(50.61, 15.87, -8.59) },
					RightShoulder = { rot = Vector3.new(79.1, 0, 6.66) },
					LeftShoulder = { rot = Vector3.new(30.59, 0, -31.73) },
					RightHip = { rot = Vector3.new(17.28, 0, -0.24), pos = Vector3.new(0, 0.95, 0) },
					LeftHip = { rot = Vector3.new(38.75, 0, -7.38), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.7188,
				pose = {
					Root = {
						rot = Vector3.new(-59.94, -16.82, -7.3),
						pos = Vector3.new(0.03, -1.18, -0.33),
					},
					Neck = { rot = Vector3.new(50.51, 15.98, -8.49) },
					RightShoulder = { rot = Vector3.new(79.08, 0, 6.81) },
					LeftShoulder = { rot = Vector3.new(30.24, 0, -31.18) },
					RightHip = { rot = Vector3.new(15.95, 0, 0.2), pos = Vector3.new(0, 0.94, 0) },
					LeftHip = { rot = Vector3.new(46.87, 0, -8.44), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(-59.86, -16.87, -7.48),
						pos = Vector3.new(0.03, -1.19, -0.33),
					},
					Neck = { rot = Vector3.new(50.4, 16.16, -8.39) },
					RightShoulder = { rot = Vector3.new(78.75, 0, 7.18) },
					LeftShoulder = { rot = Vector3.new(30.39, 0, -31.03) },
					RightHip = { rot = Vector3.new(15.36, 0, 0.31), pos = Vector3.new(0, 0.94, 0) },
					LeftHip = { rot = Vector3.new(51.82, 0, -10.26), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.7812,
				pose = {
					Root = {
						rot = Vector3.new(-59.76, -16.97, -7.72),
						pos = Vector3.new(0.03, -1.19, -0.33),
					},
					Neck = { rot = Vector3.new(50.27, 16.42, -8.28) },
					RightShoulder = { rot = Vector3.new(78.09, 0, 7.7) },
					LeftShoulder = { rot = Vector3.new(30.98, 0, -31.28) },
					RightHip = { rot = Vector3.new(15.71, 0, 0.03), pos = Vector3.new(0, 0.95, 0) },
					LeftHip = { rot = Vector3.new(54.61, 0, -10.64), pos = Vector3.new(0, 1.59, 0) },
				},
			},
			{
				time = 0.8125,
				pose = {
					Root = {
						rot = Vector3.new(-59.64, -17.11, -8),
						pos = Vector3.new(0.04, -1.18, -0.34),
					},
					Neck = { rot = Vector3.new(50.11, 16.73, -8.17) },
					RightShoulder = { rot = Vector3.new(77.14, 0, 8.33) },
					LeftShoulder = { rot = Vector3.new(31.98, 0, -31.89) },
					RightHip = { rot = Vector3.new(16.59, 0, -0.53), pos = Vector3.new(0, 0.96, 0) },
					LeftHip = { rot = Vector3.new(56.08, 0, -10.38), pos = Vector3.new(0, 1.57, 0) },
				},
			},
			{
				time = 0.8438,
				pose = {
					Root = {
						rot = Vector3.new(-59.49, -17.28, -8.29),
						pos = Vector3.new(0.04, -1.18, -0.33),
					},
					Neck = { rot = Vector3.new(49.91, 17.08, -8.07) },
					RightShoulder = { rot = Vector3.new(75.9, 0, 9.06) },
					LeftShoulder = { rot = Vector3.new(33.33, 0, -32.78) },
					RightHip = { rot = Vector3.new(17.61, 0, -1.21), pos = Vector3.new(0, 0.97, 0) },
					LeftHip = { rot = Vector3.new(56.41, 0, -10.4), pos = Vector3.new(0, 1.55, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = {
						rot = Vector3.new(-59.31, -17.48, -8.6),
						pos = Vector3.new(0.05, -1.17, -0.33),
					},
					Neck = { rot = Vector3.new(49.68, 17.47, -7.97) },
					RightShoulder = { rot = Vector3.new(74.38, 0, 9.87) },
					LeftShoulder = { rot = Vector3.new(35.06, 0, -33.92) },
					RightHip = { rot = Vector3.new(19.03, 0, -2.03), pos = Vector3.new(0, 0.98, 0) },
					LeftHip = { rot = Vector3.new(56.39, 0, -10.26), pos = Vector3.new(0, 1.55, 0) },
				},
			},
			{
				time = 0.9062,
				pose = {
					Root = {
						rot = Vector3.new(-59.16, -17.7, -8.91),
						pos = Vector3.new(0.06, -1.15, -0.33),
					},
					Neck = { rot = Vector3.new(49.49, 17.86, -7.89) },
					RightShoulder = { rot = Vector3.new(72.73, 0, 10.69) },
					LeftShoulder = { rot = Vector3.new(37.09, 0, -35.16) },
					RightHip = { rot = Vector3.new(21, 0, -2.94), pos = Vector3.new(0, 0.99, 0) },
					LeftHip = { rot = Vector3.new(55.52, 0, -10.38), pos = Vector3.new(0, 1.56, 0) },
				},
			},
			{
				time = 0.9375,
				pose = {
					Root = {
						rot = Vector3.new(-59.11, -17.93, -9.26),
						pos = Vector3.new(0.07, -1.13, -0.33),
					},
					Neck = { rot = Vector3.new(49.39, 18.27, -7.82) },
					RightShoulder = { rot = Vector3.new(70.96, 0, 11.54) },
					LeftShoulder = { rot = Vector3.new(39.64, 0, -36.54) },
					RightHip = { rot = Vector3.new(23.73, 0, -4.09), pos = Vector3.new(0, 0.99, 0) },
					LeftHip = { rot = Vector3.new(54.41, 0, -11.7), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.9688,
				pose = {
					Root = {
						rot = Vector3.new(-59.19, -18.24, -9.81),
						pos = Vector3.new(0.08, -1.09, -0.32),
					},
					Neck = { rot = Vector3.new(49.39, 18.87, -7.73) },
					RightShoulder = { rot = Vector3.new(68.36, 0, 12.74) },
					LeftShoulder = { rot = Vector3.new(43.88, 0, -38.43) },
					RightHip = { rot = Vector3.new(28.37, 0, -5.88), pos = Vector3.new(0, 0.97, 0) },
					LeftHip = { rot = Vector3.new(52.85, 0, -12.97), pos = Vector3.new(0, 1.6, 0) },
				},
			},
		},
	},
	-- ALS_CLF_Walk_L: phase clip (one cycle = 1), left foot plants at 0.4375; natural cycle 1.133 s, stride 3.62 studs per cycle
	CrouchWalkLeft = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-56.63, -23.43, -27.22),
						pos = Vector3.new(0.12, -1.06, -0.2),
					},
					Neck = { rot = Vector3.new(52.75, 35.1, -2.02) },
					RightShoulder = { rot = Vector3.new(51.89, 0, 29.1) },
					LeftShoulder = { rot = Vector3.new(36.53, 0, -34.64) },
					RightHip = { rot = Vector3.new(30.84, 0, -9.65), pos = Vector3.new(0, 1.06, 0) },
					LeftHip = { rot = Vector3.new(45.3, 0, 8.75), pos = Vector3.new(0, 1.22, 0) },
				},
			},
			{
				time = 0.0312,
				pose = {
					Root = {
						rot = Vector3.new(-56.61, -23.68, -27.47),
						pos = Vector3.new(0.12, -1.04, -0.2),
					},
					Neck = { rot = Vector3.new(52.63, 35.42, -2.05) },
					RightShoulder = { rot = Vector3.new(50.85, 0, 29.58) },
					LeftShoulder = { rot = Vector3.new(38.02, 0, -35.36) },
					RightHip = { rot = Vector3.new(32.6, 0, -7.71), pos = Vector3.new(0, 1.06, 0) },
					LeftHip = { rot = Vector3.new(41.15, 0, 4.93), pos = Vector3.new(0, 1.27, 0) },
				},
			},
			{
				time = 0.0625,
				pose = {
					Root = {
						rot = Vector3.new(-56.59, -23.9, -27.62),
						pos = Vector3.new(0.12, -1.04, -0.2),
					},
					Neck = { rot = Vector3.new(52.56, 35.66, -2.13) },
					RightShoulder = { rot = Vector3.new(49.56, 0, 30.09) },
					LeftShoulder = { rot = Vector3.new(39.87, 0, -36.13) },
					RightHip = { rot = Vector3.new(34.1, 0, -5.69), pos = Vector3.new(0, 1.06, 0) },
					LeftHip = { rot = Vector3.new(37.14, 0, 1.02), pos = Vector3.new(0, 1.3, 0) },
				},
			},
			{
				time = 0.0938,
				pose = {
					Root = {
						rot = Vector3.new(-56.59, -24.1, -27.72),
						pos = Vector3.new(0.12, -1.04, -0.2),
					},
					Neck = { rot = Vector3.new(52.53, 35.85, -2.23) },
					RightShoulder = { rot = Vector3.new(48.04, 0, 30.63) },
					LeftShoulder = { rot = Vector3.new(42.06, 0, -36.91) },
					RightHip = { rot = Vector3.new(35.57, 0, -3.86), pos = Vector3.new(0, 1.07, 0) },
					LeftHip = { rot = Vector3.new(33.66, 0, -2.95), pos = Vector3.new(0, 1.32, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = {
						rot = Vector3.new(-56.59, -24.27, -27.8),
						pos = Vector3.new(0.11, -1.04, -0.2),
					},
					Neck = { rot = Vector3.new(52.51, 36.01, -2.32) },
					RightShoulder = { rot = Vector3.new(46.31, 0, 31.18) },
					LeftShoulder = { rot = Vector3.new(44.52, 0, -37.58) },
					RightHip = { rot = Vector3.new(36.88, 0, -2.9), pos = Vector3.new(0, 1.07, 0) },
					LeftHip = { rot = Vector3.new(30.69, 0, -6.99), pos = Vector3.new(0, 1.33, 0) },
				},
			},
			{
				time = 0.1562,
				pose = {
					Root = {
						rot = Vector3.new(-56.59, -24.4, -27.88),
						pos = Vector3.new(0.11, -1.05, -0.2),
					},
					Neck = { rot = Vector3.new(52.49, 36.14, -2.4) },
					RightShoulder = { rot = Vector3.new(44.41, 0, 31.73) },
					LeftShoulder = { rot = Vector3.new(47.18, 0, -38.12) },
					RightHip = { rot = Vector3.new(37.53, 0, -1.5), pos = Vector3.new(0, 1.12, 0) },
					LeftHip = { rot = Vector3.new(27.17, 0, -10.62), pos = Vector3.new(0, 1.37, 0) },
				},
			},
			{
				time = 0.1875,
				pose = {
					Root = {
						rot = Vector3.new(-56.61, -24.5, -27.95),
						pos = Vector3.new(0.1, -1.07, -0.2),
					},
					Neck = { rot = Vector3.new(52.5, 36.25, -2.46) },
					RightShoulder = { rot = Vector3.new(42.36, 0, 32.24) },
					LeftShoulder = { rot = Vector3.new(49.99, 0, -38.48) },
					RightHip = { rot = Vector3.new(37.7, 0, 0.5), pos = Vector3.new(0, 1.2, 0) },
					LeftHip = { rot = Vector3.new(23.75, 0, -14.03), pos = Vector3.new(0, 1.42, 0) },
				},
			},
			{
				time = 0.2188,
				pose = {
					Root = {
						rot = Vector3.new(-56.63, -24.57, -28.01),
						pos = Vector3.new(0.1, -1.09, -0.21),
					},
					Neck = { rot = Vector3.new(52.52, 36.33, -2.51) },
					RightShoulder = { rot = Vector3.new(40.16, 0, 32.73) },
					LeftShoulder = { rot = Vector3.new(52.84, 0, -38.62) },
					RightHip = { rot = Vector3.new(37.76, 0, 2.65), pos = Vector3.new(0, 1.27, 0) },
					LeftHip = { rot = Vector3.new(20.82, 0, -17.18), pos = Vector3.new(0, 1.44, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(-56.67, -24.59, -28.07),
						pos = Vector3.new(0.09, -1.12, -0.21),
					},
					Neck = { rot = Vector3.new(52.57, 36.4, -2.54) },
					RightShoulder = { rot = Vector3.new(37.85, 0, 33.22) },
					LeftShoulder = { rot = Vector3.new(55.66, 0, -38.53) },
					RightHip = { rot = Vector3.new(37.88, 0, 4.78), pos = Vector3.new(0, 1.35, 0) },
					LeftHip = { rot = Vector3.new(18.16, 0, -19.76), pos = Vector3.new(0, 1.45, 0) },
				},
			},
			{
				time = 0.2812,
				pose = {
					Root = {
						rot = Vector3.new(-56.79, -24.55, -28.19),
						pos = Vector3.new(0.09, -1.14, -0.21),
					},
					Neck = { rot = Vector3.new(52.68, 36.47, -2.51) },
					RightShoulder = { rot = Vector3.new(35.51, 0, 33.73) },
					LeftShoulder = { rot = Vector3.new(58.4, 0, -38.21) },
					RightHip = { rot = Vector3.new(38.13, 0, 6.94), pos = Vector3.new(0, 1.43, 0) },
					LeftHip = { rot = Vector3.new(15.93, 0, -21.53), pos = Vector3.new(0, 1.44, 0) },
				},
			},
			{
				time = 0.3125,
				pose = {
					Root = {
						rot = Vector3.new(-56.96, -24.41, -28.34),
						pos = Vector3.new(0.08, -1.16, -0.21),
					},
					Neck = { rot = Vector3.new(52.84, 36.52, -2.42) },
					RightShoulder = { rot = Vector3.new(33.17, 0, 34.22) },
					LeftShoulder = { rot = Vector3.new(61.01, 0, -37.71) },
					RightHip = { rot = Vector3.new(38.55, 0, 9.12), pos = Vector3.new(0, 1.49, 0) },
					LeftHip = { rot = Vector3.new(14.56, 0, -22.03), pos = Vector3.new(0, 1.44, 0) },
				},
			},
			{
				time = 0.3438,
				pose = {
					Root = {
						rot = Vector3.new(-57.13, -24.19, -28.46),
						pos = Vector3.new(0.07, -1.18, -0.21),
					},
					Neck = { rot = Vector3.new(53, 36.49, -2.28) },
					RightShoulder = { rot = Vector3.new(30.84, 0, 34.65) },
					LeftShoulder = { rot = Vector3.new(63.41, 0, -37.07) },
					RightHip = { rot = Vector3.new(38.98, 0, 11.43), pos = Vector3.new(0, 1.56, 0) },
					LeftHip = { rot = Vector3.new(13.77, 0, -21.76), pos = Vector3.new(0, 1.44, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = {
						rot = Vector3.new(-57.26, -23.9, -28.51),
						pos = Vector3.new(0.06, -1.19, -0.22),
					},
					Neck = { rot = Vector3.new(53.15, 36.38, -2.12) },
					RightShoulder = { rot = Vector3.new(28.47, 0, 34.98) },
					LeftShoulder = { rot = Vector3.new(65.47, 0, -36.36) },
					RightHip = { rot = Vector3.new(39.99, 0, 13.35), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(13.67, 0, -20.79), pos = Vector3.new(0, 1.44, 0) },
				},
			},
			{
				time = 0.4062,
				pose = {
					Root = {
						rot = Vector3.new(-57.34, -23.6, -28.48),
						pos = Vector3.new(0.05, -1.19, -0.22),
					},
					Neck = { rot = Vector3.new(53.26, 36.22, -1.95) },
					RightShoulder = { rot = Vector3.new(26.29, 0, 35.19) },
					LeftShoulder = { rot = Vector3.new(67.02, 0, -35.72) },
					RightHip = { rot = Vector3.new(41.51, 0, 14.58), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(14.09, 0, -19.54), pos = Vector3.new(0, 1.44, 0) },
				},
			},
			{
				time = 0.4375,
				pose = {
					Root = {
						rot = Vector3.new(-57.32, -23.29, -28.33),
						pos = Vector3.new(0.04, -1.19, -0.22),
					},
					Neck = { rot = Vector3.new(53.3, 35.94, -1.79) },
					RightShoulder = { rot = Vector3.new(24.09, 0, 35.26) },
					LeftShoulder = { rot = Vector3.new(68.16, 0, -35.12) },
					RightHip = { rot = Vector3.new(43.03, 0, 16.19), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(14.73, 0, -18.38), pos = Vector3.new(0, 1.44, 0) },
				},
			},
			{
				time = 0.4688,
				pose = {
					Root = {
						rot = Vector3.new(-57.08, -22.85, -27.79),
						pos = Vector3.new(0.03, -1.19, -0.23),
					},
					Neck = { rot = Vector3.new(53.23, 35.32, -1.66) },
					RightShoulder = { rot = Vector3.new(21, 0, 35.1) },
					LeftShoulder = { rot = Vector3.new(69.16, 0, -34.39) },
					RightHip = { rot = Vector3.new(44.06, 0, 19.11), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(16.36, 0, -16.35), pos = Vector3.new(0, 1.44, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-56.76, -22.46, -27.01),
						pos = Vector3.new(0.03, -1.16, -0.25),
					},
					Neck = { rot = Vector3.new(53.15, 34.52, -1.69) },
					RightShoulder = { rot = Vector3.new(18.97, 0, 34.73) },
					LeftShoulder = { rot = Vector3.new(69.19, 0, -34.09) },
					RightHip = { rot = Vector3.new(42.1, 0, 21.23), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(19.25, 0, -13.78), pos = Vector3.new(0, 1.43, 0) },
				},
			},
			{
				time = 0.5312,
				pose = {
					Root = {
						rot = Vector3.new(-56.53, -22.08, -26.19),
						pos = Vector3.new(0.02, -1.11, -0.26),
					},
					Neck = { rot = Vector3.new(53.2, 33.68, -1.81) },
					RightShoulder = { rot = Vector3.new(18.44, 0, 34.4) },
					LeftShoulder = { rot = Vector3.new(68.35, 0, -34.22) },
					RightHip = { rot = Vector3.new(41.06, 0, 20.87), pos = Vector3.new(0, 1.55, 0) },
					LeftHip = { rot = Vector3.new(22.78, 0, -11.22), pos = Vector3.new(0, 1.39, 0) },
				},
			},
			{
				time = 0.5625,
				pose = {
					Root = {
						rot = Vector3.new(-56.35, -21.75, -25.46),
						pos = Vector3.new(0.02, -1.07, -0.27),
					},
					Neck = { rot = Vector3.new(53.25, 32.94, -1.94) },
					RightShoulder = { rot = Vector3.new(19.43, 0, 34.31) },
					LeftShoulder = { rot = Vector3.new(66.62, 0, -34.68) },
					RightHip = { rot = Vector3.new(38.85, 0, 16.33), pos = Vector3.new(0, 1.46, 0) },
					LeftHip = { rot = Vector3.new(26.37, 0, -8.72), pos = Vector3.new(0, 1.33, 0) },
				},
			},
			{
				time = 0.5938,
				pose = {
					Root = {
						rot = Vector3.new(-56.21, -21.46, -24.96),
						pos = Vector3.new(0.02, -1.05, -0.28),
					},
					Neck = { rot = Vector3.new(53.24, 32.4, -1.94) },
					RightShoulder = { rot = Vector3.new(21.68, 0, 34.47) },
					LeftShoulder = { rot = Vector3.new(64.03, 0, -35.26) },
					RightHip = { rot = Vector3.new(35.77, 0, 8.45), pos = Vector3.new(0, 1.33, 0) },
					LeftHip = { rot = Vector3.new(29.62, 0, -6.15), pos = Vector3.new(0, 1.28, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = {
						rot = Vector3.new(-56.07, -21.22, -24.71),
						pos = Vector3.new(0.03, -1.05, -0.28),
					},
					Neck = { rot = Vector3.new(53.16, 32.06, -1.81) },
					RightShoulder = { rot = Vector3.new(24.95, 0, 34.75) },
					LeftShoulder = { rot = Vector3.new(60.7, 0, -35.78) },
					RightHip = { rot = Vector3.new(32.7, 0, 0.34), pos = Vector3.new(0, 1.16, 0) },
					LeftHip = { rot = Vector3.new(32.64, 0, -3.28), pos = Vector3.new(0, 1.23, 0) },
				},
			},
			{
				time = 0.6562,
				pose = {
					Root = {
						rot = Vector3.new(-55.98, -21.02, -24.56),
						pos = Vector3.new(0.04, -1.06, -0.28),
					},
					Neck = { rot = Vector3.new(53.07, 31.84, -1.66) },
					RightShoulder = { rot = Vector3.new(28.95, 0, 34.86) },
					LeftShoulder = { rot = Vector3.new(56.9, 0, -36.12) },
					RightHip = { rot = Vector3.new(28.14, 0, -7.31), pos = Vector3.new(0, 1.13, 0) },
					LeftHip = { rot = Vector3.new(34.83, 0, -2.06), pos = Vector3.new(0, 1.22, 0) },
				},
			},
			{
				time = 0.6875,
				pose = {
					Root = {
						rot = Vector3.new(-55.93, -20.87, -24.5),
						pos = Vector3.new(0.05, -1.08, -0.28),
					},
					Neck = { rot = Vector3.new(53.01, 31.7, -1.52) },
					RightShoulder = { rot = Vector3.new(33.38, 0, 34.65) },
					LeftShoulder = { rot = Vector3.new(52.86, 0, -36.19) },
					RightHip = { rot = Vector3.new(25.8, 0, -13.58), pos = Vector3.new(0, 1.09, 0) },
					LeftHip = { rot = Vector3.new(35.9, 0, 0.5), pos = Vector3.new(0, 1.27, 0) },
				},
			},
			{
				time = 0.7188,
				pose = {
					Root = {
						rot = Vector3.new(-55.92, -20.77, -24.51),
						pos = Vector3.new(0.06, -1.12, -0.28),
					},
					Neck = { rot = Vector3.new(52.97, 31.64, -1.39) },
					RightShoulder = { rot = Vector3.new(37.91, 0, 34.05) },
					LeftShoulder = { rot = Vector3.new(48.82, 0, -35.93) },
					RightHip = {
						rot = Vector3.new(23.27, 0, -18.63),
						pos = Vector3.new(0, 1.02, 0),
					},
					LeftHip = { rot = Vector3.new(37.06, 0, 3.71), pos = Vector3.new(0, 1.31, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(-56, -20.7, -24.61),
						pos = Vector3.new(0.07, -1.16, -0.27),
					},
					Neck = { rot = Vector3.new(53.01, 31.67, -1.28) },
					RightShoulder = { rot = Vector3.new(42.27, 0, 33.08) },
					LeftShoulder = { rot = Vector3.new(45.11, 0, -35.38) },
					RightHip = {
						rot = Vector3.new(21.28, 0, -21.14),
						pos = Vector3.new(0, 1.01, 0),
					},
					LeftHip = { rot = Vector3.new(38.51, 0, 6.95), pos = Vector3.new(0, 1.34, 0) },
				},
			},
			{
				time = 0.7812,
				pose = {
					Root = {
						rot = Vector3.new(-56.2, -20.74, -24.82),
						pos = Vector3.new(0.08, -1.19, -0.26),
					},
					Neck = { rot = Vector3.new(53.15, 31.84, -1.25) },
					RightShoulder = { rot = Vector3.new(46.26, 0, 31.84) },
					LeftShoulder = { rot = Vector3.new(41.84, 0, -34.68) },
					RightHip = {
						rot = Vector3.new(19.73, 0, -21.86),
						pos = Vector3.new(0, 1.02, 0),
					},
					LeftHip = { rot = Vector3.new(40.67, 0, 10.22), pos = Vector3.new(0, 1.35, 0) },
				},
			},
			{
				time = 0.8125,
				pose = {
					Root = {
						rot = Vector3.new(-56.42, -20.95, -25.14),
						pos = Vector3.new(0.09, -1.2, -0.25),
					},
					Neck = { rot = Vector3.new(53.28, 32.18, -1.32) },
					RightShoulder = { rot = Vector3.new(49.46, 0, 30.52) },
					LeftShoulder = { rot = Vector3.new(39.06, 0, -33.95) },
					RightHip = {
						rot = Vector3.new(18.97, 0, -20.93),
						pos = Vector3.new(0, 1.04, 0),
					},
					LeftHip = { rot = Vector3.new(44.07, 0, 13.35), pos = Vector3.new(0, 1.31, 0) },
				},
			},
			{
				time = 0.8438,
				pose = {
					Root = {
						rot = Vector3.new(-56.6, -21.32, -25.5),
						pos = Vector3.new(0.1, -1.2, -0.24),
					},
					Neck = { rot = Vector3.new(53.36, 32.64, -1.47) },
					RightShoulder = { rot = Vector3.new(51.62, 0, 29.39) },
					LeftShoulder = { rot = Vector3.new(36.85, 0, -33.34) },
					RightHip = {
						rot = Vector3.new(19.79, 0, -19.13),
						pos = Vector3.new(0, 1.07, 0),
					},
					LeftHip = { rot = Vector3.new(47.82, 0, 15.46), pos = Vector3.new(0, 1.25, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = {
						rot = Vector3.new(-56.67, -21.82, -25.83),
						pos = Vector3.new(0.11, -1.19, -0.23),
					},
					Neck = { rot = Vector3.new(53.33, 33.15, -1.7) },
					RightShoulder = { rot = Vector3.new(52.92, 0, 28.57) },
					LeftShoulder = { rot = Vector3.new(35.29, 0, -33) },
					RightHip = { rot = Vector3.new(21.07, 0, -17.5), pos = Vector3.new(0, 1.09, 0) },
					LeftHip = { rot = Vector3.new(50.93, 0, 16.64), pos = Vector3.new(0, 1.19, 0) },
				},
			},
			{
				time = 0.9062,
				pose = {
					Root = {
						rot = Vector3.new(-56.68, -22.36, -26.17),
						pos = Vector3.new(0.11, -1.16, -0.22),
					},
					Neck = { rot = Vector3.new(53.22, 33.7, -1.92) },
					RightShoulder = { rot = Vector3.new(53.41, 0, 28.24) },
					LeftShoulder = { rot = Vector3.new(34.52, 0, -33.06) },
					RightHip = {
						rot = Vector3.new(23.45, 0, -15.65),
						pos = Vector3.new(0, 1.09, 0),
					},
					LeftHip = { rot = Vector3.new(51.97, 0, 16.26), pos = Vector3.new(0, 1.16, 0) },
				},
			},
			{
				time = 0.9375,
				pose = {
					Root = {
						rot = Vector3.new(-56.68, -22.88, -26.61),
						pos = Vector3.new(0.12, -1.11, -0.21),
					},
					Neck = { rot = Vector3.new(53.05, 34.32, -2.03) },
					RightShoulder = { rot = Vector3.new(53.17, 0, 28.4) },
					LeftShoulder = { rot = Vector3.new(34.77, 0, -33.56) },
					RightHip = {
						rot = Vector3.new(26.78, 0, -13.17),
						pos = Vector3.new(0, 1.08, 0),
					},
					LeftHip = { rot = Vector3.new(51.74, 0, 14.41), pos = Vector3.new(0, 1.14, 0) },
				},
			},
			{
				time = 0.9688,
				pose = {
					Root = {
						rot = Vector3.new(-56.66, -23.18, -26.94),
						pos = Vector3.new(0.12, -1.08, -0.2),
					},
					Neck = { rot = Vector3.new(52.9, 34.74, -2.03) },
					RightShoulder = { rot = Vector3.new(52.65, 0, 28.7) },
					LeftShoulder = { rot = Vector3.new(35.46, 0, -34.06) },
					RightHip = {
						rot = Vector3.new(28.97, 0, -11.43),
						pos = Vector3.new(0, 1.06, 0),
					},
					LeftHip = { rot = Vector3.new(49.07, 0, 11.97), pos = Vector3.new(0, 1.18, 0) },
				},
			},
		},
	},
	-- ALS_CLF_Walk_R: phase clip (one cycle = 1), left foot plants at 0.4375; natural cycle 1.133 s, stride 3.65 studs per cycle
	CrouchWalkRight = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-57.09, -24.16, -28.44),
						pos = Vector3.new(0.07, -1.18, -0.21),
					},
					Neck = { rot = Vector3.new(53.08, 36.54, -2.24) },
					RightShoulder = { rot = Vector3.new(28.02, 0, 36.47) },
					LeftShoulder = { rot = Vector3.new(86.37, 0, -31.47) },
					RightHip = { rot = Vector3.new(39.26, 0, 12), pos = Vector3.new(0, 1.57, 0) },
					LeftHip = { rot = Vector3.new(13.67, 0, -22.11), pos = Vector3.new(0, 1.45, 0) },
				},
			},
			{
				time = 0.0312,
				pose = {
					Root = {
						rot = Vector3.new(-56.87, -24.47, -28.31),
						pos = Vector3.new(0.08, -1.16, -0.21),
					},
					Neck = { rot = Vector3.new(52.85, 36.58, -2.44) },
					RightShoulder = { rot = Vector3.new(31.94, 0, 36.04) },
					LeftShoulder = { rot = Vector3.new(82.92, 0, -34.44) },
					RightHip = { rot = Vector3.new(38.5, 0, 8.8), pos = Vector3.new(0, 1.48, 0) },
					LeftHip = { rot = Vector3.new(14.22, 0, -22.83), pos = Vector3.new(0, 1.44, 0) },
				},
			},
			{
				time = 0.0625,
				pose = {
					Root = {
						rot = Vector3.new(-56.66, -24.61, -28.14),
						pos = Vector3.new(0.09, -1.13, -0.21),
					},
					Neck = { rot = Vector3.new(52.65, 36.5, -2.54) },
					RightShoulder = { rot = Vector3.new(35.87, 0, 35.39) },
					LeftShoulder = { rot = Vector3.new(78.63, 0, -37.23) },
					RightHip = { rot = Vector3.new(37.98, 0, 5.79), pos = Vector3.new(0, 1.38, 0) },
					LeftHip = { rot = Vector3.new(16.38, 0, -21.67), pos = Vector3.new(0, 1.44, 0) },
				},
			},
			{
				time = 0.0938,
				pose = {
					Root = {
						rot = Vector3.new(-56.58, -24.6, -28.06),
						pos = Vector3.new(0.1, -1.09, -0.21),
					},
					Neck = { rot = Vector3.new(52.56, 36.4, -2.52) },
					RightShoulder = { rot = Vector3.new(39.76, 0, 34.67) },
					LeftShoulder = { rot = Vector3.new(73.55, 0, -39.58) },
					RightHip = { rot = Vector3.new(37.77, 0, 2.84), pos = Vector3.new(0, 1.28, 0) },
					LeftHip = { rot = Vector3.new(20.12, 0, -18.29), pos = Vector3.new(0, 1.44, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = {
						rot = Vector3.new(-56.57, -24.49, -28.01),
						pos = Vector3.new(0.11, -1.07, -0.2),
					},
					Neck = { rot = Vector3.new(52.53, 36.28, -2.45) },
					RightShoulder = { rot = Vector3.new(43.41, 0, 33.85) },
					LeftShoulder = { rot = Vector3.new(67.82, 0, -41.22) },
					RightHip = { rot = Vector3.new(37.64, 0, -0.13), pos = Vector3.new(0, 1.17, 0) },
					LeftHip = { rot = Vector3.new(24.45, 0, -13.77), pos = Vector3.new(0, 1.41, 0) },
				},
			},
			{
				time = 0.1562,
				pose = {
					Root = {
						rot = Vector3.new(-56.57, -24.32, -27.94),
						pos = Vector3.new(0.11, -1.04, -0.2),
					},
					Neck = { rot = Vector3.new(52.53, 36.1, -2.35) },
					RightShoulder = { rot = Vector3.new(46.7, 0, 32.91) },
					LeftShoulder = { rot = Vector3.new(61.79, 0, -42.03) },
					RightHip = { rot = Vector3.new(37.37, 0, -2.5), pos = Vector3.new(0, 1.08, 0) },
					LeftHip = { rot = Vector3.new(29.23, 0, -8.69), pos = Vector3.new(0, 1.36, 0) },
				},
			},
			{
				time = 0.1875,
				pose = {
					Root = {
						rot = Vector3.new(-56.59, -24.09, -27.83),
						pos = Vector3.new(0.12, -1.04, -0.2),
					},
					Neck = { rot = Vector3.new(52.56, 35.88, -2.23) },
					RightShoulder = { rot = Vector3.new(49.56, 0, 31.89) },
					LeftShoulder = { rot = Vector3.new(55.96, 0, -42.04) },
					RightHip = { rot = Vector3.new(35.41, 0, -3.79), pos = Vector3.new(0, 1.07, 0) },
					LeftHip = { rot = Vector3.new(33.57, 0, -3.02), pos = Vector3.new(0, 1.34, 0) },
				},
			},
			{
				time = 0.2188,
				pose = {
					Root = {
						rot = Vector3.new(-56.61, -23.8, -27.69),
						pos = Vector3.new(0.12, -1.04, -0.2),
					},
					Neck = { rot = Vector3.new(52.61, 35.6, -2.1) },
					RightShoulder = { rot = Vector3.new(51.93, 0, 30.9) },
					LeftShoulder = { rot = Vector3.new(50.79, 0, -41.42) },
					RightHip = { rot = Vector3.new(33.37, 0, -6.29), pos = Vector3.new(0, 1.07, 0) },
					LeftHip = { rot = Vector3.new(38.76, 0, 2.56), pos = Vector3.new(0, 1.3, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(-56.65, -23.47, -27.42),
						pos = Vector3.new(0.12, -1.05, -0.2),
					},
					Neck = { rot = Vector3.new(52.75, 35.2, -2.03) },
					RightShoulder = { rot = Vector3.new(53.74, 0, 29.98) },
					LeftShoulder = { rot = Vector3.new(46.67, 0, -40.46) },
					RightHip = { rot = Vector3.new(31.14, 0, -8.71), pos = Vector3.new(0, 1.07, 0) },
					LeftHip = { rot = Vector3.new(44.58, 0, 8.03), pos = Vector3.new(0, 1.24, 0) },
				},
			},
			{
				time = 0.2812,
				pose = {
					Root = {
						rot = Vector3.new(-56.69, -23.1, -27.01),
						pos = Vector3.new(0.12, -1.09, -0.2),
					},
					Neck = { rot = Vector3.new(52.95, 34.67, -2.04) },
					RightShoulder = { rot = Vector3.new(54.97, 0, 29.22) },
					LeftShoulder = { rot = Vector3.new(43.8, 0, -39.49) },
					RightHip = {
						rot = Vector3.new(28.52, 0, -11.12),
						pos = Vector3.new(0, 1.08, 0),
					},
					LeftHip = { rot = Vector3.new(49.79, 0, 12.59), pos = Vector3.new(0, 1.17, 0) },
				},
			},
			{
				time = 0.3125,
				pose = {
					Root = {
						rot = Vector3.new(-56.72, -22.68, -26.59),
						pos = Vector3.new(0.12, -1.13, -0.21),
					},
					Neck = { rot = Vector3.new(53.14, 34.11, -2.02) },
					RightShoulder = { rot = Vector3.new(55.61, 0, 28.77) },
					LeftShoulder = { rot = Vector3.new(42.2, 0, -38.69) },
					RightHip = { rot = Vector3.new(25.67, 0, -13.44), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(52.4, 0, 15.39), pos = Vector3.new(0, 1.15, 0) },
				},
			},
			{
				time = 0.3438,
				pose = {
					Root = {
						rot = Vector3.new(-56.72, -22.23, -26.25),
						pos = Vector3.new(0.11, -1.17, -0.22),
					},
					Neck = { rot = Vector3.new(53.26, 33.6, -1.88) },
					RightShoulder = { rot = Vector3.new(55.67, 0, 28.71) },
					LeftShoulder = { rot = Vector3.new(41.89, 0, -38.24) },
					RightHip = {
						rot = Vector3.new(22.94, 0, -15.67),
						pos = Vector3.new(0, 1.11, 0),
					},
					LeftHip = { rot = Vector3.new(51.5, 0, 16.32), pos = Vector3.new(0, 1.17, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = {
						rot = Vector3.new(-56.71, -21.76, -25.96),
						pos = Vector3.new(0.11, -1.19, -0.23),
					},
					Neck = { rot = Vector3.new(53.35, 33.13, -1.69) },
					RightShoulder = { rot = Vector3.new(55.12, 0, 29.12) },
					LeftShoulder = { rot = Vector3.new(42.85, 0, -38.23) },
					RightHip = { rot = Vector3.new(20.92, 0, -17.5), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(51.26, 0, 16.93), pos = Vector3.new(0, 1.18, 0) },
				},
			},
			{
				time = 0.4062,
				pose = {
					Root = {
						rot = Vector3.new(-56.63, -21.34, -25.68),
						pos = Vector3.new(0.1, -1.2, -0.24),
					},
					Neck = { rot = Vector3.new(53.38, 32.7, -1.5) },
					RightShoulder = { rot = Vector3.new(53.89, 0, 29.99) },
					LeftShoulder = { rot = Vector3.new(44.91, 0, -38.55) },
					RightHip = {
						rot = Vector3.new(19.71, 0, -19.11),
						pos = Vector3.new(0, 1.07, 0),
					},
					LeftHip = { rot = Vector3.new(48.1, 0, 15.58), pos = Vector3.new(0, 1.25, 0) },
				},
			},
			{
				time = 0.4375,
				pose = {
					Root = {
						rot = Vector3.new(-56.48, -21.01, -25.36),
						pos = Vector3.new(0.09, -1.2, -0.25),
					},
					Neck = { rot = Vector3.new(53.32, 32.31, -1.36) },
					RightShoulder = { rot = Vector3.new(51.95, 0, 31.16) },
					LeftShoulder = { rot = Vector3.new(47.97, 0, -39.03) },
					RightHip = {
						rot = Vector3.new(18.89, 0, -20.71),
						pos = Vector3.new(0, 1.04, 0),
					},
					LeftHip = { rot = Vector3.new(44.81, 0, 13.85), pos = Vector3.new(0, 1.3, 0) },
				},
			},
			{
				time = 0.4688,
				pose = {
					Root = {
						rot = Vector3.new(-56.3, -20.82, -25.1),
						pos = Vector3.new(0.09, -1.2, -0.26),
					},
					Neck = { rot = Vector3.new(53.23, 32.02, -1.29) },
					RightShoulder = { rot = Vector3.new(49.5, 0, 32.38) },
					LeftShoulder = { rot = Vector3.new(51.41, 0, -39.41) },
					RightHip = { rot = Vector3.new(18.9, 0, -21.9), pos = Vector3.new(0, 1.02, 0) },
					LeftHip = { rot = Vector3.new(41.96, 0, 11.6), pos = Vector3.new(0, 1.34, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-56.12, -20.71, -24.87),
						pos = Vector3.new(0.08, -1.18, -0.26),
					},
					Neck = { rot = Vector3.new(53.12, 31.82, -1.27) },
					RightShoulder = { rot = Vector3.new(46.37, 0, 33.66) },
					LeftShoulder = { rot = Vector3.new(55.41, 0, -39.6) },
					RightHip = {
						rot = Vector3.new(20.04, 0, -22.02),
						pos = Vector3.new(0, 1.01, 0),
					},
					LeftHip = { rot = Vector3.new(39.88, 0, 9.16), pos = Vector3.new(0, 1.35, 0) },
				},
			},
			{
				time = 0.5312,
				pose = {
					Root = {
						rot = Vector3.new(-55.97, -20.71, -24.72),
						pos = Vector3.new(0.07, -1.15, -0.27),
					},
					Neck = { rot = Vector3.new(53.03, 31.73, -1.3) },
					RightShoulder = { rot = Vector3.new(42.77, 0, 34.8) },
					LeftShoulder = { rot = Vector3.new(59.81, 0, -39.45) },
					RightHip = {
						rot = Vector3.new(21.16, 0, -21.23),
						pos = Vector3.new(0, 1.01, 0),
					},
					LeftHip = { rot = Vector3.new(38.36, 0, 6.65), pos = Vector3.new(0, 1.34, 0) },
				},
			},
			{
				time = 0.5625,
				pose = {
					Root = {
						rot = Vector3.new(-55.9, -20.77, -24.62),
						pos = Vector3.new(0.06, -1.13, -0.27),
					},
					Neck = { rot = Vector3.new(52.99, 31.72, -1.38) },
					RightShoulder = { rot = Vector3.new(38.87, 0, 35.7) },
					LeftShoulder = { rot = Vector3.new(64.48, 0, -38.88) },
					RightHip = {
						rot = Vector3.new(22.68, 0, -19.27),
						pos = Vector3.new(0, 1.02, 0),
					},
					LeftHip = { rot = Vector3.new(37.24, 0, 4.16), pos = Vector3.new(0, 1.31, 0) },
				},
			},
			{
				time = 0.5938,
				pose = {
					Root = {
						rot = Vector3.new(-55.89, -20.84, -24.58),
						pos = Vector3.new(0.05, -1.1, -0.28),
					},
					Neck = { rot = Vector3.new(53.02, 31.75, -1.47) },
					RightShoulder = { rot = Vector3.new(34.79, 0, 36.31) },
					LeftShoulder = { rot = Vector3.new(69.2, 0, -37.82) },
					RightHip = {
						rot = Vector3.new(24.92, 0, -15.78),
						pos = Vector3.new(0, 1.06, 0),
					},
					LeftHip = { rot = Vector3.new(36.34, 0, 1.71), pos = Vector3.new(0, 1.28, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = {
						rot = Vector3.new(-55.9, -20.94, -24.58),
						pos = Vector3.new(0.05, -1.07, -0.28),
					},
					Neck = { rot = Vector3.new(53.06, 31.83, -1.57) },
					RightShoulder = { rot = Vector3.new(30.65, 0, 36.6) },
					LeftShoulder = { rot = Vector3.new(73.68, 0, -36.29) },
					RightHip = {
						rot = Vector3.new(26.35, 0, -11.19),
						pos = Vector3.new(0, 1.12, 0),
					},
					LeftHip = { rot = Vector3.new(35.47, 0, -0.71), pos = Vector3.new(0, 1.25, 0) },
				},
			},
			{
				time = 0.6562,
				pose = {
					Root = {
						rot = Vector3.new(-55.94, -21.07, -24.61),
						pos = Vector3.new(0.04, -1.05, -0.28),
					},
					Neck = { rot = Vector3.new(53.12, 31.95, -1.68) },
					RightShoulder = { rot = Vector3.new(26.66, 0, 36.57) },
					LeftShoulder = { rot = Vector3.new(77.74, 0, -34.39) },
					RightHip = { rot = Vector3.new(28.71, 0, -6.32), pos = Vector3.new(0, 1.13, 0) },
					LeftHip = { rot = Vector3.new(34.79, 0, -2.23), pos = Vector3.new(0, 1.22, 0) },
				},
			},
			{
				time = 0.6875,
				pose = {
					Root = {
						rot = Vector3.new(-56, -21.22, -24.69),
						pos = Vector3.new(0.03, -1.05, -0.28),
					},
					Neck = { rot = Vector3.new(53.19, 32.12, -1.79) },
					RightShoulder = { rot = Vector3.new(23, 0, 36.29) },
					LeftShoulder = { rot = Vector3.new(81.28, 0, -32.26) },
					RightHip = { rot = Vector3.new(32.32, 0, -0.41), pos = Vector3.new(0, 1.15, 0) },
					LeftHip = { rot = Vector3.new(32.74, 0, -3.47), pos = Vector3.new(0, 1.24, 0) },
				},
			},
			{
				time = 0.7188,
				pose = {
					Root = {
						rot = Vector3.new(-56.09, -21.4, -24.83),
						pos = Vector3.new(0.02, -1.05, -0.28),
					},
					Neck = { rot = Vector3.new(53.26, 32.34, -1.9) },
					RightShoulder = { rot = Vector3.new(19.84, 0, 35.86) },
					LeftShoulder = { rot = Vector3.new(84.24, 0, -30.08) },
					RightHip = { rot = Vector3.new(35.1, 0, 5.72), pos = Vector3.new(0, 1.28, 0) },
					LeftHip = { rot = Vector3.new(30.51, 0, -5.62), pos = Vector3.new(0, 1.28, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(-56.2, -21.61, -25.09),
						pos = Vector3.new(0.02, -1.06, -0.27),
					},
					Neck = { rot = Vector3.new(53.3, 32.67, -1.95) },
					RightShoulder = { rot = Vector3.new(17.33, 0, 35.44) },
					LeftShoulder = { rot = Vector3.new(86.6, 0, -28.01) },
					RightHip = { rot = Vector3.new(38.52, 0, 12.33), pos = Vector3.new(0, 1.39, 0) },
					LeftHip = { rot = Vector3.new(28.26, 0, -7.61), pos = Vector3.new(0, 1.31, 0) },
				},
			},
			{
				time = 0.7812,
				pose = {
					Root = {
						rot = Vector3.new(-56.31, -21.84, -25.51),
						pos = Vector3.new(0.02, -1.08, -0.27),
					},
					Neck = { rot = Vector3.new(53.29, 33.14, -1.91) },
					RightShoulder = { rot = Vector3.new(15.57, 0, 35.18) },
					LeftShoulder = { rot = Vector3.new(88.37, 0, -26.24) },
					RightHip = { rot = Vector3.new(40.61, 0, 17.86), pos = Vector3.new(0, 1.47, 0) },
					LeftHip = { rot = Vector3.new(25.81, 0, -9.45), pos = Vector3.new(0, 1.35, 0) },
				},
			},
			{
				time = 0.8125,
				pose = {
					Root = {
						rot = Vector3.new(-56.44, -22.1, -26.05),
						pos = Vector3.new(0.02, -1.11, -0.26),
					},
					Neck = { rot = Vector3.new(53.24, 33.71, -1.81) },
					RightShoulder = { rot = Vector3.new(14.69, 0, 35.15) },
					LeftShoulder = { rot = Vector3.new(89.63, 0, -24.95) },
					RightHip = { rot = Vector3.new(41.21, 0, 20.81), pos = Vector3.new(0, 1.54, 0) },
					LeftHip = { rot = Vector3.new(23.25, 0, -11.17), pos = Vector3.new(0, 1.4, 0) },
				},
			},
			{
				time = 0.8438,
				pose = {
					Root = {
						rot = Vector3.new(-56.6, -22.38, -26.67),
						pos = Vector3.new(0.02, -1.15, -0.25),
					},
					Neck = { rot = Vector3.new(53.2, 34.34, -1.7) },
					RightShoulder = { rot = Vector3.new(14.79, 0, 35.37) },
					LeftShoulder = { rot = Vector3.new(90.42, 0, -24.25) },
					RightHip = { rot = Vector3.new(41.48, 0, 21.51), pos = Vector3.new(0, 1.59, 0) },
					LeftHip = { rot = Vector3.new(20.8, 0, -12.86), pos = Vector3.new(0, 1.44, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = {
						rot = Vector3.new(-56.82, -22.69, -27.28),
						pos = Vector3.new(0.03, -1.17, -0.24),
					},
					Neck = { rot = Vector3.new(53.21, 34.97, -1.65) },
					RightShoulder = { rot = Vector3.new(15.96, 0, 35.76) },
					LeftShoulder = { rot = Vector3.new(90.8, 0, -24.27) },
					RightHip = { rot = Vector3.new(43.05, 0, 20.39), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(18.67, 0, -14.54), pos = Vector3.new(0, 1.46, 0) },
				},
			},
			{
				time = 0.9062,
				pose = {
					Root = {
						rot = Vector3.new(-57.08, -22.99, -27.84),
						pos = Vector3.new(0.03, -1.19, -0.23),
					},
					Neck = { rot = Vector3.new(53.3, 35.55, -1.67) },
					RightShoulder = { rot = Vector3.new(18.05, 0, 36.19) },
					LeftShoulder = { rot = Vector3.new(90.77, 0, -25.04) },
					RightHip = { rot = Vector3.new(44.02, 0, 18.62), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(17.05, 0, -16.26), pos = Vector3.new(0, 1.47, 0) },
				},
			},
			{
				time = 0.9375,
				pose = {
					Root = {
						rot = Vector3.new(-57.24, -23.32, -28.23),
						pos = Vector3.new(0.04, -1.19, -0.22),
					},
					Neck = { rot = Vector3.new(53.35, 36, -1.78) },
					RightShoulder = { rot = Vector3.new(20.75, 0, 36.51) },
					LeftShoulder = { rot = Vector3.new(90.2, 0, -26.49) },
					RightHip = { rot = Vector3.new(43.07, 0, 16.42), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(15.83, 0, -17.98), pos = Vector3.new(0, 1.47, 0) },
				},
			},
			{
				time = 0.9688,
				pose = {
					Root = {
						rot = Vector3.new(-57.24, -23.75, -28.43),
						pos = Vector3.new(0.06, -1.19, -0.22),
					},
					Neck = { rot = Vector3.new(53.26, 36.35, -2) },
					RightShoulder = { rot = Vector3.new(24.24, 0, 36.64) },
					LeftShoulder = { rot = Vector3.new(88.79, 0, -28.72) },
					RightHip = { rot = Vector3.new(41.07, 0, 14.34), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(14.53, 0, -20.06), pos = Vector3.new(0, 1.46, 0) },
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
						pos = Vector3.new(0.01, -1.22, -0.1),
					},
					Neck = { rot = Vector3.new(18.53, 7.96, 0.74) },
					RightShoulder = { rot = Vector3.new(29.96, 0, 14.09) },
					LeftShoulder = { rot = Vector3.new(12.32, 0, -18.63) },
					RightHip = { rot = Vector3.new(-6.87, 0, -3.69), pos = Vector3.new(0, 1.23, 0) },
					LeftHip = { rot = Vector3.new(27.27, 0, -3.26), pos = Vector3.new(0, 1.33, 0) },
				},
			},
			{
				time = 0.0333,
				pose = {
					Root = {
						rot = Vector3.new(-21.65, -7.4, -3.3),
						pos = Vector3.new(0.01, -1.22, -0.1),
					},
					Neck = { rot = Vector3.new(18.53, 7.96, 0.74) },
					RightShoulder = { rot = Vector3.new(29.96, 0, 14.09) },
					LeftShoulder = { rot = Vector3.new(12.32, 0, -18.63) },
					RightHip = { rot = Vector3.new(-6.87, 0, -3.69), pos = Vector3.new(0, 1.23, 0) },
					LeftHip = { rot = Vector3.new(27.27, 0, -3.26), pos = Vector3.new(0, 1.33, 0) },
				},
			},
			{
				time = 0.0667,
				pose = {
					Root = {
						rot = Vector3.new(-21.65, -7.4, -3.3),
						pos = Vector3.new(0.01, -1.22, -0.1),
					},
					Neck = { rot = Vector3.new(18.53, 7.96, 0.74) },
					RightShoulder = { rot = Vector3.new(29.96, 0, 14.09) },
					LeftShoulder = { rot = Vector3.new(12.32, 0, -18.63) },
					RightHip = { rot = Vector3.new(-6.87, 0, -3.69), pos = Vector3.new(0, 1.23, 0) },
					LeftHip = { rot = Vector3.new(27.27, 0, -3.26), pos = Vector3.new(0, 1.33, 0) },
				},
			},
		},
	},
	-- ALS_N_JumpLoop: 0.67 s
	JumpLoop = {
		length = 0.67,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-13, 0, -0.11), pos = Vector3.new(0, -0.35, 0.09) },
					Neck = { rot = Vector3.new(4.94, -0.02, -0.08) },
					RightShoulder = { rot = Vector3.new(77.96, 0, 37.36) },
					LeftShoulder = { rot = Vector3.new(62.7, 0, -37.28) },
					RightHip = { rot = Vector3.new(28.03, 0, 1.96), pos = Vector3.new(0, 0.42, 0) },
					LeftHip = { rot = Vector3.new(27.67, 0, -1.2), pos = Vector3.new(0, 0.41, 0) },
				},
			},
			{
				time = 0.0667,
				pose = {
					Root = {
						rot = Vector3.new(-14.26, -0.38, -0.08),
						pos = Vector3.new(0, -0.37, 0.07),
					},
					Neck = { rot = Vector3.new(6.02, 0.33, -0.09) },
					RightShoulder = { rot = Vector3.new(86.1, 0, 41.31) },
					LeftShoulder = { rot = Vector3.new(73.69, 0, -44.03) },
					RightHip = { rot = Vector3.new(18.9, 0, 1.22), pos = Vector3.new(0, 0.4, 0) },
					LeftHip = { rot = Vector3.new(20.92, 0, -0.68), pos = Vector3.new(0, 0.4, 0) },
				},
			},
			{
				time = 0.1333,
				pose = {
					Root = {
						rot = Vector3.new(-14.8, -1.27, -0.08),
						pos = Vector3.new(0, -0.39, 0.05),
					},
					Neck = { rot = Vector3.new(6.36, 1.23, -0.22) },
					RightShoulder = { rot = Vector3.new(97.39, 0, 44.36) },
					LeftShoulder = { rot = Vector3.new(85.82, 0, -50.03) },
					RightHip = { rot = Vector3.new(11.5, 0, -0.2), pos = Vector3.new(0, 0.37, 0) },
					LeftHip = { rot = Vector3.new(14.13, 0, -0.25), pos = Vector3.new(0, 0.36, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = {
						rot = Vector3.new(-14.68, -2.32, 0.06),
						pos = Vector3.new(0, -0.38, 0.04),
					},
					Neck = { rot = Vector3.new(6.05, 2.3, -0.4) },
					RightShoulder = { rot = Vector3.new(108.48, 0, 51.63) },
					LeftShoulder = { rot = Vector3.new(89.71, 0, -57.48) },
					RightHip = { rot = Vector3.new(1.28, 0, -0.67), pos = Vector3.new(0, 0.39, 0) },
					LeftHip = { rot = Vector3.new(2.91, 0, -0.66), pos = Vector3.new(0, 0.41, 0) },
				},
			},
			{
				time = 0.2667,
				pose = {
					Root = {
						rot = Vector3.new(-13.71, -3.21, 0.31),
						pos = Vector3.new(-0.01, -0.37, 0.05),
					},
					Neck = { rot = Vector3.new(5.16, 3.21, -0.6) },
					RightShoulder = { rot = Vector3.new(105.97, 0, 57.52) },
					LeftShoulder = { rot = Vector3.new(76.77, 0, -60.88) },
					RightHip = { rot = Vector3.new(-8.39, 0, -0.53), pos = Vector3.new(0, 0.36, 0) },
					LeftHip = { rot = Vector3.new(-8.14, 0, -1.14), pos = Vector3.new(0, 0.4, 0) },
				},
			},
			{
				time = 0.3333,
				pose = {
					Root = {
						rot = Vector3.new(-12.25, -3.61, 0.5),
						pos = Vector3.new(-0.01, -0.34, 0.07),
					},
					Neck = { rot = Vector3.new(3.83, 3.59, -0.67) },
					RightShoulder = { rot = Vector3.new(100.04, 0, 62.05) },
					LeftShoulder = { rot = Vector3.new(60.1, 0, -57.38) },
					RightHip = { rot = Vector3.new(-14.91, 0, 1.27), pos = Vector3.new(0, 0.4, 0) },
					LeftHip = { rot = Vector3.new(-15.39, 0, -1.06), pos = Vector3.new(0, 0.57, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = {
						rot = Vector3.new(-11.16, -3.25, 0.51),
						pos = Vector3.new(-0.01, -0.33, 0.09),
					},
					Neck = { rot = Vector3.new(2.72, 3.19, -0.57) },
					RightShoulder = { rot = Vector3.new(82.29, 0, 53.97) },
					LeftShoulder = { rot = Vector3.new(64.96, 0, -47.46) },
					RightHip = { rot = Vector3.new(-12.1, 0, 1.32), pos = Vector3.new(0, 0.82, 0) },
					LeftHip = { rot = Vector3.new(-12.59, 0, -1.91), pos = Vector3.new(0, 0.89, 0) },
				},
			},
			{
				time = 0.4667,
				pose = {
					Root = {
						rot = Vector3.new(-10.86, -2.36, 0.35),
						pos = Vector3.new(-0.01, -0.32, 0.1),
					},
					Neck = { rot = Vector3.new(2.35, 2.32, -0.39) },
					RightShoulder = { rot = Vector3.new(97.49, 0, 42.59) },
					LeftShoulder = { rot = Vector3.new(79.29, 0, -43.44) },
					RightHip = { rot = Vector3.new(0, 0, 1.25), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(-0.89, 0, -2.89), pos = Vector3.new(0, 1, 0) },
				},
			},
			{
				time = 0.5333,
				pose = {
					Root = {
						rot = Vector3.new(-11.02, -1.28, 0.06),
						pos = Vector3.new(0, -0.32, 0.11),
					},
					Neck = { rot = Vector3.new(2.69, 1.36, -0.22) },
					RightShoulder = { rot = Vector3.new(108.94, 0, 43.19) },
					LeftShoulder = { rot = Vector3.new(82.57, 0, -40.21) },
					RightHip = { rot = Vector3.new(15.76, 0, 1.8), pos = Vector3.new(0, 0.95, 0) },
					LeftHip = { rot = Vector3.new(13.88, 0, -3.12), pos = Vector3.new(0, 0.81, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-11.63, -0.39, -0.13),
						pos = Vector3.new(0, -0.33, 0.11),
					},
					Neck = { rot = Vector3.new(3.57, 0.48, -0.14) },
					RightShoulder = { rot = Vector3.new(110.16, 0, 39.24) },
					LeftShoulder = { rot = Vector3.new(89.61, 0, -33.33) },
					RightHip = { rot = Vector3.new(28.42, 0, 2.56), pos = Vector3.new(0, 0.53, 0) },
					LeftHip = { rot = Vector3.new(26.25, 0, -2.51), pos = Vector3.new(0, 0.45, 0) },
				},
			},
		},
	},
	-- ALS_N_FallLoop: 1.00 s
	FallLoop = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-19.86, -0.01, -0.19),
						pos = Vector3.new(0, 0.02, -0.1),
					},
					Neck = { rot = Vector3.new(20, 0.07, -0.03) },
					RightShoulder = { rot = Vector3.new(25.75, 0, 56.47) },
					LeftShoulder = { rot = Vector3.new(7.46, 0, -50.93) },
					RightHip = { rot = Vector3.new(21.08, 0, 3.45), pos = Vector3.new(0, 0.33, 0) },
					LeftHip = { rot = Vector3.new(16.41, 0, -3), pos = Vector3.new(0, 0.58, 0) },
				},
			},
			{
				time = 0.0667,
				pose = {
					Root = {
						rot = Vector3.new(-19.12, -0.01, -0.16),
						pos = Vector3.new(0, -0.01, -0.08),
					},
					Neck = { rot = Vector3.new(19.23, 0.07, -0.03) },
					RightShoulder = { rot = Vector3.new(17.34, 0, 58.15) },
					LeftShoulder = { rot = Vector3.new(0.6, 0, -51.59) },
					RightHip = { rot = Vector3.new(20.86, 0, 3.29), pos = Vector3.new(0, 0.25, 0) },
					LeftHip = { rot = Vector3.new(16.35, 0, -3.02), pos = Vector3.new(0, 0.51, 0) },
				},
			},
			{
				time = 0.1333,
				pose = {
					Root = {
						rot = Vector3.new(-18.1, -0.01, -0.15),
						pos = Vector3.new(0, -0.03, -0.07),
					},
					Neck = { rot = Vector3.new(18.2, 0.06, -0.03) },
					RightShoulder = { rot = Vector3.new(10.19, 0, 58.05) },
					LeftShoulder = { rot = Vector3.new(-4.27, 0, -50.74) },
					RightHip = { rot = Vector3.new(19.73, 0, 3.19), pos = Vector3.new(0, 0.21, 0) },
					LeftHip = { rot = Vector3.new(15.61, 0, -3.03), pos = Vector3.new(0, 0.45, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = {
						rot = Vector3.new(-16.96, 0, -0.14),
						pos = Vector3.new(0, -0.04, -0.06),
					},
					Neck = { rot = Vector3.new(17.04, 0.06, -0.03) },
					RightShoulder = { rot = Vector3.new(6.79, 0, 56.27) },
					LeftShoulder = { rot = Vector3.new(-5.75, 0, -48.73) },
					RightHip = { rot = Vector3.new(17.99, 0, 3.17), pos = Vector3.new(0, 0.21, 0) },
					LeftHip = { rot = Vector3.new(14.33, 0, -3.04), pos = Vector3.new(0, 0.4, 0) },
				},
			},
			{
				time = 0.2667,
				pose = {
					Root = {
						rot = Vector3.new(-15.82, 0, -0.14),
						pos = Vector3.new(0, -0.05, -0.05),
					},
					Neck = { rot = Vector3.new(15.89, 0.06, -0.03) },
					RightShoulder = { rot = Vector3.new(5.74, 0, 54.18) },
					LeftShoulder = { rot = Vector3.new(-5.42, 0, -46.6) },
					RightHip = { rot = Vector3.new(15.95, 0, 3.21), pos = Vector3.new(0, 0.24, 0) },
					LeftHip = { rot = Vector3.new(12.67, 0, -3.03), pos = Vector3.new(0, 0.39, 0) },
				},
			},
			{
				time = 0.3333,
				pose = {
					Root = {
						rot = Vector3.new(-14.81, 0, -0.14),
						pos = Vector3.new(0, -0.05, -0.04),
					},
					Neck = { rot = Vector3.new(14.88, 0.07, -0.02) },
					RightShoulder = { rot = Vector3.new(6.34, 0, 52.28) },
					LeftShoulder = { rot = Vector3.new(-3.95, 0, -44.78) },
					RightHip = { rot = Vector3.new(13.91, 0, 3.32), pos = Vector3.new(0, 0.3, 0) },
					LeftHip = { rot = Vector3.new(10.89, 0, -3.02), pos = Vector3.new(0, 0.42, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = {
						rot = Vector3.new(-14.08, -0.01, -0.14),
						pos = Vector3.new(0, -0.05, -0.03),
					},
					Neck = { rot = Vector3.new(14.14, 0.07, -0.02) },
					RightShoulder = { rot = Vector3.new(8.25, 0, 50.79) },
					LeftShoulder = { rot = Vector3.new(-1.69, 0, -43.42) },
					RightHip = { rot = Vector3.new(12.2, 0, 3.46), pos = Vector3.new(0, 0.38, 0) },
					LeftHip = { rot = Vector3.new(9.31, 0, -3), pos = Vector3.new(0, 0.46, 0) },
				},
			},
			{
				time = 0.4667,
				pose = {
					Root = {
						rot = Vector3.new(-13.74, -0.01, -0.15),
						pos = Vector3.new(0, -0.04, -0.03),
					},
					Neck = { rot = Vector3.new(13.8, 0.07, -0.02) },
					RightShoulder = { rot = Vector3.new(11.56, 0, 49.84) },
					LeftShoulder = { rot = Vector3.new(1.23, 0, -42.67) },
					RightHip = { rot = Vector3.new(11.06, 0, 3.62), pos = Vector3.new(0, 0.47, 0) },
					LeftHip = { rot = Vector3.new(8.2, 0, -2.98), pos = Vector3.new(0, 0.52, 0) },
				},
			},
			{
				time = 0.5333,
				pose = {
					Root = {
						rot = Vector3.new(-13.93, -0.01, -0.17),
						pos = Vector3.new(0, -0.02, -0.04),
					},
					Neck = { rot = Vector3.new(14.01, 0.08, -0.02) },
					RightShoulder = { rot = Vector3.new(16.51, 0, 49.41) },
					LeftShoulder = { rot = Vector3.new(5.05, 0, -42.65) },
					RightHip = { rot = Vector3.new(10.84, 0, 3.76), pos = Vector3.new(0, 0.55, 0) },
					LeftHip = { rot = Vector3.new(7.92, 0, -2.96), pos = Vector3.new(0, 0.58, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-14.7, -0.01, -0.18),
						pos = Vector3.new(0, 0, -0.04),
					},
					Neck = { rot = Vector3.new(14.79, 0.08, -0.01) },
					RightShoulder = { rot = Vector3.new(22.1, 0, 49.13) },
					LeftShoulder = { rot = Vector3.new(9.18, 0, -42.97) },
					RightHip = { rot = Vector3.new(11.48, 0, 3.88), pos = Vector3.new(0, 0.61, 0) },
					LeftHip = { rot = Vector3.new(8.43, 0, -2.95), pos = Vector3.new(0, 0.64, 0) },
				},
			},
			{
				time = 0.6667,
				pose = {
					Root = {
						rot = Vector3.new(-15.85, -0.01, -0.2),
						pos = Vector3.new(0, 0.02, -0.06),
					},
					Neck = { rot = Vector3.new(15.96, 0.09, -0.02) },
					RightShoulder = { rot = Vector3.new(26.83, 0, 49.02) },
					LeftShoulder = { rot = Vector3.new(12.59, 0, -43.46) },
					RightHip = { rot = Vector3.new(12.76, 0, 3.95), pos = Vector3.new(0, 0.65, 0) },
					LeftHip = { rot = Vector3.new(9.51, 0, -2.94), pos = Vector3.new(0, 0.69, 0) },
				},
			},
			{
				time = 0.7333,
				pose = {
					Root = {
						rot = Vector3.new(-17.17, -0.01, -0.21),
						pos = Vector3.new(0, 0.03, -0.07),
					},
					Neck = { rot = Vector3.new(17.3, 0.09, -0.02) },
					RightShoulder = { rot = Vector3.new(30.45, 0, 49.31) },
					LeftShoulder = { rot = Vector3.new(15.01, 0, -44.27) },
					RightHip = { rot = Vector3.new(14.48, 0, 3.96), pos = Vector3.new(0, 0.65, 0) },
					LeftHip = { rot = Vector3.new(10.93, 0, -2.94), pos = Vector3.new(0, 0.72, 0) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = {
						rot = Vector3.new(-18.44, -0.01, -0.22),
						pos = Vector3.new(0, 0.04, -0.09),
					},
					Neck = { rot = Vector3.new(18.6, 0.09, -0.02) },
					RightShoulder = { rot = Vector3.new(32.69, 0, 50.18) },
					LeftShoulder = { rot = Vector3.new(16.17, 0, -45.5) },
					RightHip = { rot = Vector3.new(16.48, 0, 3.91), pos = Vector3.new(0, 0.61, 0) },
					LeftHip = { rot = Vector3.new(12.55, 0, -2.95), pos = Vector3.new(0, 0.73, 0) },
				},
			},
			{
				time = 0.8667,
				pose = {
					Root = {
						rot = Vector3.new(-19.47, -0.01, -0.22),
						pos = Vector3.new(0, 0.05, -0.1),
					},
					Neck = { rot = Vector3.new(19.62, 0.09, -0.03) },
					RightShoulder = { rot = Vector3.new(33.17, 0, 51.75) },
					LeftShoulder = { rot = Vector3.new(15.71, 0, -47.14) },
					RightHip = { rot = Vector3.new(18.5, 0, 3.79), pos = Vector3.new(0, 0.54, 0) },
					LeftHip = { rot = Vector3.new(14.2, 0, -2.96), pos = Vector3.new(0, 0.7, 0) },
				},
			},
			{
				time = 0.9333,
				pose = {
					Root = {
						rot = Vector3.new(-20.01, -0.01, -0.21),
						pos = Vector3.new(0, 0.04, -0.1),
					},
					Neck = { rot = Vector3.new(20.16, 0.08, -0.03) },
					RightShoulder = { rot = Vector3.new(31.23, 0, 53.96) },
					LeftShoulder = { rot = Vector3.new(13.1, 0, -49.06) },
					RightHip = { rot = Vector3.new(20.19, 0, 3.63), pos = Vector3.new(0, 0.44, 0) },
					LeftHip = { rot = Vector3.new(15.62, 0, -2.98), pos = Vector3.new(0, 0.65, 0) },
				},
			},
		},
	},
	-- ALS_N_FallLoop_Fast: 1.00 s
	FallFast = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-16.02, 0, -0.08),
						pos = Vector3.new(0, 0.04, -0.09),
					},
					Neck = { rot = Vector3.new(19.2, 0.04, -0.08) },
					RightShoulder = { rot = Vector3.new(134.22, 0, 80.89) },
					LeftShoulder = { rot = Vector3.new(55.88, 0, -87.75) },
					RightHip = { rot = Vector3.new(14.33, 0, 1.22), pos = Vector3.new(0, 0.18, 0) },
					LeftHip = { rot = Vector3.new(10.75, 0, -2.08), pos = Vector3.new(0, 0.4, 0) },
				},
			},
			{
				time = 0.0667,
				pose = {
					Root = {
						rot = Vector3.new(-15.24, 0, -0.06),
						pos = Vector3.new(0, 0.01, -0.08),
					},
					Neck = { rot = Vector3.new(18.4, 0.03, -0.08) },
					RightShoulder = { rot = Vector3.new(134.37, 0, 84.02) },
					LeftShoulder = { rot = Vector3.new(55.88, 0, -87.19) },
					RightHip = { rot = Vector3.new(13.45, 0, 0.88), pos = Vector3.new(0, 0.12, 0) },
					LeftHip = { rot = Vector3.new(10.15, 0, -1.97), pos = Vector3.new(0, 0.34, 0) },
				},
			},
			{
				time = 0.1333,
				pose = {
					Root = {
						rot = Vector3.new(-14.21, 0, -0.04),
						pos = Vector3.new(0, -0.01, -0.07),
					},
					Neck = { rot = Vector3.new(17.35, 0.02, -0.08) },
					RightShoulder = { rot = Vector3.new(134.37, 0, 85.52) },
					LeftShoulder = { rot = Vector3.new(55.47, 0, -83.5) },
					RightHip = { rot = Vector3.new(11.97, 0, 0.63), pos = Vector3.new(0, 0.09, 0) },
					LeftHip = { rot = Vector3.new(8.91, 0, -1.86), pos = Vector3.new(0, 0.29, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = {
						rot = Vector3.new(-13.06, 0, -0.05),
						pos = Vector3.new(0, -0.02, -0.06),
					},
					Neck = { rot = Vector3.new(16.19, 0.03, -0.08) },
					RightShoulder = { rot = Vector3.new(134.37, 0, 85.5) },
					LeftShoulder = { rot = Vector3.new(44.94, 0, -80.71) },
					RightHip = { rot = Vector3.new(10.14, 0, 0.55), pos = Vector3.new(0, 0.09, 0) },
					LeftHip = { rot = Vector3.new(7.24, 0, -1.75), pos = Vector3.new(0, 0.26, 0) },
				},
			},
			{
				time = 0.2667,
				pose = {
					Root = {
						rot = Vector3.new(-11.93, 0, -0.05),
						pos = Vector3.new(0, -0.03, -0.04),
					},
					Neck = { rot = Vector3.new(15.05, 0.03, -0.08) },
					RightShoulder = { rot = Vector3.new(134.37, 0, 84.45) },
					LeftShoulder = { rot = Vector3.new(20.42, 0, -78.56) },
					RightHip = { rot = Vector3.new(8.23, 0, 0.59), pos = Vector3.new(0, 0.11, 0) },
					LeftHip = { rot = Vector3.new(5.4, 0, -1.66), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.3333,
				pose = {
					Root = {
						rot = Vector3.new(-10.94, 0, -0.06),
						pos = Vector3.new(0, -0.04, -0.04),
					},
					Neck = { rot = Vector3.new(14.05, 0.04, -0.07) },
					RightShoulder = { rot = Vector3.new(134.88, 0, 83.57) },
					LeftShoulder = { rot = Vector3.new(-5.28, 0, -77.2) },
					RightHip = { rot = Vector3.new(6.49, 0, 0.8), pos = Vector3.new(0, 0.17, 0) },
					LeftHip = { rot = Vector3.new(3.62, 0, -1.62), pos = Vector3.new(0, 0.27, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = {
						rot = Vector3.new(-10.22, 0, -0.08),
						pos = Vector3.new(0, -0.03, -0.03),
					},
					Neck = { rot = Vector3.new(13.32, 0.05, -0.07) },
					RightShoulder = { rot = Vector3.new(136.01, 0, 83.55) },
					LeftShoulder = { rot = Vector3.new(-20.79, 0, -76.77) },
					RightHip = { rot = Vector3.new(5.16, 0, 1.08), pos = Vector3.new(0, 0.23, 0) },
					LeftHip = { rot = Vector3.new(2.18, 0, -1.62), pos = Vector3.new(0, 0.31, 0) },
				},
			},
			{
				time = 0.4667,
				pose = {
					Root = { rot = Vector3.new(-9.9, 0, -0.09), pos = Vector3.new(0, -0.02, -0.03) },
					Neck = { rot = Vector3.new(13.01, 0.05, -0.07) },
					RightShoulder = { rot = Vector3.new(136.08, 0, 84.77) },
					LeftShoulder = { rot = Vector3.new(-25.66, 0, -77.43) },
					RightHip = { rot = Vector3.new(4.45, 0, 1.43), pos = Vector3.new(0, 0.31, 0) },
					LeftHip = { rot = Vector3.new(1.32, 0, -1.67), pos = Vector3.new(0, 0.36, 0) },
				},
			},
			{
				time = 0.5333,
				pose = {
					Root = {
						rot = Vector3.new(-10.11, 0, -0.11),
						pos = Vector3.new(0, -0.01, -0.03),
					},
					Neck = { rot = Vector3.new(13.23, 0.06, -0.07) },
					RightShoulder = { rot = Vector3.new(136.08, 0, 86.65) },
					LeftShoulder = { rot = Vector3.new(-24.29, 0, -79.19) },
					RightHip = { rot = Vector3.new(4.68, 0, 1.79), pos = Vector3.new(0, 0.37, 0) },
					LeftHip = { rot = Vector3.new(1.38, 0, -1.74), pos = Vector3.new(0, 0.41, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = { rot = Vector3.new(-10.9, 0, -0.13), pos = Vector3.new(0, 0.01, -0.04) },
					Neck = { rot = Vector3.new(14.04, 0.07, -0.07) },
					RightShoulder = { rot = Vector3.new(136.08, 0, 85.07) },
					LeftShoulder = { rot = Vector3.new(-20.75, 0, -80.65) },
					RightHip = { rot = Vector3.new(5.78, 0, 2.11), pos = Vector3.new(0, 0.43, 0) },
					LeftHip = { rot = Vector3.new(2.3, 0, -1.85), pos = Vector3.new(0, 0.46, 0) },
				},
			},
			{
				time = 0.6667,
				pose = {
					Root = {
						rot = Vector3.new(-12.06, -0.01, -0.14),
						pos = Vector3.new(0, 0.03, -0.06),
					},
					Neck = { rot = Vector3.new(15.23, 0.07, -0.07) },
					RightShoulder = { rot = Vector3.new(134.64, 0, 81.96) },
					LeftShoulder = { rot = Vector3.new(-16.03, 0, -80.98) },
					RightHip = { rot = Vector3.new(7.46, 0, 2.33), pos = Vector3.new(0, 0.46, 0) },
					LeftHip = { rot = Vector3.new(3.81, 0, -1.97), pos = Vector3.new(0, 0.51, 0) },
				},
			},
			{
				time = 0.7333,
				pose = {
					Root = {
						rot = Vector3.new(-13.39, -0.01, -0.15),
						pos = Vector3.new(0, 0.05, -0.07),
					},
					Neck = { rot = Vector3.new(16.58, 0.07, -0.07) },
					RightShoulder = { rot = Vector3.new(128.33, 0, 79.36) },
					LeftShoulder = { rot = Vector3.new(-9.52, 0, -80.84) },
					RightHip = { rot = Vector3.new(9.4, 0, 2.39), pos = Vector3.new(0, 0.46, 0) },
					LeftHip = { rot = Vector3.new(5.63, 0, -2.08), pos = Vector3.new(0, 0.53, 0) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = {
						rot = Vector3.new(-14.67, -0.01, -0.15),
						pos = Vector3.new(0, 0.06, -0.08),
					},
					Neck = { rot = Vector3.new(17.87, 0.07, -0.08) },
					RightShoulder = { rot = Vector3.new(121.25, 0, 77.74) },
					LeftShoulder = { rot = Vector3.new(-2.36, 0, -80.97) },
					RightHip = { rot = Vector3.new(11.36, 0, 2.28), pos = Vector3.new(0, 0.42, 0) },
					LeftHip = { rot = Vector3.new(7.51, 0, -2.16), pos = Vector3.new(0, 0.54, 0) },
				},
			},
			{
				time = 0.8667,
				pose = {
					Root = {
						rot = Vector3.new(-15.69, -0.01, -0.14),
						pos = Vector3.new(0, 0.07, -0.09),
					},
					Neck = { rot = Vector3.new(18.89, 0.06, -0.08) },
					RightShoulder = { rot = Vector3.new(118.07, 0, 77.34) },
					LeftShoulder = { rot = Vector3.new(2.34, 0, -81.94) },
					RightHip = { rot = Vector3.new(13.06, 0, 2), pos = Vector3.new(0, 0.36, 0) },
					LeftHip = { rot = Vector3.new(9.2, 0, -2.18), pos = Vector3.new(0, 0.51, 0) },
				},
			},
			{
				time = 0.9333,
				pose = {
					Root = { rot = Vector3.new(-16.21, 0, -0.11), pos = Vector3.new(0, 0.06, -0.1) },
					Neck = { rot = Vector3.new(19.4, 0.05, -0.08) },
					RightShoulder = { rot = Vector3.new(118.72, 0, 78.34) },
					LeftShoulder = { rot = Vector3.new(3.06, 0, -84.1) },
					RightHip = { rot = Vector3.new(14.18, 0, 1.64), pos = Vector3.new(0, 0.27, 0) },
					LeftHip = { rot = Vector3.new(10.41, 0, -2.15), pos = Vector3.new(0, 0.46, 0) },
				},
			},
		},
	},
	-- ALS_Flail: 0.67 s
	Flail = {
		length = 0.67,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-9.45, 3.65, 4.15),
						pos = Vector3.new(-0.07, -0.34, -0.02),
					},
					Neck = { rot = Vector3.new(0.82, -3.93, -3.89) },
					RightShoulder = { rot = Vector3.new(68.05, 0, 41.59) },
					LeftShoulder = { rot = Vector3.new(-151.58, 0, -56.85) },
					RightHip = {
						rot = Vector3.new(-24.89, 0, -3.71),
						pos = Vector3.new(0, 0.36, 0),
					},
					LeftHip = { rot = Vector3.new(23.74, 0, -1.51), pos = Vector3.new(0, 0.44, 0) },
				},
			},
			{
				time = 0.0667,
				pose = {
					Root = {
						rot = Vector3.new(-9.29, 1.36, 2.98),
						pos = Vector3.new(-0.05, -0.34, -0.02),
					},
					Neck = { rot = Vector3.new(0.76, -1.57, -2.64) },
					RightShoulder = { rot = Vector3.new(70.93, 0, 43.19) },
					LeftShoulder = { rot = Vector3.new(-140.1, 0, -44.52) },
					RightHip = {
						rot = Vector3.new(-19.47, 0, -1.57),
						pos = Vector3.new(0, 0.77, 0),
					},
					LeftHip = { rot = Vector3.new(15.36, 0, -2.55), pos = Vector3.new(0, 0.41, 0) },
				},
			},
			{
				time = 0.1333,
				pose = {
					Root = {
						rot = Vector3.new(-9.29, -1.39, 0.71),
						pos = Vector3.new(-0.01, -0.34, -0.03),
					},
					Neck = { rot = Vector3.new(0.78, 1.31, -0.44) },
					RightShoulder = { rot = Vector3.new(83.38, 0, 44.16) },
					LeftShoulder = { rot = Vector3.new(-122.64, 0, -41.23) },
					RightHip = { rot = Vector3.new(-5.83, 0, -0.24), pos = Vector3.new(0, 1.07, 0) },
					LeftHip = { rot = Vector3.new(7.22, 0, -0.93), pos = Vector3.new(0, 0.35, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = {
						rot = Vector3.new(-9.36, -3.68, -1.82),
						pos = Vector3.new(0.03, -0.34, -0.02),
					},
					Neck = { rot = Vector3.new(0.83, 3.81, 1.87) },
					RightShoulder = { rot = Vector3.new(97.63, 0, 51.04) },
					LeftShoulder = { rot = Vector3.new(-115.35, 0, -39.81) },
					RightHip = { rot = Vector3.new(10.29, 0, -0.33), pos = Vector3.new(0, 1.01, 0) },
					LeftHip = { rot = Vector3.new(-4.7, 0, 1.23), pos = Vector3.new(0, 0.35, 0) },
				},
			},
			{
				time = 0.2667,
				pose = {
					Root = {
						rot = Vector3.new(-9.28, -4.64, -3.7),
						pos = Vector3.new(0.06, -0.34, -0.02),
					},
					Neck = { rot = Vector3.new(0.8, 4.95, 3.43) },
					RightShoulder = { rot = Vector3.new(93.87, 0, 57.69) },
					LeftShoulder = { rot = Vector3.new(-111.4, 0, -35.47) },
					RightHip = { rot = Vector3.new(22.11, 0, -0.55), pos = Vector3.new(0, 0.65, 0) },
					LeftHip = { rot = Vector3.new(-16.25, 0, 3.22), pos = Vector3.new(0, 0.29, 0) },
				},
			},
			{
				time = 0.3333,
				pose = {
					Root = {
						rot = Vector3.new(-9.24, -3.67, -4.16),
						pos = Vector3.new(0.07, -0.34, -0.02),
					},
					Neck = { rot = Vector3.new(0.71, 3.95, 3.74) },
					RightShoulder = { rot = Vector3.new(81.45, 0, 54.57) },
					LeftShoulder = { rot = Vector3.new(-107.65, 0, -39.57) },
					RightHip = { rot = Vector3.new(21.07, 0, 0.79), pos = Vector3.new(0, 0.45, 0) },
					LeftHip = { rot = Vector3.new(-21.89, 0, 3.23), pos = Vector3.new(0, 0.42, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = {
						rot = Vector3.new(-9.23, -1.36, -2.95),
						pos = Vector3.new(0.05, -0.34, -0.02),
					},
					Neck = { rot = Vector3.new(0.68, 1.56, 2.56) },
					RightShoulder = { rot = Vector3.new(81.87, 0, 46.17) },
					LeftShoulder = { rot = Vector3.new(-102.41, 0, -44.4) },
					RightHip = { rot = Vector3.new(10.13, 0, 2.28), pos = Vector3.new(0, 0.37, 0) },
					LeftHip = { rot = Vector3.new(-17.4, 0, 1.47), pos = Vector3.new(0, 0.8, 0) },
				},
			},
			{
				time = 0.4667,
				pose = {
					Root = {
						rot = Vector3.new(-9.33, 1.39, -0.8),
						pos = Vector3.new(0.01, -0.34, -0.03),
					},
					Neck = { rot = Vector3.new(0.71, -1.23, 0.41) },
					RightShoulder = { rot = Vector3.new(98.64, 0, 41.11) },
					LeftShoulder = { rot = Vector3.new(-85.5, 0, -48.14) },
					RightHip = { rot = Vector3.new(3.38, 0, 1.02), pos = Vector3.new(0, 0.36, 0) },
					LeftHip = { rot = Vector3.new(-4.13, 0, 0.13), pos = Vector3.new(0, 0.97, 0) },
				},
			},
			{
				time = 0.5333,
				pose = {
					Root = {
						rot = Vector3.new(-9.54, 3.67, 1.68),
						pos = Vector3.new(-0.03, -0.34, -0.03),
					},
					Neck = { rot = Vector3.new(0.82, -3.63, -1.89) },
					RightShoulder = { rot = Vector3.new(109.91, 0, 44.6) },
					LeftShoulder = { rot = Vector3.new(-73.9, 0, -59.26) },
					RightHip = { rot = Vector3.new(-9.34, 0, -1.11), pos = Vector3.new(0, 0.34, 0) },
					LeftHip = { rot = Vector3.new(11.68, 0, -0.03), pos = Vector3.new(0, 0.82, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-9.61, 4.61, 3.58),
						pos = Vector3.new(-0.06, -0.34, -0.03),
					},
					Neck = { rot = Vector3.new(0.88, -4.77, -3.55) },
					RightShoulder = { rot = Vector3.new(108.56, 0, 43.08) },
					LeftShoulder = { rot = Vector3.new(-88.26, 0, -66.02) },
					RightHip = {
						rot = Vector3.new(-19.63, 0, -3.16),
						pos = Vector3.new(0, 0.26, 0),
					},
					LeftHip = { rot = Vector3.new(23.97, 0, 0.2), pos = Vector3.new(0, 0.47, 0) },
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
					Root = {
						rot = Vector3.new(0.59, -8.85, 0.09),
						pos = Vector3.new(0, 0.11, 0.01),
					},
					Neck = { rot = Vector3.new(-12.2, 8.7, 1.71) },
					RightShoulder = { rot = Vector3.new(83.34, 0, 54.46) },
					LeftShoulder = { rot = Vector3.new(93.59, 0, -58.1) },
					RightHip = { rot = Vector3.new(0.92, 0, 6.42), pos = Vector3.new(0, 0.06, 0) },
					LeftHip = { rot = Vector3.new(4.65, 0, -5.09), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.0667,
				pose = {
					Root = {
						rot = Vector3.new(-2.25, -9.99, -0.26),
						pos = Vector3.new(0, -0.16, -0.03),
					},
					Neck = { rot = Vector3.new(-9.29, 9.85, 1.79) },
					RightShoulder = { rot = Vector3.new(85.24, 0, 53.2) },
					LeftShoulder = { rot = Vector3.new(95.88, 0, -58.86) },
					RightHip = { rot = Vector3.new(0.24, 0, 5.44), pos = Vector3.new(0, 0.26, 0) },
					LeftHip = { rot = Vector3.new(2.22, 0, -4.57), pos = Vector3.new(0, 0.23, 0) },
				},
			},
			{
				time = 0.1333,
				pose = {
					Root = {
						rot = Vector3.new(-5.24, -10.76, -0.72),
						pos = Vector3.new(0.01, -0.35, -0.05),
					},
					Neck = { rot = Vector3.new(-6.04, 10.65, 1.76) },
					RightShoulder = { rot = Vector3.new(80.93, 0, 51.82) },
					LeftShoulder = { rot = Vector3.new(91.88, 0, -56.77) },
					RightHip = { rot = Vector3.new(3.38, 0, 5.4), pos = Vector3.new(0, 0.45, 0) },
					LeftHip = { rot = Vector3.new(5.15, 0, -4.6), pos = Vector3.new(0, 0.42, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = {
						rot = Vector3.new(-8.13, -11.21, -1.23),
						pos = Vector3.new(0.01, -0.46, -0.06),
					},
					Neck = { rot = Vector3.new(-2.68, 11.18, 1.67) },
					RightShoulder = { rot = Vector3.new(72.19, 0, 49.22) },
					LeftShoulder = { rot = Vector3.new(84.29, 0, -52.5) },
					RightHip = { rot = Vector3.new(6.47, 0, 5.29), pos = Vector3.new(0, 0.55, 0) },
					LeftHip = { rot = Vector3.new(7.98, 0, -4.71), pos = Vector3.new(0, 0.53, 0) },
				},
			},
			{
				time = 0.2667,
				pose = {
					Root = {
						rot = Vector3.new(-10.73, -11.44, -1.72),
						pos = Vector3.new(0.01, -0.51, -0.06),
					},
					Neck = { rot = Vector3.new(0.54, 11.49, 1.53) },
					RightShoulder = { rot = Vector3.new(62.29, 0, 44.7) },
					LeftShoulder = { rot = Vector3.new(75.7, 0, -47.66) },
					RightHip = { rot = Vector3.new(9.39, 0, 5.19), pos = Vector3.new(0, 0.58, 0) },
					LeftHip = { rot = Vector3.new(10.51, 0, -4.88), pos = Vector3.new(0, 0.57, 0) },
				},
			},
			{
				time = 0.3333,
				pose = {
					Root = {
						rot = Vector3.new(-12.82, -11.5, -2.13),
						pos = Vector3.new(0.02, -0.52, -0.06),
					},
					Neck = { rot = Vector3.new(3.36, 11.65, 1.36) },
					RightShoulder = { rot = Vector3.new(53.64, 0, 38.81) },
					LeftShoulder = { rot = Vector3.new(66.64, 0, -43.98) },
					RightHip = { rot = Vector3.new(11.86, 0, 5.14), pos = Vector3.new(0, 0.59, 0) },
					LeftHip = { rot = Vector3.new(12.75, 0, -4.97), pos = Vector3.new(0, 0.59, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = {
						rot = Vector3.new(-14.28, -11.48, -2.41),
						pos = Vector3.new(0.02, -0.5, -0.06),
					},
					Neck = { rot = Vector3.new(5.66, 11.71, 1.18) },
					RightShoulder = { rot = Vector3.new(47.02, 0, 33.1) },
					LeftShoulder = { rot = Vector3.new(58.12, 0, -40.8) },
					RightHip = { rot = Vector3.new(13.65, 0, 5.14), pos = Vector3.new(0, 0.57, 0) },
					LeftHip = { rot = Vector3.new(14.49, 0, -4.97), pos = Vector3.new(0, 0.57, 0) },
				},
			},
			{
				time = 0.4667,
				pose = {
					Root = {
						rot = Vector3.new(-15.08, -11.45, -2.58),
						pos = Vector3.new(0.01, -0.47, -0.07),
					},
					Neck = { rot = Vector3.new(7.37, 11.72, 0.99) },
					RightShoulder = { rot = Vector3.new(41.9, 0, 28.66) },
					LeftShoulder = { rot = Vector3.new(50.37, 0, -37.95) },
					RightHip = { rot = Vector3.new(14.58, 0, 5.22), pos = Vector3.new(0, 0.53, 0) },
					LeftHip = { rot = Vector3.new(15.41, 0, -4.9), pos = Vector3.new(0, 0.53, 0) },
				},
			},
			{
				time = 0.5333,
				pose = {
					Root = {
						rot = Vector3.new(-15.29, -11.35, -2.63),
						pos = Vector3.new(0.01, -0.41, -0.08),
					},
					Neck = { rot = Vector3.new(8.53, 11.65, 0.81) },
					RightShoulder = { rot = Vector3.new(37.48, 0, 25.27) },
					LeftShoulder = { rot = Vector3.new(43.34, 0, -35.28) },
					RightHip = { rot = Vector3.new(14.93, 0, 5.3), pos = Vector3.new(0, 0.48, 0) },
					LeftHip = { rot = Vector3.new(15.79, 0, -4.82), pos = Vector3.new(0, 0.48, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-15.02, -11.2, -2.56),
						pos = Vector3.new(0.01, -0.35, -0.09),
					},
					Neck = { rot = Vector3.new(9.26, 11.49, 0.63) },
					RightShoulder = { rot = Vector3.new(33.39, 0, 22.66) },
					LeftShoulder = { rot = Vector3.new(37.12, 0, -32.74) },
					RightHip = { rot = Vector3.new(14.72, 0, 5.45), pos = Vector3.new(0, 0.42, 0) },
					LeftHip = { rot = Vector3.new(15.73, 0, -4.75), pos = Vector3.new(0, 0.42, 0) },
				},
			},
			{
				time = 0.6667,
				pose = {
					Root = {
						rot = Vector3.new(-14.35, -11.01, -2.43),
						pos = Vector3.new(0.01, -0.29, -0.1),
					},
					Neck = { rot = Vector3.new(9.6, 11.28, 0.48) },
					RightShoulder = { rot = Vector3.new(29.58, 0, 20.74) },
					LeftShoulder = { rot = Vector3.new(31.75, 0, -30.34) },
					RightHip = { rot = Vector3.new(14.08, 0, 5.56), pos = Vector3.new(0, 0.35, 0) },
					LeftHip = { rot = Vector3.new(15.25, 0, -4.67), pos = Vector3.new(0, 0.35, 0) },
				},
			},
			{
				time = 0.7333,
				pose = {
					Root = {
						rot = Vector3.new(-13.39, -10.8, -2.26),
						pos = Vector3.new(0.01, -0.23, -0.1),
					},
					Neck = { rot = Vector3.new(9.62, 11.04, 0.37) },
					RightShoulder = { rot = Vector3.new(25.99, 0, 19.45) },
					LeftShoulder = { rot = Vector3.new(27.32, 0, -28.08) },
					RightHip = { rot = Vector3.new(13.15, 0, 5.56), pos = Vector3.new(0, 0.3, 0) },
					LeftHip = { rot = Vector3.new(14.39, 0, -4.56), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = {
						rot = Vector3.new(-12.25, -10.58, -2.08),
						pos = Vector3.new(0.01, -0.19, -0.1),
					},
					Neck = { rot = Vector3.new(9.41, 10.79, 0.29) },
					RightShoulder = { rot = Vector3.new(22.64, 0, 18.69) },
					LeftShoulder = { rot = Vector3.new(23.8, 0, -26.02) },
					RightHip = { rot = Vector3.new(11.83, 0, 5.64), pos = Vector3.new(0, 0.26, 0) },
					LeftHip = { rot = Vector3.new(13.23, 0, -4.45), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.8667,
				pose = {
					Root = {
						rot = Vector3.new(-11.04, -10.36, -1.91),
						pos = Vector3.new(0.01, -0.15, -0.1),
					},
					Neck = { rot = Vector3.new(9.03, 10.55, 0.24) },
					RightShoulder = { rot = Vector3.new(19.6, 0, 18.34) },
					LeftShoulder = { rot = Vector3.new(20.73, 0, -24.5) },
					RightHip = { rot = Vector3.new(10.34, 0, 5.75), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(11.91, 0, -4.33), pos = Vector3.new(0, 0.21, 0) },
				},
			},
			{
				time = 0.9333,
				pose = {
					Root = {
						rot = Vector3.new(-9.86, -10.16, -1.77),
						pos = Vector3.new(0.01, -0.12, -0.1),
					},
					Neck = { rot = Vector3.new(8.57, 10.32, 0.22) },
					RightShoulder = { rot = Vector3.new(16.94, 0, 18.31) },
					LeftShoulder = { rot = Vector3.new(18.08, 0, -23.49) },
					RightHip = { rot = Vector3.new(8.85, 0, 5.85), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(10.57, 0, -4.21), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 1,
				pose = {
					Root = {
						rot = Vector3.new(-8.82, -9.99, -1.66),
						pos = Vector3.new(0.01, -0.1, -0.1),
					},
					Neck = { rot = Vector3.new(8.11, 10.14, 0.22) },
					RightShoulder = { rot = Vector3.new(14.76, 0, 18.45) },
					LeftShoulder = { rot = Vector3.new(15.92, 0, -22.87) },
					RightHip = { rot = Vector3.new(7.51, 0, 5.94), pos = Vector3.new(0, 0.19, 0) },
					LeftHip = { rot = Vector3.new(9.35, 0, -4.11), pos = Vector3.new(0, 0.16, 0) },
				},
			},
			{
				time = 1.0667,
				pose = {
					Root = {
						rot = Vector3.new(-8.02, -9.86, -1.58),
						pos = Vector3.new(0.01, -0.08, -0.1),
					},
					Neck = { rot = Vector3.new(7.72, 10, 0.23) },
					RightShoulder = { rot = Vector3.new(13.19, 0, 18.67) },
					LeftShoulder = { rot = Vector3.new(14.36, 0, -22.56) },
					RightHip = { rot = Vector3.new(6.47, 0, 6.01), pos = Vector3.new(0, 0.18, 0) },
					LeftHip = { rot = Vector3.new(8.4, 0, -4.03), pos = Vector3.new(0, 0.14, 0) },
				},
			},
			{
				time = 1.1333,
				pose = {
					Root = {
						rot = Vector3.new(-7.57, -9.79, -1.53),
						pos = Vector3.new(0.01, -0.07, -0.1),
					},
					Neck = { rot = Vector3.new(7.49, 9.93, 0.24) },
					RightShoulder = { rot = Vector3.new(12.34, 0, 18.83) },
					LeftShoulder = { rot = Vector3.new(13.53, 0, -22.45) },
					RightHip = { rot = Vector3.new(5.88, 0, 6.05), pos = Vector3.new(0, 0.17, 0) },
					LeftHip = { rot = Vector3.new(7.86, 0, -3.99), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 1.2,
				pose = {
					Root = {
						rot = Vector3.new(-7.51, -9.78, -1.53),
						pos = Vector3.new(0.01, -0.07, -0.1),
					},
					Neck = { rot = Vector3.new(7.46, 9.92, 0.24) },
					RightShoulder = { rot = Vector3.new(12.23, 0, 18.85) },
					LeftShoulder = { rot = Vector3.new(13.42, 0, -22.44) },
					RightHip = { rot = Vector3.new(5.8, 0, 6.05), pos = Vector3.new(0, 0.17, 0) },
					LeftHip = { rot = Vector3.new(7.79, 0, -3.98), pos = Vector3.new(0, 0.13, 0) },
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
					Root = {
						rot = Vector3.new(0.52, -8.84, 0.17),
						pos = Vector3.new(0, 0.11, 0.01),
					},
					Neck = { rot = Vector3.new(-12.12, 8.7, 1.65) },
					RightShoulder = { rot = Vector3.new(128.16, 0, 32.38) },
					LeftShoulder = { rot = Vector3.new(128.51, 0, -30.95) },
					RightHip = { rot = Vector3.new(-0.15, 0, 6.16), pos = Vector3.new(0, 0.06, 0) },
					LeftHip = { rot = Vector3.new(5.93, 0, -5.91), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.0667,
				pose = {
					Root = {
						rot = Vector3.new(-3.02, -10.01, -0.39),
						pos = Vector3.new(0, -0.25, -0.03),
					},
					Neck = { rot = Vector3.new(11.94, 9.88, -1.73) },
					RightShoulder = { rot = Vector3.new(129.91, 0, 32.85) },
					LeftShoulder = { rot = Vector3.new(131.35, 0, -33.5) },
					RightHip = { rot = Vector3.new(-0.87, 0, 6.04), pos = Vector3.new(0, 0.36, 0) },
					LeftHip = { rot = Vector3.new(5.69, 0, -5.69), pos = Vector3.new(0, 0.35, 0) },
				},
			},
			{
				time = 0.1333,
				pose = {
					Root = {
						rot = Vector3.new(-8.53, -10.76, -1.28),
						pos = Vector3.new(0.02, -0.51, -0.07),
					},
					Neck = { rot = Vector3.new(15.96, 10.7, -1.79) },
					RightShoulder = { rot = Vector3.new(124.37, 0, 41.28) },
					LeftShoulder = { rot = Vector3.new(127.07, 0, -43.65) },
					RightHip = { rot = Vector3.new(4.26, 0, 5.87), pos = Vector3.new(0, 0.62, 0) },
					LeftHip = { rot = Vector3.new(10.39, 0, -5.97), pos = Vector3.new(0, 0.62, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = {
						rot = Vector3.new(-15.07, -11.15, -2.43),
						pos = Vector3.new(0.03, -0.67, -0.11),
					},
					Neck = { rot = Vector3.new(18.67, 11.33, -1.38) },
					RightShoulder = { rot = Vector3.new(106.58, 0, 51.48) },
					LeftShoulder = { rot = Vector3.new(109.06, 0, -53.96) },
					RightHip = { rot = Vector3.new(9.85, 0, 5.52), pos = Vector3.new(0, 0.78, 0) },
					LeftHip = { rot = Vector3.new(15.69, 0, -6.39), pos = Vector3.new(0, 0.77, 0) },
				},
			},
			{
				time = 0.2667,
				pose = {
					Root = {
						rot = Vector3.new(-21.5, -11.25, -3.63),
						pos = Vector3.new(0.04, -0.74, -0.14),
					},
					Neck = { rot = Vector3.new(19.85, 11.82, -0.59) },
					RightShoulder = { rot = Vector3.new(78.23, 0, 53.38) },
					LeftShoulder = { rot = Vector3.new(82.5, 0, -54.11) },
					RightHip = { rot = Vector3.new(15.42, 0, 5.13), pos = Vector3.new(0, 0.85, 0) },
					LeftHip = { rot = Vector3.new(21.07, 0, -6.79), pos = Vector3.new(0, 0.84, 0) },
				},
			},
			{
				time = 0.3333,
				pose = {
					Root = {
						rot = Vector3.new(-26.69, -11.21, -4.46),
						pos = Vector3.new(0.05, -0.78, -0.16),
					},
					Neck = { rot = Vector3.new(19.34, 12.05, 0.41) },
					RightShoulder = { rot = Vector3.new(58.53, 0, 45.3) },
					LeftShoulder = { rot = Vector3.new(67.12, 0, -46.75) },
					RightHip = { rot = Vector3.new(20.08, 0, 4.75), pos = Vector3.new(0, 0.87, 0) },
					LeftHip = { rot = Vector3.new(26.08, 0, -7.04), pos = Vector3.new(0, 0.87, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = {
						rot = Vector3.new(-29.72, -11.16, -4.92),
						pos = Vector3.new(0.05, -0.76, -0.17),
					},
					Neck = { rot = Vector3.new(17.18, 12.1, 1.35) },
					RightShoulder = { rot = Vector3.new(50.63, 0, 36.63) },
					LeftShoulder = { rot = Vector3.new(59.5, 0, -39.66) },
					RightHip = { rot = Vector3.new(23.32, 0, 4.59), pos = Vector3.new(0, 0.85, 0) },
					LeftHip = { rot = Vector3.new(29.11, 0, -7.23), pos = Vector3.new(0, 0.86, 0) },
				},
			},
			{
				time = 0.4667,
				pose = {
					Root = {
						rot = Vector3.new(-30.15, -11.18, -4.92),
						pos = Vector3.new(0.04, -0.7, -0.17),
					},
					Neck = { rot = Vector3.new(13.83, 12.01, 2.07) },
					RightShoulder = { rot = Vector3.new(46.66, 0, 31.01) },
					LeftShoulder = { rot = Vector3.new(53.6, 0, -33.53) },
					RightHip = { rot = Vector3.new(24.91, 0, 4.66), pos = Vector3.new(0, 0.77, 0) },
					LeftHip = { rot = Vector3.new(29.89, 0, -7.33), pos = Vector3.new(0, 0.79, 0) },
				},
			},
			{
				time = 0.5333,
				pose = {
					Root = {
						rot = Vector3.new(-29.35, -11.14, -4.72),
						pos = Vector3.new(0.03, -0.62, -0.17),
					},
					Neck = { rot = Vector3.new(11.57, 11.84, 2.35) },
					RightShoulder = { rot = Vector3.new(43.85, 0, 26.57) },
					LeftShoulder = { rot = Vector3.new(48.62, 0, -28.92) },
					RightHip = { rot = Vector3.new(25.35, 0, 4.89), pos = Vector3.new(0, 0.67, 0) },
					LeftHip = { rot = Vector3.new(30.24, 0, -7.12), pos = Vector3.new(0, 0.7, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-27.81, -11.04, -4.41),
						pos = Vector3.new(0.03, -0.52, -0.18),
					},
					Neck = { rot = Vector3.new(10.59, 11.63, 2.26) },
					RightShoulder = { rot = Vector3.new(40.66, 0, 23.2) },
					LeftShoulder = { rot = Vector3.new(43.67, 0, -26.2) },
					RightHip = { rot = Vector3.new(24.71, 0, 5.19), pos = Vector3.new(0, 0.56, 0) },
					LeftHip = { rot = Vector3.new(29.69, 0, -6.82), pos = Vector3.new(0, 0.6, 0) },
				},
			},
			{
				time = 0.6667,
				pose = {
					Root = {
						rot = Vector3.new(-25.8, -10.89, -4.03),
						pos = Vector3.new(0.02, -0.42, -0.19),
					},
					Neck = { rot = Vector3.new(10.06, 11.4, 2.02) },
					RightShoulder = { rot = Vector3.new(36.89, 0, 20.98) },
					LeftShoulder = { rot = Vector3.new(38.5, 0, -24.79) },
					RightHip = { rot = Vector3.new(23.25, 0, 5.48), pos = Vector3.new(0, 0.46, 0) },
					LeftHip = { rot = Vector3.new(28.43, 0, -6.5), pos = Vector3.new(0, 0.5, 0) },
				},
			},
			{
				time = 0.7333,
				pose = {
					Root = {
						rot = Vector3.new(-23.45, -10.71, -3.63),
						pos = Vector3.new(0.01, -0.34, -0.19),
					},
					Neck = { rot = Vector3.new(9.89, 11.14, 1.69) },
					RightShoulder = { rot = Vector3.new(33.09, 0, 19.49) },
					LeftShoulder = { rot = Vector3.new(33.73, 0, -23.87) },
					RightHip = { rot = Vector3.new(21.2, 0, 5.76), pos = Vector3.new(0, 0.38, 0) },
					LeftHip = { rot = Vector3.new(26.65, 0, -6.19), pos = Vector3.new(0, 0.41, 0) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = {
						rot = Vector3.new(-20.94, -10.5, -3.23),
						pos = Vector3.new(0.01, -0.27, -0.18),
					},
					Neck = { rot = Vector3.new(9.98, 10.88, 1.33) },
					RightShoulder = { rot = Vector3.new(29.34, 0, 18.64) },
					LeftShoulder = { rot = Vector3.new(29.84, 0, -23.39) },
					RightHip = { rot = Vector3.new(18.67, 0, 6.02), pos = Vector3.new(0, 0.33, 0) },
					LeftHip = { rot = Vector3.new(24.41, 0, -5.89), pos = Vector3.new(0, 0.35, 0) },
				},
			},
			{
				time = 0.8667,
				pose = {
					Root = {
						rot = Vector3.new(-18.43, -10.3, -2.87),
						pos = Vector3.new(0.01, -0.22, -0.17),
					},
					Neck = { rot = Vector3.new(10.25, 10.63, 0.98) },
					RightShoulder = { rot = Vector3.new(25.77, 0, 18.29) },
					LeftShoulder = { rot = Vector3.new(26.47, 0, -23.29) },
					RightHip = { rot = Vector3.new(15.94, 0, 6.25), pos = Vector3.new(0, 0.29, 0) },
					LeftHip = { rot = Vector3.new(21.98, 0, -5.61), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.9333,
				pose = {
					Root = {
						rot = Vector3.new(-16.09, -10.11, -2.58),
						pos = Vector3.new(0, -0.19, -0.16),
					},
					Neck = { rot = Vector3.new(10.63, 10.4, 0.67) },
					RightShoulder = { rot = Vector3.new(22.55, 0, 18.29) },
					LeftShoulder = { rot = Vector3.new(23.57, 0, -23.43) },
					RightHip = { rot = Vector3.new(13.31, 0, 6.46), pos = Vector3.new(0, 0.27, 0) },
					LeftHip = { rot = Vector3.new(19.6, 0, -5.36), pos = Vector3.new(0, 0.27, 0) },
				},
			},
			{
				time = 1,
				pose = {
					Root = {
						rot = Vector3.new(-14.08, -9.95, -2.35),
						pos = Vector3.new(0, -0.17, -0.15),
					},
					Neck = { rot = Vector3.new(11.02, 10.2, 0.41) },
					RightShoulder = { rot = Vector3.new(19.88, 0, 18.5) },
					LeftShoulder = { rot = Vector3.new(21.23, 0, -23.67) },
					RightHip = { rot = Vector3.new(11.01, 0, 6.63), pos = Vector3.new(0, 0.26, 0) },
					LeftHip = { rot = Vector3.new(17.49, 0, -5.15), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 1.0667,
				pose = {
					Root = {
						rot = Vector3.new(-12.57, -9.83, -2.19),
						pos = Vector3.new(0, -0.15, -0.14),
					},
					Neck = { rot = Vector3.new(11.37, 10.06, 0.23) },
					RightShoulder = { rot = Vector3.new(17.93, 0, 18.78) },
					LeftShoulder = { rot = Vector3.new(19.56, 0, -23.88) },
					RightHip = { rot = Vector3.new(9.28, 0, 6.76), pos = Vector3.new(0, 0.26, 0) },
					LeftHip = { rot = Vector3.new(15.89, 0, -4.99), pos = Vector3.new(0, 0.24, 0) },
				},
			},
			{
				time = 1.1333,
				pose = {
					Root = {
						rot = Vector3.new(-11.73, -9.76, -2.11),
						pos = Vector3.new(0, -0.15, -0.13),
					},
					Neck = { rot = Vector3.new(11.57, 9.99, 0.14) },
					RightShoulder = { rot = Vector3.new(16.87, 0, 18.99) },
					LeftShoulder = { rot = Vector3.new(18.66, 0, -24.02) },
					RightHip = { rot = Vector3.new(8.32, 0, 6.83), pos = Vector3.new(0, 0.26, 0) },
					LeftHip = { rot = Vector3.new(14.99, 0, -4.91), pos = Vector3.new(0, 0.23, 0) },
				},
			},
			{
				time = 1.2,
				pose = {
					Root = {
						rot = Vector3.new(-11.62, -9.75, -2.1),
						pos = Vector3.new(0, -0.15, -0.13),
					},
					Neck = { rot = Vector3.new(11.6, 9.98, 0.12) },
					RightShoulder = { rot = Vector3.new(16.73, 0, 19.02) },
					LeftShoulder = { rot = Vector3.new(18.55, 0, -24.04) },
					RightHip = { rot = Vector3.new(8.19, 0, 6.84), pos = Vector3.new(0, 0.26, 0) },
					LeftHip = { rot = Vector3.new(14.87, 0, -4.9), pos = Vector3.new(0, 0.23, 0) },
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
						pos = Vector3.new(0, 0.08, -0.1),
					},
					Neck = { rot = Vector3.new(-10.33, -0.04, -0.04) },
					RightShoulder = { rot = Vector3.new(60.21, 0, 9.33) },
					LeftShoulder = { rot = Vector3.new(60.41, 0, -20.11) },
					RightHip = { rot = Vector3.new(26.84, 0, 3.79), pos = Vector3.new(0, 0.08, 0) },
					LeftHip = { rot = Vector3.new(12.7, 0, -2.79), pos = Vector3.new(0, 0.04, 0) },
				},
			},
			{
				time = 0.0667,
				pose = {
					Root = {
						rot = Vector3.new(-22.8, 3.13, 1.22),
						pos = Vector3.new(-0.01, -0.41, -0.34),
					},
					Neck = { rot = Vector3.new(-3.92, 0.26, 2.4) },
					RightShoulder = { rot = Vector3.new(65.32, 0, 2.89) },
					LeftShoulder = { rot = Vector3.new(62.78, 0, -16.62) },
					RightHip = { rot = Vector3.new(23.25, 0, 3.41), pos = Vector3.new(0, 0.43, 0) },
					LeftHip = { rot = Vector3.new(13.81, 0, -2.69), pos = Vector3.new(0, 0.46, 0) },
				},
			},
			{
				time = 0.1333,
				pose = {
					Root = {
						rot = Vector3.new(-42.94, 9.65, 6.71),
						pos = Vector3.new(-0.06, -0.86, -0.8),
					},
					Neck = { rot = Vector3.new(11.44, -1.18, 7.93) },
					RightShoulder = { rot = Vector3.new(69.3, 0, -6.65) },
					LeftShoulder = { rot = Vector3.new(69.93, 0, -10.44) },
					RightHip = { rot = Vector3.new(23.5, 0, 1.91), pos = Vector3.new(0, 0.91, 0) },
					LeftHip = { rot = Vector3.new(18.79, 0, -3.6), pos = Vector3.new(0, 0.9, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = {
						rot = Vector3.new(-74.86, 13.5, 19.28),
						pos = Vector3.new(-0.2, -1.4, -1.4),
					},
					Neck = { rot = Vector3.new(29.7, -9.31, 12.46) },
					RightShoulder = { rot = Vector3.new(76.59, 0, -11.69) },
					LeftShoulder = { rot = Vector3.new(84.7, 0, 0.29) },
					RightHip = { rot = Vector3.new(17.42, 0, 0.33), pos = Vector3.new(0, 1.25, 0) },
					LeftHip = { rot = Vector3.new(21.61, 0, -7.88), pos = Vector3.new(0, 1.26, 0) },
				},
			},
			{
				time = 0.2667,
				pose = {
					Root = {
						rot = Vector3.new(-111.86, 9.45, 34.05),
						pos = Vector3.new(-0.35, -1.99, -1.92),
					},
					Neck = { rot = Vector3.new(9.03, 16.52, 0.86) },
					RightShoulder = { rot = Vector3.new(79.78, 0, -18.29) },
					LeftShoulder = { rot = Vector3.new(107.48, 0, 14.71) },
					RightHip = { rot = Vector3.new(24.88, 0, -9.43), pos = Vector3.new(0, 0.95, 0) },
					LeftHip = { rot = Vector3.new(34.63, 0, -15.62), pos = Vector3.new(0, 1.23, 0) },
				},
			},
			{
				time = 0.3333,
				pose = {
					Root = {
						rot = Vector3.new(-145.83, 1.32, 43.21),
						pos = Vector3.new(-0.4, -2.38, -2.2),
					},
					Neck = { rot = Vector3.new(-26.59, 20.42, 43.05) },
					RightShoulder = { rot = Vector3.new(91.28, 0, -20.81) },
					LeftShoulder = { rot = Vector3.new(121.05, 0, 17.63) },
					RightHip = {
						rot = Vector3.new(53.84, 0, -13.72),
						pos = Vector3.new(0, 0.57, 0),
					},
					LeftHip = { rot = Vector3.new(56.84, 0, -14.15), pos = Vector3.new(0, 1.06, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = {
						rot = Vector3.new(-175.28, -2.57, 50.1),
						pos = Vector3.new(-0.4, -2.49, -2.4),
					},
					Neck = { rot = Vector3.new(-20.95, 9.23, 35.05) },
					RightShoulder = { rot = Vector3.new(104.94, 0, -9.41) },
					LeftShoulder = { rot = Vector3.new(127.05, 0, 21.24) },
					RightHip = { rot = Vector3.new(62.23, 0, -1.14), pos = Vector3.new(0, 0.9, 0) },
					LeftHip = { rot = Vector3.new(57.92, 0, -11.55), pos = Vector3.new(0, 1.29, 0) },
				},
			},
			{
				time = 0.4667,
				pose = {
					Root = {
						rot = Vector3.new(-198.3, -4.08, 59.17),
						pos = Vector3.new(-0.44, -2.5, -2.71),
					},
					Neck = { rot = Vector3.new(-47.16, 3.9, 28.89) },
					RightShoulder = { rot = Vector3.new(92.04, 0, -4.23) },
					LeftShoulder = { rot = Vector3.new(112.04, 0, 16.49) },
					RightHip = { rot = Vector3.new(55.47, 0, -5.17), pos = Vector3.new(0, 0.75, 0) },
					LeftHip = { rot = Vector3.new(52.16, 0, -8.26), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.5333,
				pose = {
					Root = {
						rot = Vector3.new(-226.86, -6.21, 62.38),
						pos = Vector3.new(-0.44, -2.56, -2.99),
					},
					Neck = { rot = Vector3.new(-73.41, 14.17, 26.52) },
					RightShoulder = { rot = Vector3.new(75.29, 0, -12.13) },
					LeftShoulder = { rot = Vector3.new(95.54, 0, 2.34) },
					RightHip = { rot = Vector3.new(44, 0, -5.86), pos = Vector3.new(0, 1.02, 0) },
					LeftHip = { rot = Vector3.new(46.57, 0, -5.31), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-268.46, -10.86, 63.34),
						pos = Vector3.new(-0.44, -2.52, -3.22),
					},
					Neck = { rot = Vector3.new(-59.02, 35.57, 7.17) },
					RightShoulder = { rot = Vector3.new(71.59, 0, -5.41) },
					LeftShoulder = { rot = Vector3.new(93.77, 0, -0.69) },
					RightHip = {
						rot = Vector3.new(42.69, 0, -10.46),
						pos = Vector3.new(0, 1.07, 0),
					},
					LeftHip = { rot = Vector3.new(40.54, 0, -1.58), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.6667,
				pose = {
					Root = {
						rot = Vector3.new(-309.37, -13.02, 58.73),
						pos = Vector3.new(-0.42, -2.26, -3.55),
					},
					Neck = { rot = Vector3.new(-20.11, 30.42, -25.17) },
					RightShoulder = { rot = Vector3.new(61.9, 0, -3.24) },
					LeftShoulder = { rot = Vector3.new(87.28, 0, -14.51) },
					RightHip = { rot = Vector3.new(51.1, 0, -11.33), pos = Vector3.new(0, 1, 0) },
					LeftHip = { rot = Vector3.new(32.44, 0, 0.22), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.7333,
				pose = {
					Root = {
						rot = Vector3.new(-334.77, -7.17, 51.86),
						pos = Vector3.new(-0.4, -2.12, -3.83),
					},
					Neck = { rot = Vector3.new(-5.94, 14.88, -33.8) },
					RightShoulder = { rot = Vector3.new(69.04, 0, -3.25) },
					LeftShoulder = { rot = Vector3.new(36.79, 0, -49.77) },
					RightHip = {
						rot = Vector3.new(54.16, 0, -10.55),
						pos = Vector3.new(0, 0.95, 0),
					},
					LeftHip = { rot = Vector3.new(37.62, 0, 8.18), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = {
						rot = Vector3.new(-349.17, 1.95, 42.18),
						pos = Vector3.new(-0.32, -1.89, -4.07),
					},
					Neck = { rot = Vector3.new(-2.6, 1.2, -29.85) },
					RightShoulder = { rot = Vector3.new(69.05, 0, -2.09) },
					LeftShoulder = { rot = Vector3.new(16.54, 0, -51.73) },
					RightHip = { rot = Vector3.new(51.81, 0, -9), pos = Vector3.new(0, 0.95, 0) },
					LeftHip = { rot = Vector3.new(34.34, 0, 13.66), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.8667,
				pose = {
					Root = {
						rot = Vector3.new(-361.02, 10.31, 36.46),
						pos = Vector3.new(-0.27, -1.64, -4.41),
					},
					Neck = { rot = Vector3.new(1.43, -11.91, -26.39) },
					RightShoulder = { rot = Vector3.new(63.3, 0, 6.94) },
					LeftShoulder = { rot = Vector3.new(6.84, 0, -51.56) },
					RightHip = { rot = Vector3.new(44.45, 0, -2.74), pos = Vector3.new(0, 1.12, 0) },
					LeftHip = { rot = Vector3.new(24.28, 0, 14.81), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.9333,
				pose = {
					Root = {
						rot = Vector3.new(-370.56, 17.36, 32.54),
						pos = Vector3.new(-0.24, -1.41, -4.77),
					},
					Neck = { rot = Vector3.new(6.19, -22.79, -22.01) },
					RightShoulder = { rot = Vector3.new(57.96, 0, 17.52) },
					LeftShoulder = { rot = Vector3.new(2.28, 0, -50.25) },
					RightHip = { rot = Vector3.new(36.91, 0, 1.65), pos = Vector3.new(0, 1.18, 0) },
					LeftHip = { rot = Vector3.new(16.93, 0, 7.66), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 1,
				pose = {
					Root = {
						rot = Vector3.new(-378.51, 22.52, 29.34),
						pos = Vector3.new(-0.22, -1.2, -5.11),
					},
					Neck = { rot = Vector3.new(11.52, -29.74, -16.55) },
					RightShoulder = { rot = Vector3.new(51, 0, 26.2) },
					LeftShoulder = { rot = Vector3.new(15.64, 0, -45.2) },
					RightHip = { rot = Vector3.new(31.29, 0, 3.47), pos = Vector3.new(0, 1.12, 0) },
					LeftHip = { rot = Vector3.new(17.91, 0, 4.33), pos = Vector3.new(0, 1.41, 0) },
				},
			},
			{
				time = 1.0667,
				pose = {
					Root = {
						rot = Vector3.new(-384.25, 25.54, 26.48),
						pos = Vector3.new(-0.2, -1, -5.41),
					},
					Neck = { rot = Vector3.new(16.25, -33.06, -11.66) },
					RightShoulder = { rot = Vector3.new(41.66, 0, 31.17) },
					LeftShoulder = { rot = Vector3.new(17.86, 0, -42.35) },
					RightHip = { rot = Vector3.new(28.17, 0, 3.66), pos = Vector3.new(0, 0.99, 0) },
					LeftHip = { rot = Vector3.new(17.62, 0, -0.32), pos = Vector3.new(0, 1.26, 0) },
				},
			},
			{
				time = 1.1333,
				pose = {
					Root = {
						rot = Vector3.new(-387.37, 26.74, 23.16),
						pos = Vector3.new(-0.18, -0.84, -5.66),
					},
					Neck = { rot = Vector3.new(19.44, -33.47, -7.75) },
					RightShoulder = { rot = Vector3.new(33.98, 0, 32.93) },
					LeftShoulder = { rot = Vector3.new(16.66, 0, -39.25) },
					RightHip = { rot = Vector3.new(26.76, 0, 3.88), pos = Vector3.new(0, 0.85, 0) },
					LeftHip = { rot = Vector3.new(20.62, 0, -7.6), pos = Vector3.new(0, 1.05, 0) },
				},
			},
			{
				time = 1.2,
				pose = {
					Root = {
						rot = Vector3.new(-388.14, 26.45, 19.14),
						pos = Vector3.new(-0.15, -0.7, -5.82),
					},
					Neck = { rot = Vector3.new(20.75, -31.73, -4.9) },
					RightShoulder = { rot = Vector3.new(30.7, 0, 33.44) },
					LeftShoulder = { rot = Vector3.new(15.32, 0, -35.02) },
					RightHip = { rot = Vector3.new(26.34, 0, 4.68), pos = Vector3.new(0, 0.73, 0) },
					LeftHip = { rot = Vector3.new(21.98, 0, -9.99), pos = Vector3.new(0, 0.88, 0) },
				},
			},
			{
				time = 1.2667,
				pose = {
					Root = {
						rot = Vector3.new(-387.27, 25, 14.89),
						pos = Vector3.new(-0.11, -0.61, -5.92),
					},
					Neck = { rot = Vector3.new(20.43, -28.71, -2.96) },
					RightShoulder = { rot = Vector3.new(30.22, 0, 33.02) },
					LeftShoulder = { rot = Vector3.new(13.15, 0, -31.22) },
					RightHip = { rot = Vector3.new(25.92, 0, 5.53), pos = Vector3.new(0, 0.66, 0) },
					LeftHip = { rot = Vector3.new(19.99, 0, -8.89), pos = Vector3.new(0, 0.75, 0) },
				},
			},
			{
				time = 1.3333,
				pose = {
					Root = {
						rot = Vector3.new(-385.62, 22.86, 11.04),
						pos = Vector3.new(-0.07, -0.55, -5.97),
					},
					Neck = { rot = Vector3.new(19.1, -25.25, -1.73) },
					RightShoulder = { rot = Vector3.new(31.63, 0, 31.99) },
					LeftShoulder = { rot = Vector3.new(10.18, 0, -28.43) },
					RightHip = { rot = Vector3.new(25.44, 0, 6.16), pos = Vector3.new(0, 0.62, 0) },
					LeftHip = { rot = Vector3.new(17.5, 0, -7.79), pos = Vector3.new(0, 0.67, 0) },
				},
			},
			{
				time = 1.4,
				pose = {
					Root = {
						rot = Vector3.new(-383.94, 20.64, 8.15),
						pos = Vector3.new(-0.04, -0.52, -6),
					},
					Neck = { rot = Vector3.new(17.49, -22.17, -1) },
					RightShoulder = { rot = Vector3.new(33.9, 0, 30.95) },
					LeftShoulder = { rot = Vector3.new(6.92, 0, -26.74) },
					RightHip = { rot = Vector3.new(25.03, 0, 6.49), pos = Vector3.new(0, 0.61, 0) },
					LeftHip = { rot = Vector3.new(15.18, 0, -6.89), pos = Vector3.new(0, 0.63, 0) },
				},
			},
			{
				time = 1.4667,
				pose = {
					Root = {
						rot = Vector3.new(-382.84, 19.14, 6.58),
						pos = Vector3.new(-0.03, -0.51, -6.01),
					},
					Neck = { rot = Vector3.new(16.36, -20.25, -0.67) },
					RightShoulder = { rot = Vector3.new(35.65, 0, 30.17) },
					LeftShoulder = { rot = Vector3.new(4.64, 0, -25.92) },
					RightHip = { rot = Vector3.new(24.8, 0, 6.58), pos = Vector3.new(0, 0.6, 0) },
					LeftHip = { rot = Vector3.new(13.72, 0, -6.37), pos = Vector3.new(0, 0.61, 0) },
				},
			},
			{
				time = 1.5333,
				pose = {
					Root = {
						rot = Vector3.new(-382.68, 18.91, 6.37),
						pos = Vector3.new(-0.02, -0.5, -6.01),
					},
					Neck = { rot = Vector3.new(16.19, -19.98, -0.63) },
					RightShoulder = { rot = Vector3.new(35.93, 0, 30.04) },
					LeftShoulder = { rot = Vector3.new(4.29, 0, -25.82) },
					RightHip = { rot = Vector3.new(24.77, 0, 6.59), pos = Vector3.new(0, 0.6, 0) },
					LeftHip = { rot = Vector3.new(13.51, 0, -6.3), pos = Vector3.new(0, 0.61, 0) },
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
					Root = { rot = Vector3.new(84.72, 0, -0.14), pos = Vector3.new(0, -2.66, 0.94) },
					Neck = { rot = Vector3.new(45.63, 0.05, -0.1) },
					RightShoulder = { rot = Vector3.new(-16.81, 0, 48.83) },
					LeftShoulder = { rot = Vector3.new(-8.25, 0, -41.45) },
					RightHip = { rot = Vector3.new(11.07, 0, 11.44), pos = Vector3.new(0, 0.32, 0) },
					LeftHip = { rot = Vector3.new(10.79, 0, -7.21), pos = Vector3.new(0, 0.39, 0) },
				},
			},
			{
				time = 0.0667,
				pose = {
					Root = {
						rot = Vector3.new(78.36, -0.55, -1.17),
						pos = Vector3.new(0.02, -2.55, 0.92),
					},
					Neck = { rot = Vector3.new(10.12, -0.5, 0.87) },
					RightShoulder = { rot = Vector3.new(-16.43, 0, 44.02) },
					LeftShoulder = { rot = Vector3.new(3.95, 0, -35.68) },
					RightHip = { rot = Vector3.new(16.76, 0, 12.12), pos = Vector3.new(0, 0.35, 0) },
					LeftHip = { rot = Vector3.new(15.37, 0, -6.75), pos = Vector3.new(0, 0.44, 0) },
				},
			},
			{
				time = 0.1333,
				pose = {
					Root = {
						rot = Vector3.new(60.1, -1.11, -4.28),
						pos = Vector3.new(0.07, -2.26, 0.79),
					},
					Neck = { rot = Vector3.new(-23.6, -3.38, 0.69) },
					RightShoulder = { rot = Vector3.new(-15.85, 0, 33.97) },
					LeftShoulder = { rot = Vector3.new(30.92, 0, -19.37) },
					RightHip = { rot = Vector3.new(31.82, 0, 13.64), pos = Vector3.new(0, 0.48, 0) },
					LeftHip = { rot = Vector3.new(27.2, 0, -4.71), pos = Vector3.new(0, 0.63, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = {
						rot = Vector3.new(37.72, -0.19, -8.69),
						pos = Vector3.new(0.15, -1.97, 0.51),
					},
					Neck = { rot = Vector3.new(-23.49, -5.58, -0.33) },
					RightShoulder = { rot = Vector3.new(-16.18, 0, 28.02) },
					LeftShoulder = { rot = Vector3.new(59.78, 0, 0.14) },
					RightHip = { rot = Vector3.new(45.46, 0, 14.87), pos = Vector3.new(0, 0.79, 0) },
					LeftHip = { rot = Vector3.new(34.01, 0, -2.83), pos = Vector3.new(0, 1.04, 0) },
				},
			},
			{
				time = 0.2667,
				pose = {
					Root = {
						rot = Vector3.new(21.9, 1.06, -12.64),
						pos = Vector3.new(0.22, -1.85, 0.25),
					},
					Neck = { rot = Vector3.new(-18.2, -6.17, -0.73) },
					RightShoulder = { rot = Vector3.new(-17.98, 0, 27.62) },
					LeftShoulder = { rot = Vector3.new(79.17, 0, 14.15) },
					RightHip = { rot = Vector3.new(48.97, 0, 14.92), pos = Vector3.new(0, 1.21, 0) },
					LeftHip = { rot = Vector3.new(30.2, 0, -1.93), pos = Vector3.new(0, 1.45, 0) },
				},
			},
			{
				time = 0.3333,
				pose = {
					Root = {
						rot = Vector3.new(9.87, 1.89, -14.99),
						pos = Vector3.new(0.26, -1.8, 0.04),
					},
					Neck = { rot = Vector3.new(-12.72, -5.06, -1.5) },
					RightShoulder = { rot = Vector3.new(-18.37, 0, 27.63) },
					LeftShoulder = { rot = Vector3.new(90.84, 0, 22.56) },
					RightHip = { rot = Vector3.new(48.71, 0, 13.9), pos = Vector3.new(0, 1.56, 0) },
					LeftHip = { rot = Vector3.new(29.06, 0, -0.6), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = {
						rot = Vector3.new(-1.53, 3.01, -16.88),
						pos = Vector3.new(0.29, -1.78, -0.14),
					},
					Neck = { rot = Vector3.new(-4.66, -3.31, -1.97) },
					RightShoulder = { rot = Vector3.new(-16.47, 0, 27.98) },
					LeftShoulder = { rot = Vector3.new(95.42, 0, 23.21) },
					RightHip = { rot = Vector3.new(58.27, 0, 10.9), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(29.65, 0, 6.11), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.4667,
				pose = {
					Root = {
						rot = Vector3.new(-12.93, 4.84, -20.15),
						pos = Vector3.new(0.33, -1.77, -0.29),
					},
					Neck = { rot = Vector3.new(5.71, -1.39, -0.5) },
					RightShoulder = { rot = Vector3.new(-11.64, 0, 29.88) },
					LeftShoulder = { rot = Vector3.new(97.19, 0, 16.58) },
					RightHip = { rot = Vector3.new(70.49, 0, 4.53), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(19.23, 0, 8.31), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.5333,
				pose = {
					Root = {
						rot = Vector3.new(-22.35, 6.95, -26.09),
						pos = Vector3.new(0.37, -1.79, -0.36),
					},
					Neck = { rot = Vector3.new(15.01, 1.4, 3.87) },
					RightShoulder = { rot = Vector3.new(-4.45, 0, 35.45) },
					LeftShoulder = { rot = Vector3.new(95.89, 0, 4.99) },
					RightHip = { rot = Vector3.new(77.24, 0, -8.54), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(24.97, 0, 7.02), pos = Vector3.new(0, 1.59, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-29.56, 8.44, -30.52),
						pos = Vector3.new(0.36, -1.78, -0.36),
					},
					Neck = { rot = Vector3.new(21.83, 4.76, 6.67) },
					RightShoulder = { rot = Vector3.new(6.33, 0, 41.48) },
					LeftShoulder = { rot = Vector3.new(90.18, 0, -7.5) },
					RightHip = { rot = Vector3.new(69.16, 0, -21.66), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(34.41, 0, 5.82), pos = Vector3.new(0, 1.59, 0) },
				},
			},
			{
				time = 0.6667,
				pose = {
					Root = {
						rot = Vector3.new(-35.48, 10.01, -33.43),
						pos = Vector3.new(0.34, -1.76, -0.31),
					},
					Neck = { rot = Vector3.new(27.48, 7.56, 8.2) },
					RightShoulder = { rot = Vector3.new(19.01, 0, 45.88) },
					LeftShoulder = { rot = Vector3.new(81.3, 0, -19.53) },
					RightHip = { rot = Vector3.new(47.25, 0, -24.5), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(42.49, 0, 6.44), pos = Vector3.new(0, 1.58, 0) },
				},
			},
			{
				time = 0.7333,
				pose = {
					Root = {
						rot = Vector3.new(-40.3, 12.02, -36.74),
						pos = Vector3.new(0.35, -1.74, -0.25),
					},
					Neck = { rot = Vector3.new(32.12, 10.11, 10.7) },
					RightShoulder = { rot = Vector3.new(32.14, 0, 48.88) },
					LeftShoulder = { rot = Vector3.new(67.96, 0, -29.98) },
					RightHip = { rot = Vector3.new(50, 0, -23.84), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(50, 0, 4.92), pos = Vector3.new(0, 1.58, 0) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = {
						rot = Vector3.new(-43.56, 13.5, -39.39),
						pos = Vector3.new(0.39, -1.71, -0.18),
					},
					Neck = { rot = Vector3.new(35.18, 12.18, 13) },
					RightShoulder = { rot = Vector3.new(42.81, 0, 49.94) },
					LeftShoulder = { rot = Vector3.new(49.98, 0, -35.59) },
					RightHip = { rot = Vector3.new(33.56, 0, -24.99), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(53.5, 0, 1.03), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.8667,
				pose = {
					Root = {
						rot = Vector3.new(-45.98, 14.31, -40.09),
						pos = Vector3.new(0.43, -1.68, -0.13),
					},
					Neck = { rot = Vector3.new(37.5, 13.25, 13.96) },
					RightShoulder = { rot = Vector3.new(47.87, 0, 49.37) },
					LeftShoulder = { rot = Vector3.new(32.72, 0, -36.55) },
					RightHip = { rot = Vector3.new(13.34, 0, -17.33), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(54.68, 0, -1.22), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 0.9333,
				pose = {
					Root = {
						rot = Vector3.new(-47.63, 14.63, -38.23),
						pos = Vector3.new(0.46, -1.66, -0.12),
					},
					Neck = { rot = Vector3.new(39.36, 12.68, 13.34) },
					RightShoulder = { rot = Vector3.new(45.38, 0, 48.7) },
					LeftShoulder = { rot = Vector3.new(20.94, 0, -35.54) },
					RightHip = { rot = Vector3.new(2.65, 0, -8.78), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(56.22, 0, -2.44), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 1,
				pose = {
					Root = {
						rot = Vector3.new(-46.83, 12.83, -33.18),
						pos = Vector3.new(0.44, -1.6, -0.13),
					},
					Neck = { rot = Vector3.new(38.85, 10.05, 10.47) },
					RightShoulder = { rot = Vector3.new(37.27, 0, 47.2) },
					LeftShoulder = { rot = Vector3.new(14.23, 0, -35.65) },
					RightHip = { rot = Vector3.new(-1.65, 0, -4.19), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(55.77, 0, -0.36), pos = Vector3.new(0, 1.55, 0) },
				},
			},
			{
				time = 1.0667,
				pose = {
					Root = {
						rot = Vector3.new(-43.35, 9.28, -27.4),
						pos = Vector3.new(0.39, -1.52, -0.13),
					},
					Neck = { rot = Vector3.new(35.56, 7.28, 7.43) },
					RightShoulder = { rot = Vector3.new(31.43, 0, 44.55) },
					LeftShoulder = { rot = Vector3.new(10.18, 0, -35.92) },
					RightHip = { rot = Vector3.new(-2.04, 0, -3.37), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(48.72, 0, 0.94), pos = Vector3.new(0, 1.52, 0) },
				},
			},
			{
				time = 1.1333,
				pose = {
					Root = {
						rot = Vector3.new(-38.36, 4.56, -21.98),
						pos = Vector3.new(0.32, -1.43, -0.1),
					},
					Neck = { rot = Vector3.new(30.66, 6.04, 4.79) },
					RightShoulder = { rot = Vector3.new(30.19, 0, 39.47) },
					LeftShoulder = { rot = Vector3.new(6.76, 0, -35.33) },
					RightHip = { rot = Vector3.new(-1.41, 0, -1.95), pos = Vector3.new(0, 1.6, 0) },
					LeftHip = { rot = Vector3.new(45.76, 0, -0.56), pos = Vector3.new(0, 1.48, 0) },
				},
			},
			{
				time = 1.2,
				pose = {
					Root = {
						rot = Vector3.new(-34.04, 0.68, -17.08),
						pos = Vector3.new(0.25, -1.36, -0.1),
					},
					Neck = { rot = Vector3.new(26.88, 5.89, 3.23) },
					RightShoulder = { rot = Vector3.new(31.02, 0, 33.86) },
					LeftShoulder = { rot = Vector3.new(6.12, 0, -33.57) },
					RightHip = { rot = Vector3.new(-0.96, 0, -0.94), pos = Vector3.new(0, 1.55, 0) },
					LeftHip = { rot = Vector3.new(42.21, 0, -1.8), pos = Vector3.new(0, 1.44, 0) },
				},
			},
			{
				time = 1.2667,
				pose = {
					Root = {
						rot = Vector3.new(-30.23, -2.42, -12.5),
						pos = Vector3.new(0.18, -1.31, -0.1),
					},
					Neck = { rot = Vector3.new(24, 6.3, 2.24) },
					RightShoulder = { rot = Vector3.new(31.57, 0, 28.09) },
					LeftShoulder = { rot = Vector3.new(7.74, 0, -30.84) },
					RightHip = { rot = Vector3.new(-2.33, 0, -1.6), pos = Vector3.new(0, 1.44, 0) },
					LeftHip = { rot = Vector3.new(35.95, 0, -2.11), pos = Vector3.new(0, 1.4, 0) },
				},
			},
			{
				time = 1.3333,
				pose = {
					Root = {
						rot = Vector3.new(-26.57, -4.86, -8.45),
						pos = Vector3.new(0.11, -1.27, -0.1),
					},
					Neck = { rot = Vector3.new(21.51, 6.92, 1.51) },
					RightShoulder = { rot = Vector3.new(31.5, 0, 22.1) },
					LeftShoulder = { rot = Vector3.new(9.9, 0, -26.71) },
					RightHip = { rot = Vector3.new(-4.08, 0, -2.46), pos = Vector3.new(0, 1.34, 0) },
					LeftHip = { rot = Vector3.new(31.22, 0, -2.2), pos = Vector3.new(0, 1.36, 0) },
				},
			},
			{
				time = 1.4,
				pose = {
					Root = {
						rot = Vector3.new(-23.6, -6.49, -5.32),
						pos = Vector3.new(0.05, -1.24, -0.1),
					},
					Neck = { rot = Vector3.new(19.67, 7.54, 1.02) },
					RightShoulder = { rot = Vector3.new(30.79, 0, 17.23) },
					LeftShoulder = { rot = Vector3.new(11.48, 0, -22.07) },
					RightHip = { rot = Vector3.new(-5.71, 0, -3.2), pos = Vector3.new(0, 1.27, 0) },
					LeftHip = { rot = Vector3.new(28.68, 0, -2.65), pos = Vector3.new(0, 1.34, 0) },
				},
			},
			{
				time = 1.4667,
				pose = {
					Root = {
						rot = Vector3.new(-21.89, -7.3, -3.54),
						pos = Vector3.new(0.02, -1.22, -0.1),
					},
					Neck = { rot = Vector3.new(18.67, 7.91, 0.77) },
					RightShoulder = { rot = Vector3.new(30.08, 0, 14.47) },
					LeftShoulder = { rot = Vector3.new(12.22, 0, -19.07) },
					RightHip = { rot = Vector3.new(-6.73, 0, -3.63), pos = Vector3.new(0, 1.24, 0) },
					LeftHip = { rot = Vector3.new(27.44, 0, -3.19), pos = Vector3.new(0, 1.34, 0) },
				},
			},
			{
				time = 1.5333,
				pose = {
					Root = {
						rot = Vector3.new(-21.65, -7.4, -3.3),
						pos = Vector3.new(0.01, -1.22, -0.1),
					},
					Neck = { rot = Vector3.new(18.53, 7.96, 0.74) },
					RightShoulder = { rot = Vector3.new(29.96, 0, 14.09) },
					LeftShoulder = { rot = Vector3.new(12.32, 0, -18.63) },
					RightHip = { rot = Vector3.new(-6.87, 0, -3.69), pos = Vector3.new(0, 1.23, 0) },
					LeftHip = { rot = Vector3.new(27.27, 0, -3.26), pos = Vector3.new(0, 1.33, 0) },
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
						pos = Vector3.new(0.05, -2.65, -1.05),
					},
					Neck = { rot = Vector3.new(-8.53, -40.4, 1.76) },
					RightShoulder = { rot = Vector3.new(146.28, 0, 49.74) },
					LeftShoulder = { rot = Vector3.new(154.05, 0, -57.77) },
					RightHip = {
						rot = Vector3.new(-11.01, 0, 11.85),
						pos = Vector3.new(0, 0.49, 0),
					},
					LeftHip = { rot = Vector3.new(-13.88, 0, 1.69) },
				},
			},
			{
				time = 0.0667,
				pose = {
					Root = {
						rot = Vector3.new(-83.65, -1.74, -5.6),
						pos = Vector3.new(0.04, -2.65, -1.05),
					},
					Neck = { rot = Vector3.new(-0.69, -35.37, 6.5) },
					RightShoulder = { rot = Vector3.new(117.19, 0, 54.77) },
					LeftShoulder = { rot = Vector3.new(137.33, 0, -61.17) },
					RightHip = { rot = Vector3.new(-11.16, 0, 11.62), pos = Vector3.new(0, 0.5, 0) },
					LeftHip = { rot = Vector3.new(-13.76, 0, 1.44) },
				},
			},
			{
				time = 0.1333,
				pose = {
					Root = {
						rot = Vector3.new(-83.42, -0.63, -5.19),
						pos = Vector3.new(0.04, -2.65, -1.05),
					},
					Neck = { rot = Vector3.new(14.92, -22.17, 11.46) },
					RightShoulder = { rot = Vector3.new(49.47, 0, 32.12) },
					LeftShoulder = { rot = Vector3.new(78.1, 0, -54.27) },
					RightHip = {
						rot = Vector3.new(-11.77, 0, 10.59),
						pos = Vector3.new(0, 0.52, 0),
					},
					LeftHip = { rot = Vector3.new(-13.37, 0, 0.27), pos = Vector3.new(0, 0.03, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = {
						rot = Vector3.new(-83.16, 0.46, -4.51),
						pos = Vector3.new(0.03, -2.65, -1.05),
					},
					Neck = { rot = Vector3.new(31.9, -7.74, 8.38) },
					RightShoulder = { rot = Vector3.new(42.77, 0, 25.3) },
					LeftShoulder = { rot = Vector3.new(50.65, 0, -31.26) },
					RightHip = { rot = Vector3.new(-12.49, 0, 9.72), pos = Vector3.new(0, 0.54, 0) },
					LeftHip = { rot = Vector3.new(-13.32, 0, -1.79), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.2667,
				pose = {
					Root = {
						rot = Vector3.new(-81.26, 0.95, -3.32),
						pos = Vector3.new(0.01, -2.61, -1.05),
					},
					Neck = { rot = Vector3.new(45.64, 0.28, -0.28) },
					RightShoulder = { rot = Vector3.new(42.98, 0, 25.35) },
					LeftShoulder = { rot = Vector3.new(53.57, 0, -25.51) },
					RightHip = { rot = Vector3.new(-14.05, 0, 8.66), pos = Vector3.new(0, 0.56, 0) },
					LeftHip = { rot = Vector3.new(-14.82, 0, -3.92), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 0.3333,
				pose = {
					Root = {
						rot = Vector3.new(-72.1, 0.45, -1.94),
						pos = Vector3.new(-0.02, -2.46, -1.01),
					},
					Neck = { rot = Vector3.new(43.57, 1.46, -5.88) },
					RightShoulder = { rot = Vector3.new(43.59, 0, 23.41) },
					LeftShoulder = { rot = Vector3.new(57.79, 0, -19.65) },
					RightHip = { rot = Vector3.new(-20.02, 0, 8.08), pos = Vector3.new(0, 0.6, 0) },
					LeftHip = { rot = Vector3.new(-22.91, 0, -5.72), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = {
						rot = Vector3.new(-60.9, -0.61, -1.19),
						pos = Vector3.new(-0.05, -2.24, -0.93),
					},
					Neck = { rot = Vector3.new(28.87, 1.96, -6.72) },
					RightShoulder = { rot = Vector3.new(41.75, 0, 20.96) },
					LeftShoulder = { rot = Vector3.new(55.93, 0, -14.96) },
					RightHip = { rot = Vector3.new(-25.63, 0, 7.23), pos = Vector3.new(0, 0.68, 0) },
					LeftHip = { rot = Vector3.new(-31.94, 0, -5.63), pos = Vector3.new(0, 0.23, 0) },
				},
			},
			{
				time = 0.4667,
				pose = {
					Root = {
						rot = Vector3.new(-55.18, -2.22, -0.76),
						pos = Vector3.new(-0.07, -2.08, -0.86),
					},
					Neck = { rot = Vector3.new(14.25, 4.19, -6.94) },
					RightShoulder = { rot = Vector3.new(41.84, 0, 19.02) },
					LeftShoulder = { rot = Vector3.new(53.27, 0, -14.31) },
					RightHip = { rot = Vector3.new(-25.16, 0, 5.03), pos = Vector3.new(0, 0.82, 0) },
					LeftHip = { rot = Vector3.new(-35.07, 0, -4.84), pos = Vector3.new(0, 0.27, 0) },
				},
			},
			{
				time = 0.5333,
				pose = {
					Root = {
						rot = Vector3.new(-57.87, -3.69, -0.58),
						pos = Vector3.new(-0.07, -1.99, -0.85),
					},
					Neck = { rot = Vector3.new(5.29, 6.74, -6.22) },
					RightShoulder = { rot = Vector3.new(47.56, 0, 16.81) },
					LeftShoulder = { rot = Vector3.new(55.4, 0, -16.2) },
					RightHip = { rot = Vector3.new(-17.68, 0, 1.57), pos = Vector3.new(0, 0.91, 0) },
					LeftHip = { rot = Vector3.new(-29.06, 0, -4.59), pos = Vector3.new(0, 0.31, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-66.17, -4.75, -0.54),
						pos = Vector3.new(-0.06, -1.96, -0.85),
					},
					Neck = { rot = Vector3.new(1.94, 8.6, -5.18) },
					RightShoulder = { rot = Vector3.new(58.42, 0, 13.94) },
					LeftShoulder = { rot = Vector3.new(62.91, 0, -18.47) },
					RightHip = { rot = Vector3.new(-6.73, 0, -2.25), pos = Vector3.new(0, 1, 0) },
					LeftHip = { rot = Vector3.new(-17.63, 0, -5.2), pos = Vector3.new(0, 0.35, 0) },
				},
			},
			{
				time = 0.6667,
				pose = {
					Root = {
						rot = Vector3.new(-74.08, -5.51, -0.19),
						pos = Vector3.new(-0.05, -1.95, -0.83),
					},
					Neck = { rot = Vector3.new(0.95, 9.63, -4.8) },
					RightShoulder = { rot = Vector3.new(70.08, 0, 11.1) },
					LeftShoulder = { rot = Vector3.new(72.15, 0, -20.82) },
					RightHip = { rot = Vector3.new(3.37, 0, -6.7), pos = Vector3.new(0, 1.14, 0) },
					LeftHip = { rot = Vector3.new(-7.11, 0, -6.52), pos = Vector3.new(0, 0.41, 0) },
				},
			},
			{
				time = 0.7333,
				pose = {
					Root = {
						rot = Vector3.new(-79.96, -5.21, 0.6),
						pos = Vector3.new(-0.04, -1.99, -0.76),
					},
					Neck = { rot = Vector3.new(3.4, 8.77, -5.43) },
					RightShoulder = { rot = Vector3.new(80.14, 0, 10.27) },
					LeftShoulder = { rot = Vector3.new(81.95, 0, -22.18) },
					RightHip = { rot = Vector3.new(9.03, 0, -10.36), pos = Vector3.new(0, 1.27, 0) },
					LeftHip = { rot = Vector3.new(-0.02, 0, -8.25), pos = Vector3.new(0, 0.5, 0) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = {
						rot = Vector3.new(-83.26, -1.69, 1.36),
						pos = Vector3.new(-0.02, -2.03, -0.69),
					},
					Neck = { rot = Vector3.new(9.17, 3.62, -5.05) },
					RightShoulder = { rot = Vector3.new(86.78, 0, 14.02) },
					LeftShoulder = { rot = Vector3.new(92.2, 0, -19.05) },
					RightHip = { rot = Vector3.new(10.21, 0, -9.42), pos = Vector3.new(0, 1.38, 0) },
					LeftHip = { rot = Vector3.new(5.16, 0, -8.88), pos = Vector3.new(0, 0.58, 0) },
				},
			},
			{
				time = 0.8667,
				pose = {
					Root = {
						rot = Vector3.new(-84.12, 3.02, 1.61),
						pos = Vector3.new(0, -2.03, -0.62),
					},
					Neck = { rot = Vector3.new(16.71, -2.75, -1.73) },
					RightShoulder = { rot = Vector3.new(89.48, 0, 19.7) },
					LeftShoulder = { rot = Vector3.new(100.42, 0, -15.79) },
					RightHip = { rot = Vector3.new(9.45, 0, -8.73), pos = Vector3.new(0, 1.44, 0) },
					LeftHip = { rot = Vector3.new(7.53, 0, -9.28), pos = Vector3.new(0, 0.72, 0) },
				},
			},
			{
				time = 0.9333,
				pose = {
					Root = {
						rot = Vector3.new(-79.22, 6.38, 0.65),
						pos = Vector3.new(0.04, -1.93, -0.55),
					},
					Neck = { rot = Vector3.new(21.83, -6.36, 3.85) },
					RightShoulder = { rot = Vector3.new(85.84, 0, 22.83) },
					LeftShoulder = { rot = Vector3.new(97.7, 0, -19.43) },
					RightHip = { rot = Vector3.new(7.75, 0, -7.62), pos = Vector3.new(0, 1.45, 0) },
					LeftHip = { rot = Vector3.new(7.99, 0, -10.53), pos = Vector3.new(0, 1.13, 0) },
				},
			},
			{
				time = 1,
				pose = {
					Root = {
						rot = Vector3.new(-68.97, 6.84, -0.88),
						pos = Vector3.new(0.08, -1.75, -0.47),
					},
					Neck = { rot = Vector3.new(23.41, -5.62, 8) },
					RightShoulder = { rot = Vector3.new(76.63, 0, 21.07) },
					LeftShoulder = { rot = Vector3.new(84.33, 0, -27.04) },
					RightHip = { rot = Vector3.new(5.96, 0, -7), pos = Vector3.new(0, 1.44, 0) },
					LeftHip = { rot = Vector3.new(10.12, 0, -9.34), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 1.0667,
				pose = {
					Root = {
						rot = Vector3.new(-56.99, 4.1, -2.34),
						pos = Vector3.new(0.09, -1.57, -0.38),
					},
					Neck = { rot = Vector3.new(23.53, -1.27, 8.99) },
					RightShoulder = { rot = Vector3.new(63.95, 0, 17.04) },
					LeftShoulder = { rot = Vector3.new(62.58, 0, -33.17) },
					RightHip = { rot = Vector3.new(4.5, 0, -6.66), pos = Vector3.new(0, 1.4, 0) },
					LeftHip = { rot = Vector3.new(15.78, 0, 2.39), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 1.1333,
				pose = {
					Root = {
						rot = Vector3.new(-46.27, 0.98, -3.24),
						pos = Vector3.new(0.09, -1.44, -0.3),
					},
					Neck = { rot = Vector3.new(24.2, 2.66, 7.49) },
					RightShoulder = { rot = Vector3.new(52.32, 0, 14.87) },
					LeftShoulder = { rot = Vector3.new(41.4, 0, -31.97) },
					RightHip = { rot = Vector3.new(2.24, 0, -6.07), pos = Vector3.new(0, 1.34, 0) },
					LeftHip = { rot = Vector3.new(35.71, 0, 3), pos = Vector3.new(0, 1.6, 0) },
				},
			},
			{
				time = 1.2,
				pose = {
					Root = {
						rot = Vector3.new(-37.22, -1.77, -3.84),
						pos = Vector3.new(0.07, -1.34, -0.24),
					},
					Neck = { rot = Vector3.new(24.85, 4.88, 4.89) },
					RightShoulder = { rot = Vector3.new(45.09, 0, 13.59) },
					LeftShoulder = { rot = Vector3.new(26.87, 0, -28.81) },
					RightHip = { rot = Vector3.new(-0.7, 0, -5.31), pos = Vector3.new(0, 1.29, 0) },
					LeftHip = { rot = Vector3.new(35.77, 0, -2.62), pos = Vector3.new(0, 1.49, 0) },
				},
			},
			{
				time = 1.2667,
				pose = {
					Root = {
						rot = Vector3.new(-30.05, -4.21, -4.15),
						pos = Vector3.new(0.05, -1.28, -0.18),
					},
					Neck = { rot = Vector3.new(24.4, 6.03, 2.57) },
					RightShoulder = { rot = Vector3.new(39.73, 0, 13.31) },
					LeftShoulder = { rot = Vector3.new(17.91, 0, -25.06) },
					RightHip = { rot = Vector3.new(-3.5, 0, -4.45), pos = Vector3.new(0, 1.27, 0) },
					LeftHip = { rot = Vector3.new(32, 0, -2.9), pos = Vector3.new(0, 1.39, 0) },
				},
			},
			{
				time = 1.3333,
				pose = {
					Root = {
						rot = Vector3.new(-25.03, -6.12, -3.99),
						pos = Vector3.new(0.03, -1.25, -0.13),
					},
					Neck = { rot = Vector3.new(21.88, 7.01, 1.31) },
					RightShoulder = { rot = Vector3.new(35.41, 0, 13.54) },
					LeftShoulder = { rot = Vector3.new(13.55, 0, -21.77) },
					RightHip = { rot = Vector3.new(-5.49, 0, -3.84), pos = Vector3.new(0, 1.25, 0) },
					LeftHip = { rot = Vector3.new(29.18, 0, -2.98), pos = Vector3.new(0, 1.35, 0) },
				},
			},
			{
				time = 1.4,
				pose = {
					Root = {
						rot = Vector3.new(-22.51, -7.12, -3.44),
						pos = Vector3.new(0.02, -1.23, -0.11),
					},
					Neck = { rot = Vector3.new(19.37, 7.73, 0.8) },
					RightShoulder = { rot = Vector3.new(31.96, 0, 13.71) },
					LeftShoulder = { rot = Vector3.new(12.23, 0, -19.77) },
					RightHip = { rot = Vector3.new(-6.5, 0, -3.76), pos = Vector3.new(0, 1.23, 0) },
					LeftHip = { rot = Vector3.new(27.75, 0, -3.24), pos = Vector3.new(0, 1.34, 0) },
				},
			},
			{
				time = 1.4667,
				pose = {
					Root = {
						rot = Vector3.new(-21.76, -7.39, -3.3),
						pos = Vector3.new(0.01, -1.22, -0.1),
					},
					Neck = { rot = Vector3.new(18.64, 7.95, 0.72) },
					RightShoulder = { rot = Vector3.new(30.19, 0, 14.02) },
					LeftShoulder = { rot = Vector3.new(12.27, 0, -18.75) },
					RightHip = { rot = Vector3.new(-6.81, 0, -3.71), pos = Vector3.new(0, 1.23, 0) },
					LeftHip = { rot = Vector3.new(27.33, 0, -3.27), pos = Vector3.new(0, 1.33, 0) },
				},
			},
			{
				time = 1.5333,
				pose = {
					Root = {
						rot = Vector3.new(-21.73, -7.39, -3.3),
						pos = Vector3.new(0.01, -1.22, -0.1),
					},
					Neck = { rot = Vector3.new(18.61, 7.96, 0.73) },
					RightShoulder = { rot = Vector3.new(29.96, 0, 14.08) },
					LeftShoulder = { rot = Vector3.new(12.34, 0, -18.6) },
					RightHip = { rot = Vector3.new(-6.83, 0, -3.69), pos = Vector3.new(0, 1.23, 0) },
					LeftHip = { rot = Vector3.new(27.31, 0, -3.26), pos = Vector3.new(0, 1.33, 0) },
				},
			},
		},
	},
	-- END generated ALS clips
}

return table.freeze(clips)
