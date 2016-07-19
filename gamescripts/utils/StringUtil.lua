--[[--

Split a string by string to map, string format like "123=2 222=3"

@param string str
@param string delimiter
@return map(note: type(key) == "string")

]]
function string.tomap(str, delimiter)
	delimiter = delimiter or " "
	local map = {}
	local array = string.split(string.trim(str), delimiter)
	for _, value in ipairs(array) do
		value = string.split(string.trim(value), "=")
		if #value == 2 then
			map[value[1]] = value[2]
		end
	end

	return map
end

--以数字形式存储
function string.toNumMap(str, delimiter)
	delimiter = delimiter or " "
	local map = {}
	local array = string.split(string.trim(str), delimiter)
	for _, value in ipairs(array) do
		value = string.split(string.trim(value), "=")
		if #value == 2 then
			map[tonum(value[1])] = tonum(value[2])
		end
	end

	return map
end

-- 将"1=2=3=4" 分割成{"1", "2", "3", "4"}
function string.toArray(str, delimiter, toNum)
	delimiter = delimiter or " "
	toNum = toNum or false
	local array = {}
	local tempArray = string.split(string.trim(str), delimiter)
	for _, value in ipairs(tempArray) do
		if string.trim(value) ~= "" then
			if toNum then value = tonum(value) end
			table.insert(array, value)
		end
	end

	return array
end

-- 将"1=2=3 4=5=6" 分割成{{"1", "2", "3"}, {"4", "5", "6"}}
function string.toTableArray(str, delimiter)
	delimiter = delimiter or " "
	local array = {}
	local tempArray = string.split(string.trim(str), delimiter)
	for _, value in ipairs(tempArray) do
		local trimValue = string.trim(value)
		if trimValue ~= "" then
			value = string.split(trimValue, "=")
			table.insert(array, value)
		end
	end

	return array
end

-- Format(xxx=xxx=xxx=xxx xxx=xxx=xxx=xxx)
function string.toAttArray(str, delimiter)
	delimiter = delimiter or " "
	local array = {}
	local tempArray = string.split(string.trim(str), delimiter)
	for _, value in ipairs(tempArray) do
		local trimValue = string.trim(value)
		if trimValue ~= "" then
			value = string.split(trimValue, "=")
			local key = tonum(value[1])
			array[key] = {}
			for index, attValue in ipairs(value) do
				if index ~= 1 then
					table.insert(array[key], tonum(attValue))
				end
			end 
		end
	end

	return array
end
