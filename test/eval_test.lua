require('luacov')
local testcase = require('testcase')
local eval = require('metamodule.eval')

function testcase.eval()
    local src = 'return hello'
    local env = {
        hello = 'world',
    }

    -- test that create a function from source string
    local fn, err = eval(src, env)
    assert.is_nil(err)
    assert.is_function(fn)

    -- test that return a value from function
    assert.equal(fn(), 'world')

    -- test that return an error if source string is invalid
    fn, err = eval('retur hello')
    assert.is_nil(fn)
    assert.is_string(err)
end
