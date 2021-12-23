--
-- Copyright (C) 2021 Masatoshi Fukunaga
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
local concat = table.concat
local error = error
local getinfo = debug.getinfo
local string = require('stringex')
local find = string.find
local format = string.format
local gsub = string.gsub
local split = string.split
local ipairs = ipairs
local pairs = pairs
local setmetatable = setmetatable
local tostring = tostring
local type = type
local pcall = pcall
local require = require
local dump = require('dump')
local deepcopy = require('metamodule.deepcopy')
local eval = require('metamodule.eval')
local is = require('metamodule.is')
local pkgname = require('metamodule.pkgname')
local seal = require('metamodule.seal')
--- constants
local REGISTRY = {
    -- data structure
    -- [<regname>] = {
    --     embeds = {
    --         [<list-of-embedded-module-names>, ...]
    --     },
    --     metamethods = {
    --         __tostring = <function>,
    --         [<name> = <function>, ...]
    --     },
    --     methods = {
    --         init = <function>,
    --         instanceof = <function>,
    --         [<name> = <function>, ...]
    --     },
    --     vars = {
    --         _NAME = <string>,
    --         [_PACKAGE = <string>],
    --         [<name> = <non-function-value>, ...]
    --     }
    -- }
}

local function DEFAULT_INITIALIZER(self)
    return self
end

local function DEFAULT_TOSTRING(self)
    return self._STRING
end

--- register new metamodule
--- @param s string
--- @vararg any
local function errorf(s, ...)
    local msg = format(s, ...)
    local calllv = 2
    local lv = 2
    local info = getinfo(lv, 'nS')

    while info do
        if info.what ~= 'C' and not find(info.source, 'metamodule') then
            calllv = lv
            break
        end
        -- prev = info
        lv = lv + 1
        info = getinfo(lv, 'nS')
    end

    return error(msg, calllv)
end

--- register new metamodule
--- @param regname string
--- @param decl table
--- @return function constructor
--- @return string? error
local function register(regname, decl)
    -- already registered
    if REGISTRY[regname] then
        return nil, format('%q is already registered', regname)
    end

    -- set <instanceof> method
    local src = format('return %q', regname)
    local fn, err = eval(src)
    if err then
        return nil, err
    end
    decl.methods['instanceof'] = fn

    -- set default <init> method
    if not decl.methods['init'] then
        decl.methods['init'] = DEFAULT_INITIALIZER
    end
    -- set default <__tostring> metamethod
    if not decl.metamethods['__tostring'] then
        decl.metamethods['__tostring'] = DEFAULT_TOSTRING
    end

    local moduleMethods = decl.moduleMethods
    decl.moduleMethods = nil
    REGISTRY[regname] = decl

    -- create metatable
    local metatable = {}
    for k, v in pairs(decl.metamethods) do
        metatable[k] = v
    end

    -- create method table
    local index = {}
    for k, v in pairs(decl.methods) do
        index[k] = v
    end
    -- append embedded module methods
    for k, methods in pairs(moduleMethods) do
        index[k] = methods
    end
    metatable.__index = index

    -- create new vars table generation function
    src = format('return %s', dump(decl.vars))
    fn, err = eval(src)
    if err then
        return nil, err
    end

    -- create constructor
    return function(...)
        local _M = fn()
        _M._STRING = gsub(tostring(_M), 'table', _M._NAME)
        setmetatable(_M, metatable)
        return _M:init(...)
    end
end

--- load registered module
--- @param regname string
--- @return table module
--- @return string error
local function loadModule(regname)
    local m = REGISTRY[regname]

    -- if it is not registered yet, try to load a module
    if not m then
        local segs = split(regname, '.', true)
        local nseg = #segs
        local pkg = regname

        -- remove module-name
        if nseg > 1 and is.moduleName(segs[nseg]) then
            pkg = concat(segs, '.', 1, nseg - 1)
        end

        if is.packageName(pkg) then
            -- load package in protected mode
            local ok, err = pcall(function()
                require(pkg)
            end)

            if not ok then
                return nil, err
            end

            -- get loaded module
            m = REGISTRY[regname]
        end
    end

    if not m then
        return nil, 'not found'
    end

    return m
end

local IDENT_FIELDS = {
    ['_PACKAGE'] = true,
    ['_NAME'] = true,
    ['_STRING'] = true,
}

