require("constants")
require("shared.init")
require("utils.init")

skynet = require "skynet"
redisproxy = require("redisproxy")
json = require("shared.json")

local configLoader = require("csv.ConfigLoader")

local PvpEnvInit = class("PvpEnvInit")

function PvpEnvInit:ctor()
end

local function filterUnits(params)
	local units = {}
	for type, data in pairs(unitCsv.m_data) do
		local ok = true

		if params.profession > 0 then
			ok = ok and data.profession == params.profession
		end

		if ok and data.heroOpen == 1 then table.insert(units, data) end
	end

	return units
end

function PvpEnvInit:initRobotData()
	for rank, pvpData in pairs(pvpRobotsCsv.m_data) do
		--角色ID
        local newRole = require("datamodel.Role").new({
        	key = string.format("role:%d", rank),
        	id = rank,
        	name = pvpData.name,
        	pvpRank = rank,
        	level = pvpData.level,
        	lastLoginTime = os.time(),
        })
        newRole:create()

        --更新USER表
        redisproxy:set(string.format("user:%s", pvpData.name), rank)
        redisproxy:rpush("pvp_rank", rank)

		local roleName = pvpData.name
		local roleId = rank
		local roleKey = string.format("role:%d", roleId)

		local slotsJson = {}
		local pveFormation = {}
		local chooseHeroIds = {}

		local hasMainHeroId
		local unitTypes = {}

		local fighter = {heroList = {}}

		for pos, heroData in pairs(pvpData) do
			if type(heroData) == "table" and tonum(heroData.profession) > 0 then
				local professionUnits = filterUnits({ profession = heroData.profession, 
					stars = heroData.stars})
				if #professionUnits > 0 then
					local randIndex = math.random(1, #professionUnits)
					local unitData = professionUnits[randIndex] 
					while unitTypes[unitData.type] do
						if table.nums(unitTypes) == #professionUnits then
							unitData = nil
							break
						end
						randIndex = math.random(1, #professionUnits)
						unitData = professionUnits[randIndex] 
					end
					if unitData then
						local heroId = unitData.type
						unitTypes[heroId] = true

						-- local heroId = redisproxy:hincrby("autoincrement_set", "hero", 1)
						redisproxy:sadd(string.format("role:%d:heroIds", roleId), heroId)

						slotsJson[tostring(pos)] = slotsJson[tostring(pos)] or {}
						slotsJson[tostring(pos)].heroId = tostring(heroId)

						if not hasMainHeroId then
							redisproxy:hset(roleKey, "mainHeroId", heroId)
							hasMainHeroId = true
						end

						local skillLevel = { [tostring(unitData.talentSkillId)] = 1 }
						skillLevelJson = json.encode(skillLevel)

						local newHeroProperties = {
							key = string.format("hero:%d:%d", roleId, heroId),
							id = heroId,
							type = unitData.type,
							choose = 1,
							level = heroData.level,
							evolutionCount = heroData.evolutionCount,
							skillLevelJson = skillLevelJson,
						}

						local newHero = require("datamodel.Hero").new(newHeroProperties)
						newHero:create()
						local heroDtl = {
							id = heroId,
							level = heroData.level,
							evolutionCount = heroData.evolutionCount,
							skillLevelJson = skillLevelJson,
							blood = 100, 
							slot = tonumber(pos),
							star = heroData.stars,					
						}
						table.insert(fighter.heroList, heroDtl)

						pveFormation[pos] = heroId
						table.insert(chooseHeroIds, heroId)
					end
				end
			end
		end
		redisproxy:hmset(roleKey, "pveFormationJson", json.encode(pveFormation),
			"chooseHeroIds", json.encode(chooseHeroIds),
			"slotsJson", json.encode(slotsJson))
		newRole.slots = slotsJson

		for _, v in pairs(fighter.heroList) do
			local attrValues = require("datamodel.Hero").sGetTotalAttrValues(roleId, tonumber(v.id))
			v.attrsJson = json.encode(attrValues)
		end
		fighter['name'] = pvpData.name
		fighter['level'] = tonumber(pvpData.level)

		local force = newRole:getBattleValue()
		redisproxy:zadd("expedition:forceRank:r", force, rank)
		redisproxy:zadd("expedition:forceRank:w", force, rank)
		redisproxy:hset("expedition:fightInfo:r", roleId, json.encode(fighter))	
		redisproxy:hset("expedition:fightInfo:w", roleId, json.encode(fighter))	
	end
end

skynet.start(function()
	configLoader.loadCsv()

	local redisd = skynet.newservice("server/redisd")
	skynet.call(redisd, "lua", "open", redisParam)

	print("start")

	local instance = PvpEnvInit.new()
	instance:initRobotData()

	print("over")
end)

