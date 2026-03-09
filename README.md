lua-metamodule
==========

[![test](https://github.com/mah0x211/lua-metamodule/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-metamodule/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/mah0x211/lua-metamodule/branch/master/graph/badge.svg)](https://codecov.io/gh/mah0x211/lua-metamodule)

simple oop module for lua.


## Installation

```sh
luarocks install metamodule
```


## Usage

```lua
local metamodule = require('metamodule')

-- Define a base module
local Animal = { sound = '...' }

function Animal:init(name)
    self.name = name
    return self
end

function Animal:speak()
    print(self.name .. ' says ' .. self.sound)
end

local newAnimal = metamodule.new.Animal(Animal)

-- Embed Animal into Dog (compile-time flat copy — no prototype chain)
local Dog = { sound = 'woof' }

function Dog:fetch(item)
    print(self.name .. ' fetches ' .. item)
end

local newDog = metamodule.new.Dog(Dog, 'Animal')

-- Create instances
local a = newAnimal('Cat')
a:speak()              -- Cat says ...

local d = newDog('Rex')
d:speak()              -- Rex says woof   (Animal's method, O(1) dispatch)
d:fetch('the ball')    -- Rex fetches the ball

-- Type checks
print(d:instanceof())                   -- Dog  (returns own registered name)
print(metamodule.instanceof(d, 'Dog'))    -- true
print(metamodule.instanceof(d, 'Animal')) -- true

-- Access the embedded module's method table explicitly
print(d['Animal'].speak(d))   -- Rex says woof
```


## Design Concept

### What is metamodule?

metamodule provides a structured way to define named modules (analogous to classes) and create instances from them. It builds on Lua's standard `setmetatable` mechanism with the following additions:

| Feature | Plain `setmetatable` | metamodule |
|---|---|---|
| Module name / package tracking | manual | automatic (`_NAME`, `_PACKAGE`) |
| `instanceof` type check | manual | built-in, covers full embed hierarchy |
| Constructor (`init`) | manual | automatic call on instance creation |
| Declaration table protection | none | sealed after registration (read-only) |
| Package name from `require` path | manual | automatic |
| Field embedding with priority rules | manual | built-in |

### Embedding: compile-time flat copy, not runtime prototype delegation

Embedding another module (the `...` args to `metamodule.new`) is a **flat copy at registration time**, similar to a mixin or trait:

- Vars, methods, and metamethods from embedded modules are copied into the new module's registry entry when `metamodule.new` is called.
- All methods are resolved into a single flat `__index` table at registration time, so every method call is **O(1)** — regardless of how many modules were embedded.
- Changes to the embedded module after registration do **not** affect the derived module.
- Multiple modules can be embedded in parallel (like multiple traits).
- This is **not** a prototype chain — there is no runtime delegation to a parent object.

```
Prototype chain:          Child --> Parent --> GrandParent (runtime lookup at every call)
metamodule embedding:     Child [all methods copied in at registration] (O(1) at every call)
```

### Performance Trade-offs

metamodule makes a deliberate trade between **instance creation cost** and **method call cost**.

**At `register()` time** (once, when the module is defined), all methods from embedded modules
are resolved and stored in a single flat `__index` table. This means every method call on any
instance is always **O(1)** — exactly one `__index` hop — regardless of how many modules
were embedded.

**At construction time** (every `new()` call), metamodule performs three steps that plain
`setmetatable({}, Class)` does not:

1. Copies module vars (including `_NAME`) into a fresh table for each instance
2. Calls `setmetatable()` to attach the method table
3. Dispatches through `init()` (even the default no-op incurs a method call)

This results in a construction cost roughly **1.6× higher** than bare `setmetatable({}, Class)`.
However, if a plain implementation also stored `_NAME` per-instance and called an `init()`
method, the gap narrows to approximately **1.3×** — the remainder being the overhead of the
constructor closure itself. The key point is that this overhead is **constant and
depth-independent**: embedding 3 modules costs the same as embedding 0.

#### When the trade-off is worth it

metamodule is a good fit when:

- **Objects are long-lived and methods are called repeatedly** — the fixed construction
  overhead is amortized over many calls; with 2–3 levels of embedding, method calls run
  roughly 20–40% faster than plain prototype chains.
- **Embedding depth matters** — plain prototype chains slow down
  proportionally with depth (O(depth)); metamodule stays flat (O(1)) regardless of
  how many modules are embedded.
- **Module organization, type safety, or `instanceof` checks are needed** — these features
  come at no additional runtime cost beyond the construction overhead already described.

#### When plain `setmetatable` is better

Consider avoiding metamodule when:

- **Object creation is on the critical hot path** — e.g. allocating thousands of tiny,
  short-lived objects per frame in a tight game loop where there are few or no method calls
  per instance.
- **Instances carry only data, not behaviour** — if instances are never called as methods
  (no `obj:method()`), the flat `__index` table provides no benefit and the construction
  overhead is pure cost.

#### LuaJIT

Under LuaJIT 2.1, the JIT compiler eliminates the trade-off almost entirely.
Both instance creation and method dispatch are optimized so aggressively that the
differences between plain `setmetatable` and metamodule fall within measurement
noise. On LuaJIT, choose metamodule (or not) purely on **architectural** grounds — module
naming, `instanceof`, declaration sealing, embedded module organization — without any
performance concern.


## Create a Module

### `fn = metamodule.new[.ModuleName](_M, ...)`

Register a module and return its constructor function.

**Parameters**

- `_M:table`: declaration table containing methods (functions) and vars (non-function values).
- `...:string`: names of modules to embed.

**Returns**

- `fn:function`: constructor function. Calling `fn(...)` creates and returns a new instance.

**How the registered name is determined**

When `metamodule.new` is called from inside a file loaded by `require`, the package name is automatically detected from the call stack. The full registered name (**regname**) is formed as:

| Call form | Loaded via `require` | regname |
|---|---|---|
| `metamodule.new(decl)` | yes (`mypkg`) | `"mypkg"` |
| `metamodule.new.Hello(decl)` | yes (`mypkg`) | `"mypkg.Hello"` |
| `metamodule.new.Hello(decl)` | no | `"Hello"` |
| `metamodule.new(decl)` | no | **error** (name cannot be nil) |

If the file is **not** loaded via `require` (e.g. a standalone script), `ModuleName` is mandatory.

**Which form to use**

- Use **`metamodule.new(decl)`** when one file exports exactly one module. The regname becomes the `require` path itself (e.g. a file `animal.lua` loaded as `require('animal')` gets regname `"animal"`). This is the simplest form and supports tail-call usage (`return metamodule.new(decl)`).
- Use **`metamodule.new.Name(decl)`** when one file defines **multiple classes**, or when registering from a standalone script. For example, `geometry.lua` (loaded as `require('geometry')`) can define both `Point` and `Rect` in the same file — `metamodule.new.Point(Point)` gets regname `"geometry.Point"` and `metamodule.new.Rect(Rect)` gets regname `"geometry.Rect"`.

> **Note — tail call and package name detection:**
> Package name auto-detection works by inspecting the Lua call stack at registration time.
> `metamodule.new(decl)` (the `__call` form) supports tail call usage:
> `return metamodule.new(decl)` works correctly on all Lua versions (5.1–5.4 and LuaJIT).
> The module name is recovered from the `require` call frame via `debug.getlocal` when the
> module's own stack frame has been eliminated by tail-call optimization.

**Example — loaded via `require`**

```lua
-- file: mypkg/hello.lua  (loaded as require('mypkg.hello'))
local metamodule = require('metamodule')

local Hello = { prefix = 'hello' }

function Hello:init(msg)
    self.word = string.format('%s %s!', self.prefix, msg or 'world')
    return self
end

function Hello:say()
    print(self.word)
end

-- regname becomes "mypkg.hello.Hello"
return metamodule.new.Hello(Hello)
```

**Example — standalone script (ModuleName required)**

```lua
local metamodule = require('metamodule')

local Hello = { prefix = 'hello' }

function Hello:init(msg)
    self.word = string.format('%s %s!', self.prefix, msg or 'world')
    return self
end

function Hello:say()
    print(self.word)
end

-- regname becomes "Hello"
local newHello = metamodule.new.Hello(Hello)
local m = newHello('metamodule')
m:say() -- hello metamodule!
```


## Declaration Constraints

The following field names **cannot** be used in a declaration table:

| Name | Reason |
|---|---|
| `constructor` | reserved |
| `instanceof` | automatically generated by metamodule |
| `_NAME`, `_PACKAGE`, `_STRING` | automatically set on instances |

Additional rules:

- All field names must be **strings** (integer or other-type keys raise an error).
- The `init` field, if present, **must** be a function.
- `__index` is **not** reserved — it is a valid metamethod (function type only; see [Metamethods](#metamethods)).
- Non-function fields (vars) and non-function metamethods (e.g. `__mode`, `__name`) are **deep-copied** at registration time. Any field containing a **circular table reference** will raise an error: `field "x" cannot be used: unable to copy circularly referenced values`.


## Module Declaration is Sealed After Registration

Once `metamodule.new` completes, the declaration table (`_M`) becomes **read-only**. Any attempt to modify it afterwards raises an error:

```lua
local metamodule = require('metamodule')

local Hello = { prefix = 'hello' }
function Hello:say() print(self.prefix) end

metamodule.new.Hello(Hello)

Hello.prefix = 'hi'  -- ERROR: cannot change module definition after module declaration
```

This prevents accidental modification of a module's definition after it has been registered.


## Instance Fields

Every instance created by a constructor has the following read-only fields set automatically:

| Field | Type | Description |
|---|---|---|
| `_NAME` | string | Full registered name of the module (regname), e.g. `"mypkg.Hello"` or `"Hello"` |
| `_PACKAGE` | string or nil | Package name derived from the `require` path; `nil` when called outside `require` |
| `_STRING` | string or nil | Lazily-computed string representation. `nil` until the first `tostring(obj)` call; after that cached as `"ModuleName: 0x..."`. |

```lua
local newHello = metamodule.new.Hello({ prefix = 'hi' })
local m = newHello()
print(m._NAME)    --> Hello
print(m._PACKAGE) --> nil  (standalone script)
print(m._STRING)  --> nil  (not yet computed)
print(tostring(m))--> Hello: 0x...
print(m._STRING)  --> Hello: 0x...  (now cached)
```


## `init` Method

The `init` method is **called automatically** by the constructor, and the constructor returns whatever `init` returns.

- If `init` is not defined, a default initializer is used that simply returns `self`.
- If `init` is defined, it **must** be a function (a non-function `init` field is an error).
- The return value of `init` becomes the return value of the constructor call.

```lua
local metamodule = require('metamodule')

local Counter = { count = 0 }

function Counter:init(start)
    self.count = start or 0
    return self  -- must return self (or whatever the caller should receive)
end

function Counter:increment()
    self.count = self.count + 1
end

local newCounter = metamodule.new.Counter(Counter)
local c = newCounter(10)
print(c.count) -- 10
c:increment()
print(c.count) -- 11
```


## `obj:instanceof()`

Calling `instanceof` on an instance (with no arguments) returns the module's registered name as a string.

```lua
local newHello = metamodule.new.Hello({ prefix = 'hi' })
local m = newHello()
print(m:instanceof()) -- Hello
```

See also [`metamodule.instanceof`](#boolmetamoduleinstanceofobj-name) for type-checking by name.


## Metamethods

Fields whose names begin with `__` are treated as metamethods and placed in the instance's metatable. For the known metamethods listed below, if the value is not a function an error is raised. For `__mode` and `__name`, any value type is accepted (Lua treats them as strings at runtime, but metamodule does not enforce this). Any unlisted `__xxx` field is also accepted without type enforcement.

| Name | Type enforced |
|---|---|
| `__add`, `__sub`, `__mul`, `__div`, `__mod`, `__pow`, `__unm` | function |
| `__idiv`, `__band`, `__bor`, `__bxor`, `__bnot`, `__shl`, `__shr` | function |
| `__concat`, `__len`, `__eq`, `__lt`, `__le` | function |
| `__index`, `__newindex`, `__call`, `__tostring`, `__gc`, `__close` | function |
| `__mode`, `__name` | *(not enforced — any value accepted)* |

**Default `__tostring`**

If `__tostring` is not defined, a default is used that returns the `_STRING` field (`"ModuleName: 0x..."`).

**Special behavior of `__index` as a function**

If `__index` is defined as a function, metamodule generates a dynamic metatable at construction time that wraps both the method lookup table and the user-defined `__index` function:

```lua
-- effective __index behavior when __index is defined as a function:
__index = function(self, key)
    if methods[key] then
        return methods[key]
    else
        return user_defined_index(self, key)  -- fallback
    end
end
```

This means named methods always take priority over the custom `__index`.

```lua
local metamodule = require('metamodule')

local Proxy = {}

-- __index is called only for keys that are NOT defined as methods
function Proxy:__index(key)
    return function()
        return tostring(self) .. ': dynamic key=' .. key
    end
end

function Proxy:greet()
    return 'hello from ' .. self._NAME
end

local newProxy = metamodule.new.Proxy(Proxy)
local p = newProxy()
print(p:greet())      -- hello from Proxy  (defined method takes priority)
print(p:anything())   -- Proxy: 0x...: dynamic key=anything
```


## Module Embedding

Pass module names as additional arguments to `metamodule.new` to embed other modules:

```lua
metamodule.new.Child(decl, 'Parent1', 'Parent2', ...)
```

### What gets copied

At registration time, the following are merged into the new module from each embedded module:

- **vars** (non-function fields) — deep-copied
- **methods** (function fields)
- **metamethods** (`__`-prefix fields)

### Priority rules

**Own module fields always win.** When the same name exists in multiple sources, the priority order is:

```
own module  >  first embedded  >  second embedded  >  ...
```

### Accessing embedded module methods

All methods from embedded modules are directly accessible on the instance as if they were the module's own methods. Additionally, each embedded module's full method table is stored on the instance under the key `obj[regname]` (where `regname` is the embedded module's registered name):

```lua
local metamodule = require('metamodule')

local Base = { val = 'base' }
function Base:hello() return 'Base:hello ' .. self.val end

local newBase = metamodule.new.Base(Base)

local Child = { val = 'child' }
-- Child does NOT define :hello, so Base's is used directly
local newChild = metamodule.new.Child(Child, 'Base')

local c = newChild()
print(c:hello())           -- Base:hello child  (self.val is child's val)
print(c['Base'].hello(c))  -- Base:hello child  (same, called explicitly)
```

### Calling an overridden base method

If the child module overrides a method, the original base method is still accessible via `obj[regname]` (where `regname` is the embedded module's registered name):

```lua
local metamodule = require('metamodule')

local Base = {}
function Base:greet() return 'Hello from Base, name=' .. self._NAME end

local newBase = metamodule.new.Base(Base)

local Child = {}
function Child:greet() return 'Hello from Child, name=' .. self._NAME end

local newChild = metamodule.new.Child(Child, 'Base')

local c = newChild()
print(c:greet())               -- Hello from Child, name=Child  (own method)
print(c['Base'].greet(c))      -- Hello from Base, name=Child   (base method with child self)
```

> **Note:** Use `.method(obj)` (dot notation with explicit `self`), not `:method()`.
> `obj["Base"]:method()` is syntactic sugar for `obj["Base"].method(obj["Base"])`,
> so `self` inside the method would be the method table, not the instance.

Nested embeddings also work — if `Base` embeds `GrandBase`, then `obj["GrandBase"]` is also available on `Child` instances.

### Lazy loading of embedded modules

If a module name passed to `metamodule.new` has not been registered yet, metamodule automatically calls `require(pkgname)` to load it. **Loading happens at `metamodule.new` call time** (i.e. registration time), not when instances are created.

```lua
-- node.lua (registered as 'node')
local metamodule = require('metamodule')
local Node = {}
function Node:value() return self._value end

return metamodule.new(Node)  -- registers as 'node'

-- list.lua
local metamodule = require('metamodule')
local List = {}
function List:push(v)
    -- implementation
end

-- 'node' is not loaded yet — metamodule calls require('node') here
return metamodule.new.List(List, 'node')
```

#### Circular embedding (mutual dependency)

If module A embeds B and B embeds A, one of them will fail at registration time with a clear error:

```
cannot embed module 'A': circular embedding detected
```

**Avoid circular embedding.** If two modules need each other's behaviour, restructure so that shared logic lives in a third module that both embed:

```
-- Bad: circular
A embeds B, B embeds A

-- Good: extract shared logic
Shared ← A embeds Shared
Shared ← B embeds Shared
```

#### Instance-level references vs. embedding

Circular *instance* relationships (e.g. a doubly-linked list where each node holds a `prev` and `next`) are perfectly fine because instances are plain tables — they do not cause module registration issues.

```lua
-- Linked list: Node embeds nothing from other modules
local metamodule = require('metamodule')

local Node = {}
function Node:init(value)
    self.value = value
    self.next  = nil
    return self
end

local newNode = metamodule.new.Node(Node)

local a = newNode(1)
local b = newNode(2)
local c = newNode(3)
a.next = b  -- instance-level reference, no embedding involved
b.next = c

-- traverse
local n = a
while n do
    print(n.value)
    n = n.next
end
-- 1
-- 2
-- 3
```

The rule of thumb: **embedding is for sharing methods** (like traits), not for expressing runtime relationships between instances.

### Constraints on embedding

- The same module cannot be embedded twice: `metamodule.new.C(C, 'A', 'A')` raises an error.
- The module name passed as an embed argument must be a valid package name (lowercase alphanumeric segments separated by `.`). An invalid name such as `'UnregisteredModule'` raises: `cannot embed module 'X': invalid module name`.
- If the package loads successfully but does not call `metamodule.new`, embedding raises: `cannot embed module 'X': not a metamodule`.
- Circular embedding causes a registration-time error (`circular embedding detected`). See [Circular embedding](#circular-embedding-mutual-dependency).


## `bool = metamodule.instanceof(obj, name)`

Check whether `obj` is an instance of the module registered under `name`, including modules embedded into it.

**Parameters**

- `obj:any`: the value to check.
- `name:string`: the registered module name to check against. **Must be a string** (raises an error otherwise).

**Returns**

- `bool:boolean`: `true` if `obj` is an instance of `name` or any module that embeds `name`; `false` otherwise.

```lua
local metamodule = require('metamodule')

local newBase = metamodule.new.Base({})
local newChild = metamodule.new.Child({}, 'Base')

local b = newBase()
local c = newChild()

print(metamodule.instanceof(b, 'Base'))   -- true
print(metamodule.instanceof(c, 'Child'))  -- true
print(metamodule.instanceof(c, 'Base'))   -- true  (Base is embedded in Child)
print(metamodule.instanceof(b, 'Child'))  -- false

-- non-metamodule values return false
print(metamodule.instanceof('hello', 'Base'))  -- false
print(metamodule.instanceof({}, 'Base'))       -- false
```


## `str = metamodule.dump()`

Dump the internal module registry as a human-readable string. Useful for debugging.

**Returns**

- `str:string`: dump string of the `REGISTRY` table.

The registry entry for each module contains:

- `embeds`: list of directly embedded module names (both as array and as name→index map)
- `metamethods`: metamethod functions/values
- `methods`: all methods including `init` and `instanceof`
- `vars`: non-function fields including `_NAME` and `_PACKAGE`

```lua
local metamodule = require('metamodule')

local Hello = { prefix = 'hello' }
function Hello:init(msg)
    self.word = string.format('%s %s!', self.prefix, msg or '')
    return self
end
function Hello:say() print(self.word) end
metamodule.new.Hello(Hello)

local Hey = { prefix = 'hey' }
metamodule.new.Hey(Hey, 'Hello')

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
