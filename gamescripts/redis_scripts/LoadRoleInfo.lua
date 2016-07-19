-- KEYS[1] 玩家ID

local roleDetail = {}

local roleInfo = redis.call("HMGET", string.format("role:%d", KEYS[1]), "delete", "name", "level", "pvpRank", "mainHeroId", "lastLoginTime","slotsJson", "chooseHeroIds","partnersJson")
if tonumber(roleInfo[1]) == 1 then
	return roleDetail
end

roleDetail = { 
	roleInfo[2],		-- roleName 	
	roleInfo[3], 		-- roleLevel
	roleInfo[4],		-- pvpRank
	roleInfo[5],		-- mainHeroId
	roleInfo[6],		-- lastLoginTime
	roleInfo[7],		-- slotsJson
	roleInfo[9],        -- partnersJson
}
local chooseHeroIds = cjson.decode(roleInfo[8])
for index, heroId in ipairs(chooseHeroIds) do
	local heroInfo = redis.call("HMGET", string.format("hero:%d:%s", KEYS[1], heroId), "delete", "type", "evolutionCount", "wakeLevel","level", "star")
	if tonumber(heroInfo[1]) == 0 then
		roleDetail[#roleDetail + 1] = heroId
		roleDetail[#roleDetail + 1] = heroInfo[2]
		roleDetail[#roleDetail + 1] = heroInfo[3]
		roleDetail[#roleDetail + 1] = heroInfo[4]
		roleDetail[#roleDetail + 1] = heroInfo[5]
		roleDetail[#roleDetail + 1] = heroInfo[6]
	end
end

return roleDetail