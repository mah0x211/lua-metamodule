local World = {
    val = 'world-value',
}

function World:say2()
    return table.concat({
        self._NAME,
        'say2',
        self.val,
    }, ' ')
end

return {
    new = require('metamodule').new.World(World, 'metamodule.test.hello'),
}

