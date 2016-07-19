local Email = class("Email", require("shared.ModelBase"))

function Email:ctor(properties)
	Email.super.ctor(self, properties)
end

Email.schema = {
    key     	= {"string"}, 	-- redis key
    id 			= {"number", 0},	-- 数据库ID
    emailId		= {"number", 0},	-- 邮件csv ID
    title 		= {"string", ""},	-- 邮件标题
    content 	= {"string", ""},	-- 邮件正文
    attachments	= {"string", ""},
    status		= {"number", 0},	-- 邮件状态: 未读, 已读, 保存
    createtime	= {"number", skynet.time()},
    pm1 		= {"string", ""},
    pm2			= {"string", ""},
    pm3 		= {"string", ""},
}

Email.fields = {
	id = true,
	emailId = true,
	title = true,
	content = true,
	attachments = true,
	status = true,
	createtime = true,
	pm1 = true,
	pm2 = true,
	pm3 = true,
}

function Email:pbData()
	local emailId = self:getProperty("emailId")
	local title = self:getProperty("title")
	local content = self:getProperty("content")
	local attachments = self:getProperty("attachments")

	local emailData = emailCsv:getEmailById(emailId)

	if emailData then
		-- 如果内容是直接插入到数据库
		if content == "" and emailData.contentPath ~= "" then
			content = io.readfile("res/" .. emailData.contentPath)
			local pm1 = self:getProperty("pm1")
			if #pm1 > 0 then
				local pm2 = self:getProperty("pm2")
				local pm3 = self:getProperty("pm3")
				content = string.format(content, pm1, pm2, pm3)
			end
		end

		if title == "" and emailData.title ~= "" then
			title = emailData.title
		end

		if attachments == "" and emailData.attachments ~= "" then
			attachments = emailData.attachments
		end
	end
	if emailId == globalCsv:getFieldValue("pvpUpEmailId") then
		attachments = string.format("602=%s", self:getProperty("pm3"))
		self:setProperty("attachments", attachments)
	end

	return {
		id = self:getProperty("id"),
		status = self:getProperty("status"),
		createtime = self:getProperty("createtime"),
		title = title,
		content = content,
		attachments = attachments,
	}
end

return Email