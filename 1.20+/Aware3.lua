-- Aware turtle module that tracks location and provides movement methods
local Aware = {}

---Creates a new Aware turtle instance with location tracking and movement capabilities
---@return table instance A new turtle instance with the following methods:
---
--- Movement Methods:
---@field forward fun(distance?: number, canDig?: boolean): boolean Move forward by specified distance
---@field back fun(distance?: number, canDig?: boolean): boolean Move backward by specified distance
---@field up fun(distance?: number, canDig?: boolean): boolean Move up by specified distance
---@field down fun(distance?: number, canDig?: boolean): boolean Move down by specified distance
---@field moveTo fun(x: number, y: number, z: number, f?: number, canDig?: boolean, order?: string): boolean Move to specific coordinates. order defaults to "yxz"
---@field home fun(canDig?: boolean, order?: string): boolean move to home coordinates order defaults to "yxz"
---
--- Rotation Methods:
---@field turnLeft fun(): boolean Turn 90 degrees left
---@field turnRight fun(): boolean Turn 90 degrees right
---@field turnAround fun(): boolean Turn 180 degrees
---@field turnTo fun(n: number|string): boolean Turn to face direction. Accepts numbers 1-4 or strings "x", "-x", "z", "-z"
---
--- Location Methods:
---@field getLocation fun(): table Returns current location {x: number, y: number, z: number, f: number}
function Aware.create(logger)
    local instance = {}
    local location = {x = 0, y = 0, z = 0, f = 1}
    local checkpoint = nil

    instance.fuelMap = {
        ["minecraft:coal"] = 80,
        ["minecraft:lava_bucket"] = 1000,
        ["minecraft_coal_block"] = 800,
        ["minecraft_charcoal_block"] = 800
    }

    -- Get current location
    function instance.getLocation()
        return {
            x = location.x,
            y = location.y,
            z = location.z,
            f = location.f
        }
    end

    --- ===============================================================
    --- CHECKPOINT METHODS
    --- ===============================================================

    -- get the current checkpoint if it exists
    function instance.getCheckpoint()
        return checkpoint
    end

    -- set the checkpoint
    function instance.setCheckpoint()
        checkpoint = {
            x = location.x,
            y = location.y,
            z = location.z,
            f = location.f
        }

        logger.debug("Setting checkpoint at " .. instance.getStringLocation(checkpoint))
    end

    function instance.clearCheckpoint()
        checkpoint = nil
    end

    --- ===============================================================
    --- MOVEMENT METHODS
    --- ===============================================================

    -- Move the turtle along an axis, optionally allowing it to dig if it needs to
    local function move(direction, distance, canDig)
        -- default direction
        if not direction then
            direction = "forward"
        end

        -- default distance of 1
        if not distance then
            distance = 1
            else
            distance = math.abs(distance)
        end

        -- ensure valid direction
        if direction ~= "forward" and direction ~= "back" and direction ~= "up" and direction ~= "down" then
            error(direction .. " is not a valid direction at " .. instance.getStringLocation(location))
        end

        -- for each distance
        for _ = 1, distance do
            -- attempt to move turtle in direction
            while not turtle[direction]() do
                local detectMethod = "detect"
                local digMethod = "dig"
                local attackMethod = "attack"
                local fail = false

                -- if direction is back we need to turn around and face that block
                if direction == "back" then
                    instance.turnAround()
                end

                -- update methods if up or down
                if direction == "up" or direction == "down" then
                    detectMethod = detectMethod .. string.upper(string.sub(direction, 1, 1)) .. string.sub(direction, 2)
                    digMethod = digMethod .. string.upper(string.sub(direction, 1, 1)) .. string.sub(direction, 2)
                    attackMethod = attackMethod .. string.upper(string.sub(direction, 1, 1)) .. string.sub(direction, 2)
                end

                -- detect a block
                if turtle[detectMethod]() then
                    if canDig then
                        -- dig the detected block
                        if not turtle[digMethod]() then
                            fail = true
                        end
                        os.queueEvent("block_broken")
                    else
                        error("I need to dig " .. direction .. " but I'm not allowed. at " .. instance.getStringLocation(location))
                    end
                else
                    -- since we didnt move, and we didnt detect a block, and we're not out of fuel, must be some entity in the way, attack it!
                    turtle[attackMethod]()
                end

                if direction == "back" then
                    instance.turnAround()
                end

                if fail then
                    error("I attempted to dig but failed at " .. instance.getStringLocation(location))
                end
            end

            -- update stored location
            if direction == "up" or direction == "down" then
                location.y = direction == "down" and location.y - 1 or location.y + 1
            elseif direction == "forward" or direction == "back" then
                if location.f == 1 then
                    location.z = direction == "back" and location.z + 1 or location.z - 1
                elseif location.f == 2 then
                    location.x = direction == "back" and location.x - 1 or location.x + 1
                elseif location.f == 3 then
                    location.z = direction == "back" and location.z - 1 or location.z + 1
                elseif location.f == 4 then
                    location.x = direction == "back" and location.x + 1 or location.x - 1
                end
            end

            os.queueEvent("location_updated", location)
            os.queueEvent("moved")
        end

        return true
    end

    -- Move the turtle forwards `N` number of blocks, optionally allowing it to dig if it needs to
    function instance.forward(distance, canDig)
        return move("forward", distance, canDig)
    end

    -- Move the turtle backwards `N` number of blocks, optionally allowing it to dig if it needs to
    function instance.back(distance, canDig)
        return move("back", distance, canDig)
    end

    -- Move the turtle up `N` number of blocks, optionally allowing it to dig if it needs to
    function instance.up(distance, canDig)
        return move("up", distance, canDig)
    end

    -- Move the turtle down `N` number of blocks, optionally allowing it to dig if it needs to
    function instance.down(distance, canDig)
        return move("down", distance, canDig)
    end

    -- Explicitly move the turtle along the z-axis to a specified coordinate, optionally allowing the turtle to dig if it needs to
    local function moveToZ(z, canDig, direction, shouldLog)
        if location.z == z then
            if shouldLog then
                logger.debug("We are already at z:" .. location.z)
            end

            return true
        end

        direction = direction or "forward"

        if shouldLog then
            logger.debug("We will move " .. direction .. " along the z-axis. Currently facing " .. location.f)
        end

        if shouldLog then
            logger.debug("Current z:" .. location.z .. " is " .. (location.z < z and "less" or "greater") .. " than destination z:" .. z)
        end

        local moveSuccess

        if location.z < z then
            if direction == "back" then
                instance.turnTo("-z")
            else
                instance.turnTo("z")
            end

            moveSuccess = instance.forward(z - location.z, canDig)
        elseif location.z > z then
            if direction == "back" then
                instance.turnTo("z")
            else
                instance.turnTo("-z")
            end

            moveSuccess = instance.forward(location.z - z, canDig)
        end

        if shouldLog then
            logger.debug("Moved along z-axis to block " .. z .. " while facing " .. location.f)
        end

        return moveSuccess
    end

    -- Explicitly move the turtle along the x-axis to a specified coordinate, optionally allowing the turtle to dig if it needs to
    local function moveToX(x, canDig, direction, shouldLog)
        if location.x == x then
            if shouldLog then
                logger.debug("We are already at x:" .. location.x)
            end

            return true
        end

        direction = direction or "forward"

        if shouldLog then
            logger.debug("We will move " .. direction .. " along the x-axis. Currently facing " .. location.f)
        end

        if shouldLog then
            logger.debug("Current x:" .. location.x .. " is " .. (location.x < x and "less" or "greater") .. " than destination x:" .. x)
        end

        local moveSuccess

        if location.x < x then
            if direction == "back" then
                instance.turnTo("-x") -- we need to increase on x-axis, but we're going backwards so we should be facing negative x
            else
                instance.turnTo("x") -- we need to increase on x-axis, and we're moving forwards so we should be facing positive x
            end

            if shouldLog then
                logger.debug("After turning we are facing " .. location.f)
            end

            moveSuccess = instance[direction](x - location.x, canDig)
        elseif location.x > x then

            if direction == "back" then
                instance.turnTo("x") -- we need to decrease on x-axis, but we're going backwards so we should be facing positive x
            else
                instance.turnTo("-x") -- we need to decrease on x-axis, and we're moving forwards so we should be facing negative x
            end

            moveSuccess = instance[direction](location.x - x, canDig)
        end

        if shouldLog then
            logger.debug("Moved along x-axis to block " .. x .. " while facing " .. location.f)
        end

        return moveSuccess
    end

    -- Explicitly move the turtle along the y-axis to a specified coordinate, optionally allowing the turtle to dig if it needs to
    local function moveToY(y, canDig, shouldLog)
        if location.y == y then
            if shouldLog then
                logger.debug("We are already at y:" .. location.y)
            end

            return true
        end

        if location.y < y then
            return instance.up(y - location.y, canDig)
        elseif location.y > y then
            return instance.down(location.y - y, canDig)
        end

        return false
    end

    -- Move the turtle to a specific location, providing exact coordinates, optionally allowing the turtle to dig if it needs to, and optionally specifying the axis order in which it moves
    function instance.moveTo(_location, options)
        options = options or {}

        if not options.order then
            options.order = "yxz"  -- Default movement order
        end

        -- Create a table copy with coordinates
        local destination = {
            x = _location.x,
            y = _location.y,
            z = _location.z
        }

        for i = 1, #options.order do
            local char = options.order:sub(i, i)
            local success

            if char == "x" then
                success = moveToX(destination[char], options.canDig, options.direction, options.shouldLog)
            elseif char == "y" then
                success = moveToY(destination[char], options.canDig, options.shouldLog)
            elseif char == "z" then
                success = moveToZ(destination[char], options.canDig, options.direction, options.shouldLog)
            end

            if not success then
                return false
            end
        end

        local success = instance.turnTo(_location.f)

        if options.shouldLog then
            logger.debug("Facing direction " .. location.f .. " after moveTo")
        end

        return success
    end

    -- Move the turtle to home
    function instance.home(order, canDig)
        instance.moveTo({
            x = 0,
            y = 0,
            z = 0,
            f = 1
        }, {
            order = order,
            canDig = canDig,
            shouldLog = true
        })
    end


    --- ===============================================================
    --- ROTATION METHODS
    --- ===============================================================

    -- Rotates the turtle 90 degrees to the left
    function instance.turnLeft()
        if turtle.turnLeft() then
            location.f = location.f == 1 and 4 or location.f - 1
            os.queueEvent("location_updated", location)
            return true
        end

        return false
    end

    -- Rotates the turtle 90 degrees to the right
    function instance.turnRight()
        if turtle.turnRight() then
            location.f = location.f == 4 and 1 or location.f + 1
            os.queueEvent("location_updated", location)
            return true
        end

        return false
    end

    -- Rotates the turtle 180 degrees
    function instance.turnAround()
        for _ = 1, 2 do
            if not instance.turn("right") then
                return false
            end
        end

        return true
    end

    function instance.turn(direction)
        if direction == "left" then
            return instance.turnLeft()
        elseif direction == "right" then
            return instance.turnRight()
        end

        return false
    end

    -- Rotate the turtle to a specified direction
    function instance.turnTo(n)
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
            else
                error("Invalid direction string. Must be x, -x, z, or -z")
            end
        end

        if type(n) ~= "number" then
            error("Invalid arguments. n must be a number")
        end

        -- if the calculated face is the same face the turtle is facing, just return
        if n == location.f then
            return false
        end

        while n ~= location.f do
            local diff = location.f - n

            if diff == 1 or diff == -3 then
                turtle.turnLeft()
                location.f = location.f == 1 and 4 or location.f - 1
            else
                turtle.turnRight()
                location.f = location.f == 4 and 1 or location.f + 1
            end
        end

        os.queueEvent("location_updated", location)

        return true
    end

    --- ===============================================================
    --- FUELING METHODS
    --- ===============================================================

    function instance.useFuel(targetFuelLevel)
        local refueledAmount = 0

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
                if instance.fuelMap[itemDetail.name] then
                    fuelPer = instance.fuelMap[itemDetail.name]
                else
                    fuelPer = 80
                end

                -- get the number of items we can eat for fuel
                local count = turtle.getItemCount()

                -- reduce the number of items to consume until we are at or below the target fuel level
                while (turtle.getFuelLevel() + (count * fuelPer)) > targetFuelLevel and count > 1 do
                    count = count - 1
                end

                refueledAmount = refueledAmount + (count * fuelPer)

                -- burn that shit
                turtle.refuel(count)
            end
        end

        turtle.select(slot)

        return refueledAmount
    end

    --- ===============================================================
    --- LOGGER METHODS
    --- ===============================================================

    --- function to get the string formatted location
    function instance.getStringLocation(location)
        return "x:" .. location.x .. " y:" .. location.y .. " z:" .. location.z .. " f:" .. location.f
    end

    return instance
end

return Aware