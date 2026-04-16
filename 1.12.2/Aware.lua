if not turtle then
    error("Turtle required!")
end

local utils = require("utils")
local programName = shell.getRunningProgram()
local Aware = {}

Aware.__index = Aware

--- Aware object constructor
-- @param pos table: position table
-- @return Aware
function Aware.new()
    local self = setmetatable({}, Aware)

    -- the file path where the state is written
    self.dbPath = fs.combine("database", programName, "state")

    -- load any existing state
    self.state = self:getState()

    -- allows us to always refer to 1 as forward, 2 as right, 3 as back, and 4 as left, even when using absolute positioning from GPS
    self.directionMap = {
        { 1, 2, 3, 4 },
        { 2, 3, 4, 1 },
        { 3, 4, 1, 2 },
        { 4, 1, 2, 3 }
    }

    -- default state
    if not self.state then
        self.state = {
            pos = {
                x = 0,
                y = 0,
                z = 0,
                f = 1
            }
        }
    end

    -- tells us if this turtle can use gps or not, depending on if he has a modem, and can fetch his coordinates from a GPS host
    self.state.hasGPS = self:hasGPS()

    -- override the position if we have GPS
    if self.state.hasGPS then
        self.state.pos = self:locate()
    end

    -- set home if we don't have one
    if not self.state.home then
        self.state.home = utils.deepCopy(self.state.pos)
    end

    -- write the current state back to file
    self:saveState(self.state)

    return self
end

--- ===============================================================
--- DATABASE METHODS
--- ===============================================================

--- Fetch any saved state
-- @return table,nil
function Aware:getState()
    if fs.exists(self.dbPath) then
        local file = fs.open(self.dbPath, "r")
        local state = textutils.unserialize(file.readAll())

        file.close()

        return state
    end

    return nil
end

--- Save a new state
-- @param state table
function Aware:saveState(state)
    local file = fs.open(self.dbPath, "w")

    file.write(textutils.serialize(state))
    file.close()

    os.queueEvent("stateSaved")
end

--- Delete the state
function Aware:deleteState()
    return fs.delete(fs.combine("database", programName))
end

--- ===============================================================
--- ROTATION METHODS
--- ===============================================================

--- Turn the turtle to the left, update facing position, and save state
-- @return boolean
function Aware:turnLeft()
    turtle.turnLeft()
    self.state.pos.f = self.state.pos.f == 1 and 4 or self.state.pos.f - 1
    self:saveState(self.state)

    return true
end

--- Turn the turtle to the right, update facing position, and save state
-- @return boolean
function Aware:turnRight()
    turtle.turnRight()
    self.state.pos.f = self.state.pos.f == 4 and 1 or self.state.pos.f + 1
    self:saveState(self.state)

    return true
end

--- Turn the turtle a requested direction, update facing position, and save state
-- @param n number, string: either 1,2,3,4 or x,-x,z,-z
-- @param c boolean: should use cardinal directions?
-- @return boolean
function Aware:turnTo(n, c)
    -- for both relative and cardinal directions, these axis always map to correct values
    if type(n) == "string" then
        if n == "x" then
            n = 2
        elseif n == "-x" then
            n = 4
        elseif n == "-z" then
            n = 1
        elseif n == "z" then
            n = 3
        end
    else
        if not c then
            -- update n to be the correct relative value based on the home facing direction
            -- if home f is 3 and n is 2, we update n to 4
            n = self.directionMap[self.state.home.f][n]
        end
    end

    local diff = self.state.pos.f - n

    while n ~= self.state.pos.f do
        if diff == 1 or diff == -3 then
            self:turnLeft()
        else
            self:turnRight()
        end
    end

    return true
end

--- Turn the turtle around 180 degrees
-- @return boolean
function Aware:turnAround()
    for i = 1, 2 do
        self:turnLeft()
    end

    return true
end

--- ===============================================================
--- LOCATION UPDATE METHODS
--- ===============================================================

--- Update the turtle's X or Z axis coordinate based on its current facing position and if the back param is passed
-- @param back boolean: was the move a backwards movement?
-- @return table
function Aware:updateXZ(back)
    if self.state.pos.f == 1 then
        self.state.pos.z = back and self.state.pos.z + 1 or self.state.pos.z - 1
    elseif self.state.pos.f == 2 then
        self.state.pos.x = back and self.state.pos.x - 1 or self.state.pos.x + 1
    elseif self.state.pos.f == 3 then
        self.state.pos.z = back and self.state.pos.z - 1 or self.state.pos.z + 1
    elseif self.state.pos.f == 4 then
        self.state.pos.x = back and self.state.pos.x + 1 or self.state.pos.x - 1
    end

    self:saveState(self.state)

    return self.state.pos
end

