local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local TweenService = require(script.Parent.TweenService)

local LocalPlayer
local Camera

if RunService:IsClient() then
	LocalPlayer = Players.LocalPlayer
	Camera = workspace.CurrentCamera
end

local savedAudios = {}

local AudioService = {}

local function createSoundContainer(cframe)
	local newContainer = Instance.new("Part")
	newContainer.Transparency = 1
	newContainer.CanCollide = false
	newContainer.Anchored = true
	newContainer.Locked = true
	newContainer.CFrame = cframe
	newContainer.Parent = Camera or workspace.Sound
	
	return newContainer
end

-- id: int of numbers, string of numbers, or entire id link		ex. 4069771750, rbxassetid://4069771750
-- target: instance, vector3, cframe							ex. workspace.Sound, Vector3.new(0,0,0), CFrame.new(0,0,0)
-- properties: list of sound properties and values				ex. {Looped = true, MaxDistance = 5}
-- effects: list of effect instance names and their properties	ex. {PitchShiftSoundEffect = {Octave = 0.5}}

-- full example usage: AudioService:Create(4069771750, tower,PrimaryPart, {Looped = true}, {PitchShiftSoundEffect = {Octave = 0.5})

-- all sounds/containers are automatically destroyed after the sound has ended unless the sound is looped
-- if the container was given, only the sound object will be destroyed
function AudioService:Create(id, target, properties, effects, saveId)
	id = tostring(id)
	
	if not id:match("%d+") then
		error("SoundId must be a string of all number characters")
	end
	
	local newSoundObject = Instance.new("Sound")
	newSoundObject.Name = (properties or {}).Name or id
	newSoundObject.SoundId = "rbxassetid://"..id:match("%d+")
	
	for effect, properties in pairs(effects or {}) do
		local newEffect = Instance.new(effect)
		for property, value in pairs(properties or {}) do
			newEffect[property] = value
		end
		
		newEffect.Parent = newSoundObject
	end
	
	newSoundObject["Volume"] = 0.2
	for property, value in pairs(properties or {}) do
		if property ~= "Delay" and property ~= "Duration" then
			newSoundObject[property] = value
		elseif property == "Duration" then
			newSoundObject["Looped"] = true
		end
	end
	
	local container
	local createdContainer = false
	
	if typeof(target) == "Instance" then
		container = target
	elseif typeof(target) == "Vector3" then
		container = createSoundContainer(CFrame.new(target))
		createdContainer = true
	elseif typeof(target) == "CFrame" then
		container = createSoundContainer(target)
		createdContainer = true
	end
	
	newSoundObject.Parent = container
	
	task.spawn(function()
		task.wait((properties or {}).Delay or 0.01)
		newSoundObject:Play()
		
		if saveId then
			if createdContainer then
				savedAudios[saveId] = container
			else
				savedAudios[saveId] = newSoundObject
			end
		else
			if not newSoundObject.Looped then
				newSoundObject.Ended:Connect(function()
					if createdContainer then
						container:Destroy()
					else
						newSoundObject:Destroy()
					end
				end)
			elseif properties and properties.Duration then
				task.wait((properties or {}).Duration or 0)
				if createdContainer then
					container:Destroy()
				else
					newSoundObject:Destroy()
				end
			end
		end
	end)
	
	return newSoundObject, container
end

function AudioService:Fade(object, fadeTime, fadeValue)
	if object then
		local goal = {Volume = fadeValue}
		local properties = {Time = fadeTime}
		TweenService.tween(object, goal, properties)
	end
end

function AudioService:Destroy(saveId)
	if savedAudios[saveId] then
		savedAudios[saveId]:Destroy()
	end
end

return AudioService