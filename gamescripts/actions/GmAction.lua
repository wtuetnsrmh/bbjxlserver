local GmAction = {}

function GmAction.GmRequest(agent, data)
	local msg = pb.decode("GmEvent", data)
	local role = agent.role
	if not role then return end
	local action = gmSubAction[msg.cmd]
	local bin = pb.encode("GmEvent", { cmd = "指令失败" })
	if not action then 
		SendPacket(actionCodes.GmReceiveResponse, bin)
		return 
	end
	local ret = action(role, msg) 
	bin = pb.encode("GmEvent", { cmd = ret })
	SendPacket(actionCodes.GmReceiveResponse, bin)
end

return GmAction