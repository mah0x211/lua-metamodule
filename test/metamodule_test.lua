require('luacov')
local testcase = require('testcase')

function testcase.before_all()
    -- install hello and world module
    local f = assert(io.popen(table.concat({
        'cd testdata',
        'luarocks make hello-scm-1.rockspec',
        'luarocks make world-scm-1.rockspec',
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
        hello = require('hello')
    end))
    local h = hello.new()
    assert.equal(h._NAME, 'hello')
    assert.equal(h._PACKAGE, 'hello')
    assert.match(h, '^hello: ', false)
    assert.equal(h.val, 'hello-value')

    -- test that return a module name
    assert.equal(h:instanceof(), 'hello')

    -- test that call method
    assert.equal(h:say(), 'hello hello-value')
end

function testcase.world_based_on_hello()
    -- test that check module is declared with metamodule
    local hello
    local world
    assert(pcall(function()
        world = require('world')
        hello = require('hello')
    end))
    local w = world.new()
    assert.equal(w._NAME, 'world.World')
    assert.equal(w._PACKAGE, 'world')
    assert.match(w, '^world%.World: ', false)
    assert.equal(w.val, 'world-value')
    local h = hello.new()
    assert.equal(w.say, h.say)

    -- test that contains a base module methods
    assert.equal(w.hello, {
        init = h.init,
        say = h.say,
        instanceof = h.instanceof,
    })

    -- test that return a module name
    assert.equal(w:instanceof(), 'world.World')

    -- test that call method
    assert.equal(w:say(), 'world.World world-value')

    -- test that call method
    assert.equal(w:say2(), 'world.World say2 world-value')
end

function testcase.instanceof()
    local hello
    local world
    assert(pcall(function()
        world = require('world')
        hello = require('hello')
    end))
    local w = world.new()
    local h = hello.new()
    local metamodule = require('metamodule')

    -- test that return true
    assert.is_true(metamodule.instanceof(h, 'hello'))
    assert.is_true(metamodule.instanceof(w, 'world.World'))
    assert.is_true(metamodule.instanceof(w, 'hello'))

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
        require('world')
        require('hello')
    end))
    local metamodule = require('metamodule')

    -- test that return string
    assert.is_string(metamodule.dump())
end
