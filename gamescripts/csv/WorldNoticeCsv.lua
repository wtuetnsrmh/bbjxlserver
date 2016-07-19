local WorldNoticeCsvData = {
	m_data = {},
	level = 1,
	pvp = 2,
	beauty = 3,
	carbon = 4,
	newHero = 5,
	starUp = 6,
	evolution = 7,
	vip = 8,
}

function WorldNoticeCsvData:load(fileName)
	self.m_data = {}
	local csvData = CsvLoader.load(fileName)
	for line = 1, #csvData do
		local type = tonum(csvData[line]["类型"])
		if type > 0 then
			self.m_data[type] = {
				type = type,
				conditionParams = string.toArray(csvData[line]["条件参数"], "=", true),
				desc = csvData[line]["描述"],
			}
		end
	end
end

function WorldNoticeCsvData:getDataByType(type)
	return self.m_data[type]
end

function WorldNoticeCsvData:isConditionFit(type, param)
	local data = self:getDataByType(type)
	return data and table.find(data.conditionParams, param) or false
end

function WorldNoticeCsvData:getDesc(type, params)
	local data = self:getDataByType(type)
	local str = ""
	if data then
		str = string.format(data.desc, params.playerName, params.param1, params.param2)
	end
	return str
end

return WorldNoticeCsvData