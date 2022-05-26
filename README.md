lua-metamodule
==========

[![test](https://github.com/mah0x211/lua-metamodule/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-metamodule/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/mah0x211/lua-metamodule/branch/master/graph/badge.svg)](https://codecov.io/gh/mah0x211/lua-metamodule)

simple oop module for lua.

## Installation

```sh
luarocks install metamodule
```


## Create a Module

### fn = metamodule.new[.ModuleName](_M, ...)

register the module and returns the constructor.

**Parameters**

- `_M:table`: module table that contains functions and non-function properties.
- `...:string`: embedding module names

**Returns**

- `fn:function`: module constructor function.


### Description

the module name will be registered as the concatenation of the module path specified in the `require` function and 'ModuleName'. If there is no `ModuleName`, only the module path will be registered.

if you want to define the module in a file that is not loaded by the `require` function, you must specify the `ModuleName`.


### Constraints

the following reserved words cannot be used in property or method names;

- `constructor`
- `instanceof`
- `__index`


### Usage

```lua
local metamodule = require('metamodule')

-- declare Hello metamodule
local Hello = {
    prefix = 'hello',
}

--- init method is automatically called in the constructor function,
--- and returns the return value of the init method.
function Hello:init(msg)
    self.word = string.format('%s %s!', self.prefix, msg or '')
    return self
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
print(m:instanceof()) -- Hello
print(metamodule.instanceof(m, 'Hello')) -- true
print(metamodule.instanceof(m, 'World')) -- false

m:say() -- hello metamodule!

m = newHey('metamodule')
print(m:instanceof()) -- Hey
print(metamodule.instanceof(m, 'Hello')) -- true
print(metamodule.instanceof(m, 'World')) -- false
print(metamodule.instanceof(m, 'Hey')) -- true
m:say() -- hey metamodule!
```


## Dump the metamodule registry

### str = metamodule.dump()

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
--             [1] = "Hello",
--             Hello = 1
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
--     },
--     ["function: 0x7f801f41c610"] = "Hello",
--     ["function: 0x7f801f41eb50"] = "Hey"
-- }
```
