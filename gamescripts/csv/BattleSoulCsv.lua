local BattleSoulCsvData = {
	m_data = {},
	toItemIndex = 6000
}

function BattleSoulCsvData:load(fileName)
	self.m_data = {}
	local csvData = CsvLoader.load(fileName)
	for line = 1, #csvData do
		local id = tonum(csvData[line]["id"])
		if id > 0 then
			self.m_data[id] = {
				id = id,
				requireLevel = tonum(csvData[line]["需求等级"]),
				flag = tonum(csvData[line]["碎片标识"]),
				material = string.toNumMap(csvData[line]["合成所需"]),
				money = tonum(csvData[line]["合成价格"]),
				hp = tonum(csvData[line]["生命"]),
				atk = tonum(csvData[line]["攻击"]),
				def = tonum(csvData[line]["防御"]),
			}
		end
	end
end

function BattleSoulCsvData:getDataById(id)
	return self.m_data[id]
end

return BattleSoulCsvData