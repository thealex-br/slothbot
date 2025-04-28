function _type(v)
	return isElement(v) and getElementType(v) or type(v)
end

_destroyElement = destroyElement
function destroyElement(element)
	return isElement(element) and _destroyElement(element)
end

_setPedCameraRotation = setPedCameraRotation
function setPedCameraRotation(thePed, rotation)
	if getPedTask(thePed, "secondary", 0) == "TASK_SIMPLE_USE_GUN" then
		local rx, ry = getElementRotation(thePed)
		return setElementRotation(thePed, rx, ry, rotation, "default", true)
	else
		return _setPedCameraRotation(thePed, -rotation)
	end
end

function getDistanceBetweenElements(element1, element2)
	local x1, y1, z1 = getElementPosition(element1)
	local x2, y2, z2 = getElementPosition(element2)
	return getDistanceBetweenPoints3D(x1, y1, z1, x2, y2, z2)
end

function findRotation(x1, y1, x2, y2)
	local t = -math.deg(math.atan2(x2 - x1, y2 - y1))
	return t < 0 and t + 360 or t
end

function getFuturePosition(element, x, y, z, time)
	local d = 1 / 60 * 1000
	local vx, vy, vz = getElementVelocity(element)
	return x + (time / d * vx), y + (time / d * vy), z + (time / d * vz)
end

function table.merge(t_1, t_2)
	local t = {}
	for i, v in ipairs(t_1) do
		table.insert(t, v)
	end
	for i, v in ipairs(t_2) do
		table.insert(t, v)
	end
	return t
end

function hasWaited(element, key, time)
	local lastWait = getElementData(element, key) or getTickCount()
	if getTickCount() - lastWait >= time then
		setElementData(element, key, getTickCount(), false)
		return true
	end
	return false
end

function getPedEyesPosition(ped)
	local x1, y1, z1 = getPedBonePosition(ped, 6)
	local x2, y2, z2 = getPedBonePosition(ped, 7)
	return (x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2
end

function canPedSee(ped, element)
	local px, py, pz = getPedEyesPosition(ped)
	local tx, ty, tz = getPedEyesPosition(element)
	if getPedTask(ped, "secondary", 0) == "TASK_SIMPLE_USE_GUN" then
		px, py, pz = getPedWeaponMuzzlePosition(ped)
	end
	return isLineOfSightClear(px, py, pz, tx, ty, tz, true, false, false, true, false, false, false)
end

function togglePedControlState(ped, control, bool)
	setPedControlState(ped, control, bool)
	setTimer(setPedControlState, 0, 1, ped, control, not bool)
end

function makePedShoot(ped, element)
	assert(_type(ped) == "ped", "Expected ped at argument 1, got " .. _type(ped))
	assert(isElement(element), "Expected element at argument 1, got " .. _type(element))

	local px, py, pz = getPedEyesPosition(ped)
	local tx, ty, tz = getPedBonePosition(element, 3)
	tx, ty, tz = getFuturePosition(element, tx, ty, tz, g_sync_interval)
	-- olha para a posição futura

	local fx, fy, fz = getPedBonePosition(element, 3)
	fx, fy, fz = getFuturePosition(element, fx, fy, fz, -g_sync_interval * 2)
	-- corrigir corpo olhando muito para a posição futura

	setPedCameraRotation(ped, findRotation(px, py, fx, fy))
	setPedAimTarget(ped, tx, ty, tz)

	setPedControlState(ped, "action", true)
	setPedControlState(ped, "aim_weapon", true)
end

function makePedAttack(ped, element)
	assert(_type(ped) == "ped", "Expected ped at argument 1, got " .. _type(ped))
	assert(isElement(element), "Expected element at argument 1, got " .. _type(element))

	local px, py, pz = getElementPosition(ped)
	local tx, ty, tz = getElementPosition(element)

	setPedCameraRotation(ped, findRotation(px, py, tx, ty))
	setPedAimTarget(ped, tx, ty, tz)

	togglePedControlState(ped, "fire", true)
	togglePedControlState(ped, "fire", false)
end

function getNearestElement(player, type, distance)
	local result = false
	local dist = nil
	if player and isElement(player) then
		local elements = getElementsWithinRange(Vector3(getElementPosition(player)), distance, type, getElementInterior(player), getElementDimension(player))
		for i = 1, #elements do
			local element = elements[i]
			if element ~= player then
				if not dist then
					result = element
					dist = getDistanceBetweenPoints3D(Vector3(getElementPosition(player)), Vector3(getElementPosition(element)))
				else
					local newDist = getDistanceBetweenPoints3D(Vector3(getElementPosition(player)), Vector3(getElementPosition(element)))
					if newDist <= dist then
						result = element
						dist = newDist
					end
				end
			end
		end
	end
	return result
end

local allControls = {
	"fire",
	"aim_weapon",
	"next_weapon",
	"previous_weapon",
	"forwards",
	"backwards",
	"left",
	"right",
	"zoom_in",
	"zoom_out",
	"change_camera",
	"jump",
	"sprint",
	"look_behind",
	"crouch",
	"action",
	"walk",
	"conversation_yes",
	"conversation_no",
	"group_control_forwards",
	"group_control_back",
	"vehicle_fire",
	"vehicle_secondary_fire",
	"vehicle_left",
	"vehicle_right",
	"steer_forward",
	"steer_back",
	"accelerate",
	"brake_reverse",
	"radio_next",
	"radio_previous",
	"radio_user_track_skip",
	"horn",
	"sub_mission",
	"handbrake",
	"vehicle_look_left",
	"vehicle_look_right",
	"vehicle_look_behind",
	"vehicle_mouse_look",
	"special_control_left",
	"special_control_right",
	"special_control_down",
	"special_control_up",
}

function resetPedControls(ped)
	for i, control in ipairs(allControls) do
		setPedControlState(ped, control, false)
	end
end

function l_setElementData(...)
	local arg = { ... }
	if getElementData(arg[1], arg[2]) ~= arg[3] or not hasElementData(arg[1], arg[2]) then
		return setElementData(...)
	end
	return false
end
