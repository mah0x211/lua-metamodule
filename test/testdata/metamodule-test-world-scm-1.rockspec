package = 'metamodule-test-world'
version = 'scm-1'
source = {
    url = 'git+https://example.com/lua-metamodule-test-world.git',
}
dependencies = {
    'lua >= 5.1',
}
build = {
    type = 'builtin',
    modules = {
        ['metamodule.test.world'] = 'init.lua',
    },
}
