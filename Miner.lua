if not turtle then
    error("Turtle required!")
end

local Miner = {}

Miner.__index = Miner

--- new Miner constructor
-- @param aware Aware: Aware instance
-- @return Miner
function Miner.new(aware)
    local self = setmetatable({}, Miner)
    local utils = require("utils")

    self.aware = aware

    -- table to return the opposite direction
    self.invert = {
        ["forward"] = "back",
        ["back"] = "forward",
        ["up"] = "down",
        ["down"] = "up"
    }

    -- blocks to throw out when out of space
    self.trash = utils.minerTrash

    -- blocks to ignore when vein mining
    self.ignore = utils.minerIgnore

    -- table containing valid storage block n
    self.validStorage = utils.minerStorage

    -- save the axis for which the turtle uses for forward/backward and lateral movements
    if not self.aware.state.axis then
        -- if facing 1 (-z) or 3 (z)
        -- if facing 2 (x) or 4 (-x)

        local isNorthSouth = self.aware.state.home.f == 1 or self.aware.state.home.f == 3

        self.aware.state.axis = {
            trunk = isNorthSouth and 'z' or 'x',
            branch = isNorthSouth and 'x' or 'z',
        }

        self.aware:saveState(self.aware.state)
    end

    return self
end

--- Attack with the turtle in a particular direction
-- @param d string: nil, forward, up, or down
-- @return boolean
function Miner:attack(d)
    if not d or d == "forward" then
        return turtle.attack()
    elseif d == "up" then
        return turtle.attackUp()
    elseif d == "down" then
        return turtle.attackDown()
    end

    return false
end

--- Drop items in a particular direction
-- @param d string: nil, forward, up, or down
-- @param c number: number of items to drop
-- @return boolean
function Miner:drop(d, c)
    if not d or d == "forward" then
        return turtle.drop(c)
    elseif d == "up" then
        return turtle.dropUp(c)
    elseif d == "down" then
        return turtle.dropDown(c)
    end

    return false
end

--- Detect with the turtle in a particular direction
-- @param d string: nil, forward, up, or down
-- @return boolean
function Miner:detect(d)
    if not d or d == "forward" then
        return turtle.detect()
    elseif d == "up" then
        return turtle.detectUp()
    elseif d == "down" then
        return turtle.detectDown()
    end

    return false
end

--- Inspect with the turtle in a particular direction
-- @param d string: nil, forward, up, or down
-- @return boolean
function Miner:inspect(d)
    if not d or d == "forward" then
        return turtle.inspect()
    elseif d == "up" then
        return turtle.inspectUp()
    elseif d == "down" then
        return turtle.inspectDown()
    end

    return false
end

--- Dig with the turtle in a particular direction
-- @param d string: nil, up, or down
-- @return boolean
function Miner:dig(d)
    if not d or d == "forward" then
        return turtle.dig()
    elseif d == "up" then
        return turtle.digUp()
    elseif d == "down" then
        return turtle.digDown()
    end

    return false
end

--- Turn the turtle left or right
-- @param d string: left, right
-- @return boolean
function Miner:turn(d)
    if d == "left" then
        return self.aware:turnLeft()
    elseif d == "right" then
        return self.aware:turnRight()
    end

    return false
end

--- Turn the turtle to a particular direction, either a 1-4 value or an x,-x,y,-y,z,-z value
-- @param n number, string: direction 1234, or x,-x,z,-z
-- @param c boolean: should be interpreted as cardinal directions?
-- @return boolean
function Miner:turnTo(n, c)
    return self.aware:turnTo(n, c)
end

--- Turn the turtle around 180 degrees
-- @return boolean
function Miner:turnAround()
    for i = 1, 2 do
        local res = self:turn("right")

        if not res then
            return false
        end
    end

    return true
end

--- Private method to move the turtle one block in any direction
-- @param d nil, string: direction
-- @return boolean
function Miner:_m(d)
    if not d then
        d = "forward"
    end

    return self.aware[d](self.aware, 1, true)
end

