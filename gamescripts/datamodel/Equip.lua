local Equip = class("Equip", require("shared.ModelBase"))

function Equip:ctor(properties)
	Equip.super.ctor(self, properties)
	require("shared.EventProtocol").extend(self)
end

Equip.schema = {
    key     = {"string"},       -- redis key
    id 		= {"number"},      	-- id 存储用户 ID
    type    = {"number", 0},    -- 装备ID，即csvid
    level   = {"number", 1},    -- 等级
    evolCount = {"number", 0},  -- 进阶等级
    evolExp = {"number", 0},    -- 进化经验
}   

Equip.fields = {
	id = true, 
    type = true, 
    level = true,
    evolCount = true,
    evolExp = true,
}

-- 给武器升级
-- @param 升级值
function Equip:upLevel( deltaValue )
    if deltaValue == 0 then return end
    local origLevel = self:getProperty("level")
    if origLevel >= self.owner:getProperty("level") * 2 then
        -- 达到升级上限
        return
    end

    self:setProperty("level", origLevel + deltaValue)
end

function Equip:getSlot()
    local id = self:getProperty("id")
    for slot, data in pairs(self.owner.slots) do
        if data.equips and data.equips[self.csvData.equipSlot] == id then
            return tonum(slot)
        end
    end
    return 0
end

-- 通知client, 装备数据的变动
-- @param 更新域
-- @param 新值
function Equip:updateProperty(field, newValue, notify)
    self:setProperty(field, newValue)
    
    local updateData = {
        id = self:getProperty("id"),
        key = field,
        newValue = newValue,
    }
    notify = notify == nil and true or notify
    if notify then
        local bin = pb.encode("EquipUpdateProperty", updateData)
        SendPacket(actionCodes.EquipUpdateProperty, bin)
    end
end

function Equip:onInit()
    self.csvData = equipCsv:getDataByType(self:getProperty("type"))
end


function Equip:getBaseAttributes()
    local attrs = {}
    for key, value in pairs(EquipAttEnum) do
        attrs[key] = math.floor(self.csvData.attrs[value] and 
            (self.csvData.attrs[value][1] + self.csvData.attrs[value][2] * self:getProperty("level")) * (globalCsv:getFieldValue("equipEvolFactor")[self:getProperty("evolCount")] or 1) or 0)
    end
    return attrs
end

--装备作为原材料提供的exp
function Equip:getOfferExp()
    local exp = self:getProperty("evolExp") + self.csvData.offerExp
    for index = 1, self:getProperty("evolCount") do
        exp = exp + self.csvData.evolExp[index]
    end
    return exp
end

--装备出售的钱
function Equip:getSellMoney()
    local sellMoney = self:getLevelReturnMoney()
    local itemData = itemCsv:getItemById(self:getProperty("type") + Equip2ItemIndex.ItemTypeIndex)
    if itemData then
        sellMoney = sellMoney + itemData.sellMoney  
    end
    return sellMoney
end

--得到装备等级补偿的钱
function Equip:getLevelReturnMoney()
    local sellData = equipLevelCostCsv:getDataByLevel(self:getProperty("level"))
    return sellData.sellMoney[self.csvData.star] or 0
end


--装备进阶
function Equip:addEvolExp(addExp)
    addExp = addExp + self:getProperty("evolExp")
    local nextEvolCount = EQUIP_MAX_EVOL
    local curEvolCount = self:getProperty("evolCount")
    for evolCount = curEvolCount + 1, EQUIP_MAX_EVOL do
        local needExp = self.csvData.evolExp[evolCount]
        if addExp >= needExp then
            addExp = addExp - needExp
        else
            nextEvolCount = evolCount - 1
            break
        end
    end
    self:upEvolCount(nextEvolCount - curEvolCount)
    self:updateProperty("evolExp", addExp, true)
end

function Equip:upEvolCount(deltaCount)
    if deltaCount <= 0 then return end
    local curEvolCount = self:getProperty("evolCount")
    local nextEvolCount = math.min(curEvolCount + deltaCount, EQUIP_MAX_EVOL)
    self:updateProperty("evolCount", nextEvolCount, true)
end

function Equip:pbData()
    return {
        id = self:getProperty("id"), 
        type = self:getProperty("type"), 
        level = self:getProperty("level"), 
        evolCount = self:getProperty("evolCount"),
        evolExp = self:getProperty("evolExp"),
    }
end

return Equip

