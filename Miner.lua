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

    self.fuelValues = {
        ["minecraft:coal"] = 80,
        ["minecraft:charcoal"] = 80,
        ["minecraft:lava_bucket"] = 1000,
        ["minecraft_coal_block"] = 800,
        ["minecraft_charcoal_block"] = 800,
        ["immersiveengineering:coke"] = 1600,
        ["immersiveengineering:coal_coke"] = 160,
    }

    self.keepItems = {
        ["minecraft:torch"] = true,
        ["computercraft:wireless_modem_advanced"] = true
    }

    self.resourceMessages = {
        action = {
            ["vein"] = "Branch Mining",
            ["trunk"] = "Trunk Mining",
            ["back"] = "Completing Branch",
            ["descend"] = "Descending",
            ["home"] = "Heading Home",
            ["pitstop"] = "Pitstop",
            ["checkpoint"] = "Checkpoint",
            ["done"] = "Finished"
        }
    }

    self.fuelReserve = 1000

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
    end

    if not self.aware.state.blocksTraveled then
        self.aware.state.blocksTraveled = 0
    end

    if not self.aware.state.oresMined then
        self.aware.state.oresMined = 0
    end

    self.aware:saveState(self.aware.state)

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
-- @param targetFuelLevel number: target fuel level for the turtle
-- @return boolean
function Miner:useFuel(targetFuelLevel)
    -- cache the currently selected slot, so we can put it back when we're done
    local slot = turtle.getSelectedSlot()

    -- loop through the entire inventory
    for i = 1, 16 do
        if not turtle.select(i) then
            return false
        end

        -- if we've reached our fuel target, we can quit
        if turtle.getFuelLevel() >= targetFuelLevel then
            break
        end

        local itemDetail = turtle.getItemDetail(i)

        -- if the item is able to be used as fuel and is not at torch (we want to keep those)
        if turtle.refuel(0) and itemDetail.name ~= "minecraft:torch" then
            local fuelPer

            -- try to get a better estimate on what the fuel is
            if self.fuelValues[itemDetail.name] then
                fuelPer = self.fuelValues[itemDetail.name]
            else
                fuelPer = 80
            end

            -- get the number of items we can eat for fuel
            local count = turtle.getItemCount()

            -- reduce the number of items to consume until we are at or below the target fuel level
            while (turtle.getFuelLevel() + (count * fuelPer)) > targetFuelLevel and count > 1 do
                count = count - 1
            end

            -- burn that shit
            turtle.refuel(count)
        end
    end

    return turtle.select(slot)
end

--- Return a table containing inventory slots with fuel items, and the total value of fuel in each slot, as well as the grand total value of all fuel slots added together
-- @return table, number
--function Miner:getFuelInventory()
--    local slot = turtle.getSelectedSlot()
--    local slotsWithFuel = {}
--    local totalFuelInventory = 0
--
--    for i = 1, 16 do
--        local itemDetail = turtle.getItemDetail(i)
--
--        if itemDetail then
--            turtle.select(i)
--
--            if turtle.refuel(0) then
--                local count = itemDetail.count
--                local fuelPer = self.fuelValues[itemDetail.name]
--
--                if fuelPer then
--                    slotsWithFuel[tostring(i)] = count * fuelPer
--                end
--            end
--        end
--    end
--
--    for _, v in pairs(slotsWithFuel) do
--        totalFuelInventory = totalFuelInventory + v
--    end
--
--    -- reselect previously selected inventory slot
--    turtle.select(slot)
--
--    return slotsWithFuel, totalFuelInventory
--end

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

    -- an aggregate total of fuel that we choose to keep in the turtle inventory as a fuel reserve
    -- this is needed so once we accumulate enough to meet the fuel reserve, we can dump the rest
    local fuelKept = 0

    for i = 1, 16 do
        local item = turtle.getItemDetail(i)

        if item and not self.keepItems[item.name] then
            local amountToDrop

            -- if the item can be used as fuel, we need to do some extra processing
            -- because we want to keep _some_ fuel in the inventory as a reserve
            if self.fuelValues[item.name] then
                local amountToKeep = 0

                for j = 1, item.count do
                    -- if we've already kept enough fuel we
                    if fuelKept >= self.fuelReserve then
                        break
                    end

                    amountToKeep = j
                    fuelKept = fuelKept + self.fuelValues[item.name]
                end

                amountToDrop = item.count - amountToKeep
            else
                amountToDrop = item.count
            end

            turtle.select(i)

            if not self:drop(d, amountToDrop) then
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
    local lastAction = self.aware.state.currentAction

    self:setCurrentAction("pitstop")

    local loc = self.aware.state.pos

    self.aware.state.pos.temp = { x = loc.x, y = loc.y, z = loc.z, f = loc.f }

    -- has the turtle been successfully unloaded?
    local unloadSuccess = false

    -- if has some onboard portable chest-like item, try to use that
    -- places down the storage item
    -- unloads inventory into the storage item (self:unload())
    -- digs digs the block back up and carries on
    if self:selectStorageItem() then
        local canPlace = false
        local placeDir

        -- find a spot to place the chest
        for _ = 1, 4 do
            if not self:detect() then
                canPlace = true
                break
            end

            self:turn("right")
        end

        -- if we still can't place, check above and below
        if not canPlace then
            if not self:detect("up") then
                canPlace = true
                placeDir = "up"
            elseif not self:detect("down") then
                canPlace = true
                placeDir = "down"
            end
        end

        -- place the chest, unload into the chest, dig the chest back up
        if canPlace then
            self:_p(placeDir)

            unloadSuccess = self:unload(placeDir)

            self:dig(placeDir)
        end
    end

    -- if the done flag is false, that means we did not unload everything into an onboard storage item, so we need to go home and unload
    if not unloadSuccess then
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

    self:setCurrentAction(lastAction)

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
                self.aware.state.oresMined = self.aware.state.oresMined + 1

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
            if turtle.getFuelLevel() < 1000 then
                self:useFuel(1000)
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