--- Public method to move the turtle one block in any direction. If invert is true, the turtle will move the opposite direction
-- @param d string: the direction the turtle should move
-- @param invert boolean: Flag telling the move the turtle in the inverse direction
-- @return boolean
function Miner:move(d, invert)
    if not d then
        d = "forward"
    end

    if invert then
        d = self.invert[d]
    end

    local moved = false

    while true do
        -- attempt to move the turtle
        moved = self:_m(d)

        -- if the turtle moved, return true
        if moved then
            break
        end

        -- if the turtle didnt move because of fuel, return false
        if turtle.getFuelLevel() == 0 then
            return false
        end

        -- if the direction is back, we need to turn around to detect
        if d == "back" then
            self:turnAround()
        end

        -- if the turtle didnt move because of a block, return false
        local detectResult = self:detect(d == "back" and "forward" or d)

        -- turn the turtle back around
        if d == "back" then
            self:turnAround()
        end

        -- if there is a block in front, that's why it didnt move, return false this is normal
        if detectResult then
            return false
        end

        -- finally, if the turtle didnt move, but he has fuel, and there is no block in his way, some entity is blocking him, so we must smash it
        while true do
            -- if the direction is back, we need to turn around to detect
            if d == "back" then
                self:turnAround()
            end

            local attackResult = self:attack(d == "back" and "forward" or d)

            -- turn the turtle back around
            if d == "back" then
                self:turnAround()
            end

            if not attackResult then
                break
            else
                print("attacked")
            end
        end
    end

    return moved
end

--- Private method to make the turtle place a block in a particular direction
-- @param d string, nil: direction
-- @return boolean
function Miner:_p(d)
    if not d or d == "forward" then
        return turtle.place()
    elseif d == "up" then
        return turtle.placeUp()
    elseif d == "down" then
        return turtle.placeDown()
    end
end

--- Private method to make the turtle place a specific block, by name, from its inventory
-- @param n string: name of block
-- @param d nil, string: direction
-- @return boolean
function Miner:_pb(n, d)
    if not n then
        error("missing required name param")
    end
    if not d then
        d = "forward"
    end

    if not self:detect(d) then
        local slot = turtle.getSelectedSlot()

        for i = 1, 16 do
            if turtle.getItemCount(i) > 0 then
                if turtle.getItemDetail(i).name == n then
                    turtle.select(i)
                    local result = self:_p(d)
                    turtle.select(slot)

                    return result
                end
            end
        end
    end

    return false
end

--- Helper method to make the turtle place cobble in a particular direction
-- @param d string, nil: direction
-- @return boolean
function Miner:placeCobble(d)
    return self:_pb("minecraft:cobblestone", d)
end

--- Helper method to make the turtle place a torch in a particular direction
-- @param d nil, string: direction
-- @return boolean
function Miner:placeTorch(d)
    return self:_pb("minecraft:torch", d)
end

--- Get a table of slots which are empty in the turtle's inventory
-- @return table: table of empty slots
function Miner:getEmptySlots()
    local t = {}

    for i = 1, 16 do
        if turtle.getItemCount(i) == 0 then
            table.insert(t, i)
        end
    end

    return t
end

--- Make the turtle drop any items considered to be trash
-- @return boolean
function Miner:dropTrash()
    local slot = turtle.getSelectedSlot()

    for i = 1, 16 do
        local item = turtle.getItemDetail(i)

        if item and self.trash[item.name] then
            if not turtle.select(i) then
                return false
            end
            if not self:drop("forward", item.count) then
                return false
            end
        end
    end

    return turtle.select(slot)
end

--- Refuel the turtle with any fuel item from its inventory, except torches
-- @return boolean
function Miner:useFuel()
    local slot = turtle.getSelectedSlot()

    for i = 1, 16 do
        if not turtle.select(i) then
            return false
        end

        if turtle.refuel(0) then
            if turtle.getItemDetail(i).name ~= "minecraft:torch" then
                turtle.refuel(turtle.getItemCount())
            end
        end
    end

    return turtle.select(slot)
end