--- embed methods and metamethods of modules to module declaration table and
--- returns the list of module names and the methods of all modules
--- @param decl table
--- @return table moduleNames
--- @return table moduleMethods
local function embedModules(decl, ...)
    local moduleNames = {}
    local moduleMethods = {}
    local chkdup = {}
    local vars = {}
    local methods = {}
    local metamethods = {}

    for _, regname in ipairs({
        ...,
    }) do
        -- check for duplication
        if chkdup[regname] then
            errorf('cannot embed module %q twice', regname)
        end
        chkdup[regname] = true
        moduleNames[#moduleNames + 1] = regname

        local m, err = loadModule(regname)

        -- unable to load the specified module
        if err then
            errorf('cannot embed module %q: %s', regname, err)
        end

        -- embed m.vars
        local circular = {
            [tostring(m.vars)] = regname,
        }
        for k, v in pairs(m.vars) do
            -- if no key other than the identity key is defined in the VAR,
            -- copy the key-value pairs.
            if not IDENT_FIELDS[k] and not decl.vars[k] then
                v, err = deepcopy(v, regname .. '.' .. k, circular)
                if err then
                    errorf('field %q cannot be used: %s', k, err)
                end
                -- overwrite the field of previous embedded module
                vars[k] = v
            end
        end

        -- embed m.metamethods
        for k, v in pairs(m.metamethods) do
            if not decl.metamethods[k] then
                -- overwrite the field of previous embedded module
                metamethods[k] = v
            end
        end

        -- add embedded module methods into methods.<regname> field
        local mmethods = {}
        for k, v in pairs(m.methods) do
            mmethods[k] = v
            if not decl.methods[k] then
                -- overwrite the field of previous embedded module
                methods[k] = v
            end
        end

        moduleMethods[regname] = mmethods
    end

    -- add vars, methods and metamethods field of embedded modules
    for src, dst in pairs({
        [vars] = decl.vars,
        [methods] = decl.methods,
        [metamethods] = decl.metamethods,
    }) do
        for k, v in pairs(src) do
            if not dst[k] then
                dst[k] = v
            end
        end
    end

    return moduleNames, moduleMethods
end

local RESERVED_FIELDS = {
    ['constructor'] = true,
    ['instanceof'] = true,
    ['__index'] = true,
}

--- inspect module declaration table
--- @param regname string
--- @param moddecl table
--- @return table delc
local function inspect(regname, moddecl)
    local circular = {
        [tostring(moddecl)] = regname,
    }
    local vars = {}
    local methods = {}
    local metamethods = {}

    for k, v in pairs(moddecl) do
        if type(k) ~= 'string' then
            errorf('field name must be string: %q', tostring(k))
        elseif IDENT_FIELDS[k] or RESERVED_FIELDS[k] then
            errorf('reserved field %q cannot be used', k)
        elseif k == 'init' then
            if type(v) ~= 'function' then
                errorf('field "init" must be function')
            end
            -- use as method
            methods[k] = v
        elseif type(v) ~= 'function' then
            -- use as variable
            local cpval, err = deepcopy(v, regname .. '.' .. k, circular)
            if err then
                errorf('field %q cannot be used: %s', k, err)
            end

            if is.metamethodName(k) then
                -- use as metamethod variable
                metamethods[k] = cpval
            else
                -- use as variable
                vars[k] = cpval
            end
        elseif is.metamethodName(k) then
            -- use as metamethod
            metamethods[k] = v
        else
            -- use as method
            methods[k] = v
        end
    end

    return {
        vars = vars,
        methods = methods,
        metamethods = metamethods,
    }
end

--- create constructor of new metamodule
--- @param modname string
--- @param moddecl table
--- @return function constructor
local function new(modname, moddecl, ...)
    -- verify modname
    if modname ~= nil and not is.moduleName(modname) then
        errorf('module name must be the following pattern string: %q',
               is.PAT_MODNAME)
    end
    -- prepend package-name
    local regname = modname
    local pkg = pkgname()
    if not pkg then
        if not modname then
            errorf('module name must not be nil')
        end
    elseif modname then
        regname = pkg .. '.' .. modname
    else
        regname = pkg
    end

    -- verify moddecl
    if type(moddecl) ~= 'table' then
        errorf('module declaration must be table')
    end

    -- prevent duplication
    if REGISTRY[regname] then
        if pkg then
            errorf('module name %q already defined in package %q',
                   modname or pkg, pkg)
        end
        errorf('module name %q already defined', modname)
    end

    -- inspect module declaration table
    local decl = inspect(regname, moddecl)

    -- embed another modules
    decl.embeds, decl.moduleMethods = embedModules(decl, ...)
    -- register to registry
    decl.vars._PACKAGE = pkg
    decl.vars._NAME = regname
    local newfn, err = register(regname, decl)
    if err then
        errorf('failed to register %q: %s', regname, err)
    end

    -- seal the declaration table to prevent misuse
    seal(moddecl)

    return newfn
end

--- dump registry table
--- @return string
local function dumpRegstiry()
    return dump(REGISTRY)
end

return {
    dump = dumpRegstiry,
    new = setmetatable({}, {
        __metatable = 1,
        __newindex = function(_, k)
            errorf('attempt to assign to a readonly property: %q', k)
        end,
        --- wrapper function to create a new metamodule
        -- usage: metamodule.<modname>([moddecl, [embed_module, ...]])
        __index = function(_, modname)
            return function(...)
                return new(modname, ...)
            end
        end,
        __call = function(_, ...)
            return new(nil, ...)
        end,
    }),
}
