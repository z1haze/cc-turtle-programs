local utils = {}

local function deepCopy(t)
    local clone = {}

    for k, v in pairs(t) do
        -- for all keys...
        if type(v) == "table" then
            -- if value is a table
            clone[k] = deepCopy(v) -- recursively copy that too
        else
            clone[k] = v           -- just copy the value.
        end
    end

    return clone
end

utils.deepCopy = deepCopy

utils.minerKeep = {
    ["minecraft:torch"] = true,
    ["computercraft:wireless_modem_advanced"] = true
}

utils.minerTrash = {
    ["minecraft:cobblestone"] = true,
    ["minecraft:gravel"] = true,
    ["minecraft:andesite"] = true,
    ["minecraft:granite"] = true,
    ["minecraft:diorite"] = true
}

utils.minerIgnore = utils.deepCopy(utils.minerTrash)
utils.minerIgnore["minecraft:torch"] = true

utils.minerStorage = {
    ["minecraft:chest"] = true,
    ["minecraft:trapped_chest"] = true,
    ["minecraft:shulker_box"] = true,
    ["minecraft:white_shulker_box"] = true,
    ["minecraft:orange_shulker_box"] = true,
    ["minecraft:magenta_shulker_box"] = true,
    ["minecraft:light_blue_shulker_box"] = true,
    ["minecraft:yellow_shulker_box"] = true,
    ["minecraft:lime_shulker_box"] = true,
    ["minecraft:pink_shulker_box"] = true,
    ["minecraft:gray_shulker_box"] = true,
    ["minecraft:silver_shulker_box"] = true,
    ["minecraft:cyan_shulker_box"] = true,
    ["minecraft:purple_shulker_box"] = true,
    ["minecraft:blue_shulker_box"] = true,
    ["minecraft:brown_shulker_box"] = true,
    ["minecraft:green_shulker_box"] = true,
    ["minecraft:red_shulker_box"] = true,
    ["minecraft:black_shulker_box"] = true
}

return utils
