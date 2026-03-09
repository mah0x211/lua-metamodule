require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local mm = require('metamodule')

local function run(cmd)
    local f = assert(io.popen(cmd))
    f:read('*a')
    f:close()
end

function testcase.before_all()
    -- install the hello and world test modules as real luarocks packages.
    -- these modules are located under a path containing 'metamodule', so
    -- get_pkgname() uses the require-argument (getlocal) fallback to detect
    -- their package names rather than the file-path based pathname2modname.
    run('cd testdata && luarocks make metamodule-test-hello-scm-1.rockspec 2>&1')
    run('cd testdata && luarocks make metamodule-test-world-scm-1.rockspec 2>&1')
end

function testcase.after_all()
    run('luarocks remove metamodule-test-hello 2>&1')
    run('luarocks remove metamodule-test-world 2>&1')
end

-- =============================================================================
-- Integration tests: modules loaded via require with correct package names
-- =============================================================================

function testcase.hello_module()
    -- module declared as metamodule.new(Hello) (non-TCO __call form).
    -- package name detected from require argument via getlocal.
    local hello = require('metamodule.test.hello')
    local h = hello.new()

    assert.equal(h._NAME, 'metamodule.test.hello')
    assert.equal(h._PACKAGE, 'metamodule.test.hello')
    assert.match(h, '^metamodule%.test%.hello: ', false)
    assert.equal(h.val, 'hello-value')

    -- instanceof() with no args returns the registered name
    assert.equal(h:instanceof(), 'metamodule.test.hello')

    -- regular method
    assert.equal(h:say(), 'metamodule.test.hello hello-value')

    -- custom __index: unknown keys are handled by the metamethod
    assert.equal(h:foo(), tostring(h) .. ': __index foo')
end

function testcase.world_module()
    -- world is declared with new.World(...) (__index named form) and embeds hello.
    -- package name detected via require argument since source path has 'metamodule'.
    local hello = require('metamodule.test.hello')
    local world = require('metamodule.test.world')
    local h = hello.new()
    local w = world.new()

    -- _NAME includes the 'World' suffix added by the named-module form
    assert.equal(w._NAME, 'metamodule.test.world.World')
    assert.equal(w._PACKAGE, 'metamodule.test.world')
    assert.match(w, '^metamodule%.test%.world%.World: ', false)
    assert.equal(w.val, 'world-value')

    -- say() is inherited from hello (same function reference)
    assert.equal(w.say, h.say)

    -- embedded module methods are also accessible by registered name
    assert.equal(w['metamodule.test.hello'], {
        init = h.init,
        say = h.say,
        instanceof = h.instanceof,
    })

    assert.equal(w:instanceof(), 'metamodule.test.world.World')
    assert.equal(w:say(), 'metamodule.test.world.World world-value')
    assert.equal(w:say2(), 'metamodule.test.world.World say2 world-value')

    -- __index metamethod inherited from hello
    assert.equal(w:bar(), tostring(w) .. ': __index bar')
end

function testcase.pkgname_tco_call_form()
    -- when `return metamodule.new(decl)` is the last statement in a module
    -- file, the module's Lua frame is eliminated by tail-call optimisation.
    -- get_pkgname() must recover the package name from require's argument
    -- via debug.getlocal instead of the (missing) source-file path.
    local modname = 'test.mm.tco'
    package.preload[modname] = function()
        local M = {
            val = 'tco',
        }
        function M:greet()
            return self._NAME .. ' ' .. self.val
        end
        return mm.new(M) -- tail call: module frame eliminated by TCO
    end
    local new_m = require(modname)
    local obj = new_m()

    assert.equal(obj._NAME, modname)
    assert.equal(obj._PACKAGE, modname)
    assert.equal(obj:greet(), modname .. ' tco')

    assert.is_true(mm.instanceof(obj, modname))
end

function testcase.pkgname_named_module_in_require()
    -- when mm.new.ModName(decl) is used inside a require'd module, the source
    -- path is filtered (contains 'metamodule') so get_pkgname falls back to
    -- getlocal, correctly resolving pkgname to the require argument.
    local modname = 'test.mm.namedmod'
    package.preload[modname] = function()
        local M = {}
        return {
            new = mm.new.NamedMod(M),
        }
    end
    local mod = require(modname)
    local obj = mod.new()

    assert.equal(obj._NAME, modname .. '.NamedMod')
    assert.equal(obj._PACKAGE, modname)
