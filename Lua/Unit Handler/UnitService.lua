local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Database = ReplicatedStorage.Database
local UnitData = require(Database.UnitData)
local TypeMap = require(Database.TypeMap)

local ReplicateModules = ReplicatedStorage.Modules
local PlayerValues = require(ReplicateModules.PlayerValues)

local ServerModules = ServerScriptService.Modules
local ResourceService = require(ServerModules.ResourceService)
local BuildingService = require(ServerModules.BuildingService)
local ActionService = require(ServerModules.ActionService)

local Utility = ReplicatedStorage.Utility
local ResourceFunctions = require(Utility.ResourceFunctions)
local SharedFunctions = require(Utility.SharedFunctions)
local PlayerRemoteService = require(Utility.PlayerRemoteService)
local Postie = require(Utility.Postie)

local Remotes = ReplicatedStorage.Remotes
local UnitConnection = Remotes.UnitConnection

local HEALTH_MULTIPLIER = 10
local COORD_MULTIPLIER = 5
local ROT_MULTIPLIER = 10
local REPLICATE_FREQUENCY = 8
local TIME_OFFSET = math.floor(os.time() - tick() + 0.5)

local ActiveUnits = {}
local CurrentId = 0
local ActionId = 0

local RunCount = 0

local ActiveResources = ResourceService:GetActiveResources()
local ActiveBuildings = BuildingService:GetActiveBuildings()
local ActionStorage = ActionService:GetActionStorage()

local UnitService = {}

local function getTime()
	return tick() + TIME_OFFSET
end

local function encodeUnitPositionData(position)
	local X = math.floor(COORD_MULTIPLIER * position.X + 0.5)
	local Z = math.floor(COORD_MULTIPLIER * position.Z + 0.5)

	return Vector2int16.new(position.X, position.Z)
end

local function encodeUnitMovementPackage(id, position, orientation)
	local orientation = math.floor(ROT_MULTIPLIER * orientation + 0.5)

	return {
		Vector2int16.new(id, orientation),
		encodeUnitPositionData(position)
	}
end

local function unitWoodCheck(unit)
	if unit.target.dead then
		if unit.target.objectType == "Resource" then
			if unit.target.resourceType == "Wood" then
				local nearestNextResource = ResourceFunctions:GetClosestResource(unit.position, {resourceType = "Wood"})
				if nearestNextResource and (unit.position - nearestNextResource.position).Magnitude <= 25 then
					local newAction, actionId = ActionService:New({action = "collect", target = nearestNextResource, goalPosition = nearestNextResource.position, units = {unit}})
					unit.target = nearestNextResource
				end
			end
		end
	end
end

local function getUnitsFromIds(idList, verification)
	local unitsToReturn = {}

	for _,id in pairs(idList) do
		local unit = ActiveUnits[tostring(id)]
		if unit then
			local verified = true
			for property,value in pairs(verification or {}) do
				if unit[property] ~= value then
					verified = false
					break
				end
			end

			if verified then
				table.insert(unitsToReturn, unit)
			end
		end
	end

	return unitsToReturn
end

local function createNewUnit(args)
	CurrentId = CurrentId + 1
	
	local UnitObject = {
		owner = args.owner,
		id = CurrentId,
		unitId = args.unitId or 1,
		team = args.team or 0,
		
		maxHealth = UnitData[args.unitId].health,
		health = UnitData[args.unitId].health,
		speed = UnitData[args.unitId].speed,
		position = args.position,
		
		objectType = "Unit",
		dead = false,
		
		cooldowns = {
			attack = 0
		}
	}
	
	function UnitObject:ConvertToSend()
		local valuesToSend = {
			owner = self.owner,
			id = self.id,
			unitId = self.unitId,
			maxHealth = self.maxHealth,
			health = self.health,
			position = self.position,
			objectType = self.objectType,
			team = self.team
		}
		
		return valuesToSend
	end
	
	function UnitObject:Death()
		coroutine.wrap(function()
			self.dead = true
			self.goalPosition = nil
			self.target = nil

			wait(2)

			ActiveUnits[tostring(self.id)] = nil
		end)()
	end
	
	function UnitObject:TakeDamage(fromUnit, damage)
		self.health -= damage
		PlayerRemoteService:FireAllClientsWithAction(UnitConnection, "unit-health", Vector2int16.new(self.id, math.floor(self.health * HEALTH_MULTIPLIER + 0.5)))
		
		if self.health <= 0 then
			self:Death()
		end
	end
	
	function UnitObject:SetGoalLocation(position)
		self.goalPosition = position + UnitData[self.unitId].offset
	end

	function UnitObject:AttackTarget()
		if self.target and not self.target.dead then
			local _,unitOrientation,_ = CFrame.new(self.position, self.target.position):ToOrientation()
			unitOrientation = math.floor(ROT_MULTIPLIER * unitOrientation + 0.5)
			
			PlayerRemoteService:FireAllClientsWithAction(UnitConnection, "unit-attack", Vector3int16.new(self.id, self.target.id, TypeMap[self.target.objectType]), unitOrientation)
			self.target:TakeDamage(self, UnitData[self.unitId].attackDamage)
			
			unitWoodCheck(self)
		else
			unitWoodCheck(self)
			
			if self.target.dead then
				self.target = nil
			end
		end
	end
	
	function UnitObject:Start()
		ActiveUnits[tostring(self.id)] = self
		PlayerRemoteService:FireAllClientsWithAction(UnitConnection, "unit-new", self:ConvertToSend())
	end
	
	return UnitObject
