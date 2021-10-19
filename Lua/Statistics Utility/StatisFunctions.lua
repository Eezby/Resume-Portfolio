local function cloneTable(t)
	local newTable = {}
	
	for i,v in pairs(t) do
		newTable[i] = v
	end
	
	return newTable
end

local Statis = {}

function Statis.Sum(data)
	local sum = 0
	
	for _,value in pairs(data) do
		sum += value
	end
	
	return sum
end

function Statis.Mean(data)
	local mean = 0
	
	for _,value in pairs(data) do
		mean += value
	end
	
	mean /= #data
	
	return mean
end

function Statis.Median(data)
	if #data % 2 == 0 then
		local leftValue = data[#data / 2]
		local rightValue = data[#data / 2 + 1]
		
		return (leftValue + rightValue) / 2
	end
	
	return data[math.ceil(#data / 2)]
end

function Statis.Variance(data, isPopulation)
	local xMinusMean = {}
	local minusMeanSquared = {}
	
	local mean = Statis.Mean(data)
	local variance = 0
	
	for _,value in pairs(data) do
		table.insert(xMinusMean, value-mean)
		table.insert(minusMeanSquared, math.pow((value-mean), 2))
	end
	
	for _,square in pairs(minusMeanSquared) do
		variance += square
	end
	
	if isPopulation then
		variance /= #data
	else
		variance /= (#data-1)
	end
	
	return variance, xMinusMean, minusMeanSquared
end

function Statis.StandardDeviation(data, isPopulation)
	local variance = Statis.Variance(data, isPopulation)
	return math.sqrt(variance)
end

function Statis.Correlation(data)
	local xData = {}
	local yData = {}
	
	for x,y in pairs(data) do
		table.insert(xData, x)
		table.insert(yData, y)
	end
	
	return Statis.CorrelationXY(xData, yData)
end

function Statis.CorrelationXY(xData, yData)
	local _, xMinusMean, xMinusMeanSquared = Statis.Variance(xData)
	local _, yMinusMean, yMinusMeanSquared = Statis.Variance(yData)
	
	local combinedMinusXY = 0
	for i = 1,#xMinusMean do
		combinedMinusXY += (xMinusMean[i] * yMinusMean[i])
	end

	local correlationR = combinedMinusXY / (math.sqrt(Statis.Sum(xMinusMeanSquared)) * math.sqrt(Statis.Sum(yMinusMeanSquared)))
	
	return correlationR
end

function Statis.LinearRegression()
	
end

function Statis.Sort(data)
	local dataClone = cloneTable(data)
	table.sort(dataClone, function(a,b) return a < b end)
	
	return dataClone
end

function Statis.Convert(str, delimiter)
	local data = {}
	
	local nextNumber = ""
	for i = 1,string.len(str) do
		if string.sub(str,i,i) == (delimiter or " ") then
			table.insert(data, tonumber(nextNumber))
			nextNumber = ""
		else
			nextNumber = nextNumber..string.sub(str,i,i)
		end
	end
	
	return data
end

function Statis.Minimum(data)
	return math.min(table.unpack(data))
end

function Statis.Maximum(data)
	return math.max(table.unpack(data))
end

function Statis.SingleValueSummary(data)
	print'~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
	
	print("Data: ", table.concat(data, ", "))
	print("Data Sorted: ", table.concat(Statis.Sort(data), ", "))
	print("Count (n): ", #data)
	print("Minimum: ", Statis.Minimum(data))
	print("Maximum: ", Statis.Maximum(data))
	print("Mean: ", Statis.Mean(data))
	print("Median: ", Statis.Median(data))
	print("Sample Variance (s^2): ", Statis.Variance(data))
	print("Population Variance (o^2): ", Statis.Variance(data, true))
	print("Sample Standard Dev. (s): ", Statis.StandardDeviation(data))
	print("Population Standard Dev. (o): ", Statis.StandardDeviation(data, true))
	
	print'~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
end

function Statis.DoubleValueSummary(dataX, dataY)
	print'~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
	
	print("Correlation (r): ", Statis.CorrelationXY(dataX, dataY))
	print("Determination (r^2): ", math.pow(Statis.CorrelationXY(dataX, dataY), 2))
	
	print'~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
end
return Statis
