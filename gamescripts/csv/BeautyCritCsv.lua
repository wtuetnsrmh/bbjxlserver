-- 美人系统宠幸暴击配表解析
-- by yangkun
-- 2014.3.17

local BeautyCritCsvData = {
	m_data = {}
}

function BeautyCritCsvData:load(fileName) 
	local csvData = CsvLoader.load(fileName)
	self.m_data = {}

	for index = 1, #csvData do
		local id = tonum(csvData[index]["id"])
		if id > 0 then
			self.m_data[id] = {
				id = id,
				weight = tonum(csvData[index]["暴击权值"]),
				multiple = tonum(csvData[index]["暴击倍率"]),
			}
		end
	end
end

function BeautyCritCsvData:getBeautyTrainCritById(id) 
	return self.m_data[id]
end

function BeautyCritCsvData:getAllBeautyCritData()
	return self.m_data
end

return BeautyCritCsvData