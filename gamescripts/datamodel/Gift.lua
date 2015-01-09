local Gift = class("Gift", require("shared.ModelBase"))

function Gift:ctor(properties)
	Gift.super.ctor(self, properties)
	require("shared.EventProtocol").extend(self)
end

Gift.schema = {
    key     = {"string"},       -- redis key
    id 		= {"number"},      	-- id 数据库 ID
    itemId  = {"number"},       -- 道具ID 对应于道具表
    createTime = {"number", skynet.time()},    -- 获得时间
}   

Gift.fields = {
	id = true, 
	itemId = true, 
	createTime = true,
}

function Gift:pbData()
	return {
		id = self:getProperty("id"),
		itemId = self:getProperty("itemId"), 
		createTime = self:getProperty("createTime"),
	}
end

-- 删除武将记录
function Gift:delete()
    redisproxy:del(string.format("gift:%d:%d", self.owner:getProperty("id"), self:getProperty("id")))
    redisproxy:srem(string.format("role:%d:giftIds", self.owner:getProperty("id")), self:getProperty("id"))
end

return Gift