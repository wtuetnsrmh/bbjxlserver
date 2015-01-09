-- 查询玩家详细信息
-- KEYS[1]	玩家角色ID

local roleDetail = {}

local roleFields = { "delete", "name", "level", "exp", "pvpRank", "mainHeroId", "lastLoginTime" }

-- 玩家信息
local roleInfo = redis.call("HMGET", string.format("role:%d", KEYS[1]), unpack(roleFields))

for index, field in ipairs(roleFields) do
	roleDetail[field] = roleInfo[index]
end
	
-- 武将信息
local heroFields = { "id", "type", "level", "exp" }
local heroIds = redis.call("smembers", string.format("role:%d:heroIds", KEYS[1]))

roleDetail.heros = roleDetail.heros or {}
for _, heroId in ipairs(heroIds) do
	local heroInfo = redis.call("HMGET", string.format("hero:%d:%d", KEYS[1], heroId), unpack(heroFields))
	local hero = {}
	for index, field in ipairs(heroFields) do
		hero[field] = heroInfo[index]
	end
	table.insert(roleDetail.heros, hero)
end

-- 装备信息

-- 道具信息

return cjson.encode(roleDetail)