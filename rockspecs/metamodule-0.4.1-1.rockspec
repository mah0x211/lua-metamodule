package = "metamodule"
version = "0.4.1-1"
source = {
    url = "git+https://github.com/mah0x211/lua-metamodule.git",
    tag = "v0.4.1",
}
description = {
    summary = "simple oop module for lua",
    homepage = "https://github.com/mah0x211/lua-metamodule",
    license = "MIT/X11",
    maintainer = "Masatoshi Fukunaga",
}
dependencies = {
    "lua >= 5.1",
    "dump ~> 0.1",
    "string-trim >= 0.2.0",
    "string-split >= 0.3.0",
}
build = {
    type = "builtin",
    modules = {
        metamodule = "metamodule.lua",
        ["metamodule.deepcopy"] = "lib/deepcopy.lua",
        ["metamodule.eval"] = "lib/eval.lua",
        ["metamodule.is"] = "lib/is.lua",
        ["metamodule.normalize"] = "lib/normalize.lua",
        ["metamodule.seal"] = "lib/seal.lua",
    },
}