end


--[[
[Vector3]	position 	- 	where the unit starts
[Int]		unitId		-	id that the unit is
[Bool]		dontStart	-	prevent immediate activation
]]
function UnitService:New(args)
	local newUnit = createNewUnit(args)
	if not args.dontStart then
		newUnit:Start()
	end
	
	return newUnit
end

function UnitService:GetActiveUnits()
	return ActiveUnits
end

Postie.SetCallback("UnitConnection", function(client, action, args)
	local clientTeam = PlayerValues:GetValue(client, "team")
	
	if action == "move" then
		local units = getUnitsFromIds(args.units, {owner = client, team = clientTeam})
		local newAction, actionId = ActionService:New({action = "move", goalPosition = args.position, units = units})
		
		for _,unit in pairs(units) do
			if not unit.dead then
				unit.target = nil
				unit.currentActionId = actionId
				unit:SetGoalLocation(args.position)
			end
		end
	elseif action == "attack" then		
		local units = getUnitsFromIds(args.units, {owner = client, team = clientTeam})
		local target = ActiveUnits[tostring(args.targetId)] or ActiveBuildings[tostring(args.buildingId)]
		
		local newAction, actionId = ActionService:New({action = "attack", goalPosition = target.position, target = target, units = units})
		
		if target and not target.dead then
			for _,unit in pairs(units) do
				if not unit.dead and unit.team ~= target.team then
					unit.currentActionId = actionId
					unit.target = target
				end
			end
		end
	elseif action == "collect" then
		local units = getUnitsFromIds(args.units, {owner = client, team = clientTeam})
		local resource = ActiveResources[tostring(args.resourceId)]
		
		local newAction, actionId = ActionService:New({action = "collect", goalPosition = resource.position, target = resource, units = units})
		
		if resource and not resource.dead then
			for _,unit in pairs(units) do
				if not unit.dead then
					unit.currentActionId = actionId
					unit.target = resource
				end
			end
		end
	end
end)

RunService.Heartbeat:Connect(function(dt)
	RunCount += 1
	
	local unitPositionsToUpdate = {}
	for _,unit in pairs(ActiveUnits) do
		if not unit.dead then
			local currentUnitAction = ActionStorage[unit.currentActionId]
			if unit.goalPosition then
				unit.position += (unit.goalPosition - unit.position).Unit * dt * unit.speed
				
				local goalPosition = unit.goalPosition
				
				if SharedFunctions:GetPositionMagnitude(unit.position, unit.goalPosition) <= 0.04 then
					unit.goalPosition = nil
				end
				
				local unitOrientation
				
				if not unit.goalPosition and unit.target then
					local unitCFrame = CFrame.new(goalPosition, ActionStorage[unit.currentActionId].target.position)
					_,unitOrientation,_ = unitCFrame:ToOrientation()
				else
					local unitCFrame = CFrame.new(unit.position, goalPosition)
					_,unitOrientation,_ = unitCFrame:ToOrientation()
				end
				
				if RunCount >= REPLICATE_FREQUENCY then
					table.insert(unitPositionsToUpdate, encodeUnitMovementPackage(unit.id, unit.position, unitOrientation))
				end
			end
			
			if unit.target then
				local unitOffsetPosition = currentUnitAction.unitOffsets[unit.id] or unit.target.position
				
				if SharedFunctions:GetPositionMagnitude(unit.position, unitOffsetPosition) > UnitData[unit.unitId].attackRange then
					unit:SetGoalLocation(unitOffsetPosition)
				elseif unit.cooldowns.attack - tick() <= 0 then
					unit.cooldowns.attack = tick() + UnitData[unit.unitId].attackCooldown
					unit:AttackTarget()
				end
			end
		end
	end
	
	if RunCount >= REPLICATE_FREQUENCY then
		RunCount = 0
		if #unitPositionsToUpdate > 0 then
			PlayerRemoteService:FireAllClientsWithAction(UnitConnection, "unit-move", unitPositionsToUpdate)
		end
	end
end)

return UnitService