end

-- =============================================================================
-- metamodule.new validation errors
-- =============================================================================

function testcase.new_error_invalid_module_name()
    -- module names must be PascalCase: ^[A-Z][a-zA-Z0-9]*$
    local err = assert.throws(function()
        mm.new.fooBar({}) -- starts with lowercase
    end)
    assert.match(err, 'module name must be the following pattern string')
end

function testcase.new_error_no_module_name()
    -- calling the __call form outside require: pkgname=nil, modname=nil → error
    local err = assert.throws(function()
        mm.new({})
    end)
    assert.match(err, 'module name must not be nil')
end

function testcase.new_error_non_table_decl()
    local err = assert.throws(function()
        mm.new.NewNonTableDecl('not-a-table')
    end)
    assert.match(err, 'module declaration must be table')
end

function testcase.new_error_already_registered_no_pkgname()
    -- second registration of the same name without a package must fail
    mm.new.AlreadyReg({})
    local err = assert.throws(function()
        mm.new.AlreadyReg({})
    end)
    assert.match(err, 'already defined')
end

function testcase.new_error_already_registered_with_pkgname()
    -- when the module is loaded from require and is already registered,
    -- the error message includes the package name
    local modname = 'test.mm.dupreg'
    package.preload[modname] = function()
        local M = {}
        return {
            new = mm.new.DupPkg(M),
        }
    end
    require(modname)
    package.loaded[modname] = nil -- clear cache to force re-execution
    local err = assert.throws(function()
        require(modname)
    end)
    assert.match(err, 'already defined in package')
end

function testcase.new_table_is_readonly()
    -- metamodule.new is a protected proxy table; assignment must error
    local err = assert.throws(function()
        mm.new.foo = 'bar'
    end)
    assert.match(err, 'attempt to assign to a readonly property')
end

-- =============================================================================
-- inspect() validation errors
-- =============================================================================

function testcase.inspect_error_non_string_key()
    local err = assert.throws(function()
        mm.new.InspNonStr({
            [1] = 'value',
        })
    end)
    assert.match(err, 'field name must be string')
end

function testcase.inspect_error_reserved_fields()
    -- constructor, instanceof, and identity fields (_NAME/_PACKAGE/_STRING) are reserved
    for i, field in ipairs({
        'constructor',
        'instanceof',
        '_NAME',
        '_PACKAGE',
        '_STRING',
    }) do
        local decl = {}
        decl[field] = 'value'
        local err = assert.throws(function()
            mm.new['InspReserved' .. i](decl)
        end)
        assert.match(err, 'reserved field')
    end
end

function testcase.inspect_error_metamethod_must_be_function()
    -- metamethods listed with type 'function' in METAFIELD_TYPES must be functions
    local err = assert.throws(function()
        mm.new.InspMetaWrongType({
            __tostring = 'not-a-function',
        })
    end)
    assert.match(err, 'must be function')
end

function testcase.inspect_metamethod_string_value()
    -- __mode and __name are allowed to be strings, not functions
    local new_m = mm.new.InspMetaStrVal({
        __mode = 'k',
    })
    assert.is_function(new_m)
end

function testcase.inspect_error_metamethod_circular_ref()
    -- a string-type metamethod containing a circular reference must error
    local t = {}
    t.loop = t
    local err = assert.throws(function()
        mm.new.InspMetaCircular({
            __name = t, -- __name allows non-function, deepcopy detects the cycle
        })
    end)
    assert.match(err, 'circularly referenced')
end

function testcase.inspect_error_init_not_function()
    local err = assert.throws(function()
        mm.new.InspInitNotFn({
            init = 'not-a-function',
        })
    end)
    assert.match(err, 'field "init" must be function')
end

function testcase.inspect_error_var_circular_ref()
    -- a non-function field (var) that contains a circular table must error
    local t = {}
    t.self = t
    local err = assert.throws(function()
        mm.new.InspVarCircular({
            data = t,
        })
    end)
    assert.match(err, 'circularly referenced')
