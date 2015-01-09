
local CURRENT_MODULE_NAME = ...

-- init base classes
cc = cc or {}
cc.Registry = import(".Registry")
cc.GameObject = import(".GameObject")

-- init components
local components = {
    "behavior.StateMachine",
}
for _, packageName in ipairs(components) do
    cc.Registry.add(import("." .. packageName, CURRENT_MODULE_NAME), packageName)
end
