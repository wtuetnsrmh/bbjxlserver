local seed = tonumber(KEYS[1])
local selfRoleId = tonumber(KEYS[2])
local maxForce = tonumber(KEYS[3])
local confJson1 = KEYS[4]
local confJson2 = KEYS[5] 

local conf1 = cjson.decode(confJson1)
-- key保证是字符串 
local conf2 = cjson.decode(confJson2)

math.randomseed(seed)

local keyName = "expedition:forceRank:r"

local pre = redis.call("hmget", string.format("role:%d", selfRoleId), "pre1", "pre2")
local delta = tostring(pre[1] - pre[2])
local adjust = conf2[delta]

-- 2. 随机出远征对手
local ismember = function (tbl, val)
	for _, v in pairs(tbl) do
		if v == val then return true end
	end
	return false
end

local scopes = {}
local lowMin, lowMax = 0, 0
for k, v in ipairs(conf1) do
	local min = maxForce*v.min/100*(1+adjust/100)
	if k == 1 then lowMax = min end
	local max = maxForce*v.max/100*(1+adjust/100)
	local scope = redis.call("zrangebyscore", keyName, min, max)
	scope = scope or {}
	table.insert(scopes, scope)
end
local lowScope = redis.call("zrangebyscore", keyName, lowMin, lowMax)

local ret = {}
local j = 15
for i = 15, 1, -1 do
	if j > i then j = i end
	while true do 
		local scope = scopes[j] and scopes[j] or lowScope
		local len1 = #scope
		if len1 > 0 then
			local index = math.random(len1)
			local roleId = tonumber(scope[index])
			if roleId == selfRoleId then
				table.remove(scope, index)
				local len2 = #scope
				if len2 > 0 then
					index = math.random(len2)
					roleId = scope[index]
				end
			end
			if roleId ~= selfRoleId and not ismember(ret, roleId) then
				table.remove(scope, index)
				local key = redis.call("zrank", "expedition:forceRank:r", roleId)
				ret[key] = roleId
				break
			end
		end
		if j == -15 then break end
		j = j - 1
	end
end

local keys = {}
for k, _ in pairs(ret) do
	table.insert(keys, k)
end

local ok = #keys == 15
if ok then
	table.sort(keys, function (a, b) return tonumber(a) < tonumber(b) end)

	for k, v in ipairs(keys) do
		local val = redis.call("hget", "expedition:fightInfo:r", ret[v])
		redis.call("hset", string.format("expedition:fightList:%d", selfRoleId), k, val)
	end
end

return ok
