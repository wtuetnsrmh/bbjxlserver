
local _M = {}

local mc = require "multicast"
local datacenter = require "datacenter"
local skynet = require "skynet"

local chan_w

function _M:sub_world(w_channel)
	chan_w = mc.new {
		channel = w_channel,
		dispatch = function (channel, source, ...)
			if select("#", ...) == 0 then
				return
			end
			local actionCode, bin = ...
			SendPacket(actionCode, bin)
		end
	}
	chan_w:subscribe()		
end

function _M:usub_world()
	if chan_w then
		chan_w:unsubscribe()
		chan_w = nil
	end
end

function _M:pub_world(actionCode, bin)
	if not bin or not chan_w then return end
	chan_w:publish(actionCode, bin)
end

function _M:sub_guild(gid)
	local g_channel = datacenter.get("MC_G_CHANNEL", gid)
	if not g_channel then 
		skynet.error(string.format("guild channel %d not exist;sub_guild failed", gid))
		return
	end
	local chan_g = mc.new {
		channel = g_channel,
		dispatch = function (channel, source, ...)
			if select("#", ...) == 0 then
				return
			end
			local actionCode, bin = ...
			SendPacket(actionCode, bin)
		end
	}
	chan_g:subscribe()	
end

function _M:usub_guild(gid)
	local chan_g = datacenter.get("MC_G_CHANNEL", gid)
	if not chan_g then 
		skynet.error(string.format("guild channel %d not exist;usub_guild failed", gid))
		return
	end	
	chan_g:unsubscribe()
	datacenter.set("MC_G_CHANNEL", gid, nil)
end

function _M:pub_guild(gid, actionCode, bin)
	local chan_g = datacenter.get("MC_G_CHANNEL", gid)
	if not chan_g then 
		skynet.error(string.format("guild channel %d not exist;pub_guild failed", gid))
		return
	end	
	if not bin then return end
	chan_g:publish(actionCode, bin)
end

function _M:pub_person(source, target, data)
	if 0 == redisproxy:exists("role:"..target) then
		return
	end
	-- 若在线，实时发送聊天信息
	local tar_agent = datacenter:get("agent", target)
	if tar_agent then 
		self:route_chat_cli(data, tar_agent.fd)
	end
	-- TODO:若不在线，
end

function _M:route_chat_cli(data, fd)
	local bin = pb.encode("ChatMsg", data)
	SendPacket(actionCodes.ChatReceiveResponse, bin, fd)
end

return _M