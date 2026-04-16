if not turtle then
    error("Turtle required!")
end

local TurtleUtils = {}

TurtleUtils.invert = {
    ["forward"] = "back",
    ["back"] = "forward",
    ["up"] = "down",
    ["down"] = "up"
}

--- Drop items in a particular direction
TurtleUtils.drop = function(direction, count)
    if not direction or direction == "forward" then
        return turtle.drop(count)
    elseif direction == "up" then
        return turtle.dropUp(count)
    elseif direction == "down" then
        return turtle.dropDown(count)
    end

    return false
end

--- Consolidate partial stacks of items to save inventory space
TurtleUtils.compact = function()
    local incompleteStacks = {}

    -- compact stacks
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)

        if item then
            local name = item.name
            local existingSlot = incompleteStacks[name]

            if existingSlot then
                turtle.select(i)
                turtle.transferTo(existingSlot)

                if turtle.getItemCount() > 0 then
                    incompleteStacks[name] = i
                end
            else
                incompleteStacks[name] = i
            end
        end
    end
end

--- Make the turtle drop any items considered to be trash
TurtleUtils.dropTrash = function(trash)
    local slot = turtle.getSelectedSlot()

    for i = 1, 16 do
        local item = turtle.getItemDetail(i)

        if item then
            if trash[item.name] then
                if not turtle.select(i) then
                    return false
                end
                if not TurtleUtils.drop("forward", item.count) then
                    return false
                end
            end
        end
    end

    return turtle.select(slot)
end

--- Get a table of slots which are empty in the turtle's inventory
TurtleUtils.getEmptySlots = function()
    local t = {}

    for i = 1, 16 do
        if turtle.getItemCount(i) == 0 then
            table.insert(t, i)
        end
    end

    return t
end

--- Make the turtle unload its entire inventory to the block at a particular direction
TurtleUtils.unload = function(direction, possibleStorages)
    possibleStorages = possibleStorages or {}
    direction = direction or "forward"

    -- cache the slot we already have selected
    local slot = turtle.getSelectedSlot()

    -- an aggregate total of fuel that we choose to keep in the turtle inventory as a fuel reserve
    -- this is needed so once we accumulate enough to meet the fuel reserve, we can dump the rest
    local fuelKept = 0

    for i = 1, 16 do
        local item = turtle.getItemDetail(i)

        if item then
            turtle.select(i)

            if not TurtleUtils.drop(direction, item.count) then
                return false
            end
        end
    end

    return turtle.select(slot)
end

--- Detect a block in front, above, or below
TurtleUtils.detect = function(direction)
    if not direction or direction == "forward" then
        return turtle.detect()
    elseif direction == "up" then
        return turtle.detectUp()
    elseif direction == "down" then
        return turtle.detectDown()
    end

    return false
end

--- Inspect the details about a block in front, above, or below
TurtleUtils.inspect = function(direction)
    if not direction or direction == "forward" then
        return turtle.inspect()
    elseif direction == "up" then
        return turtle.inspectUp()
    elseif direction == "down" then
        return turtle.inspectDown()
    end

    return false
end

--- Dig a block in front, above, or below
TurtleUtils.dig = function(direction)
    if not direction or direction == "forward" then
        return turtle.dig()
    elseif direction == "up" then
        return turtle.digUp()
    elseif direction == "down" then
        return turtle.digDown()
    end

    return false
end

--- Attack in front, above, or below
TurtleUtils.attack = function(direction)
    if not direction or direction == "forward" then
        return turtle.attack()
    elseif direction == "up" then
        return turtle.attackUp()
    elseif direction == "down" then
        return turtle.attackDown()
    end

    return false
end

--- Determine if an item details is a valid storage item
TurtleUtils.isStorageItem = function(item, possibleStorages)
    if not item then
        return false
    end

    -- iterate through the keys and values of the table, which are block names, and block tags
    for k, v in pairs(possibleStorages) do
        -- iterate over the keys and values of each table which are number,string or string,boolean
        for kk, _ in pairs(v) do
            -- check against valid names
            if k == "name" and item.name == v[kk] then
                return true
            end

            -- check against valid tags
            if k == "tags" and item.tags[kk] then
                return true
            end
        end
    end

    return false
end

return TurtleUtils