--- Make the turtle unload its entire inventory to the block at a particular direction
-- @param d string,nil: direction
-- @return boolean
function Miner:unload(d)
    if not d then
        d = "forward"
    end

    -- if there is no block in the direction we are unloading, error out
    if not self:detect(d) then
        error("I have nowhere to put these items!")
    end

    -- get the details of the block we are supposed to unload into
    local _, details = self:inspect(d)

    -- if the item i'm supposed to be unloading into is not a storage item, wtf are you even doing
    if not self:isStorageItem(details) and not details.tags["forge:chests"] then
        error("Cannot deposit items into " .. details.name)
    end

    -- cache the slot we already have selected
    local slot = turtle.getSelectedSlot()

    for i = 1, 16 do
        local item = turtle.getItemDetail(i)

        if item and (item.name ~= "minecraft:torch" and item.name ~= "computercraft:wireless_modem_advanced") then
            if not turtle.select(i) then
                return false
            end

            if not self:drop(d, item.count) then
                return false
            end
        end
    end

    return turtle.select(slot)
end

--- Helper method to check whether or not the turtle is at its home position
-- @return boolean
function Miner:isHome()
    return (self.aware.state.pos.x == self.aware.state.home.x and self.aware.state.pos.z == self.aware.state.home.z and self.aware.state.y == self.aware.state.home.y and self.aware.state.pos.f == self.aware.state.home.f)
end

--- Make the turtle go to its home position, following a particular axis order
-- @param order, string: the order of axis to move
-- @return boolean
function Miner:goHome(order)
    return self.aware:moveTo(self.aware.state.home, true, order)
end

--- Determine if an item details is a valid storage item
function Miner:isStorageItem(item)
    if not item then
        return false
    end

    -- iterate through the keys and values of the table, which are block names, and block tags
    for k, v in pairs(self.validStorage) do
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

--- Return a slot in the turtle that contains a block that acts as portable storage, such as a shulker box, or immersive engineering crate
-- @return boolean
function Miner:selectStorageItem()
    for i = 1, 16 do
        local item = turtle.getItemDetail(i, true)

        if self:isStorageItem(item) then
            turtle.select(i)

            return true
        end
    end

    return false
end

--- Consolidate partial stacks of items to save inventory space
function Miner:compact()
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

--- Make the turtle return to home to unload its inventory, and move back to its previous position
-- @return boolean
function Miner:pitStop()
    local loc = self.aware.state.pos

    self.aware.state.pos.temp = { x = loc.x, y = loc.y, z = loc.z, f = loc.f }

    -- if has some onboard portable chest-like item, try to use that
    -- places down the storage item
    -- unloads inventory into the storage item (self:unload())
    -- digs digs the block back up and carries on
    if self:selectStorageItem() then
        local done = false

        for i = 1, 4 do
            if self:detect() then
                self:turn("right")
            else
                self:_p()
                self:unload()
                self:dig()

                done = true
                break
            end
        end

        -- if there were no empty blocks on any side, check above and below
        -- we are just looking for a place to put the storage block so we can unload into it
        if not done then
            if not self:detect("up") then
                self:_p("up")
                self:unload("up")
                self:dig("up")

                done = true
            elseif not self:detect("down") then
                self:_p("down")
                self:unload("down")
                self:dig("down")

                done = true
            end
        end

        -- if we somehow did not have an empty space on any side, go home, and error because something broke
        if not done then
            self:goHome(self.aware.state.axis.branch .. self.aware.state.axis.trunk .. "y")
            error("I thought I had storage, but I couldn't find it.")
        end
    else
        -- go home
        if not self:goHome(self.aware.state.axis.branch .. self.aware.state.axis.trunk .. "y") then
            return false
        end

        -- turn to front
        if not self:turnTo(1) then
            return false
        end

        -- unload into chest, default placement is above turtle
        if not self:unload("up") then
            return false
        end
    end

    -- return to loc in moving axis in reverse
    if not self.aware:moveTo(self.aware.state.pos.temp, true, "y" .. self.aware.state.axis.trunk .. self.aware.state.axis.branch) then
        return false
    end

    -- unset temp loc
    self.aware.state.pos.temp = nil

    return true
end