end

-- =============================================================================
-- embedModules() errors
-- =============================================================================

function testcase.embed_error_module_not_found()
    -- pkg is a valid lowercase package name but require fails (not installed)
    local err = assert.throws(function()
        mm.new.EmbedNotFound({}, 'nonexistent.NotAMod')
    end)
    assert.match(err, 'cannot embed module')
end

function testcase.embed_error_circular_embedding()
    -- simulate circular embedding via package.preload:
    -- 'test.mm.circa' embeds 'test.mm.circb', 'test.mm.circb' tries to embed 'test.mm.circa'
    -- use mm.new({}, ...) (no modname) so regname == pkgname == require path
    package.preload['test.mm.circa'] = function()
        mm.new({}, 'test.mm.circb')
    end
    package.preload['test.mm.circb'] = function()
        mm.new({}, 'test.mm.circa')
    end

    local err = assert.throws(function()
        mm.new.EmbedCircTrigger({}, 'test.mm.circa')
    end)
    assert.match(err, 'circular embedding detected')

    package.preload['test.mm.circa'] = nil
    package.preload['test.mm.circb'] = nil
    package.loaded['test.mm.circa']  = nil
    package.loaded['test.mm.circb']  = nil
end

function testcase.embed_error_not_a_package_name()
    -- a PascalCase-only name is not a valid package name, so loadModule() returns
    -- 'invalid module name' without attempting require()
    local err = assert.throws(function()
        mm.new.EmbedBadPkg({}, 'UnregisteredModule')
    end)
    assert.match(err, 'cannot embed module')
end

function testcase.embed_error_package_loaded_but_not_metamodule()
    -- require succeeds but the package does not call metamodule.new,
    -- so the module name is absent from the registry → 'not a metamodule'
    package.preload['test.mm.notmm'] = function()
        return {} -- plain table, not a metamodule
    end
    local err = assert.throws(function()
        mm.new.EmbedNotMM({}, 'test.mm.notmm')
    end)
    assert.match(err, 'cannot embed module')
end

function testcase.embed_error_same_module_twice()
    -- embedding the same module in one declaration is not allowed
    mm.new.EmbedDupBase({})
    local err = assert.throws(function()
        mm.new.EmbedDupChild({}, 'EmbedDupBase', 'EmbedDupBase')
    end)
    assert.match(err, 'cannot embed module')
    assert.match(err, 'twice')
end

