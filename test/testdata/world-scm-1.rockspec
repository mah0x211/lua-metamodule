package = 'world'
version = 'scm-1'
source = {
    url = 'git+https://example.com/lua-world.git',
}
dependencies = {
    'lua >= 5.1',
}
build = {
    type = 'builtin',
    modules = {
        world = 'init.lua',
    }
}
