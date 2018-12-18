local require = require
local Entity = require('Enity')
local System = require('System')
local Group = require('Group')

local format = string.format
local insert = table.insert
local clear = table.clear
local error = error
local assert = assert
local type = type
local select = select
local pairs = pairs
local EventMgr = GameEvent.ECSEvent
local List = List
local ilist = ilist
local Class = Class
local printyellow = printyellow
local printcolor = printcolor
local LogError = LogError

local reusedEntities = List:new()
local compPool = {}--k:组件类型;v:组件池

---@class World
local World = Class:new("World")

local OnComponentChanged
local OnComponentUpdated
local OnComponentModify
local OnCreateEntity
local OnDestroyEntity

local removeChangeEvt
local removeUpdateEvt
local removeDestroyEvt

function World:Init(name, entityID)
    self.name = name or "World"
    self.entityID = entityID or 1
    self.entities = {}   ---array mix hash
    self.systemNodes = {}  -- 键值对,便于遍历查询
    self.systemList = List:new()      -- 链表,便于list中节点修改
    self.groups = {}    --逐帧处理,系统各引用一个组;key-filterName:value-group
    self.groupForIndex = {} --组件类型做为key,对groups分类;key-compindex:value-groups
end

function World:Update(dt)
    ----上一帧执行的添加移除更新操作,在下一帧开始时执行,顺序如下
    ----1.添加
    ----2.移除
    ----3.更新
    ----4.处理前[可选]
    ----5.处理中
    ----6.处理后[可选]

    for _, v in ilist(self.systemList) do
        local system = v
        if system and system.enable then
            if system.OnUpdate then
                system:OnUpdate(dt)
            elseif system.OnNotify and system.group and #system.group > 0 then
                system:Notify() --需要定义 OnNotify
            end
        end
    end
end

function World:Reset()
    self:DestroyAllEntities()
    self.entityID = 0
end

function World:CreateEnity()
    local entity = nil
    if reusedEntities.length > 0 then
        entity = reusedEntities:Shift()
        entity:Reset(self, self.entityID)
    else
        entity = Entity:new(self, self.entityID)
    end
    insert(self.entities, entity)
    self.entities[entity] = #self.entities
    self.entityID = self.entityID + 1
    return entity
end

function World:RemoveEnity(entity)
    if not entity then
        LogError('World:%s remove entity-%d fail.', self.name)
        return
    end

    local entities = self.entities
    local index = entities[entity]
    if index then
        local lastEntity = entities[#entities]
        entities[index] = lastEntity
        entities[#entities] = nil
        entities[lastEntity] = index
        entities[entity] = nil
    end

    ---是否进入Group的筛选操作

    reusedEntities:Push(entity)
end

function World:DestroyAllEntities()
    for i = 1, #self.entities do
        local entity = self.entities[i]
        self.entities[entity] = nil
        OnDestroyEntity(entity)
        reusedEntities:Push(entity)
    end
end

-----------------------------------------------
-----------------System控制函数
-----------------------------------------------
---@param nodes List
local SetSystemEnable = function(nodes, enable, ...)
    local length = select('#', ...)
    if length > 0 then
        for i = 1, length do
            local name = select(i, ...)
            nodes[name].value.enable = enable
        end
    else
        local node = nodes:Head()
        while node do
            node.value.enable = enable
            node = node:Next()
        end
        printyellow('World:Set all systems', enable)
    end
end
function World:StartSystems(...)
    SetSystemEnable(self.systemNodes, true, ...)
end
function World:StopSystems(...)
    SetSystemEnable(self.systemNodes, false, ...)
end
-----系统执行顺序以添加顺序为准,顺序可动态调整
---@param ... string
function World:AddSystem(...)
    local length = select('#', ...)
    if length == 0 then
        return
    end

    for i = 1, length do
        ---name:相对Systems路径名
        local name = select(i, ...)
        ---@type System
        local system = self.systemNodes[name]
        if not system then
            system = require('Systems.' .. name)
            system:Init(self, name)
            local node = self.systemList:Push(system)
            self.systemNodes[name] = node
            local filterName = system.filterName
            local group = self.groups[filterName]
            if not group then
                group = Group:new(system.filter)
                if system.OnUpdate then
                    for i = 1, #self.entities do
                        local entity = self.entities[i]
                        group:Filter(entity)
                    end
                else
                    system.collector = {}
                end
                self.groups[filterName] = group
                local indices = system.filter.indices
                for i = 1, #indices do
                    local index = indices[i]
                    local gs = self.groupForIndex[index]
                    if gs then
                        insert(gs, group)
                    else
                        gs = {group}
                    end
                    self.groupForIndex[index] = gs
                end
            end
            system.group = group
            group:AddSystem(name)
        else
            printcolor('red', 'World:Repeat registration system ' .. name)
        end
    end
end
----从World中移除System
---@param ... string
function World:RemoveSystem(...)
    local length = select('#', ...)
    if length == 0 then
        return
    end

    local names = { ... }
    local count = 0
    local node = self.systemList:Head()
    while node ~= nil and length ~= count do
        local del = nil
        local system = node.value
        for i = 1, length do
            if system.name == names[i] then
                count = count + 1
                del = node
                break
            end
        end
        node = self.systemList:Next(node)
        if del then
            local node = self.systemNodes[del.name]
            self.systemList:Remove(node)
            local group = self.groups[del.filterName]
            group:RemoveSystem(del.name)
            --self.groups[del.filterName] = nil
            --local filter = group.filter
            --for i = 1, #filter do
            --    local index = filter[i]
            --    local gs = self.groupForIndex[index]
            --    for j = 1, #gs do
            --        if gs[j] == group then
            --            gs[j] = nil
            --            break
            --        end
            --    end
            --end
            del:Destroy()
        end
    end
end

------------------------------------
---------------事件函数
------------------------------------
function World:OnComponentChanged(entity, index)
    local gs = self.groupForIndex[index]
    for i = 1, #gs do
        local group = gs[i]
        local index = group[entity]
        if not group:CheckEmpty() then
            if group:Filter(entity) then
                if not index then
                    insert(group, entity)
                    group[entity] = #group
                end
            else
                if index then
                    local last = group[#group]
                    local lastIndex = #group
                    group[index] = last
                    group[entity] = nil
                    group[last] = index
                    group[lastIndex] = nil
                end
            end
        end
    end
end
function World:OnComponentModify(entity, index)
    local gs = self.groupForIndex[index]
    for i = 1, #gs do
        local group = gs[i]
        local index = group[entity]
        if not index then
            insert(group, entity)
            group[entity] = #group
        end
    end

    for _, name in pairs(entity.linkedSys) do
        local group = self.groups[name]
        local index = group[entity]
        if not index then
            insert(group, entity)
            group[entity] = #group
        end
    end
end

return World



