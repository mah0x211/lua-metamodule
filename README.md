lua-metamodule
==========

simple oop module for lua.

## Installation

```sh
luarocks install metamodule
```

## Dependencies

- lua-dump https://github.com/mah0x211/lua-dump

## Create a Module

### fn = metamodule.new.<ModuleName>(_M, ...)

creates a new module constructor

**Parameters**

- `_M:table`: module table that contains functions and non-function properties.
- `...:string': embedding module names

**Returns**

- `fn:function`: module constructor function.

**e.g.**

```lua
local metamodule = require('metamodule')

-- declare Hello metamodule
local Hello = {
    prefix = 'hello',
}

--- init method will be called automatically in constructor function
function Hello:init(msg)
    self.word = string.format('%s %s!', self.prefix, msg or '')
end

function Hello:say()
    print(self.word)
end

local newHello = metamodule.new.Hello(Hello)

-- declare Hey metamodule
local Hey = {
    prefix = 'hey',
}

local newHey = metamodule.new.Hey(Hey, 'Hello')

-- create instances
local m = newHello('metamodule')
m:say() -- hello metamodule!

m = newHey('metamodule')
m:say() -- hey metamodule!
```


## Dump the metamodule registry

### str = metamodule.dump

dump the metamodule registry table.

**Returns**

- `str:string`: dump string.

**e.g.**

```lua
local metamodule = require('metamodule')

-- declare Hello metamodule
local Hello = {
    prefix = 'hello',
}

--- init method will be called automatically in constructor function
function Hello:init(msg)
    self.word = string.format('%s %s!', self.prefix, msg or '')
end

function Hello:say()
    print(self.word)
end

metamodule.new.Hello(Hello)

-- declare Hey metamodule
local Hey = {
    prefix = 'hey',
}

metamodule.new.Hey(Hey, 'Hello')

-- print registry
print(metamodule.dump())
-- {
--     Hello = {
--         embeds = {},
--         metamethods = {
--             __tostring = "function: 0x7f801f41ae70"
--         },
--         methods = {
--             init = "function: 0x7f801f41baa0",
--             instanceof = "function: 0x7f801f41c610",
--             say = "function: 0x7f801f41ba70"
--         },
--         vars = {
--             _NAME = "Hello",
--             prefix = "hello"
--         }
--     },
--     Hey = {
--         embeds = {
--             [1] = "Hello"
--         },
--         metamethods = {
--             __tostring = "function: 0x7f801f41ae70"
--         },
--         methods = {
--             init = "function: 0x7f801f41baa0",
--             instanceof = "function: 0x7f801f41eb50",
--             say = "function: 0x7f801f41ba70"
--         },
--         vars = {
--             _NAME = "Hey",
--             prefix = "hey"
--         }
--     }
-- }
```
