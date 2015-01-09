local AssociationInfoCsvData = {
	m_data = {},
}

function AssociationInfoCsvData:load( fileName )
	local csvData = CsvLoader.load(fileName)

	for index = 1, #csvData do
		local id = tonum(csvData[index]["组合技ID"])

		if id ~= 0 then
			self.m_data[id] = {
				id = id,
				name = csvData[index]["组合技名称"],
				desc = csvData[index]["组合技描述"],
				skillHeroName = csvData[index]["技能武将名称"],
				skillHeroType = tonum(csvData[index]["技能武将ID"]),
				heroGroup = string.split(csvData[index]["武将组合"], " "),
				groupType = tonum(csvData[index]["组合技类型"]),
				attackBonus = tonum(csvData[index]["攻击加成"]),
				defenseBonus = tonum(csvData[index]["防御加成"]),
				hpBonus = tonum(csvData[index]["生命加成"]),
				attackSpeedBonus = tonum(csvData[index]["攻速加成"]),
			}
		end
	end
end