require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local mm = require('metamodule')
local eval = require('metamodule.eval')

-- Load the REGISTRY snapshot as a plain Lua table via dump().
-- Functions are serialized as address strings ("function: 0x...").
-- Uses metamodule.eval for Lua 5.1 / 5.2+ compatibility
-- (Lua 5.1 load() does not accept strings; loadstring() is needed).
local function load_registry()
    local f, err = eval('return ' .. mm.dump())
    assert(not err, err)
    return f()
end

-- Returns true if v is a serialized-function string.
local function is_fn_str(v)
    return type(v) == 'string' and v:find('^function: ') ~= nil
end

-- =============================================================================
-- vars
-- =============================================================================

function testcase.vars_name_and_package_standalone()
    -- standalone: _PACKAGE is nil, _NAME is the ModuleName
    mm.new.VarsStandalone({})
    local reg = load_registry()
    assert.equal(reg.VarsStandalone.vars._NAME, 'VarsStandalone')
    assert.is_nil(reg.VarsStandalone.vars._PACKAGE)
end

function testcase.vars_user_values_are_copied()
    -- user-defined vars (non-function values) must appear in registry vars
    local decl = {
        num = 42,
        str = 'hello',
        flag = true,
        tbl = {
            x = 1,
        },
    }
    mm.new.VarsUserValues(decl)
    local reg = load_registry()
    local v = reg.VarsUserValues.vars
    assert.equal(v.num, 42)
    assert.equal(v.str, 'hello')
    assert.equal(v.flag, true)
    assert.equal(v.tbl.x, 1)
end

function testcase.vars_string_field_is_not_in_registry_vars()
    -- _STRING is an IDENT_FIELD and must never appear in registry vars
    mm.new.VarsNoString({})
    local reg = load_registry()
    assert.is_nil(reg.VarsNoString.vars._STRING)
end

function testcase.vars_function_fields_are_not_in_vars()
    -- functions go into methods, not vars
    local decl = {}
    function decl.myfn(_)
    end
    mm.new.VarsFnNotInVars(decl)
    local reg = load_registry()
    assert.is_nil(reg.VarsFnNotInVars.vars.myfn)
end

-- =============================================================================
-- methods
-- =============================================================================

function testcase.methods_user_defined_method_is_registered()
    local decl = {}
    function decl.greet(_)
        return 'hi'
    end
    mm.new.MethodsUserDefined(decl)
    local reg = load_registry()
    assert.is_true(is_fn_str(reg.MethodsUserDefined.methods.greet))
end

function testcase.methods_instanceof_auto_added()
    -- instanceof is always injected by register()
    mm.new.MethodsInstanceof({})
    local reg = load_registry()
    assert.is_true(is_fn_str(reg.MethodsInstanceof.methods.instanceof))
end

function testcase.methods_default_init_auto_added_when_not_defined()
    -- when decl has no init, DEFAULT_INITIALIZER is registered
    mm.new.MethodsDefaultInit({})
    local reg = load_registry()
    assert.is_true(is_fn_str(reg.MethodsDefaultInit.methods.init))
end

function testcase.methods_custom_init_is_preserved()
    -- user-defined init must not be replaced by DEFAULT_INITIALIZER
    local decl = {}
    function decl.init(self, v)
        self.v = v
        return self
    end
    local newM = mm.new.MethodsCustomInit(decl)
    local obj = newM(99)
    assert.equal(obj.v, 99)
    local reg = load_registry()
    assert.is_true(is_fn_str(reg.MethodsCustomInit.methods.init))
end

-- =============================================================================
-- metamethods
-- =============================================================================

function testcase.metamethods_default_tostring_auto_added()
    -- when __tostring is not defined, DEFAULT_TOSTRING is registered
    mm.new.MetaDefaultTostring({})
    local reg = load_registry()
    assert.is_true(is_fn_str(reg.MetaDefaultTostring.metamethods.__tostring))
end

function testcase.metamethods_custom_tostring_is_preserved()
    -- user-defined __tostring must not be replaced by DEFAULT_TOSTRING
    local decl = {}
    function decl.__tostring(_)
        return 'custom'
    end
    local newM = mm.new.MetaCustomTostring(decl)
    local obj = newM()
    assert.equal(tostring(obj), 'custom')
    local reg = load_registry()
    assert.is_true(is_fn_str(reg.MetaCustomTostring.metamethods.__tostring))
end

function testcase.metamethods_non_function_metamethod_registered()
    -- __mode and __name are string metamethods and must appear in metamethods
    mm.new.MetaNonFn({
        __mode = 'v',
        __name = 'MyType',
    })
    local reg = load_registry()
    assert.equal(reg.MetaNonFn.metamethods.__mode, 'v')
    assert.equal(reg.MetaNonFn.metamethods.__name, 'MyType')
end

function testcase.metamethods_function_metamethods_registered()
    local decl = {}
    function decl.__tostring(_)
        return 'x'
    end
    function decl.__call(_)
    end
    function decl.__len(_)
        return 0
    end
    mm.new.MetaFnMethods(decl)
    local reg = load_registry()
    assert.is_true(is_fn_str(reg.MetaFnMethods.metamethods.__tostring))
    assert.is_true(is_fn_str(reg.MetaFnMethods.metamethods.__call))
    assert.is_true(is_fn_str(reg.MetaFnMethods.metamethods.__len))
end

-- =============================================================================
-- embeds structure
-- =============================================================================

function testcase.embeds_empty_when_no_embedding()
    mm.new.EmbedsNone({})
    local reg = load_registry()
    -- embeds table exists but is empty (no sequential or keyed entries)
    local e = reg.EmbedsNone.embeds
    assert.equal(next(e), nil)
