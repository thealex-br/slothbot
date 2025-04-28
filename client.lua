g_sync_interval = false

local bots = {}

local function isBot(ped)
	return hasElementData(ped, "isBot")
end

local function task_simple_goto(bot, element)
	local bx, by, bz = getElementPosition(bot)
	local tx, ty, tz = getElementPosition(element)

	local angle = findRotation(bx, by, tx, ty)
	setPedCameraRotation(bot, angle)

	local distance = getDistanceBetweenPoints3D(bx, by, bz, tx, ty, tz)

	local shouldJog = distance > 2.2
	local shouldSprint = distance > 5
	setPedControlState(bot, "forwards", shouldJog)
	setPedControlState(bot, "sprint", shouldSprint)
end

local function task_complex_guard(bot)
	local target = getElementData(bot, "target")
	local guardTarget = getElementData(bot, "guardTarget")

	if guardTarget == target then
		target = nil
	end

	local bx, by, bz = getElementPosition(bot)
	local cx, cy, cz = getElementPosition(guardTarget)

	local hasReachedLocation = getDistanceBetweenPoints3D(bx, by, bz, cx, cy, cz) < 2.2

	local onlyShootWhenInPosition = getElementData(bot, "onlyShootWhenInPosition")
	if not hasReachedLocation then
		task_simple_goto(bot, guardTarget)
	end

	local canAttack = getElementData(bot, "canAttack")

	local slot = getPedWeaponSlot(bot)
	local shouldShoot = (slot > 1 and slot < 8)
	local shouldPunch = (slot < 2 or slot == 10)

	if canAttack and isElement(target) and shouldShoot and canPedSee(bot, target) then
		if onlyShootWhenInPosition and hasReachedLocation or not onlyShootWhenInPosition then
			makePedShoot(bot, target)
			setPedControlState(bot, "forwards", false)
		end
	end

	if canAttack and isElement(target) and shouldPunch and getDistanceBetweenElements(bot, target) < 2.5 then
		makePedAttack(bot, target)
	end

	l_setElementData(bot, "hasReachedLocation", hasReachedLocation)
end

local function task_complex_chase(bot)
	local target = getElementData(bot, "target")

	local bx, by, bz = getElementPosition(bot)
	local cx, cy, cz = getElementPosition(target)

	local hasReachedTarget = getDistanceBetweenPoints3D(bx, by, bz, cx, cy, cz) < 2.2
	if not hasReachedTarget then
		task_simple_goto(bot, target)
	end

	local canAttack = getElementData(bot, "canAttack")

	local slot = getPedWeaponSlot(bot)
	local shouldShoot = (slot > 1 and slot < 8)
	local shouldPunch = (slot < 2 or slot == 10)

	if canAttack and shouldShoot and canPedSee(bot, target) then
		makePedShoot(bot, target)
		setPedControlState(bot, "forwards", false)
	end

	if canAttack and shouldPunch and getDistanceBetweenElements(bot, target) < 2.5 then
		makePedAttack(bot, target)
	end

	l_setElementData(bot, "hasReachedTarget", hasReachedTarget)
end

local function task_complex_hunt(bot)
	-- todo
end

local function postProcess(bot)
	resetPedControls(bot)

	local state = getElementData(bot, "task")
	local target = getElementData(bot, "target")

	if state == "guard" then
		task_complex_guard(bot)
	end
	if state == "follow" and isElement(target) then
		task_simple_goto(bot, target)
	end
	if state == "idle" then
		-- lol
	end
	if state == "hunt" and isElement(target) then
		task_complex_chase(bot)
	end
	if state == "chase" and isElement(target) then
		task_complex_chase(bot)
	end
end

local function preProcess()
	for bot in pairs(bots) do
		if isBot(bot) and not isPedDead(bot) then
			postProcess(bot)
		end
	end
end

local function onRecieveData(sync_interval)
	if isTimer(processTimer) then
		killTimer(processTimer)
	end
	processTimer = setTimer(preProcess, sync_interval, 0)
	g_sync_interval = sync_interval
end
addEvent("getSyncInterval", true)
addEventHandler("getSyncInterval", resourceRoot, onRecieveData)

local function onStopBeingSynced()
	resetPedControls(source)
	bots[source] = nil
end
addEvent("onClientElementStopSync", true)
addEventHandler("onClientElementStopSync", resourceRoot, onStopBeingSynced)

local function onStartBeingSynced()
	bots[source] = true
end
addEvent("onClientElementStartSync", true)
addEventHandler("onClientElementStartSync", resourceRoot, onStartBeingSynced)