-- 邮件系统action类
-- by liaodingbai
-- 2014.2.28

local EmailAction = {}

function EmailAction.listRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role

	local response = { emails = {} }
	local key_ids = string.format("role:%d:emailIds", msg.roleId)
	local emailIds = redisproxy:lrange(key_ids, 0, 19)
	local del_list = {}
	local now = skynet.time()

	for _, id in ipairs(emailIds) do
		local email = require("datamodel.Email").new({ key = string.format("email:%d:%s", msg.roleId, id)})
		if email:load() then
			local expire = email:getProperty("createtime") + MAIL_EXPIRE_TIME
			if now >= expire then
				table.insert(del_list, id)
			else
				table.insert(response.emails, email:pbData())
			end
		end
	end

	for _, id in ipairs(del_list) do
		local key = string.format("role:%d:%d", msg.roleId, id)
		redisproxy:lrem(key_ids, 0, id)
		redisproxy:del(key)
	end

	local bin = pb.encode("EmailList", response)
	SendPacket(actionCodes.EmailListResponse, bin)
end

function EmailAction.checkRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)
	local email = require("datamodel.Email").new({ key = string.format("email:%d:%s", msg.roleId, msg.param1)})
	if not email:load() then
		return
	end
	email:setProperty("status", 1)
	local bin = pb.encode("SimpleEvent", { roleId = msg.roleId, param1 = email:getProperty("status") })
	SendPacket(actionCodes.EmailCheckResponse, bin)
end

function EmailAction.recvAttachmentRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)
	local role = agent.role

	local email = require("datamodel.Email").new({ key = string.format("email:%d:%s", msg.roleId, msg.param1)})

	if not email:load() then
		return
	end

	if email:getProperty("status") == 2 then
		return
	end

	local emailData = emailCsv:getEmailById(email:getProperty("emailId"))
	local attachments
	if emailData and #emailData.attachments > 0 then
		attachments = string.toTableArray(emailData.attachments)
	else
		attachments = string.toTableArray(email:getProperty("attachments"))
	end
	if #attachments == 0 then return end

	for _, attachment in ipairs(attachments) do
		local itemId = tonum(attachment[1])
		local num = tonum(attachment[2])
		local mailId = email:getProperty("emailId")
		log_util.log_mail_award(role, itemId, num, mailId)
		role:awardItemCsv(itemId, { num = num })
	end

	-- 领取含附件邮件后，删除邮件
	local key0 = string.format("role:%d:emailIds", role:getProperty("id")) 
	redisproxy:lrem(key0, 0, email:getProperty("id"))
	local key1 = string.format("email:%d:%d", role:getProperty("id"), email:getProperty("id"))
	redisproxy:del(key1)

	email:setProperty("status", 2)
	local bin = pb.encode("SimpleEvent", { roleId = msg.roleId, param1 = email:getProperty("status") })
	SendPacket(actionCodes.EmailRecvAttachmentResponse, bin)
end

return EmailAction