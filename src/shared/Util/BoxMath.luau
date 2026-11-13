--!strict
-- BoxMath: box geometry shared by the server's rewound hitbox (Server/
-- Systems/Combat/Hitbox) and the attacker's hit prediction (Client/Combat/
-- HitPrediction), so both answer exactly the same way.
-- No tables are created: safe to call every frame (a tackle tests its
-- hitbox each Heartbeat).

local BoxMath = {}

-- Shadow of a box (axes r, u, l, half sizes h) on `axis`: its half length.
local function radiusOn(axis: Vector3, r: Vector3, u: Vector3, l: Vector3, h: Vector3): number
	return h.X * math.abs(r:Dot(axis)) + h.Y * math.abs(u:Dot(axis)) + h.Z * math.abs(l:Dot(axis))
end

-- Is `axis` a direction where the two boxes' shadows don't touch?
local function separatedOn(
	axis: Vector3,
	between: Vector3,
	ar: Vector3,
	au: Vector3,
	al: Vector3,
	ha: Vector3,
	br: Vector3,
	bu: Vector3,
	bl: Vector3,
	hb: Vector3
): boolean
	if axis.Magnitude < 1e-6 then
		return false -- parallel edges: not a real direction
	end
	return math.abs(between:Dot(axis))
		> radiusOn(axis, ar, au, al, ha) + radiusOn(axis, br, bu, bl, hb)
end

-- Do two rotated boxes overlap? ("Separating axis" test: they DON'T
-- overlap if there is a direction in which their shadows don't touch. For
-- boxes, checking 15 directions is enough.)
function BoxMath.boxesOverlap(a: CFrame, sizeA: Vector3, b: CFrame, sizeB: Vector3): boolean
	local ar, au, al = a.RightVector, a.UpVector, a.LookVector
	local br, bu, bl = b.RightVector, b.UpVector, b.LookVector
	local ha, hb = sizeA / 2, sizeB / 2
	local between = b.Position - a.Position
	if
		separatedOn(ar, between, ar, au, al, ha, br, bu, bl, hb)
		or separatedOn(au, between, ar, au, al, ha, br, bu, bl, hb)
		or separatedOn(al, between, ar, au, al, ha, br, bu, bl, hb)
		or separatedOn(br, between, ar, au, al, ha, br, bu, bl, hb)
		or separatedOn(bu, between, ar, au, al, ha, br, bu, bl, hb)
		or separatedOn(bl, between, ar, au, al, ha, br, bu, bl, hb)
	then
		return false
	end
	for i = 1, 3 do
		local axisA = if i == 1 then ar elseif i == 2 then au else al
		if
			separatedOn(axisA:Cross(br), between, ar, au, al, ha, br, bu, bl, hb)
			or separatedOn(axisA:Cross(bu), between, ar, au, al, ha, br, bu, bl, hb)
			or separatedOn(axisA:Cross(bl), between, ar, au, al, ha, br, bu, bl, hb)
		then
			return false
		end
	end
	return true
end

-- One slab of the ray / box test: the [tMin, tMax] range narrowed to where
-- the ray is between -h and h on this axis, or nil if it never is.
local function slab(o: number, d: number, h: number, tMin: number, tMax: number): (number?, number)
	if math.abs(d) < 1e-9 then
		if o < -h or o > h then
			return nil, tMax -- parallel to this slab and outside it
		end
		return tMin, tMax
	end
	local t1, t2 = (-h - o) / d, (h - o) / d
	if t1 > t2 then
		t1, t2 = t2, t1
	end
	local low, high = math.max(tMin, t1), math.min(tMax, t2)
	if low > high then
		return nil, tMax
	end
	return low, high
end

-- How far along `direction` (in multiples of it) the ray from `origin`
-- enters the box, or nil if it misses it. ("Slab" method: the ray must be
-- inside the box on X, Y and Z at once.)
function BoxMath.rayHitsBox(
	origin: Vector3,
	direction: Vector3,
	box: CFrame,
	size: Vector3
): number?
	local o = box:PointToObjectSpace(origin)
	local d = box:VectorToObjectSpace(direction)
	local half = size / 2
	local tMin: number?, tMax = slab(o.X, d.X, half.X, 0, math.huge)
	if tMin == nil then
		return nil
	end
	tMin, tMax = slab(o.Y, d.Y, half.Y, tMin, tMax)
	if tMin == nil then
		return nil
	end
	tMin = slab(o.Z, d.Z, half.Z, tMin, tMax)
	return tMin
end

return table.freeze(BoxMath)