--- Check for non ignored blocks in all blocks around the turtle.
--- If blocks are found follow those blocks and repeat the checking,
--- until no more blocks are found, then retrace steps back to where it started
-- @param string direction: which direction the turtle moved into this block
-- @return boolean
function Miner:recursiveDig(dir)
    --- check if a block should be mined or not
    --
    -- @param d string: direction
    --
    -- @return boolean
    local function check(d)
        if self:detect(d) then
            local result, block = self:inspect(d)
            if result and not self.ignore[block.name] then
                return true
            end
        end

        return false
    end

    --- helper function to dig blocks recursively in a direction
    --
    -- @param d string: direction
    local function dig(d)
        self:dig(d)
        self:move(d)
        self:recursiveDig(d)
        self:move(d, true) -- moves the inverse
    end

    --------------------------------- begin recursive checking ---------------------------------

    local positions = { "forward", "left", "right", "up", "down", "back" }

    -- remove the inverse of forward, up, or down, because
    -- we dont need to check the direction we came from
    if dir == "forward" or dir == "up" or dir == "down" then
        local indexToRemove

        for key, v in pairs(positions) do
            if v == self.invert[dir] then
                indexToRemove = key
                break
            end
        end

        positions[indexToRemove] = nil
    end

    -- loop over the remaining directions and handle accordingly
    for _, v in pairs(positions) do
        dir = v

        -- turn to direction
        if v == "left" then
            self:turn("left")
        elseif v == "right" then
            self:turn("right")
        elseif v == "back" then
            self:turnAround()
        end

        -- for both and right, we just check forward
        -- because we turn to face that direction
        if v == "left" or v == "right" or v == "back" then
            dir = "forward"
        end

        if check(dir) then
            dig(dir)
        end

        -- turn back to front
        if v == "left" then
            self:turn("right")
        elseif v == "right" then
            self:turn("left")
        elseif v == "back" then
            self:turnAround()
        end
    end

    return true
end

--- Helper function to branch vein mine
-- @param data table
function Miner:veinMine(data)
    local f = data.f -- facing direction
    local l = data.l -- length
    local b = data.b -- block number
    local t = data.t -- place torches?
    local c = data.c -- place cobble?
    local a = data.a -- action

    -- default the block number to 1
    if not b then
        b = 1
    end

    self:setCurrentAction(a)

    if self.aware.state.pos.f ~= f then
        self:turnTo(f)
    end

    -- for each block length of the branch...
    for i = b, l do
        self.aware:setCheckpoint()
        self:setCurrentBlock(i)

        local shouldPlaceTorch = t and (i == 2 or (i - 2) % 14 == 0)

        -- for each block in the current position (bottom and top because it is a 2-tall tunnel)
        for j = 1, 2 do
            -- refuel if necessary
            if turtle.getFuelLevel() < 100 then
                self:useFuel()
            end

            -- consolidate partial stacks where possible
            if #self:getEmptySlots() <= 1 then
                self:compact()
            end

            -- check if there are empty slots, dump any useless blocks to save space
            if #self:getEmptySlots() <= 1 then
                self:dropTrash()
            end

            -- if after dump useless blocks the empty space is 1, go unload
            if #self:getEmptySlots() <= 1 then
                self:pitStop()
            end

            -- recursive dig the blocks on this level
            self:recursiveDig("forward")

            if j == 1 then
                if self.aware.state.pos.y == self.aware.state.yLevel then
                    if c then
                        self:placeCobble("down")
                    end

                    self:move("up")
                else
                    self:move("down")

                    if c then
                        self:placeCobble("down")
                    end
                end
            end
        end

        if i < l then
            self:move("forward")
        end

        if shouldPlaceTorch then
            if self.aware.state.pos.y == self.aware.state.yLevel then
                self:turnAround()
                self:placeTorch()
                self:turnAround()
            end
        end
    end

    -- branches with even numbered blocks will end on the bottom, and we want to end on the top
    if self.aware.state.pos.y == self.aware.state.yLevel and a == "vein" then
        self:move("up")
    end

    self.aware:setCheckpoint()

    self:setCurrentBlock() -- reset the current block
    self:setCurrentAction() -- reset the current action
end

--- ===============================================================
--- STATE MANAGEMENT METHODS
--- ===============================================================

--- TODO
function Miner:setCurrentAction(a)
    self.aware.state.currentAction = a

    self.aware:saveState(self.aware.state)
end

--- TODO
function Miner:setCurrentBranch(n)
    self.aware.state.currentBranch = n

    self.aware:saveState(self.aware.state)
end

--- TODO
function Miner:setCurrentBlock(n)
    self.aware.state.currentBlock = n

    self.aware:saveState(self.aware.state)
end

return Miner