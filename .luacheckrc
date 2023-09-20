std = 'max'
include_files = {
    'metamodule.lua',
    'lib/*.lua',
    'test/*.lua',
}
ignore = {
    'assert',
    -- Value assigned to a local variable is unused
    '311',
}
