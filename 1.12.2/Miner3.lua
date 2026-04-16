local GUIUtils = require("GUIUtils")
local TurtleUtils = require("TurtleUtils")

-- Miner turtle module that implements Awareness and mining capabilities
local Miner = {}

local ResourceMessages = {
    Actions = {
        ["descend"] = "Descending",
        ["branch"] = "Branch Mining",
        ["home"] = "Heading Home",
        ["pitstop"] = "Pitstop",
        ["checkpoint"] = "Checkpoint",
        ["floor"] = "Next Floor",
        ["done"] = "Finished",
        ["refuel"] = "Refuel"
    }
}

function Miner.create(data, logger)
    -- deps
    local Aware = require("Aware")
    local guiUtils = GUIUtils.create()
    local aware = Aware.create(logger)

    -- our "instance" object that gets returned from this method
    local instance = {}
    -- tracking recursive movements so we can back the fuck out when we need a pitstop
    local movements = {}

    -- local private data for running this shit
    local trash = data.trash or {}
    local storage = data.storage or {}
    local shouldCheckLeft = data.shouldCheckLeft == true
    local shouldCheckRight = data.shouldCheckRight == true
    local shouldCheckUp = data.shouldCheckUp == true
    local shouldCheckDown = data.shouldCheckDown == true
    local doRecursion = data.doRecursion == true
    local startY = data.startY
    local minY = data.minY
    local maxY = data.maxY
    local targetY = data.minY
    local branchGap = data.branchGap
    local floorGap = data.floorGap
    local currentBranch = 1
    local branchCount = data.branchCount or 1
    local branchLength = data.branchLength or 16
    local branchBlock = 1
    local blocksTraveled = 0
    local blocksCollected = 0
    local blocksBroken = 0
    local fuelReserve = 20000
    local guiAction

    --- update the gui action and emit an event so the gui listener can use it
    local function setGUIAction(_guiAction)
        guiAction = _guiAction
        os.queueEvent("action_change")
    end

    --- private abstraction to the aware movement api
    local function _move(direction)
        if not direction then
            direction = "forward"
        end

        return aware[direction](1, true)
    end

    --- handle turtle movements, accounting for possible entities in the way
    local function move(direction, _invert)
        direction = direction or "forward"

        if _invert then
            direction = TurtleUtils.invert[direction]
        end

        local moved = false

        while true do
            -- attempt to move the turtle
            moved = _move(direction)

            -- if the turtle moved, return true
            if moved then
                break
            end

            -- if the turtle didnt move because of fuel, return false
            if turtle.getFuelLevel() == 0 then
                logger.fatal("Ran out of fuel at " .. aware.getStringLocation(aware.getLocation()))
                error("Ain't go no gas in it!")
            end

            -- if the direction is back, we need to turn around to detect
            if direction == "back" then
                aware.turnAround()
            end

            -- if the turtle didnt move because of a block, return false
            local detectResult = TurtleUtils.detect(direction == "back" and "forward" or direction)

            -- if there is a block in front, that's why it didnt move, return false this is normal
            if detectResult then
                logger.fatal("Need to dig but I'm not allowed at " .. aware.getStringLocation(aware.getLocation()))
                error("couldn't move, block in the way")
            end

            -- turn the turtle back around
            if direction == "back" then
                aware.turnAround()
            end

            -- finally, if the turtle didnt move, but he has fuel, and there is no block in his way, some entity is blocking him, so we must smash it
            while true do
                -- if the direction is back, we need to turn around to detect
                if direction == "back" then
                    aware.turnAround()
                end

                local attackResult = TurtleUtils.attack(direction)

                -- turn the turtle back around
                if direction == "back" then
                    aware.turnAround()
                end

                if not attackResult then
                    break
                end
            end
        end

        return moved
    end

    --- traverse the movements logged from the recursiveDig function
    local function traverseMovements(reverse)
        if reverse then
            for i = #movements, 1, -1 do
                local movement = movements[i]

                if movement == "left" then
                    aware.turnRight()
                elseif movement == "right" then
                    aware.turnLeft()
                elseif movement == "turnAround" then
                    aware.turnAround()
                else
                    move(movements[i], true)
                end
            end
        else
            for i = 1, #movements do
                local movement = movements[i]

                if movement == "left" then
                    aware.turnLeft()
                elseif movement == "right" then
                    aware.turnRight()
                elseif movement == "turnAround" then
                    aware.turnAround()
                else
                    move(movements[i])
                end
            end
        end
    end

    --- unload the turtle
    local function unload(direction)
        direction = direction or "up"

        logger.debug("Unloading in the " .. direction .. " direction")

        -- if there is no block in the direction we are unloading, error out
        if not TurtleUtils.detect(direction) then
            logger.error("Failed to find a chest at location " .. aware.getStringLocation(aware.getLocation()))
            error("I have nowhere to put these items!")
        end

        -- get the details of the block we are supposed to unload into
        local _, details = TurtleUtils.inspect(direction)

        -- if the item i'm supposed to be unloading into is not a _storage item, wtf are you even doing
        if not TurtleUtils.isStorageItem(details, storage) then
            error("Cannot deposit items into " .. details.name)
        end

        -- unload the goods
        return TurtleUtils.unload(direction, storage)
    end

    --- Takes full load back to the chest at home and comes back
    local function pitStop(waitForFuel)
        local prevAction = guiAction -- save the current action so we can set it back after the pitstop

        logger.debug("Starting pitstop " .. aware.getStringLocation(aware.getLocation()))

        -- tell gui we are performing a pitstop
        setGUIAction(waitForFuel and "refuel" or "pitstop")

        -- move back to the branch block before any recursive digging occurred
        traverseMovements(true)

        -- set a checkpoint back to the current branch block
        aware.setCheckpoint()

        -- move to origin with order of axis z,x,y
        aware.home("zxy", true)

        logger.debug("I'm home? " .. aware.getStringLocation(aware.getLocation()))

        -- unload into chest, default placement is above turtle
        unload("up")

        -- if we came back because we needed fuel
        if waitForFuel then
            logger.debug("Waiting at home for fuel during pitstop")

            -- attempt to refuel every 10 seconds
            -- once the fuel is at least half of the fuel reserve we can continue on
            while true do
                aware.refuel(fuelReserve)
                sleep(10)

                if turtle.getFuelLevel() >= fuelReserve then
                    break
                end
            end
        end

        -- move back to the checkpoint block
        setGUIAction("checkpoint")
        aware.moveTo(aware.getCheckpoint())
        logger.debug("Moved back to checkpoint at " .. aware.getStringLocation(aware.getLocation()))
        aware.clearCheckpoint()

        -- move back to the recursive block location if it exists
        traverseMovements()

        logger.debug("Ending pitstop at " .. aware.getStringLocation(aware.getLocation()))

        -- put the action back to the previous action before we did the pitstop
        setGUIAction(prevAction)
    end

    --- Handle freeing up slots in the turtle, and make a pitstop if necessary
    local function freeUpSpace()
        local fuelLevel = turtle.getFuelLevel()

        ---- refuel if necessary
        if fuelLevel < fuelReserve then
            aware.useFuel(fuelReserve - turtle.getFuelLevel())
        end

        -- if we're dangerouly low, we need to go back and wait for more fuel
        if turtle.getFuelLevel() < 1000 then
            pitStop(true)
        end

        ---- consolidate partial stacks where possible
        if #TurtleUtils.getEmptySlots() < 2 then
            TurtleUtils.compact()
        end

        ---- check if there are empty slots, dump any useless blocks to save space
        if #TurtleUtils.getEmptySlots() < 2 then
            TurtleUtils.dropTrash(trash)
        end

        ---- if after dump useless blocks the empty space is 1, go unload
        if #TurtleUtils.getEmptySlots() < 2 then
            pitStop()
        end

        -- select the first slot to possibly help fix stacking issues?
        turtle.select(1)
    end

    --- Check for a "wanted" block in front, above, or below
    local function check(direction)
        if TurtleUtils.detect(direction) then
            local result, block = TurtleUtils.inspect(direction)

            if result and not trash[block.name] then
                return true
            end
        end

        return false
    end

    --- Recursively mine in a direction, checking for "wanted" blocks
    local function recursiveDig(dir)
        dir = dir or "forward"

        --- helper function to dig blocks recursively in a direction
        --
        -- @param d string: direction
        local function dig(direction)
            direction = direction or "forward"
            TurtleUtils.dig(direction)
            os.queueEvent("block_collected")
            os.queueEvent("block_broken")
            freeUpSpace()
            move(direction)
            table.insert(movements, direction)
            recursiveDig(direction)
            move(direction, true) -- moves the inverse
            table.remove(movements)
        end

        --------------------------------- begin recursive checking ---------------------------------

        local positions = { "forward", "left", "right", "up", "down", "back" }

        -- remove the inverse of forward, up, or down, because
        -- we dont need to check the direction we came from
        if dir == "forward" or dir == "up" or dir == "down" then
            local indexToRemove

            for key, v in pairs(positions) do
                if v == TurtleUtils.invert[dir] then
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
                aware.turn("left")
                table.insert(movements, "left")
            elseif v == "right" then
                aware.turn("right")
                table.insert(movements, "right")
            elseif v == "back" then
                aware.turnAround()
                table.insert(movements, "turnAround")
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
                aware.turn("right")
                table.remove(movements)
            elseif v == "right" then
                aware.turn("left")
                table.remove(movements)
            elseif v == "back" then
                aware.turnAround()
                table.remove(movements)
            end
        end

        return true
    end

    --- An abstraction to help mining each block in a branch
    local function handleBlock(direction, doRecursiveChecks)
        direction = direction or "forward"

        if check(direction) then
            TurtleUtils.dig(direction)
            os.queueEvent("block_collected")
            os.queueEvent("block_broken")

            if doRecursiveChecks then
                move(direction)
                table.insert(movements, direction)
                recursiveDig(direction)
                move(direction, true)
                movements = {}
            end
        end
    end

    --- The meat and potatoes of the mining program
    local function branchMine()
        for i = 1, branchLength do
            os.queueEvent("branch_block", i)

            freeUpSpace()

            -- this ensures that if we want branches that are total length of 16 blocks that
            -- that only 15 blocks will be traveled but all 16 blocks will be checked.
            -- this is because the turtle starts on the surface on block 1 and digs down to the
            -- correct y-level and begins branch mining
            -- doing this means that the starting block will get the proper checks too
            if i > 1 then
                if check("forward") then
                    turtle.dig()
                    os.queueEvent("block_collected")
                else
                    turtle.dig()
                    os.queueEvent("block_broken")
                end

                if not move() then
                    error("Tried to move in branch mine but couldn't")
                end
            end

            -- check the block above
            if shouldCheckUp then
                handleBlock("up", doRecursion)
            end

            -- check the block below
            if shouldCheckDown then
                handleBlock("down", doRecursion)
            end

            -- check the block to the left
            if shouldCheckLeft then
                aware.turnLeft()
                handleBlock("forward", doRecursion)
                aware.turnRight()
            end

            -- check the block to the right
            if shouldCheckRight then
                aware.turnRight()
                handleBlock("forward", doRecursion)
                aware.turnLeft()
            end
        end
    end

    --- Keeps the GUI updated with statistics
    local function updateGUI()
        local actionMessage = guiAction and ResourceMessages.Actions[guiAction] or "Awaiting Work"

        -- write the current action line
        term.setCursorPos(3, 2)
        guiUtils.clearLine()
        write("Current Action: " .. actionMessage .. "...")

        if guiAction == "descend" then
            actionMessage = "Descending to Y-Level " .. targetY
        elseif guiAction == "branch" then
            actionMessage = "On Branch " .. currentBranch .. "/" .. branchCount

            if branchBlock then
                actionMessage = actionMessage .. ", Block " .. branchBlock .. "/" .. branchLength
            end
        elseif guiAction == "pitstop" then
            actionMessage = "Shitter's full, gotta dump"
        elseif guiAction == "checkpoint" then
            actionMessage = "Moving to saved checkpoint"
        elseif guiAction == "home" then
            actionMessage = "Finishing mining, heading home"
        elseif guiAction == "done" then
            actionMessage = "Operation Complete."
        elseif guiAction == "refuel" then
            actionMessage = "Fuel dangerously low. Insert fuel"
        end

        if actionMessage then
            term.setCursorPos(3, 4)
            guiUtils.clearLine()
            write(actionMessage)
        end

        -- total blocks traveled
        term.setCursorPos(3, 6)
        guiUtils.clearLine()
        write("Blocks Traveled   : " .. blocksTraveled)

        -- total blocks collected
        term.setCursorPos(3, 7)
        guiUtils.clearLine()
        write("Blocks Collected  : " .. blocksCollected)

        -- total blocks mined
        term.setCursorPos(3, 8)
        guiUtils.clearLine()
        write("Blocks Mined      : " .. blocksBroken)

        -- current fuel level
        term.setCursorPos(3, 9)
        guiUtils.clearLine()
        write("Fuel Level        : " .. turtle.getFuelLevel())

        -- target y level
        term.setCursorPos(3, 10)
        guiUtils.clearLine()
        write("Target Y-Level    : " .. targetY)
    end

    -- MAIN LOOP FUNCTIONS

    --- Listens for queued events and updates runtime variables for displaying on the GUI
    function instance.listen()
        while true do
            local shouldUpdate = false
            local event = os.pullEvent()

            if event == "block_collected" then
                blocksCollected = blocksCollected + 1
                shouldUpdate = true
            elseif event == "block_broken" then
                blocksBroken = blocksBroken + 1
                shouldUpdate = true
            elseif event == "moved" then
                blocksTraveled = blocksTraveled + 1
                shouldUpdate = true
            elseif event == "action_change" then
                shouldUpdate = true
            end

            if shouldUpdate then
                updateGUI()
            end
        end
    end

    local function waitToEnd()
        term.setCursorPos(12, 2)
        write("Press any key to end the program")
        os.pullEvent("key")
    end

    --- The main loop
    function instance.run()
        local success, err = pcall(function()
            -- tell the gui we are descending
            setGUIAction("descend")

            logger.debug("Descending to target y-level: " .. minY)

            -- descend to target y level
            aware.moveTo({
                x = 0,
                -- initial descent is to the minimum y level
                y = minY - startY,
                z = 0,
                f = 1
            }, {
                canDig = true
            })

            -- indicates if there are more floors (y-levels) to be mined
            local keepGoing = true

            -- mine out all floors
            while keepGoing do
                setGUIAction("branch")

                for i = 1, branchCount do
                    currentBranch = i

                    logger.debug("Beginning branch " .. currentBranch)

                    local isEvenBranch = i % 2 == 0

                    -- at the start of the branch, we either look left or look right, depending if the branch is even or odd
                    -- think of it like a zig zag pattern, going back and forth. e.g. we tell the turtle to either look east or west
                    if isEvenBranch then
                        aware.turnLeft()
                    else
                        aware.turnRight()
                    end

                    -- tell the miner to mine a single branch
                    branchMine()

                    -- move across the z axis (relative north) to prepare for the next branch
                    if i < branchCount then
                        logger.debug("Moving to the next branch starting point")

                        -- free up space after the branch is mined, before preparing for the next branch
                        freeUpSpace()

                        -- face to the relative north
                        aware.turnTo(1)

                        -- dig out the branch gap to get in position for the next branch iteration
                        for _ = 1, branchGap + 1 do
                            turtle.dig()
                            move()
                        end
                    end
                end

                -- PREPARE FOR POSSIBLE NEXT FLOOR!
                logger.debug("Moving back to vertical shaft")

                -- move to vertical shaft
                aware.moveTo({
                    x = 0,
                    y = aware.getLocation().y,
                    z = 0,
                    f = 1
                }, {
                    canDig = false,
                    order = "zxy"
                })

                -- next potential y level to mine out
                targetY = startY + aware.getLocation().y + floorGap + 1

                -- are we at beyond the starting y?
                if targetY >= startY or targetY > maxY then
                    keepGoing = false
                else
                    logger.debug("Moving to the next floor at y-level: " .. targetY)

                    -- tell the gui we are moving to the next floor
                    setGUIAction("floor")

                    -- move up to the next floor
                    aware.moveTo({
                        x = 0,
                        y = targetY - startY, -- remember, its relative
                        z = 0,
                        f = 1
                    }, {
                        canDig = false
                    })
                end
            end

            logger.debug("No more floors to mine. Going home")

            -- tell the gui we are moving to home
            setGUIAction("home")

            -- move to home
            aware.home("xzy", true)

            -- attempt to unload the stuffs above the turtle
            unload("up")

            logger.info("Traveled " .. blocksTraveled .. " blocks")
            logger.info("Mined a total of " .. blocksBroken .. " blocks, " .. blocksCollected .. " of which considered valuable.")

            setGUIAction("done")
            waitToEnd()

            term.clear()
            term.setCursorPos(1, 1)
        end)

        if not success then
            logger.fatal("Program crashed at relative coordinates " .. aware.getStringLocation(aware.getLocation()))
            logger.fatal(tostring(err))

            traverseMovements(true)
            aware.home("xzy", true)
            logger.info("Stopping the program at relative coordinates " .. aware.getStringLocation(aware.getLocation()))
            return
        end
    end

    return instance
end

return Miner