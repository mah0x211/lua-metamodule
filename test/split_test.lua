require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local split = require('metamodule.split')

function testcase.splits_by_single_char_separator()
    local t = split('a.b.c', '.')
    assert.equal(#t, 3)
    assert.equal(t[1], 'a')
    assert.equal(t[2], 'b')
    assert.equal(t[3], 'c')
end

function testcase.splits_by_semicolon()
    -- mirrors the package.path use case
    local t = split('/usr/share/lua/?.lua;/usr/local/?.lua', ';')
    assert.equal(#t, 2)
    assert.equal(t[1], '/usr/share/lua/?.lua')
    assert.equal(t[2], '/usr/local/?.lua')
end

function testcase.splits_by_multi_char_separator()
    local t = split('a::b::c', '::')
    assert.equal(#t, 3)
    assert.equal(t[1], 'a')
    assert.equal(t[2], 'b')
    assert.equal(t[3], 'c')
end

function testcase.no_separator_found_returns_single_element()
    local t = split('abc', '.')
    assert.equal(#t, 1)
    assert.equal(t[1], 'abc')
end

function testcase.empty_string_returns_one_empty_element()
    local t = split('', '.')
    assert.equal(#t, 1)
    assert.equal(t[1], '')
end

function testcase.separator_at_start_produces_leading_empty_element()
    local t = split('.a.b', '.')
    assert.equal(#t, 3)
    assert.equal(t[1], '')
    assert.equal(t[2], 'a')
    assert.equal(t[3], 'b')
end

function testcase.separator_at_end_produces_trailing_empty_element()
    local t = split('a.b.', '.')
    assert.equal(#t, 3)
    assert.equal(t[1], 'a')
    assert.equal(t[2], 'b')
    assert.equal(t[3], '')
end

function testcase.consecutive_separators_produce_empty_elements()
    local t = split('a..b', '.')
    assert.equal(#t, 3)
    assert.equal(t[1], 'a')
    assert.equal(t[2], '')
    assert.equal(t[3], 'b')
end

function testcase.only_separator_produces_two_empty_elements()
    local t = split('.', '.')
    assert.equal(#t, 2)
    assert.equal(t[1], '')
    assert.equal(t[2], '')
end

function testcase.separator_longer_than_string_returns_whole_string()
    local t = split('ab', 'abc')
    assert.equal(#t, 1)
    assert.equal(t[1], 'ab')
end

function testcase.pattern_special_chars_treated_as_literal()
    -- '.' would match any char as a pattern; here it must match only '.'
    local t = split('a%db', '%d')
    assert.equal(#t, 2)
    assert.equal(t[1], 'a')
    assert.equal(t[2], 'b')
end

function testcase.dotted_module_name_split()
    -- mirrors the regname split use case in loadModule
    local t = split('foo.bar.Baz', '.')
    assert.equal(#t, 3)
    assert.equal(t[1], 'foo')
    assert.equal(t[2], 'bar')
    assert.equal(t[3], 'Baz')
end