--- ===============================================================
--- GUI METHODS
--- ===============================================================

function Miner:clearLine()
    local x, y = term.getCursorPos()

    term.setCursorPos(1, y)
    write("|                                     |")
    term.setCursorPos(x, y)
end

function Miner:guiStats()
    local action = self.aware.state.currentAction
    local actionResourceMsg = action and self.resourceMessages.action[action] or "Awaiting Work"
    local actionMessage

    -- write the current action line
    term.setCursorPos(3, 2)
    self:clearLine()
    write("Current Action: " .. actionResourceMsg .. "...")

    if action == "descend" then
        actionMessage = "Descending to Y-Level " .. self.aware.state.yLevel
    elseif action == "vein" then
        actionMessage = "On Branch " .. self.aware.state.currentBranch .. "/" .. self.aware.state.branchCount

        if self.aware.state.currentBlock then
            actionMessage = actionMessage .. ", Block " .. self.aware.state.currentBlock .. "/" .. self.aware.state.branchLength
        end
    elseif action == "back" then
        actionMessage = "Moving back to the trunk"
    elseif action == "trunk" then
        actionMessage = "Mining trunk to branch " .. self.aware.state.currentBranch + 1
    elseif action == "pitstop" then
        actionMessage = "Shitter's full, gotta dump"
    elseif action == "checkpoint" then
        actionMessage = "Moving to saved checkpoint"
    elseif action == "home" then
        actionMessage = "Finishing mining, heading home"
    elseif action == "done" then
        actionMessage = "Operation Complete. Mined " .. self.aware.state.branchCount .. "B " .. self.aware.state.branchLength .. "L"
    end

    if actionMessage then
        term.setCursorPos(3, 4)
        self:clearLine()
        write(actionMessage)
    end

    -- total blocks traveled
    term.setCursorPos(3, 6)
    self:clearLine()
    write("Distance Traveled : " .. self.aware.state.blocksTraveled)

    -- total ores mined
    term.setCursorPos(3, 7)
    self:clearLine()
    write("Ores Mined        : " .. self.aware.state.oresMined)

    -- current fuel level
    term.setCursorPos(3, 8)
    self:clearLine()
    write("Fuel Level        : " .. turtle.getFuelLevel())
end

function Miner:guiFrame()
    term.clear()

    -- side borders
    for i = 1, 13 do
        term.setCursorPos(1, i)
        write("|")
        term.setCursorPos(39, i)
        write("|")
    end

    -- top border
    term.setCursorPos(1, 1)
    write("O-------------------------------------O")

    -- middle line
    term.setCursorPos(1, 5)
    write("O-------------------------------------O")

    -- bottom border
    term.setCursorPos(1, 13)
    write("O-------------------------------------O")
end

return Miner