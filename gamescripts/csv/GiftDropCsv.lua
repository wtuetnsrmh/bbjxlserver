require("utils.StringUtil")

local GiftDropCsvData = {
	m_data = {},
}

function GiftDropCsvData:load( fileName )
	self.m_data = {}
	
	local csvData = CsvLoader.load(fileName)

	for index = 1, #csvData do
		local id = tonum(csvData[index]["随机道具id"])
		if id > 0 then
			self.m_data[id] = {
				id = id,
				desc = csvData[index]["随机道具描述"],
				count = tonum(csvData[index]["掉落次数"]),
				specialItems = string.toTableArray(csvData[index]["特掉道具"], " "),
				specialFloor = tonum(csvData[index]["特掉阀值下限"]),
				specialCeil = tonum(csvData[index]["特掉阀值上限"]),
				specialProbability = tonum(csvData[index]["特调概率"]),
				initThreshold = tonum(csvData[index]["初始阀值"]),
				commonItems = string.toTableArray(csvData[index]["普掉道具"], " "),
				firstDropItems = string.toTableArray(csvData[index]["首次十连抽必出英雄"]),
			}
		end
	end
end

function GiftDropCsvData:getDropData(id)
	return self.m_data[id]
end

function GiftDropCsvData:getTotalDropData(id)
	return self.m_data
end

return GiftDropCsvData