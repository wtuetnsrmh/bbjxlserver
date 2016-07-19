require("utils.StringUtil")
require("utils.CommonFunc")

local PvpAwardCsvData = {
	m_data = {},
}

function PvpAwardCsvData:load(fileName)

	local csvData = CsvLoader.load(fileName)

	self.m_data = {}

	for index = 1, #csvData do
		local id = tonum(csvData[index]["id"])
		local floorRank = tonum(csvData[index]["名次上限"])

		if id > 0 then
			self.m_data[floorRank] = {
				floorRank = floorRank,
				ceilRank = tonum(csvData[index]["名次下限"]),
				money = tonum(csvData[index]["获得金钱"]),
				moneyStarBonus = string.tomap(csvData[index]["金钱星级修正"]),
				exp = tonum(csvData[index]["获得经验"]),
				expStarBonus = string.tomap(csvData[index]["经验星级修正"]),
				zhangong = tonum(csvData[index]["获得战功"]),
				zhangongStarBonus = string.tomap(csvData[index]["战功星级修正"])
			}
		end
	end
end

function PvpAwardCsvData:getAwardData(rank)
	return lowerBoundSeach(self.m_data, rank)
end

return PvpAwardCsvData