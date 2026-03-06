require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local eval = require('metamodule.eval')

function testcase.eval_with_env()
    -- test that eval compiles src and applies the given environment
    local fn, err = eval('return hello', {
        hello = 'world',
    })
    assert.is_nil(err)
    assert.is_function(fn)
    assert.equal(fn(), 'world')
end

function testcase.eval_without_env()
    -- test that eval works when no environment is provided (uses default globals)
    local fn, err = eval('return type("hello")')
    assert.is_nil(err)
    assert.is_function(fn)
    assert.equal(fn(), 'string')
end

function testcase.eval_syntax_error()
    -- test that a syntax error returns nil + error string
    local fn, err = eval('retur hello')
    assert.is_nil(fn)
    assert.is_string(err)
end
