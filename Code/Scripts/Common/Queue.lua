local List = List
local Class = Class

---@class Queue:List
local Queue = Class:new(List)

function Queue:Enqueue(item)
    self:push(item)
end
function Queue:Peek()
   return self:head()
end
function Queue:Dequeue()
    return self:shift()
end
function Queue:Clear()
    self:clear()
end
function Queue:Count()
    return self.length
end
function Queue:Contains(item)
    local node = self:find(item)
    return node ~= nil
end
function Queue:Clone(item)
    self:clone()
end
function Queue:MoveNext()
    return self:movenext()
end
function Queue:Current()
    return self:current()
end
function Queue:InitEnumerator()
    self:initenumerator()
end
function Queue:ToTable()
    return self:totable()
end
return Queue