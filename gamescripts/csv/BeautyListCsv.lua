-- 美人系统美人列表配表解析
-- by yangkun
-- 2014.2.17

local BeautyListCsvData = {
	m_data = {}
}

function BeautyListCsvData:load(fileName) 
	local csvData = CsvLoader.load(fileName)
	self.m_data = {}

	for index = 1, #csvData do
		local beautyId = tonum(csvData[index]["美人ID"])

		if beautyId > 0 then
			self.m_data[beautyId] = {
				beautyId = beautyId,
				beautyName = csvData[index]["美人名称"],
				star = tonum(csvData[index]["星级"]),
				evolutionMax = tonum(csvData[index]["进阶上限"]),
				evolutionLevel = tonum(csvData[index]["每阶等级上限"]),

				hpInit = tonum(csvData[index]["品德初始值"]),
				atkInit = tonum(csvData[index]["才艺初始值"]),
				defInit = tonum(csvData[index]["美色初始值"]),
				hpGrow = tonum(csvData[index]["品德成长值"]),
				atkGrow = tonum(csvData[index]["才艺成长值"]),
				defGrow = tonum(csvData[index]["美色成长值"]),

				potential = tonum(csvData[index]["参悟潜力"]),
				potentialDesc = csvData[index]["潜力评价"],

				-- 美人计
				beautySkill1 = tonum(csvData[index]["美人计1ID"]),
				beautySkill2 = tonum(csvData[index]["美人计2ID"]),
				beautySkill3 = tonum(csvData[index]["美人计3ID"]),

				activeLevel = tonum(csvData[index]["激活等级"]),
				preBeautyId = tonum(csvData[index]["前提美人ID"]),
				preChallengeId = tonum(csvData[index]["前提精英关卡ID"]),
				employMoney = string.split(string.trim((csvData[index]["招募金币"])), "="),

				headImage = csvData[index]["头像"],
				heroRes = csvData[index]["全身像"],
			}
		end
		-- dump(self:getBeautyById(beautyId))
	end
end

function BeautyListCsvData:getBeautyById(beautyId) 
	return self.m_data[beautyId]
end

function BeautyListCsvData:getAllData()
	return self.m_data
end

return BeautyListCsvData