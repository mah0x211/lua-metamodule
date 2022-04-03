package = 'hello'
version = 'scm-1'
source = {
    url = 'git+https://example.com/lua-hello.git'
}
dependencies = {
    'lua >= 5.1',
}
build = {
    type = 'builtin',
    modules = {
        hello = 'hello.lua',
    }
}
