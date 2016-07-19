local RoleInfoCsvData = {
	m_data = {},
	m_level_index = {},
	m_choose_level = {},
}

function RoleInfoCsvData:load(fileName)
	self.m_data = {}
	self.m_level_index = {}
	self.m_choose_level = {}

	local csvData = CsvLoader.load(fileName)

	for index = 1, #csvData do
		local id = tonum(csvData[index]["id"])
		
		if id ~= 0 then
			self.m_data[id] = self.m_data[id] or {}
			self.m_data[id].id = tonum(csvData[index]["id"])
			self.m_data[id].level = tonum(csvData[index]["玩家等级"])
			self.m_data[id].upLevelExp = tonum(csvData[index]["升级经验"])
			self.m_data[id].campHp = tonum(csvData[index]["大本营生命"])
			self.m_data[id].bagHeroLimit = tonum(csvData[index]["包裹武将上限"])
			self.m_data[id].fieldGridNum = tonum(csvData[index]["格子数"])
			self.m_data[id].chooseHeroNum = tonum(csvData[index]["点将上限"])
			self.m_data[id].healthLimit = tonum(csvData[index]["体力上限"])
			self.m_data[id].friendLimit = tonum(csvData[index]["好友上限"])
			self.m_data[id].functionOpen = string.tomap(csvData[index]["功能开放"])
			self.m_data[id].beautyOpen = tonum(csvData[index]["美人功能"])
			self.m_data[id].sweepOpen = tonum(csvData[index]["扫荡"])

			if self.m_data[id].functionOpen["1"] then
				self.m_choose_level[tonum(self.m_data[id].functionOpen["1"])] = self.m_data[id].level
			end
			self.m_level_index[self.m_data[id].level] = self.m_data[id]
		end
	end
end

function RoleInfoCsvData:getLevelByChooseNum(chooseLimit)
	return self.m_choose_level[chooseLimit]
end

function RoleInfoCsvData:getDataByLevel(level)
	return self.m_level_index[level]
end

return RoleInfoCsvData