--- Update the turtle's Y axis coordinate based on its moving up or down
-- @param down boolean: was the move a downward move?
-- @return table
function Aware:updateY(down)
    self.state.pos.y = down and self.state.pos.y - 1 or self.state.pos.y + 1
    self:saveState(self.state)

    return self.state.pos
end

--- Set a checkpoint position that the system can later use to recover from
function Aware:setCheckpoint()
    self.state.checkpoint = utils.deepCopy(self.state.pos)

    self:saveState(self.state)
end

--- ===============================================================
--- MOVEMENT METHODS
--- ===============================================================

--- Move the turtle in a particular direction

-- @param dir string: direction
-- @param dist string: distance
-- @param canDig boolean: can dig
-- @return boolean
function Aware:move(dir, dist, canDig)
    -- default direction
    if not dir then
        dir = "forward"
    end

    -- default distance of 1
    if not dist then
        dist = 1
    end

    -- ensure valid direction
    if dir ~= "forward" and dir ~= "back" and dir ~= "up" and dir ~= "down" then
        error("invalid direction")
    end

    -- for each distance
    for i = 1, dist do
        -- attempt to move turtle in direction
        while not turtle[dir]() do
            if turtle.getFuelLevel() == 0 then
                return false
            end

            local detectMethod = "detect"
            local digMethod = "dig"
            local attackMethod = "attack"
            local fail = false

            -- if direction is back we need to turn around and face that block
            if dir == "back" then
                self:turnAround()
            end

            -- update methods if up or down
            if dir == "up" or dir == "down" then
                detectMethod = detectMethod .. string.upper(string.sub(dir, 1, 1)) .. string.sub(dir, 2)
                digMethod = digMethod .. string.upper(string.sub(dir, 1, 1)) .. string.sub(dir, 2)
                attackMethod = attackMethod .. string.upper(string.sub(dir, 1, 1)) .. string.sub(dir, 2)
            end

            -- detect a block
            if turtle[detectMethod]() then
                if canDig then
                    -- dig the detected block
                    if not turtle[digMethod]() then
                        fail = true
                    end
                else
                    -- fail because we dont have permission to dig the block
                    error("I need to dig, but I'm not allowed")
                end
            else
                -- since we didnt move, and we didnt detect a block, and we're not out of fuel, must be some entity in the way, attack it!
                turtle[attackMethod]()
            end

            if dir == "back" then
                self:turnAround()
            end

            if fail then
                return false
            end
        end

        -- increment the number of blocks moved
        self.state.blocksTraveled = self.state.blocksTraveled + 1

        -- update stored position
        if dir == "up" or dir == "down" then
            self:updateY(dir == "down")
        elseif dir == "forward" or dir == "back" then
            self:updateXZ(dir == "back")
        end
    end

    return true
end

--- Move the turtle forward 1 block
-- @param dist number: how many blocks to dig
-- @param dig boolean: can dig
-- @return boolean
function Aware:forward(dist, dig)
    return self:move("forward", dist, dig)
end

--- Move the turtle backwards 1 block
-- @param dist number: how many blocks to dig
-- @param dig boolean: can dig
-- @return boolean
function Aware:back(dist, dig)
    return self:move("back", dist, dig)
end

--- Move the turtle up one block
-- @param dist number: how many blocks to dig
-- @param dig boolean: can dig
-- @return boolean
function Aware:up(dist, dig)
    return self:move("up", dist, dig)
end

--- Move the turtle down one block
-- @param dist number: how many blocks to dig
-- @param dig boolean: can dig
-- @return boolean
function Aware:down(dist, dig)
    return self:move("down", dist, dig)
end

--- Move the turtle to a specific xyz coordinate, relative to the turtle's home position
-- @param pos table: coordinates
-- @param dig boolean: can dig
-- @param order string: order of axis, xyz, zyx, yxz, etc
-- @return boolean
function Aware:moveTo(pos, dig, order)
    if not order then
        -- default order is y, x, z
        if not self:moveToY(pos.y, dig) then
            return false
        end

        if not self:moveToX(pos.x, dig) then
            return false
        end

        if not self:moveToZ(pos.z, dig) then
            return false
        end

        return self:turnTo(pos.f)
    end

    if string.len(order) ~= 3 then
        error("invalid order length")
    end

    for i = 1, #order do
        local char = order:sub(i, i)
        if not self["moveTo" .. string.upper(char)](self, pos[char], dig) then
            return false
        end
    end

    return self:turnTo(pos.f)
end

--- Move the turtle to a specific X axis coordinate
-- @param coord number: coordinate point
-- @param dig boolean: can dig
-- @return boolean
function Aware:moveToX(coord, dig)
    if self.state.pos.x == coord then
        return true
    end

    if self.state.pos.x < coord then
        self:turnTo("x")

        return self:forward(coord - self.state.pos.x, dig)
    elseif self.state.pos.x > coord then
        self:turnTo("-x")

        return self:forward(self.state.pos.x - coord, dig)
    end

    return false