end

function testcase.embeds_single_embed_sequential_and_reverse()
    -- embeds must have both [1]="Base" and Base=1
    mm.new.EmbedsBase({})
    mm.new.EmbedsChild({}, 'EmbedsBase')
    local reg = load_registry()
    local e = reg.EmbedsChild.embeds
    assert.equal(e[1], 'EmbedsBase')
    assert.equal(e.EmbedsBase, 1)
end

function testcase.embeds_multiple_embeds_ordering()
    -- multiple embeds: sequential indices and reverse lookup must match
    mm.new.EmbedsMultiA({})
    mm.new.EmbedsMultiB({})
    mm.new.EmbedsMultiC({}, 'EmbedsMultiA', 'EmbedsMultiB')
    local reg = load_registry()
    local e = reg.EmbedsMultiC.embeds
    assert.equal(e[1], 'EmbedsMultiA')
    assert.equal(e[2], 'EmbedsMultiB')
    assert.equal(e.EmbedsMultiA, 1)
    assert.equal(e.EmbedsMultiB, 2)
end

-- =============================================================================
-- BFS flattening of methods
-- =============================================================================

function testcase.methods_embedded_methods_are_flattened()
    -- child's methods table must contain base's methods (BFS flattened)
    local base = {}
    function base.base_method(_)
    end
    mm.new.FlatBase(base)

    local child = {}
    function child.child_method(_)
    end
    mm.new.FlatChild(child, 'FlatBase')

    local reg = load_registry()
    assert.is_true(is_fn_str(reg.FlatChild.methods.child_method))
    assert.is_true(is_fn_str(reg.FlatChild.methods.base_method))
end

function testcase.methods_two_level_embed_fully_flattened()
    -- grandchild's methods must include grandparent's methods (2-level BFS)
    local grand = {}
    function grand.grand_method(_)
    end
    mm.new.FlatGrand(grand)

    local parent = {}
    function parent.parent_method(_)
    end
    mm.new.FlatParent(parent, 'FlatGrand')

    local child = {}
    function child.child_method2(_)
    end
    mm.new.FlatChild2(child, 'FlatParent')

    local reg = load_registry()
    local m = reg.FlatChild2.methods
    assert.is_true(is_fn_str(m.child_method2))
    assert.is_true(is_fn_str(m.parent_method))
    assert.is_true(is_fn_str(m.grand_method))
end

-- =============================================================================
-- override priority: child > embedded
-- =============================================================================

function testcase.methods_child_overrides_embedded_method()
    -- when child and base define the same method name,
    -- child's version must be in the registry methods
    local base = {}
    function base.shared(_)
        return 'base'
    end
    mm.new.PrioBase(base)

    local child = {}
    function child.shared(_)
        return 'child'
    end
    local newChild = mm.new.PrioChild(child, 'PrioBase')

    -- runtime verification: instance calls child's version
    local obj = newChild()
    assert.equal(obj:shared(), 'child')

    -- registry: child's fn pointer must differ from base's
    local reg = load_registry()
    assert.not_equal(reg.PrioChild.methods.shared, reg.PrioBase.methods.shared)
end

function testcase.vars_child_overrides_embedded_var()
    -- child var takes priority over embedded module var of same name
    local base = {
        color = 'red',
    }
    mm.new.VarPrioBase(base)

    local child = {
        color = 'blue',
    }
    local newChild = mm.new.VarPrioChild(child, 'VarPrioBase')

    local obj = newChild()
    assert.equal(obj.color, 'blue')
end

-- =============================================================================
-- embedded module method table on instance (obj["EmbedName"])
-- =============================================================================

function testcase.instance_has_embedded_method_table_by_name()
    -- obj["BaseName"] must be a table containing the base's methods
    local base = {}
    function base.hello(_)
        return 'hello from base'
    end
    mm.new.InstBase(base)

    local child = {}
    local newChild = mm.new.InstChild(child, 'InstBase')

    local obj = newChild()
    assert.is_table(obj['InstBase'])
    assert.is_function(obj['InstBase'].hello)
end

function testcase.instance_embedded_method_called_with_child_self()
    -- calling base method via obj["Base"].method(obj) uses child's self
    local base = {}
    function base.get_name(self)
        return self._NAME
    end
    mm.new.InstSelfBase(base)

    local child = {}
    local newChild = mm.new.InstSelfChild(child, 'InstSelfBase')

    local obj = newChild()
    -- direct call uses child's method (flat)
    assert.equal(obj:get_name(), 'InstSelfChild')
    -- explicit base call still uses child's self
    assert.equal(obj['InstSelfBase'].get_name(obj), 'InstSelfChild')
end

-- =============================================================================
-- __index as function
-- =============================================================================

function testcase.index_fn_constructor_works()
    -- when __index is a function, dynamic metatable generation must succeed
    -- and instances must route unknown keys through __index
    local decl = {}
    function decl.__index(_, key)
        return key .. '_dynamic'
    end
    local newM = mm.new.IndexFn(decl)
    local obj = newM()
    assert.equal(obj:instanceof(), 'IndexFn')
    assert.equal(obj.unknown_key, 'unknown_key_dynamic')
end

function testcase.index_fn_own_methods_take_priority_over_index_fn()
    -- own methods must be returned before falling through to __index
    local decl = {}
    function decl.my_method(_)
        return 'own'
    end
    function decl.__index(_, key)
        return key .. '_dynamic'
    end
    local newM = mm.new.IndexFnPrio(decl)
    local obj = newM()
    assert.equal(obj:my_method(), 'own')
    assert.equal(obj.other_key, 'other_key_dynamic')
end
