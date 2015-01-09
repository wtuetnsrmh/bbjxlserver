local _M = {}

local function proc_online(cmd, pms)
	local roleId = pms['id']
	local agent = datacenter.get("agent", tonumber(roleId))
	if agent then
		local fpms = {}
		for k,v in pairs(pms) do
			if k == 'pm1' or k == 'pm2' or k == 'pm3' then
				fpms[k] = tonumber(v)
			else
				fpms[k] = v
			end
		end
		local ok, result = pcall(skynet.call, agent.serv, "lua", cmd, fpms)
		return ok and result or "指令失败"
	end
	return "not_online"
end

local function sub_broadcast(roleId, pms)
	local agent = datacenter.get("agent", tonumber(roleId))
	if agent then
		pcall(skynet.call, agent.serv, "lua", "broadcast", pms)
	end
end

function _M.broadcast(pms)
	local maxRoleId = tonumber(redisproxy:hget("autoincrement_set", "role"))
	for roleId = 10001, maxRoleId do
		skynet.fork(sub_broadcast, roleId, pms)
	end
	return "指令成功"
end

function _M.friend_value(pms)
	local isOk = proc_online("friend_value", pms)
	if isOk ~= "not_online" then
		return isOk
	end
	return "玩家不在线"
end

function _M.employ(pms)
	local isOk = proc_online("employ", pms)
	if isOk ~= "not_online" then
		return isOk
	end
	return "玩家不在线"
end

function _M.vip(pms)
	local isOk = proc_online("vip", pms)
	if isOk ~= "not_online" then
		return isOk
	end
	
	local val = tonumber(pms['pm1'])
	if val > 12 then val = 12 end
	if val < 0 then val = 0 end

	local key = string.format("role:%d", tonumber(pms['id']))
	redisproxy:hset(key, 'vipLevel', val)
	return "指令生效"
end

function _M.wake(pms)
	local isOk = proc_online("wake", pms)
	if isOk ~= "not_online" then
		return isOk
	end
	return "玩家不在线"
end

function _M.hero_skill(pms)
	local isOk = proc_online("hero_skill", pms)
	if isOk ~= "not_online" then
		return isOk
	end
	return "玩家不在线"
end

function _M.hero_level(pms)
	local isOk = proc_online("hero_level", pms)
	if isOk ~= "not_online" then
		return isOk
	end
	return "玩家不在线"
end

function _M.star_up(pms)
	local isOk = proc_online("star_up", pms)
	if isOk ~= "not_online" then
		return isOk
	end
	return "玩家不在线"
end

function _M.exp_fb(pms)
	local isOk = proc_online("exp_fb", pms)
	if isOk ~= "not_online" then
		return isOk
	end
	return "玩家不在线"
end

function _M.money_fb(pms)
	local isOk = proc_online("money_fb", pms)
	if isOk ~= "not_online" then
		return isOk
	end
	return "玩家不在线"
end

function _M.exp(pms)
	local isOk = proc_online("exp", pms)
	if isOk ~= "not_online" then
		return isOk
	end
	local roleId = tonum(pms['id'])
	local key = string.format("role:%d", roleId)
	redisproxy:hincrby(key, 'exp', tonum(pms['pm1']))
	return "指令成功"
end

function _M.health(pms)
	local isOk = proc_online("health", pms)
	if isOk ~= "not_online" then
		return isOk
	end
	local roleId = tonum(pms['id'])
	local key = string.format("role:%d", roleId)
	redisproxy:hincrby(key, 'health', tonum(pms['pm1']))
	return "指令成功"	
end

function _M.level(pms)
	local isOk = proc_online("level", pms)
	if isOk ~= "not_online" then
		return isOk
	end
	local roleId = tonum(pms['id'])
	local key = string.format("role:%d", roleId)
	redisproxy:hincrby(key, 'level', tonum(pms['pm1']))
	return "指令成功"	
end

