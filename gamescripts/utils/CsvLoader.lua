
-- break record from csv file into array of strings
local function fromCsv(s, separator)
	if not s then error("s is null") end
	s = s .. separator -- end with separator
	if separator == ' ' then separator = '%s+' end
	local t = {}
	local fieldstart = 1
	repeat
		-- next field is quoted? (starts with "?)
		if string.find(s, '^"', fieldstart) then
			local a, c
			local i = fieldstart
			repeat
				-- find closing quote
				a, i, c = string.find(s, '"("?)', i+1)
			until c ~= '"' -- quote not followed by quote?
			if not i then error('unmatched "') end
			local f = string.sub(s, fieldstart+1, i-1)
			table.insert(t, (string.gsub(f, '""', '"')))
			fieldstart = string.find(s, separator, i) + 1
		else
			local nexti = string.find(s, separator, fieldstart)
			table.insert(t, string.sub(s, fieldstart, nexti-1))
			fieldstart = nexti + 1
		end
	until fieldstart > string.len(s)

	return t
end

CsvLoader = {
	separator = ","
}

function CsvLoader.load(fileName)
	local res = {}

	local file, msg = assert(io.open(fileName, "r"))
	if not file then error(msg) end
	
	local line = assert(file:read("*l"))
	local header = fromCsv(line, CsvLoader.separator)
	local headerLookup = {}
	for i, field in ipairs(header) do headerLookup[field] = i end

	local mt = {
		__index = function(tbl, key)
			local idx = headerLookup[key]
			if idx == nil then
				return ""
			else
				return string.trim(tbl[idx])
			end
		end
	}
	
	line = file:read("*l")
	while line ~= nil do
		res[#res + 1] = setmetatable(fromCsv(line, CsvLoader.separator), mt)
		line = file:read("*l")
	end
	file:close()

	return res
end
