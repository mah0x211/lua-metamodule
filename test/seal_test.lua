require('luacov')
local testcase = require('testcase')
local seal = require('metamodule.seal')

function testcase.seal()
    -- test that sets the metatable that contains __newindex field to table
    local tbl = {}
    seal(tbl)
    assert.is_function((getmetatable(tbl) or {}).__newindex)

    -- test that throws an error when attempt to add new field to sealed table
    local err = assert.throws(function()
        tbl.foo = 'bar'
    end)
    assert.match(err,
                 'cannot change module definition after module declaration',
                 false)

    -- test that throws an error if argument is not table
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
        err = assert.throws(function()
            seal(v)
        end)
        assert.match(err, 'tbl must be table', false)
    end
end
