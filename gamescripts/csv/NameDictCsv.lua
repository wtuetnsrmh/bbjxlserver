local NameDictCsvData = {
	prefixes = {},
	familyNames = {},
	givenNames = {},
}

function NameDictCsvData:load(fileName)
	self.prefixes = {}
	self.familyNames = {}
	self.givenNames = {}

	local csvData = CsvLoader.load(fileName)

	for index = 1, #csvData do
		local prefixId = tonum(csvData[index]["形容词ID"])
		if prefixId > 0 then
			table.insert(self.prefixes, csvData[index]["形容词"])
		end

		local familyId = tonum(csvData[index]["姓氏ID"])
		if familyId > 0 then
			table.insert(self.familyNames, csvData[index]["姓氏"])
		end

		local givenId = tonum(csvData[index]["名字ID"])
		if givenId > 0 then
			table.insert(self.givenNames, csvData[index]["名字"])
		end
	end
end

function NameDictCsvData:randomName()
	local prefixIndex = math.random(1, #self.prefixes)
	local familyIndex = math.random(1, #self.familyNames)
	local givenIndex = math.random(1, #self.givenNames)

	local name = self.prefixes[prefixIndex] .. self.familyNames[familyIndex] .. self.givenNames[givenIndex]

	if string.utf8len(name) < 7 then
		return name
	else
		self:randomName()
	end
end

return NameDictCsvData