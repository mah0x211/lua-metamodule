std = 'min'
include_files = {
    '*.lua',
    'lib/*.lua',
}
files['*_spec.lua'] = {
    std = '+busted'
}
files['lib/*_spec.lua'] = {
    std = '+busted'
}
