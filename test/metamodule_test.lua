require('luacov')
local testcase = require('testcase')

function testcase.before_all()
    -- install hello and world module
    local f = assert(io.popen(table.concat({
        'cd testdata',
        'luarocks make metamodule-test-hello-scm-1.rockspec',
        'luarocks make metamodule-test-world-scm-1.rockspec',
    }, ' && ')))
    for line in f:lines() do
        print(line)
    end
    f:close()
end

function testcase.after_all()
    -- install hello and world module
    local f = assert(io.popen(table.concat({
        'cd testdata',
        'luarocks remove metamodule-test-hello',
        'luarocks remove metamodule-test-world',
    }, ' && ')))
    for line in f:lines() do
        print(line)
    end
    f:close()
end

function testcase.hello()
    -- test that check module is declared with metamodule
    local hello
    assert(pcall(function()
        hello = require('metamodule.test.hello')
    end))
    local h = hello.new()
    assert.equal(h._NAME, 'metamodule.test.hello')
    assert.equal(h._PACKAGE, 'metamodule.test.hello')
    assert.match(h, '^metamodule%.test%.hello: ', false)
    assert.equal(h.val, 'hello-value')

    -- test that return a module name
    assert.equal(h:instanceof(), 'metamodule.test.hello')

    -- test that call method
    assert.equal(h:say(), 'metamodule.test.hello hello-value')

    -- test that call __index metamethod
    assert.equal(h:foo(), tostring(h) .. ': __index foo')
end

function testcase.world_based_on_hello()
    -- test that check module is declared with metamodule
    local hello
    local world
    assert(pcall(function()
        world = require('metamodule.test.world')
        hello = require('metamodule.test.hello')
    end))
    local w = world.new()
    assert.equal(w._NAME, 'metamodule.test.world.World')
    assert.equal(w._PACKAGE, 'metamodule.test.world')
    assert.match(w, '^metamodule%.test%.world%.World: ', false)
    assert.equal(w.val, 'world-value')
    local h = hello.new()
    assert.equal(w.say, h.say)

    -- test that contains a base module methods
    assert.equal(w['metamodule.test.hello'], {
        init = h.init,
        say = h.say,
        instanceof = h.instanceof,
    })

    -- test that return a module name
    assert.equal(w:instanceof(), 'metamodule.test.world.World')

    -- test that call method
    assert.equal(w:say(), 'metamodule.test.world.World world-value')

    -- test that call method
    assert.equal(w:say2(), 'metamodule.test.world.World say2 world-value')

    -- test that call __index metamethod
    assert.equal(w:bar(), tostring(w) .. ': __index bar')
end

function testcase.instanceof()
    local hello
    local world
    assert(pcall(function()
        world = require('metamodule.test.world')
        hello = require('metamodule.test.hello')
    end))
    local w = world.new()
    local h = hello.new()
    local metamodule = require('metamodule')

    -- test that return true
    assert.is_true(metamodule.instanceof(h, 'metamodule.test.hello'))
    assert.is_true(metamodule.instanceof(w, 'metamodule.test.world.World'))
    assert.is_true(metamodule.instanceof(w, 'metamodule.test.hello'))

    -- test that return false
    assert.is_false(metamodule.instanceof(h, 'foo'))

    -- test that return false if obj is invalid
    assert.is_false(metamodule.instanceof('foo', 'bar'))
    assert.is_false(metamodule.instanceof({
        instanceof = function()
        end,
    }, 'hello'))

    -- test that throws an error if name is not string
    local err = assert.throws(metamodule.instanceof, {})
    assert.match(err, 'name must be string')
end

function testcase.dump()
    assert(pcall(function()
        require('metamodule.test.world')
        require('metamodule.test.hello')
    end))
    local metamodule = require('metamodule')

    -- test that return string
    assert.is_string(metamodule.dump())
end