function _M.lingpai(pms)
	local isOk = proc_online("lingpai", pms)
	if isOk ~= "not_online" then
		return isOk
	end
	local roleId = tonum(pms['id'])
	local key = string.format("role:%d", roleId)
	redisproxy:hincrby(key, 'lingpai', tonum(pms['pm1']))
	return "指令成功"	
end

function _M.zhangong(pms)
	local isOk = proc_online("zhangong", pms)
	if isOk ~= "not_online" then
		return isOk
	end
	local roleId = tonum(pms['id'])
	local key = string.format("role:%d", roleId)
	redisproxy:hincrby(key, 'zhangong', tonum(pms['pm1']))
	return "指令成功"
end

function _M.herosoul(pms)
	local isOk = proc_online("herosoul", pms)
	if isOk ~= "not_online" then
		return isOk
	end
	local roleId = tonum(pms['id'])
	local key = string.format("role:%d", roleId)
	redisproxy:hincrby(key, 'herosoul', tonum(pms['pm1']))
	return "指令成功"
end

function _M.starsoul(pms)
	local isOk = proc_online("starsoul", pms)
	if isOk ~= "not_online" then
		return isOk
	end
	local roleId = tonum(pms['id'])
	local key = string.format("role:%d", roleId)
	redisproxy:hincrby(key, 'starsoul', tonum(pms['pm1']))
	return "指令成功"
end

function _M.money(pms)
	local isOk = proc_online("money", pms)
	if isOk ~= "not_online" then
		return isOk
	end
	local roleId = tonum(pms['id'])
	local key = string.format("role:%d", roleId)
	redisproxy:hincrby(key, 'money', tonum(pms['pm1']))
	return "指令成功"
end

function _M.yuanbao(pms)
	local isOk = proc_online("yuanbao", pms)
	if isOk ~= "not_online" then
		return isOk
	end
	local roleId = tonum(pms['id'])
	local key = string.format("role:%d", roleId)
	redisproxy:hincrby(key, 'yuanbao', tonum(pms['pm1']))
	return "指令成功"
end

function _M.get(pms)
	local isOk = proc_online("get", pms)
	if isOk ~= "not_online" then
		return isOk
	end
	return "玩家不在线"	
end

function _M.hero(pms)
	local isOk = proc_online('hero', pms)
	if isOk ~= "not_online" then
		return isOk
	end
	return "玩家不在线"
end

function _M.yuanzheng(pms)
	local isOk = proc_online('yuanzheng', pms)
	if isOk ~= "not_online" then
		return isOk
	end
	local roleId = tonumber(pms['id'])
	local key = string.format("role:%d:daily", role)
	redisproxy:hset(key, "expeditionResetCount", 0)
	return "指令成功"
end

function _M.shengwang(pms)
	local isOk = proc_online('shengwang', pms)
	if isOk ~= "not_online" then
		return isOk
	end
	local roleId = tonum(pms['id'])
	local key = string.format("role:%d", roleId)
	redisproxy:hset(key, 'reputation', tonum(pms['pm1']))
	return "指令成功"
end

function _M.skip_guide(pms)
	local isOk = proc_online('skip_guide', pms)
	if isOk ~= "not_online" then
		return isOk
	end
	local activedGuide = "1111111111111111111111111111111111111111111111111111111111111111"
	local roleId = tonum(pms['id'])
	local key = string.format("role:%d", roleId)
	redisproxy:hmset(key, 'activedGuide', activedGuide, "guideStep", 1000)
	return "指令成功"
end

function _M.silent(pms)
	local isOk = proc_online('silent', pms)
	if isOk ~= "not_online" then
		return isOk
	end
	local roleId = tonum(pms['id'])
	local day = tonum(pms['pm1'])
	local key = string.format("role:%d", roleId)
	if day < 1 then
		redisproxy:hset(key, 'silent', 0)
		return "解禁生效"
	end
	redisproxy:hincrby(key, 'silent', day*86400)
	return "禁言成功"
end

return _M