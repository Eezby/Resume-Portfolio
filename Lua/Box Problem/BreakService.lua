local CollectionService = game:GetService("CollectionService")

local SCALING_CONSTANT = 2
local ABSOLUTE_MAX_COMBINE = 6

local function combineParts(model, parts, cubeSize, originalPart)
	local centralPosition = Vector3.new(0,0,0)
	
	for _,part in pairs(parts) do
		centralPosition += part.Position
	end
	
	centralPosition /= #parts
	
	local xMinPosition = 99e99
	local xMaxPosition = 0
	
	local yMinPosition = 99e99
	local yMaxPosition = 0
	
	local zMinPosition = 99e99
	local zMaxPosition = 0
	
	for _,part in pairs(parts) do
		xMinPosition = math.min(xMinPosition, part.Position.X - cubeSize.X/2)
		xMaxPosition = math.max(xMaxPosition, part.Position.X + cubeSize.X/2)
		
		yMinPosition = math.min(yMinPosition, part.Position.Y - cubeSize.Y/2)
		yMaxPosition = math.max(yMaxPosition, part.Position.Y + cubeSize.Y/2)
		
		zMinPosition = math.min(zMinPosition, part.Position.Z - cubeSize.Z/2)
		zMaxPosition = math.max(zMaxPosition, part.Position.Z + cubeSize.Z/2)
	end
	
	local newPart = Instance.new("Part")
	newPart.Anchored = true
	newPart.CanCollide = true
    newPart.Color = originalPart.Color
    newPart.Material = originalPart.Material
	newPart.Size = Vector3.new(
		xMaxPosition - xMinPosition,
		yMaxPosition - yMinPosition,
		zMaxPosition - zMinPosition
	)

	for _,texture in pairs(originalPart:GetChildren()) do
		if texture:IsA("Texture") then
			local clonedTexture = texture:Clone()
			clonedTexture.Parent = newPart
		end
	end
	
    newPart.CFrame = CFrame.new(centralPosition)
	newPart.Parent = model

    CollectionService:AddTag(newPart, "Destructable")
end

local function makeRemainingParts(model, parts, cubeSize, originalPart)
	for _,part in pairs(parts) do
		if not part.combined then
			local newPart = Instance.new("Part")
			newPart.Anchored = true
			newPart.CanCollide = true
            newPart.Color = originalPart.Color
            newPart.Material = originalPart.Material
			newPart.Size = cubeSize

			for _,texture in pairs(originalPart:GetChildren()) do
				if texture:IsA("Texture") then
					local clonedTexture = texture:Clone()
					clonedTexture.Parent = newPart
				end
			end

            newPart.CFrame = CFrame.new(part.Position)
			newPart.Parent = model
			
            CollectionService:AddTag(newPart, "Destructable")
		end
	end
end

local function getAvailableSize(parts, x, y, z, maxValues)
	local validParts = {}
	
	local xSizes = {}
	local ySizes = {}
	local zSizes = {}
	
	for i = 1,maxValues.X do
		table.insert(xSizes, {i, math.random(1,100)})
	end
	
	for i = 1,maxValues.Y do
		table.insert(ySizes, {i, math.random(1,100)})
	end
	
	for i = 1,maxValues.Z do
		table.insert(zSizes, {i, math.random(1,100)})
	end
	
	
	table.sort(xSizes, function(a,b) return a[2] < b[2] end)
	table.sort(ySizes, function(a,b) return a[2] < b[2] end)
	table.sort(zSizes, function(a,b) return a[2] < b[2] end)
	
	for _,xS in pairs(xSizes) do
		local valid = true
		for _,yS in pairs(ySizes) do
			valid = true
			for _,zS in pairs(zSizes) do
				valid = true
				for xO = 0,xS[1]-1 do
					for yO = 0,yS[1]-1 do
						for zO = 0,zS[1]-1 do
							table.insert(validParts, parts[x+xO][y+yO][z+zO])
							
							if parts[x+xO][y+yO][z+zO].combined then
								valid = false
								break
							end
							
							if not valid then break end
							
						end
						if not valid then break end
					end
					if not valid then break end
				end
				
				if valid then
					return Vector3.new(xS[1], yS[1], zS[1]), validParts
				else
					validParts = {}
				end
			end
		end
	end
	
	return Vector3.new(1,1,1), {parts[x][y][z]}
end

local BreakService = {}
function BreakService.split(part)
    local partSizeMagnitude = part.Size.Magnitude

    local scalingSizeFactor = partSizeMagnitude / SCALING_CONSTANT  -- smaller = bigger parts
   
    local scalerValues = Vector3.new(                               -- how to scale the part depending on directional scale of part to it's magnitude
        part.Size.X / partSizeMagnitude,
        part.Size.Y / partSizeMagnitude,
        part.Size.Z / partSizeMagnitude
    )

    local vecSize = Vector3.new(
        math.clamp(math.floor(scalingSizeFactor * scalerValues.X + 0.5), 1, 99e99),
        math.clamp(math.floor(scalingSizeFactor * scalerValues.Y + 0.5), 1, 99e99),
        math.clamp(math.floor(scalingSizeFactor * scalerValues.Z + 0.5), 1, 99e99)
    )

    local vecCombine = Vector3.new(
        math.floor(math.clamp(vecSize.X/2.5 * scalerValues.X, 1, ABSOLUTE_MAX_COMBINE) + 0.5),
        math.floor(math.clamp(vecSize.Y/2.5 * scalerValues.Y, 1, ABSOLUTE_MAX_COMBINE) + 0.5),
        math.floor(math.clamp(vecSize.Y/2.5 * scalerValues.Z, 1, ABSOLUTE_MAX_COMBINE) + 0.5)
    )

    local cubeSize = part.Size / vecSize

    local splitParts = {}
    local uncombinedParts = {}

    local model = Instance.new("Model")
    model.Name = part.Name

    for x = 1,vecSize.X do
        splitParts[x] = {}
        for y = 1,vecSize.Y do
            splitParts[x][y] = {}
            for z = 1,vecSize.Z do
                splitParts[x][y][z] = {
                    part = {Position = Vector3.new((x-1) * cubeSize.X, (y-1) * cubeSize.Y, (z-1) * cubeSize.Z)},
                    combined = false
                }
            end
        end
    end

    for x = 1,vecSize.X do
        for y = 1,vecSize.Y do
            for z = 1,vecSize.Z do
                if not splitParts[x][y][z].combined then
                    local combineSize, validParts = getAvailableSize(splitParts, x, y, z, Vector3.new(
                        math.clamp(vecSize.X-x, 1, vecCombine.X),
                        math.clamp(vecSize.Y-y, 1, vecCombine.Y),
                        math.clamp(vecSize.Z-z, 1, vecCombine.Z)
                    ))
                    
                    if #validParts > 1 then
                        local partsToSend = {}
                        for _,part in pairs(validParts) do
                            part.combined = true
                            table.insert(partsToSend, part.part)
                        end
                        
                        combineParts(model, partsToSend, cubeSize, part)
                    else
                        table.insert(uncombinedParts, splitParts[x][y][z].part)
                    end
                end
            end
        end
    end

    makeRemainingParts(model, uncombinedParts, cubeSize, part)

    model.Parent = part.Parent
    model:PivotTo(part:GetPivot())

    part:Destroy()

    return model
end
return BreakService