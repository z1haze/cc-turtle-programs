local utils = {}

function utils.deepCopy(t)
    local clone = {}

    for k, v in pairs(t) do
        -- for all keys...
        if type(v) == "table" then
            -- if value is a table
            clone[k] = deepCopy(v) -- recursively copy that too
        else
            clone[k] = v -- just copy the value.
        end
    end

    return clone
end

utils.minerKeep = {
    ["minecraft:torch"] = true,
    ["computercraft:wireless_modem_advanced"] = true
}

utils.minerTrash = {}

utils.minerIgnore = utils.deepCopy(utils.minerTrash)
utils.minerIgnore["minecraft:torch"] = true

utils.minerStorage = {
    name = {
        "immersiveengineering:crate"
    },

    tags = {
        ["minecraft:shulker_boxes"] = true,
        ["forge:shulker_boxes"] = true
    }
}

return utils