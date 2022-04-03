local metamodule = require('metamodule')

local Hello = {
    val = 'hello-value',
}

function Hello:say()
    return table.concat({
        self._NAME,
        self.val,
    }, ' ')
end

return {
    new = metamodule.new(Hello),
}
