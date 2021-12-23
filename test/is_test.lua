require('luacov')
local assert = require('assertex')
local testcase = require('testcase')
local is = require('metamodule.is')

function testcase.isModuleName()
    -- test that return true
    for _, v in ipairs({
        'Foo',
        'FooBar01',
    }) do
        assert.is_true(is.moduleName(v))
    end

    -- test that return false
    for _, v in ipairs({
        'foo',
        'fooBar01',
        true,
        false,
        {},
        1,
        function()
        end,
    }) do
        assert.is_false(is.moduleName(v))
    end
end

function testcase.isMetamethodName()
    -- test that return true
    for _, v in ipairs({
        '__tostring',
        '__newindex',
    }) do
        assert.is_true(is.metamethodName(v))
    end

    -- test that return false
    for _, v in ipairs({
        'Foo',
        '_Foo',
        '__Foo',
        '__foo01',
        '__foo_bar',
        true,
        false,
        {},
        1,
        function()
        end,
    }) do
        assert.is_false(is.metamethodName(v))
    end
end

