local export = exports['lulu_interact']

local function call(self, index, ...)
    local function method(...)
        return export[index](nil, ...)
    end

    if not ... then
        self[index] = method
    end

    return method
end

local interact = setmetatable({
    name = 'lulu_interact',
}, {
    __index = call,
    __newindex = function(self, key, fn)
        rawset(self, key, fn)

        local src = debug.getinfo(2, 'S').short_src
        if src:find('lulu_interact') and src:find('client') then
            exports(key, fn)
        end
    end
})

_ENV.interact = interact