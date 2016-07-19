-- KEYS[1] 玩家角色ID
-- ARGV[1] 随机种子

local assistHeroInfo = {}

-- 从好友列表里面查找
local myFriends = redis.call("SMEMBERS", string.format("role:%d:friends", KEYS[1]))
local friendAssistCnt = 0

math.randomseed(tonumber(ARGV[1]))

for _, friendId in ipairs(myFriends) do
	if friendAssistCnt >= 5 then break end

	local assistCd = redis.call("EXISTS", string.format("friendAssist:%d:%d", KEYS[1], friendId))
	if assistCd == 1 then
		redis.log(redis.LOG_NOTICE, string.format("friendAssist:%d:%d", KEYS[1], friendId) .. " exist")
	else
		local friendInfo = redis.call("HMGET", string.format("role:%d", friendId), "delete", "name", "level", "chooseHeroIds")
		local chooseHeroIds = cjson.decode(friendInfo[4])
		if tonumber(friendInfo[1]) == 0 and #chooseHeroIds > 0 then
			local heroId = chooseHeroIds[math.random(1, #chooseHeroIds)]
			local mainHeroInfo = redis.call("HMGET", string.format("hero:%d:%s", friendId, heroId), "delete", "type", "level", "skillLevelJson", "evolutionCount", "wakeLevel", "star")

			if tonumber(mainHeroInfo[1]) == 0 then
				local myStrangerAssistKey = string.format("role:%d:friendAssistIds", KEYS[1])
				local exist = redis.call("SISMEMBER", myStrangerAssistKey, friendId)

				friendAssistCnt = friendAssistCnt + 1
				table.insert(assistHeroInfo, {
					tonumber(friendId),		-- roleId
					friendInfo[2],			-- roleName
					friendInfo[3],			-- roleLevel
					heroId,	-- heroId	
					tonumber(mainHeroInfo[2]),	-- heroType
					tonumber(mainHeroInfo[3]),	-- heroLevel
					mainHeroInfo[4],	-- heroSkillLevelJson
					tonumber(mainHeroInfo[5]),	-- heroEvolutionCount
					tonumber(mainHeroInfo[6]),	-- heroWakeLevel
					tonumber(mainHeroInfo[7]),	-- star
					exist,
				})
			end
		end
	end
end

return assistHeroInfo