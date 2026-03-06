require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local normalize = require('metamodule.normalize')

function testcase.bare_relative_path()
    assert.equal(normalize('a/b/c'), 'a/b/c')
end

function testcase.absolute_path_preserved()
    assert.equal(normalize('/a/b/c'), '/a/b/c')
end

function testcase.dot_prefix_path_preserved()
    assert.equal(normalize('./a/b'), './a/b')
end

function testcase.double_slashes_collapsed()
    assert.equal(normalize('a//b///c'), 'a/b/c')
    assert.equal(normalize('//a/b'), '/a/b')
    assert.equal(normalize('.//a'), './a')
end

function testcase.dot_segments_are_removed()
    assert.equal(normalize('a/./b'), 'a/b')
    assert.equal(normalize('./a/./b'), './a/b')
    assert.equal(normalize('/a/./b'), '/a/b')
end

function testcase.dotdot_removes_preceding_segment()
    assert.equal(normalize('a/b/../c'), 'a/c')
    assert.equal(normalize('/a/b/../c'), '/a/c')
end

function testcase.dotdot_at_root_level_is_silently_dropped()
    -- when there is no preceding segment, '..' is consumed without error
    assert.equal(normalize('../a'), './a')
    assert.equal(normalize('a/b/../../c'), 'c')
end

function testcase.absolute_path_root_only()
    assert.equal(normalize('/'), '/')
end

function testcase.empty_string()
    assert.equal(normalize(''), '')
end

function testcase.complex_path()
    assert.equal(normalize('/a/b/../c/./d'), '/a/c/d')
    assert.equal(normalize('./a/b/../../c'), './c')
end
