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

utils.minerTrash = {
    ["minecraft:andesite"] = true,
    ["minecraft:blackstone"] = true,
    ["minecraft:chest"] = true,
    ["minecraft:coarse_dirt"] = true,
    ["minecraft:cobblestone"] = true,
    ["minecraft:diorite"] = true,
    ["minecraft:dirt"] = true,
    ["minecraft:glass"] = true,
    ["minecraft:granite"] = true,
    ["minecraft:grass"] = true,
    ["minecraft:grass_block"] = true,
    ["minecraft:gravel"] = true,
    ["minecraft:obsidian"] = true,
    ["minecraft:oak_fence"] = true,
    ["minecraft:oak_log"] = true,
    ["minecraft:oak_leaves"] = true,
    ["minecraft:oak_planks"] = true,
    ["minecraft:sand"] = true,
    ["minecraft:sandstone"] = true,
    ["minecraft:stone"] = true,

    ["chisel:basalt2"] = true,
    ["chisel:marble2"] = true,

    ["quark:basalt"] = true,
    ["quark:cobbedstone"] = true,
    ["quark:deepslate"] = true,
    ["quark:glowcelium"] = true,
    ["quark:jasper"] = true,
    ["quark:limestone"] = true,
    ["quark:marble"] = true,
    ["quark:permafrost"] = true,
    ["quark:root_item"] = true,
    ["quark:slate"] = true,
    ["quark:smooth_basalt"] = true,

    ["create:dark_scoria"] = true,
    ["create:gabbro"] = true,
    ["create:natural_scoria"] = true,
    ["create:scoria"] = true,
    ["create:weathered_limestone"] = true
}

utils.minerIgnore = utils.deepCopy(utils.minerTrash)

utils.minerIgnore["minecraft:bedrock"] = true
utils.minerIgnore["minecraft:torch"] = true

utils.minerIgnore["quark:deepslate"] = true

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