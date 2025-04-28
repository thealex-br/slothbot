-- [key] == canBeModifiedByClient
local subscriberKeys = {
	["task"] = false,
	["team"] = false,
	["target"] = false,
	["guardTarget"] = false,
	["onlyShootWhenInPosition"] = false,
	["canAttack"] = false,

	-- internals

	["hasReachedLocation"] = true,
	["hasReachedTarget"] = true,
	["targetPath"] = false,
}

local resources = {}

local function setElementResource(element, theResource)
	local resourceName = "slothbot:" .. getResourceName(theResource or resource)
	if not resources[resourceName] then
		resources[resourceName] = {}
	end
	table.insert(resources[resourceName], element)
end

local function destroyElementsFromResource(theResource)
	local resourceName = "slothbot:" .. getResourceName(theResource or resource)
	if resources[resourceName] then
		for i, element in ipairs(resources[resourceName]) do
			if isElement(element) then
				destroyElement(element)
			end
		end
		resources[resourceName] = nil
	end
end
addEventHandler("onResourceStop", root, destroyElementsFromResource)

addEvent("onBotFindEnemy", true)
addEvent("onBotWasted", true)
addEvent("onBotSpawned", true)
addEvent("onBotFollow", true)

function onPlayerResourceStart(startedResource)
	if not (startedResource == resource) then
		return false
	end
	local sync_interval = getServerConfigSetting("player_sync_interval")
	triggerClientEvent(source, "getSyncInterval", resourceRoot, sync_interval)
end
addEventHandler("onPlayerResourceStart", root, onPlayerResourceStart)

local function postProcess(bot)
	local task = getElementData(bot, "task")
	if not (task == "guard" or task == "hunt") then
		return
	end

	local botTeam = getElementData(bot, "team")
	local x, y, z = getElementPosition(bot)
	local interior, dimension = getElementInterior(bot), getElementDimension(bot)

	local targets = {}

	local players = getElementsWithinRange(x, y, z, 50, "player", interior, dimension)
	local peds = getElementsWithinRange(x, y, z, 50, "ped", interior, dimension)

	for _, player in ipairs(players) do
		if player and player ~= bot then
			local playerTeam = getPlayerTeam(player)
			-- Target if the player is not on the same team or has no team
			if not botTeam or not playerTeam or playerTeam ~= botTeam then
				if not isPedDead(player) then
					table.insert(targets, player)
				end
			end
		end
	end

	for _, ped in ipairs(peds) do
		if ped and ped ~= bot then
			local pedTeam = getElementData(ped, "team")
			-- Target if the ped is not on the same team or has no team
			if not botTeam or not pedTeam or pedTeam ~= botTeam then
				if not isPedDead(ped) then
					table.insert(targets, ped)
				end
			end
		end
	end

	table.sort(targets, function(a, b)
		local x1, y1, z1 = getElementPosition(a)
		local x2, y2, z2 = getElementPosition(b)
		return getDistanceBetweenPoints3D(x, y, z, x1, y1, z1) < getDistanceBetweenPoints3D(x, y, z, x2, y2, z2)
	end)

	players = nil
	peds = nil

	local nearest = #targets > 0 and targets[1]

	if nearest and getElementData(bot, "target") ~= nearest then
		triggerEvent("onBotFindEnemy", bot, nearest)
	end

	setElementData(bot, "target", nearest, "broadcast", "deny")
end

local function preProcess()
	local bots = getElementsByType("ped", resourceRoot)
	for i, bot in ipairs(bots) do
		if isBot(bot) and not isPedDead(bot) then
			postProcess(bot)
		end
	end
end
setTimer(preProcess, 250, 0)

local function onPedDead(_, attacker, weapon, bodypart)
	local syncer = getElementSyncer(source)
	if not syncer then
		return
	end
	if not isBot(source) then
		return
	end
	for theKey in pairs(subscriberKeys) do
		removeElementData(source, theKey)
	end
	setElementSyncer(source, false, true)
	triggerEvent("onBotWasted", source, attacker, weapon, bodypart)
	setTimer(destroyElement, 60 * 1000, 1, source)
end
addEventHandler("onPedWasted", resourceRoot, onPedDead)

