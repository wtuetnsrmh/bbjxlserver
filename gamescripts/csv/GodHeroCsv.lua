local GodHeroCsvData = {
	m_data = {},
}

function GodHeroCsvData:load(fileName)
	self.m_data = {}
	local csvData = CsvLoader.load(fileName)
	for line = 1, #csvData do
		local id = tonum(csvData[line]["id"])
		if id > 0 then
			self.m_data[id] = {
				id = id,
				heroType = tonum(csvData[line]["神将id"]),
				fragRate = string.toArray(csvData[line]["神将碎片概率"], "=", true),
				rate = tonum(csvData[line]["神将概率"]),
				threshold = tonum(csvData[line]["神将必掉阀值"]),
				otherHeros = string.toTableArray(csvData[line]["其他武将碎片id"]),
				otherHeroFragNum = self:myRead(csvData[line]["其他武将碎片数量"], {"num", "weight"}),
				otherItems = self:myRead(csvData[line]["其他道具"], {"itemId", "num", "weight"}),
			}
		end
	end
end

function GodHeroCsvData:getDataById(id)
	return self.m_data[id]
end

function GodHeroCsvData:myRead(str, params)
	local t = {}
	local temp = string.toTableArray(str)
	for _, data in ipairs(temp) do
		local subt = {}
		for index, num in ipairs(data) do
			subt[params[index]] = num
		end
		table.insert(t, subt)
	end
	return t
end

function GodHeroCsvData:getTodayHeros(startTime, id)
	local csvData = self:getDataById(id)
	if not csvData then return end

	local secondPerDay = 3600 * 24
	local day = math.ceil((skynet.time() - startTime - 1) / secondPerDay)
	local day = (day - 1) % 7 + 1 
	return csvData.otherHeros[day] or {}
end

return GodHeroCsvData