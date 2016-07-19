-- 背包系统物品
-- by yangkun
-- 2014.3.21

local Item = class("Item", require("shared.ModelBase"))

function Item:ctor(properties)
	Item.super.ctor(self,properties)
	require("shared.EventProtocol").extend(self)
end

Item.schema = {
	key = {"string"},			-- redis key
	id = {"number"}, 			-- item id 全局id
	count = {"number", 0},		-- 背包 item 的个数
}

Item.fields = {
	id = true,
	count = true,
}

-- 删除某个物品
function Item:delete()
	redisproxy:del(self:getKey())
	redisproxy:srem(string.format("role:%d:items", self.owner:getProperty("id")), self:getProperty("id"))
end

function Item:addCount(count, notNotifyClient)
	local result = self:getProperty("count") + count
	if result <= 0 then
		self.owner.items[self:getProperty("id")] = nil
		self:delete()
	else
		self:setProperty("count", result)
	end

	if not notNotifyClient then
		local bin = pb.encode("SimpleEvent", 
			{ roleId = self.owner:getProperty("id"), param1 = self:getProperty("id"), param2 = count })
		SendPacket(actionCodes.ItemUpdateProperty, bin)
	end
end

function Item:pbData()
	return {
		id = self:getProperty("id"),
		count = self:getProperty("count"),
	}
end

return Item