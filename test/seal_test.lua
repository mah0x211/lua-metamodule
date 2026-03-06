require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local seal = require('metamodule.seal')

function testcase.seal_sets_newindex_guard()
    local tbl = {}
    seal(tbl)
    assert.is_function((getmetatable(tbl) or {}).__newindex)
end

function testcase.seal_raises_on_write()
    local tbl = {}
    seal(tbl)
    local err = assert.throws(function()
        tbl.foo = 'bar'
    end)
    assert.match(err,
                 'cannot change module definition after module declaration',
                 false)
end

function testcase.seal_raises_on_non_table()
    for _, v in ipairs({
        'str',
        1,
        3.14,
        true,
        false,
        function()
        end,
        coroutine.create(function()
        end),
    }) do
        local err = assert.throws(function()
            seal(v)
        end)
        assert.match(err, 'tbl must be table', false)
    end
end
