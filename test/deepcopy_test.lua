require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local deepcopy = require('metamodule.deepcopy')

function testcase.returns_non_table_values_unchanged()
    -- non-table values are returned as-is without copying
    for _, v in ipairs({
        nil,
        true,
        false,
        0,
        3.14,
        'hello',
        function()
        end,
    }) do
        local result, err = deepcopy(v, 'key', {})
        assert.equal(result, v)
        assert.is_nil(err)
    end
end

function testcase.copies_flat_table()
    local src = {
        a = 1,
        b = 'hello',
        c = true,
    }
    local result, err = deepcopy(src, 'root', {})
    assert.is_nil(err)
    -- content is preserved
    assert.equal(result, src)
    -- the copy is a distinct table object
    assert.is_true(result ~= src)
end

function testcase.copies_nested_table()
    local src = {
        level1 = {
            level2 = {
                value = 42,
            },
        },
    }
    local result, err = deepcopy(src, 'root', {})
    assert.is_nil(err)
    assert.equal(result.level1.level2.value, 42)
    -- each nested table is a distinct copy
    assert.is_true(result.level1 ~= src.level1)
    assert.is_true(result.level1.level2 ~= src.level1.level2)
end

function testcase.copy_does_not_share_references()
    local src = {
        nested = {
            x = 1,
        },
    }
    local result, err = deepcopy(src, 'root', {})
    assert.is_nil(err)
    -- mutating the copy must not affect the original
    result.nested.x = 99
    assert.equal(src.nested.x, 1)
end

function testcase.error_on_direct_circular_reference()
    -- a table that directly references itself
    local t = {}
    t.self = t
    local result, err = deepcopy(t, 'root', {})
    assert.is_nil(result)
    assert.is_string(err)
    assert.match(err, 'circularly referenced')
end

function testcase.error_on_indirect_circular_reference()
    -- a → b → a: deepcopy must detect the cycle and return an error
    local a = {}
    local b = {
        ref = a,
    }
    a.ref = b
    local result, err = deepcopy(a, 'root', {})
    assert.is_nil(result)
    assert.is_string(err)
    assert.match(err, 'circularly referenced')
end

function testcase.error_propagates_from_nested_copy()
    -- a nested value that causes a circular error must bubble up
    local inner = {}
    inner.loop = inner
    local outer = {
        child = inner,
    }
    local result, err = deepcopy(outer, 'root', {})
    assert.is_nil(result)
    assert.is_string(err)
    assert.match(err, 'circularly referenced')
end
