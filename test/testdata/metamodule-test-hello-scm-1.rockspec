package = 'metamodule-test-hello'
version = 'scm-1'
source = {
    url = 'git+https://example.com/lua-metamodule-test-hello.git',
}
dependencies = {
    'lua >= 5.1',
}
build = {
    type = 'builtin',
    modules = {
        ['metamodule.test.hello'] = 'hello.lua',
    },
}
