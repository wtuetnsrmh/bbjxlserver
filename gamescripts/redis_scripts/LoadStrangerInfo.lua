-- KEYS[1] 玩家和陌生人助战KEY
-- KEYS[2] 随机的陌生人ID
-- KEYS[3] 玩家ID
-- ARGV[1] 玩家等级
-- ARGV[2] 随机种子

local assistInfo = {}

local assistCd = redis.call("EXISTS", KEYS[1])
if assistCd == 1 then
	redis.log(redis.LOG_NOTICE, KEYS[1] .. " exist")
	return assistInfo 
end

local roleInfo = redis.call("HMGET", string.format("role:%d", KEYS[2]), "delete", "name", "level", "chooseHeroIds")
local chooseHeroIds = cjson.decode(roleInfo[4])
if tonumber(roleInfo[1]) == 1 or tonumber(#chooseHeroIds) <= 0 or tonumber(roleInfo[3]) > tonumber(ARGV[1]) then
	return assistInfo
end

math.randomseed(tonumber(ARGV[2]))
local heroId = chooseHeroIds[math.random(1, #chooseHeroIds)]
local mainHeroInfo = redis.call("HMGET", string.format("hero:%d:%s", KEYS[2], heroId), "delete", "type", "level", "skillLevelJson", "evolutionCount", "wakeLevel", "star")
if tonumber(mainHeroInfo[1]) == 1 then return assistInfo end

local myStrangerAssistKey = string.format("role:%d:strangerAssistIds", KEYS[3])
local exist = redis.call("SISMEMBER", myStrangerAssistKey, KEYS[2])
redis.log(redis.LOG_WARNING, "exist", exist)

assistInfo = { 
	roleInfo[2],		-- roleName 	
	roleInfo[3], 		-- roleLevel
	heroId,		-- heroId
	mainHeroInfo[2],	-- heroType 
	mainHeroInfo[3], 	-- heroLevel
	mainHeroInfo[4], 	-- heroSkillLevelJson
	mainHeroInfo[5],	-- heroEvolutionCount
	mainHeroInfo[6],	-- wakeLevel
	mainHeroInfo[7],	-- star
	exist,
}

return assistInfo