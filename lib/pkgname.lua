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
local ipairs = ipairs
local string = require('stringex')
local match = string.match
local gsub = string.gsub
local sub = string.sub
local split = string.split
local trim_space = string.trim_space
local sort = table.sort
local getinfo = debug.getinfo
local normalize = require('metamodule.normalize')

--- constants
local PKG_PATH = (function()
    local list = split(package.path, ';', true)
    local res = {}

    sort(list)
    for _, path in ipairs(list) do
        path = trim_space(path)
        if #path > 0 then
            path = gsub(path, '%.', '%%.')
            path = gsub(path, '%-', '%%-')
            path = gsub(path, '%?', '(.+)')
            res[#res + 1] = '^' .. path
        end
    end
    res[#res + 1] = '(.+)%.lua'

    return res
end)()

--- converts pathname in package.path to module names
---@param s string
---@return string|nil
local function pathname2modname(s)
    for _, pattern in ipairs(PKG_PATH) do
        local cap = match(s, pattern)
        if cap then
            -- remove '/init' suffix
            cap = gsub(cap, '/init$', '')
            return gsub(cap, '/', '.')
        end
    end
end

--- get the package name from the filepath.
--- the package name is the same as the modname argument of the require function.
--- returns nil if called by a function other than the require function.
--- @return string|nil
local function pkgname()
    local lv = 2
    local prev

    -- traverse call stack
    repeat
        local info = getinfo(lv, 'nS')

        if info then
            if info.what == 'C' and info.name == 'require' then
                -- found source of 'require' function
                local src = normalize(sub(prev.source, 2))
                return pathname2modname(src)
            end
            -- check next level
            prev = info
            lv = lv + 1
        end
    until info == nil

    return nil
end

return pkgname
