local ModelBase = class("ModelBase")
ModelBase.key = "key"
ModelBase.schema = {
    key = {"string"}
}
ModelBase.fields = {}   -- 数据库字段 field, update 是否立即更新

local function filterProperties(properties, filter)
    for i, field in ipairs(filter) do
        properties[field] = nil
    end
end

function ModelBase:ctor(properties)
    self.isModelBase_ = true
    self.dirtyFields = {}
    redisproxy = redisproxy

    if type(properties) ~= "table" then properties = {} end
    self:setProperties(properties)  --缺少的域将设置默认值
end

--[[--

返回对象的 ID 值。

**Returns:**

-   ID 值

]]
function ModelBase:getKey()
    local id = self[self.class.key .. "_"]
    assert(id ~= nil, string.format("%s [%s:getKey()] Invalid key", tostring(self), self.class.__cname))
    return id
end

function ModelBase:load()
    if not self:isValidKey() then
        print(string.format("%s [%s:id] should be set before load", tostring(self), self.class.__cname))
        return false
    end

    local properties = redisproxy:hgetall(self:getKey())
    if #table.keys(properties) == 0 then return false end
    
    self:setProperties(properties)
    self:onInit()
    return true
end

--创建model对应的redis数据, 必须已经设置了ID
function ModelBase:create()
    if not self:isValidKey() then
        print(string.format("%s [%s:key] should be set before create", tostring(self), self.class.__cname))
        return nil
    end

    --将所有的域都置为dirty, 存储到redis
    for fieldName, update in pairs(self.class.fields) do
        self.dirtyFields[fieldName] = true
    end
    self:save()
    self:onInit()

    return self
end

function ModelBase:save()
    local redisProperties = self:getProperties()

    for fieldName, value in pairs(redisProperties) do
        if self.dirtyFields[fieldName] then
            local propname = fieldName .. "_"
            redisproxy:hset(self:getKey(), fieldName, self[propname])
        end
    end
end

--[[--

确定对象是否设置了有效的 key。

]]
function ModelBase:isValidKey()
    local propname = self.class.key .. "_"
    local key = self[propname]
    return type(key) == "string" and key ~= ""
end

--[[--

修改对象的属性。
NOTE: 如果properties缺少schema中的域, 将用默认值来填充

**Parameters:**

-   properties: 包含属性值的数组

]]
function ModelBase:setProperties(properties)
    assert(type(properties) == "table", "Invalid properties")
           -- string.format("%s [%s:setProperties()] Invalid properties", tostring(self), self.class.__cname))
    
    for field, schema in pairs(self.class.schema) do
        local typ, def = unpack(schema)
        local propname = field .. "_"

        local val = properties[field] or def
        if val ~= nil then
            if typ == "number" then val = tonumber(val) end
            assert(type(val) == typ,
               string.format("%s [%s:setProperties()] Type mismatch, %s expected %s, actual is %s",
                                 tostring(self), self.class.__cname, field, typ, type(val)))
            self[propname] = val
        end
    end
end

--[[--

取得对象的属性值。

**Parameters:**

-   fields: 要取得哪些属性的值，如果未指定该参数，则返回 fields 中设定的属性
-   filter: 要从结果中过滤掉哪些属性，如果未指定则不过滤

**Returns:**

-   包含属性值的数组

]]
function ModelBase:getProperties(fields, filter)
    local schema = self.class.schema
    if type(fields) ~= "table" then fields = table.keys(self.class.fields) end

    local properties = {}
    for i, field in ipairs(fields) do
        local propname = field .. "_"
        local typ = schema[field][1]
        local val = self[propname]
        assert(type(val) == typ,
               string.format("%s [%s:getProperties()] Type mismatch, %s expected %s, actual is %s",
                                 tostring(self), self.class.__cname, field, typ, type(val)))
        properties[field] = val
    end

    if type(filter) == "table" then
        filterProperties(properties, filter)
    end

    return properties
end

function ModelBase:getProperty(property)
    if type(property) ~= "string" then return nil end
    return self:getProperties({property})[property]
end

function ModelBase:setProperty(property, value, update)
    if not self.class.schema[property] then
        print(string.format("%s [%s:setProperty()] Invalid property : %s",
            tostring(self), self.class.__cname, property))
        return
    end

    local typ, def = unpack(self.class.schema[property])
    local propname = property .. "_"

    if typ == "number" then value = tonumber(value) end
    assert(type(value) == typ,
       string.format("%s [%s:setProperties()] Type mismatch, %s expected %s, actual is %s",
         tostring(self), self.class.__cname, property, typ, type(value)))
    self[propname] = value

    if self.class.fields[property] or update then
        redisproxy:hset(self:getKey(), property, value)
    else
        self.dirtyFields[property] = true  -- record the fields been modified
    end
end

function ModelBase:onInit()
end

return ModelBase