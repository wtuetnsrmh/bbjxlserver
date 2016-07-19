require("utils.StringUtil")

local MapBattleCsvData = {
	m_data = {},
	m_mapId_index = {},
	m_prevMapId_index = {}
}

function MapBattleCsvData:load(files)
	if type(files) ~= "table" then
		return
	end

	self.m_data = {}

	self.m_ptIds = {}
	self.m_jyIds = {}
	self.m_dyIds = {}

	self.m_mapId_index = {}
	self.m_prevMapId_index = {}

	for _, fileName in pairs(files) do

	local csvData = CsvLoader.load(fileName)

		for index = 1, #csvData do
			local carbonId = tonum(csvData[index]["副本ID"])

			if carbonId ~= 0 then

				if 1 == tonum(csvData[index]["副本类型"]) then
					table.insert(self.m_ptIds, carbonId)
				elseif 2 == tonum(csvData[index]["副本类型"]) then
					table.insert(self.m_jyIds, carbonId)	
				elseif 3 == tonum(csvData[index]["副本类型"]) then
					table.insert(self.m_dyIds, carbonId)	
				end
				
				self.m_data[carbonId] = {
					carbonId = carbonId,
					type = tonum(csvData[index]["副本类型"]),
					name = csvData[index]["副本名"],
					openLevel = tonum(csvData[index]["开启等级"]),
					prevCarbonId = tonum(csvData[index]["前置副本"]),
					battleLevel = tonum(csvData[index]["战斗等级"]),
					battleCsv = csvData[index]["战斗配表"],
					battleTotalPhase = tonum(csvData[index]["战斗阶段"]),
					backgroundPic = csvData[index]["场景背景"],
					hasPlot = tonum(csvData[index]["剧情"]) == 1,
					consumeType = tonum(csvData[index]["消耗类型"]),
					campLife =  tonum(csvData[index]["大本营生命"]),
					hasFoggy = tonum(csvData[index]["战争迷雾"]) == 1,
					playCount = tonum(csvData[index]["挑战次数"]),
					consumeValue = tonum(csvData[index]["消耗类型值"]),
					passExp = tonum(csvData[index]["过关经验"]),
					starExpBonus = string.tomap(csvData[index]["星级经验修正"], " "),
					passMoney = tonum(csvData[index]["过关金钱"]),
					starMoneyBonus = string.tomap(csvData[index]["星级金钱修正"], " "),
					backgroundMusic = csvData[index]["背景音乐"],
					firstPassAward = string.tomap(csvData[index]['首次通关奖励'], " "),
				}

				local mapId = math.floor(carbonId / 100)
				self.m_mapId_index[mapId] = self.m_mapId_index[mapId] or {}
				table.insert(self.m_mapId_index[mapId], carbonId)

				local prevCarbonId = self.m_data[carbonId].prevCarbonId
				self.m_prevMapId_index[prevCarbonId] = self.m_prevMapId_index[prevCarbonId] or {}
				table.insert(self.m_prevMapId_index[prevCarbonId], self.m_data[carbonId])
			end
		end
	end
end

function MapBattleCsvData:getCarbonById(carbonID)
	return self.m_data[carbonID]
end

function MapBattleCsvData:get_pt_ids()
	return self.m_ptIds
end

function MapBattleCsvData:get_jy_ids()
	return self.m_jyIds
end

function MapBattleCsvData:get_dy_ids()
	return self.m_dyIds
end

-- 根据前置ID得到可以打开的新副本
function MapBattleCsvData:getCarbonByPrev(prevCarbonId)
	return self.m_prevMapId_index[prevCarbonId] or {}
end

function MapBattleCsvData:getCarbonByMap(mapId)
	local carbonIds = self.m_mapId_index[mapId]
	local ret = {}
	if carbonIds == nil then
		logger.exitMethod("MapBattleCsvData:getCarbonByMap", { ret = ret})
		return ret
	end

	for _, carbonId in ipairs(carbonIds) do
		local carbonInfo = self.m_data[carbonId]
		if carbonInfo then
			ret[#ret + 1] = carbonInfo
		end
	end

	return ret
end

function MapBattleCsvData:getCarbonByLevelMap(level, mapId)
	local carbons = self:getCarbonByMap(mapId)
	local ret = {}
	for _, carbonInfo in pairs(carbons) do
		if carbonInfo.openLevel <= level then
			ret[#ret + 1] = carbonInfo
		end
	end

	return ret
end
return MapBattleCsvData