local function onStartSync(newSyncer)
	if not isBot(source) then
		return
	end
	--[[
	for theKey, canBeModifiedByClient in pairs(subscriberKeys) do
		addElementDataSubscriber(source, theKey, newSyncer)
	end
	]]
	triggerClientEvent(newSyncer, "onClientElementStartSync", source)
end
addEventHandler("onElementStartSync", resourceRoot, onStartSync)

local function onStopSync(oldSyncer)
	if not isBot(source) then
		return
	end
	--[[
	for theKey, canBeModifiedByClient in pairs(subscriberKeys) do
		removeElementDataSubscriber(source, theKey, oldSyncer)
	end
	]]
	triggerClientEvent(oldSyncer, "onClientElementStopSync", source)
end
addEventHandler("onElementStopSync", resourceRoot, onStopSync)

function isBot(ped)
	return hasElementData(ped, "isBot")
end
isPedBot = isBot -- slothbot

function createBot(...)
	local bot = createPed(...)
	if not bot then
		return false
	end
	setElementResource(bot, sourceResource)
	setElementData(bot, "isBot", true, "broadcast", "deny")
	setElementData(bot, "task", "hunt", "broadcast", "deny")
	setElementData(bot, "canAttack", true, "broadcast", "deny")
	triggerEvent("onBotSpawned", bot)
	return bot
end

local remappedTaskNames = {
	["hunting"] = "hunt",
	["waiting"] = "idle",
	["guarding"] = "guard",
	["following"] = "follow",
	["chasing"] = "chase",
}

function spawnBot(x, y, z, rot, skin, int, dim, team, weapon, task, target)
	local bot = createPed(skin or 0, x, y, z, rot)
	if not bot then
		return false
	end

	if not task then
		task = "hunting"
	end
	task = remappedTaskNames[task]

	setElementResource(bot, sourceResource)
	setElementData(bot, "isBot", true, "broadcast", "deny")
	setElementData(bot, "task", task, "broadcast", "deny")
	if isElement(target) then
		setElementData(bot, "target", target, "broadcast", "deny")
	end
	setElementData(bot, "canAttack", true, "broadcast", "deny")

	setElementDimension(bot, dim or 0)
	setElementInterior(bot, int or 0)
	if team then
		setElementData(bot, "team", team, "broadcast", "deny")
	end
	if weapon then
		giveWeapon(bot, weapon, 99999, true)
	end
	return bot
end -- slothbot

function setBotGuard(bot, x, y, z, priority)
	setElementData(bot, "task", "guard", "broadcast", "deny")

	local col = getElementData(bot, "guardTarget")
	if isElement(col) then
		destroyElement(col)
	end

	local col = createColSphere(x, y, z, 1.5)
	setElementData(bot, "guardTarget", col, "broadcast", "deny")
	setElementParent(col, bot)

	if priority == true then
		setElementData(bot, "onlyShootWhenInPosition", true, "broadcast", "deny")
	else
		removeElementData(bot, "onlyShootWhenInPosition")
	end
	return true
end

function setBotFollow(bot, element)
	setElementData(bot, "task", "follow", "broadcast", "deny")
	setElementData(bot, "target", element, "broadcast", "deny")
	triggerEvent("onBotFollow", bot, element)
	return true
end

function setPedIdle(bot)
	return setElementData(bot, "task", "idle", "broadcast", "deny")
end
setPedWait = setPedIdle -- slothbot

function setBotChase(bot, element)
	setElementData(bot, "task", "chase", "broadcast", "deny")
	setElementData(bot, "target", element, "broadcast", "deny")
	return true
end

function setBotHunt(bot)
	return setElementData(bot, "task", "hunt", "broadcast", "deny")
end

function getBotTeam(bot)
	return getElementData(bot, "team")
end

function setBotTeam(bot, team)
	return setElementData(bot, "team", team, "broadcast", "deny")
end

function getBotTask(bot)
	return getElementData(bot, "team")
end
getBotMode = getBotTask -- slothbot

function getBotAttackEnabled(bot)
	return getElementData(bot, "canAttack")
end

function setBotAttackEnabled(bot, bool)
	if bool == true then
		setElementData(bot, "canAttack", true, "broadcast", "deny")
	else
		removeElementData(bot, "canAttack")
	end
	return true
end

function setBotWeapon(bot, weapon)
	return giveWeapon(bot, weapon, 99999, true)
end