end

--- Move the turtle to a specific Z axis coordinate
-- @param coord number: coordinate point
-- @param dig boolean: can dig
-- @return boolean
function Aware:moveToZ(coord, dig)
    if self.state.pos.z == coord then
        return true
    end

    if self.state.pos.z < coord then
        self:turnTo("z")

        return self:forward(coord - self.state.pos.z, dig)
    elseif self.state.pos.z > coord then
        self:turnTo("-z")

        return self:forward(self.state.pos.z - coord, dig)
    end

    return false
end

--- Move the turtle to a specific Y axis coordinate
-- @param coord number: coordinate point
-- @param dig boolean: can dig
-- @return boolean
function Aware:moveToY(coord, dig)
    if self.state.pos.y == coord then
        return true
    end

    if self.state.pos.y < coord then
        return self:up(coord - self.state.pos.y, dig)
    elseif self.state.pos.y > coord then
        return self:down(self.state.pos.y - coord, dig)
    end

    return false
end

--- ===============================================================
--- UTILITY METHODS
--- ===============================================================

--- Detect if the turtle has GPS capability
--@return boolean: does the turtle have GPS functionality
function Aware:hasGPS()
    local x = gps.locate(5)

    -- if x returns a value, we know that gps is working
    if x then
        return true
    end

    local equipResult, slotNumber = self:equip("computercraft:wireless_modem_advanced", "right")

    if equipResult then
        x = gps.locate(5)

        -- re-equip the previously equipped item
        turtle.select(slotNumber)
        turtle.equipRight()

        if x then
            return true
        end
    end

    return false
end

--- Equip an item on a side of the turtle
--@param name string: the name of the item to equip
--@param side string: which side of the turtle, left or right
--@return boolean, number,nil
function Aware:equip(name, side)
    -- check for item in turtle inventory that we can equip
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)

        if item and item.name == name then
            turtle.select(i)

            -- return the result of the item equip and the slot number that was equipped
            return turtle["equip" .. string.upper(string.sub(side, 1, 1)) .. string.sub(side, 2)](), i
        end
    end

    -- if we didnt find the item in the inventory, we need to see if the item is already equipped
    -- we can do this, but we first need to find an empty inventory slot to unequip the item to check what it is
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)

        -- find empty slot to swap out with equipped item
        if not item then
            -- select the empty slot
            turtle.select(i)

            -- attempt to unequip item into selected slot
            turtle["equip" .. string.upper(string.sub(side, 1, 1)) .. string.sub(side, 2)]()

            -- check if item is now in selected slot
            item = turtle.getItemDetail(i)

            -- put whatever it was back
            turtle["equip" .. string.upper(string.sub(side, 1, 1)) .. string.sub(side, 2)]()

            if item and item.name == name then
                return true, i
            end

            return false
        end
    end

    printError("Unable to find item to equip: " .. name)

    return false
end

--- Find the direction the turtle is facing by moving one block forward, and seeing which axis changed
--- NOTE: this method will assumes that the modem is already equipped, because of how I am calling it.. ymmv
-- @param x number
-- @param z number
-- @return number
function Aware:getDirection(x, z)
    local equipSuccess, slot

    -- move 1 block forward so we can get an updated position
    while not self:move("forward", 1, true) do
        equipSuccess, slot = self:equip("minecraft:diamond_pickaxe", "right")
    end

    if equipSuccess then
        turtle.select(slot)
        turtle.equipRight()
    end

    -- get updated gps location
    local nx, _, nz = gps.locate(5)

    -- reset position after getting update
    self:move("back", 1, true)

    -- determine face
    if z > nz then
        return 1
    elseif x < nx then
        return 2
    elseif z < nz then
        return 3
    elseif x > nx then
        return 4
    end

    error("Unknown direction")
end

--- Using GPS, get the precise location of the miner, including direction
--@return table,nil
function Aware:locate()
    if not self.state.hasGPS then
        error("GPS is not enabled on this turtle")
    end

    local x, y, z = gps.locate(5)

    local pos

    if x then
        pos = {
            x = x,
            y = y,
            z = z,
            f = self:getDirection(x, z)
        }
    else
        local _, slotNumber = self:equip("computercraft:wireless_modem_advanced", "right")

        x, y, z = gps.locate(5)

        -- we got a gps result
        if x then
            pos = {
                x = x,
                y = y,
                z = z,
                f = self:getDirection(x, z)
            }
        end

        -- put the previous item back
        turtle.select(slotNumber)
        turtle.equipRight()

        if not x then
            error("I am equipped with GPS, but there appears not to be a GPS host")
        end
    end

    return pos
end

return Aware