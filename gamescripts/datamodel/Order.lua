local Order = class("Order", require("shared.ModelBase"))

function Order:ctor(properties)
	Order.super.ctor(self, properties)
	require("shared.EventProtocol").extend(self)
end

Order.schema = {
    key     	= {"string"},       -- redis key
    order 		= {"string"},      	-- 自己订单号
    kunlunOrder	= {"string", ""},	-- 昆仑方产生的订单号
    uname 		= {"string", ""},	-- 玩家名
    createTime  = {"number", skynet.time()},       -- 订单创建时间
    platformTime = {"number", 0},	-- 渠道成功创建时间, 仅供参考
    kunlunTime	= {"number", 0},	-- 昆仑代理商完成时间
}   

Order.fields = {
	order = true, 
	kunlunOrder = true,
	uname = true,
	createTime = true, 
	platformTime = true,
	kunlunTime = true,
}

return Order