function testcase.register_error_already_registered_during_embed()
    -- Proves register()'s REGISTRY guard: an embedded module's require() can
    -- register the same regname as a side-effect between new()'s pre-check and
    -- register().  An extra helper frame keeps require at lv=5 (outside
    -- get_pkgname()'s lv=3..4 range), so both calls produce regname='RaceTarget'.
    package.preload['test.mm.sideeffect'] = function()
        -- register_side_effect() adds one extra frame so get_pkgname() returns nil
        local function register_side_effect()
            mm.new.RaceTarget({})
        end
        register_side_effect()
        mm.new({}) -- pkgname='test.mm.sideeffect' (require visible at lv=4)
    end

    local err = assert.throws(function()
        -- pkgname=nil (not in require context) → regname='RaceTarget';
        -- embedModules loads 'test.mm.sideeffect' which registers 'RaceTarget' first
        mm.new.RaceTarget({}, 'test.mm.sideeffect')
    end)

    package.preload['test.mm.sideeffect'] = nil
    package.loaded['test.mm.sideeffect'] = nil

    assert.match(err, 'already registered')
end

function testcase.register_custom_index_function()
    -- when __index is defined as a function, a dynamic metatable wrapper is
    -- generated so that named methods are checked before calling __index
    local new_m = mm.new.RegIndexFn({
        __index = function(_, key)
            return 'dynamic:' .. key
        end,
    })
    local obj = new_m()
    -- unknown keys fall through to the custom __index function
    assert.equal(obj.unknown_key, 'dynamic:unknown_key')
    -- named methods (instanceof, init) are still accessible via the wrapper
    assert.is_function(obj.instanceof)
end

function testcase.register_error_index_invalid_type()
    -- inspect() also checks that __index is a function (METAFIELD_TYPES enforces this)
    local err = assert.throws(function()
        mm.new.RegIndexInvalid({
            __index = 42,
        })
    end)
    assert.match(err, 'must be function')
end

-- =============================================================================
-- Instance construction and fields
-- =============================================================================

function testcase.instance_has_required_fields()
    -- every instance has _NAME and _PACKAGE set automatically;
    -- _STRING is computed lazily on the first tostring() call
    local new_m = mm.new.InstFields({})
    local obj = new_m()

    assert.equal(obj._NAME, 'InstFields')
    assert.is_nil(obj._PACKAGE) -- no package when called outside require
    assert.is_nil(obj._STRING) -- not yet computed (lazy)
    local str = tostring(obj)
    assert.match(str, '^InstFields: 0x', false)
    assert.equal(obj._STRING, str) -- now cached
end

function testcase.instance_default_init_returns_self()
    -- without a custom init, the constructor returns the new instance
    local new_m = mm.new.InstDefaultInit({
        val = 'hello',
    })
    local obj = new_m()

    assert.equal(obj.val, 'hello')
    assert.equal(obj._NAME, 'InstDefaultInit')
end

function testcase.instance_custom_init_receives_args()
    -- init receives all constructor arguments and can mutate self
    local new_m = mm.new.InstCustomInit({
        init = function(self, x, y)
            self.sum = x + y
            return self
        end,
    })
    local obj = new_m(10, 32)

    assert.equal(obj.sum, 42)
end

function testcase.instance_init_return_value_propagated()
    -- if init returns nil, the constructor also returns nil
    local new_m = mm.new.InstInitNil({
        init = function()
            return nil
        end,
    })

    assert.is_nil(new_m())
end

function testcase.instance_default_tostring()
    -- the default __tostring returns '<ModuleName>: <address>'
    local new_m = mm.new.InstDefToStr({})
    local obj = new_m()

    assert.match(tostring(obj), '^InstDefToStr: 0x', false)
end

function testcase.instance_custom_tostring()
    local new_m = mm.new.InstCustToStr({
        __tostring = function(self)
            return 'custom:' .. self._NAME
        end,
    })

    assert.equal(tostring(new_m()), 'custom:InstCustToStr')
end

-- =============================================================================
-- Embedding: method and var inheritance
-- =============================================================================

function testcase.embed_transitive_chain()
    -- three-level chain: Top embeds Middle, Middle embeds GrandBase.
    -- during register() the while-loop walks transitive embeds one level at a
    -- time; GrandBase's methods must appear in Top's index table.
    local GrandBase = {}
    function GrandBase.grand_method(_)
        return 'grand'
    end
    mm.new.TransGrandBase(GrandBase)

    local Middle = {}
    function Middle.middle_method(_)
        return 'middle'
    end
    mm.new.TransMiddle(Middle, 'TransGrandBase')

    local Top = {}
    function Top.top_method(_)
        return 'top'
    end
    local new_top = mm.new.TransTop(Top, 'TransMiddle')
    local obj = new_top()

    -- all three levels of methods are reachable
    assert.equal(obj:grand_method(), 'grand')
    assert.equal(obj:middle_method(), 'middle')
    assert.equal(obj:top_method(), 'top')

    -- transitive embedded module methods accessible by name
    assert.equal(obj['TransGrandBase'].grand_method, GrandBase.grand_method)
end

function testcase.pkgname_from_file_path()
    -- Tests the pathname2modname branch of get_pkgname(): when the module source
    -- path does not contain 'metamodule', the package name is derived from the
    -- file path rather than from require's argument.
    local tmpdir = (os.getenv('TMPDIR') or '/tmp'):gsub('/+$', '')
    local modfile = tmpdir .. '/mmtest_pathmod.lua'

    -- write a module file outside any path containing 'metamodule'
    local f = assert(io.open(modfile, 'w'))
    f:write([[
local mm = require('metamodule')
local M = {}
return { new = mm.new(M) }
]])
    f:close()

    -- temporarily extend package.path so require can find the file;
    -- require must be called directly (not via pcall/xpcall) so that the
    -- require C frame retains its name in debug info on Lua 5.1, which
    -- get_pkgname() depends on to identify the require frame.
    local orig_path = package.path
    package.path = tmpdir .. '/?.lua;' .. orig_path
    local mod = require('mmtest_pathmod')
    package.path = orig_path
    os.remove(modfile)
    package.loaded['mmtest_pathmod'] = nil

    -- _NAME is derived from the file path via pathname2modname;
    -- the exact value depends on TMPDIR but must contain the module stem
    local obj = mod.new()
    assert.match(obj._NAME, 'mmtest_pathmod')
end

function testcase.embed_inherits_vars_and_methods()
    local Base = {
        base_val = 'from-base',
    }
    function Base:base_method()
        return self._NAME .. ':base'
    end
    mm.new.EmbedBase(Base)

    local Child = {
        child_val = 'from-child',
    }
    function Child:child_method()
        return self._NAME .. ':child'
    end
    local new_child = mm.new.EmbedChild(Child, 'EmbedBase')
    local obj = new_child()

    -- vars from both modules are present
    assert.equal(obj.base_val, 'from-base')
    assert.equal(obj.child_val, 'from-child')

    -- both sets of methods are callable
    assert.equal(obj:base_method(), 'EmbedChild:base')
    assert.equal(obj:child_method(), 'EmbedChild:child')

    -- embedded module's methods are also accessible via obj['EmbedBase']
    assert.equal(obj['EmbedBase'].base_method, Base.base_method)
end

function testcase.embed_child_field_takes_priority_over_base()
    -- when child and base define the same field, the child's version wins
    local BaseOvr = {
        shared_val = 'base-val',
    }
    function BaseOvr.shared_method(_)
        return 'base-method'
    end
    mm.new.EmbedOvrBase(BaseOvr)

    local ChildOvr = {
        shared_val = 'child-val',
    }
    function ChildOvr.shared_method(_)
        return 'child-method'
    end
    local new_child = mm.new.EmbedOvrChild(ChildOvr, 'EmbedOvrBase')
    local obj = new_child()

    assert.equal(obj.shared_val, 'child-val')
    assert.equal(obj:shared_method(), 'child-method')

    -- the base method is still reachable via the embedded-module access table,
    -- using dot notation with an explicit self to pass the right receiver.
    -- (colon notation would pass obj['EmbedOvrBase'] as self, not obj itself)
    assert.equal(obj['EmbedOvrBase'].shared_method(obj), 'base-method')
end

-- =============================================================================
-- metamodule.instanceof()
-- =============================================================================

function testcase.instanceof_method_returns_registered_name()
    local new_m = mm.new.InstanceofMethod({})
    local obj = new_m()

    assert.equal(obj:instanceof(), 'InstanceofMethod')
end

function testcase.instanceof_true_for_own_type()
    local new_m = mm.new.InstanceofOwn({})

    assert.is_true(mm.instanceof(new_m(), 'InstanceofOwn'))
end

function testcase.instanceof_true_for_embedded_type()
    mm.new.InstanceofEmbBase({})
    local new_child = mm.new.InstanceofEmbChild({}, 'InstanceofEmbBase')
    local obj = new_child()

    assert.is_true(mm.instanceof(obj, 'InstanceofEmbChild'))
    assert.is_true(mm.instanceof(obj, 'InstanceofEmbBase'))
end

function testcase.instanceof_false_for_unrelated_type()
    local new_m = mm.new.InstanceofFalse({})

    assert.is_false(mm.instanceof(new_m(), 'SomeOtherType'))
end

function testcase.instanceof_false_for_non_metamodule_objects()
    -- plain table without instanceof
    assert.is_false(mm.instanceof({}, 'anything'))
    -- non-table
    assert.is_false(mm.instanceof('str', 'anything'))
    -- table with instanceof function not registered in REGISTRY
    assert.is_false(mm.instanceof({
        instanceof = function()
        end,
    }, 'anything'))
end

function testcase.instanceof_error_name_not_string()
    local err = assert.throws(mm.instanceof, {})
    assert.match(err, 'name must be string')
end

-- =============================================================================
-- metamodule.dump()
-- =============================================================================

function testcase.dump_returns_string()
    assert.is_string(mm.dump())
end

