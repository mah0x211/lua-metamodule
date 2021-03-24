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
local error = error
local sub = string.sub
local find = string.find
local type = type
--- constants
local INF_POS = math.huge
local INF_NEG = -INF_POS

--- isFinite
-- @param arg
-- @return ok
local function isFinite(arg)
    return type(arg) == 'number' and (arg < INF_POS and arg > INF_NEG)
end

--- split string
---@param str string
---@param sep string
---@param limit number
---@return table
local function split(str, sep, limit)
    if type(str) ~= 'string' then
        error('str must be string', 2)
    elseif type(sep) ~= 'string' then
        error('sep must be string', 2)
    elseif limit ~= nil and not isFinite(limit) then
        error('limit must be finite-integer', 2)
    elseif str == '' then
        -- empty-string
        return {''}
    end

    if sep == '' then
        local arr = {}
        for i = 1, #str do
            if limit and i > limit then
                arr[i] = sub(str, i)
                return arr
            end

            arr[i] = sub(str, i, i)
        end

        return arr
    end

    local arr = {}
    local idx = 1
    local pos = 0
    local head, tail = find(str, sep, pos, true)
    while head do
        if limit and idx > limit then
            break
        end
        arr[idx] = sub(str, pos, head - 1)
        idx = idx + 1
        pos = tail + 1
        head, tail = find(str, sep, pos, true)
    end

    if pos <= #str then
        arr[idx] = sub(str, pos)
    end

    return arr
end

return split
