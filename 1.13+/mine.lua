if not turtle then
    error("Turtle required!")
end

write("Miner initializing")
textutils.slowPrint("...", 5)

-- if this file exists, we know that we need to resume a previous task
local resume = fs.exists(fs.combine("database", shell.getRunningProgram(), "state"))
local running = false

local Aware = require("Aware")
local aware = Aware.new()

local Miner = require("Miner")
local miner = Miner.new(aware)

function setup()
    local branchCount, branchLength, branchGap, currentY, targetY, placeTorches

    -- capture trunk length
    while branchCount == nil do
        print("");
        print("How many branches should be mined?")

        local input = read();
        branchCount = tonumber(input)

        if branchCount == nil then
            print("'" .. input .. "' should be a number")
        end
    end

    -- capture branch length
    while branchLength == nil do
        print("");
        print("How long should each branch be?")

        local input = read();
        branchLength = tonumber(input)

        if branchLength == nil then
            print("'" .. input .. "' should be a number")
        end
    end

    if branchCount > 1 then
        -- capture branch gap
        while branchGap == nil do
            print("");
            print("How many block gap should there be between branches?")

            local input = read();
            branchGap = tonumber(input)

            if branchGap == nil then
                print("'" .. input .. "' should be a number")
            end
        end
    end

    if not miner.aware.state.hasGPS then
        -- capture current Y level
        while currentY == nil do
            print("");
            print("What is the current Y level of the turtle?")

            local input = read();
            currentY = tonumber(input)

            if currentY == nil then
                print("'" .. input .. "' should be a number")
            end
        end
    end

    -- capture target Y level
    while targetY == nil do
        print("");
        print("What is the target Y level of the turtle?")

        local input = read();
        targetY = tonumber(input)

        if targetY == nil then
            print("'" .. input .. "' should be a number")
        end
    end

    -- capture torch setting
    while placeTorches == nil do
        print("");
        print("Should I place torches? Enter 'yes' or 'no'")

        local input = read();

        if input == 'yes' then
            placeTorches = true
        elseif input == 'no' then
            placeTorches = false
        end

        if placeTorches == nil then
            print("'" .. input .. "' should be 'yes' or 'no'")
        end
    end

    miner.aware.state.branchCount = branchCount
    miner.aware.state.branchLength = branchLength
    miner.aware.state.branchGap = branchGap
    miner.aware.state.currentBranch = 1
    miner.aware.state.placeTorches = placeTorches

    if not miner.aware.state.hasGPS then
        miner.aware.state.yLevel = miner.aware.state.pos.y - (currentY - targetY)
    else
        miner.aware.state.yLevel = targetY
    end

    -- setup the GUI frame
    miner:guiFrame()
    running = true
    miner.aware:saveState(miner.aware.state)
end

function doIt()
    if not resume then
        setup()
    end

    running = true

    miner:useFuel(1000)

    if not miner.aware:equip("minecraft:diamond_pickaxe", "right") then
        error()
    end

    if resume then
        if not miner.aware.state.hasGPS then
            error("Sorry, too unreliable to recover without GPS")
        end

        if miner.aware.state.checkpoint then
            miner:setCurrentAction("checkpoint")
            miner.aware:moveTo(miner.aware.state.checkpoint, true, "y" .. miner.aware.state.axis.trunk .. miner.aware.state.axis.branch)
            miner:setCurrentAction()
        else
            -- if we are home or we are in the main chute
            if (miner.aware.state.pos.x == miner.aware.state.home.x and miner.aware.state.pos.z == miner.aware.state.home.z) and miner.aware.state.currentBranch < miner.aware.state.branchCount then
                miner:setCurrentAction("descend")
                miner.aware:moveToY(miner.aware.state.yLevel, true)
                miner:setCurrentAction()
            else
                miner:setCurrentAction("home")
                miner:goHome(miner.aware.state.axis.branch .. miner.aware.state.axis.trunk .. "y")
                error("No checkpoint, unable to continue. I Came home like a good boy.")
            end
        end
    else
        miner:setCurrentAction("descend")
        miner.aware:moveToY(miner.aware.state.yLevel, true)
        miner:setCurrentAction()
    end

    local currentAction = miner.aware.state.currentAction

    for i = miner.aware.state.currentBranch, miner.aware.state.branchCount do
        miner:setCurrentBranch(i)

        -- mine out the branch
        if not currentAction or currentAction == "vein" then
            miner:veinMine({
                f = 2,
                l = miner.aware.state.branchLength,
                b = miner.aware.state.currentBlock,
                t = miner.aware.state.placeTorches,
                c = true,
                a = currentAction and currentAction or "vein"
            })
        end

        -- move back to the trunk
        if currentAction ~= "trunk" then
            miner:setCurrentAction("back")

            local coords = {
                y = miner.aware.state.yLevel + 1,
                f = 4
            }

            coords[miner.aware.state.axis.trunk] = miner.aware.state.pos[miner.aware.state.axis.trunk]
            coords[miner.aware.state.axis.branch] = miner.aware.state.home[miner.aware.state.axis.branch]

            miner.aware:moveTo(coords, true, "zxy")

            -- if we have more trunk to dig, move down the main level
            if i < miner.aware.state.branchCount and miner.aware.state.pos.y == miner.aware.state.yLevel + 1 then
                miner:move("down")
            end

            miner:setCurrentAction()
        end

        if i < miner.aware.state.branchCount then
            miner:veinMine({
                f = 1,
                l = miner.aware.state.branchGap + 2,
                b = miner.aware.state.currentBlock,
                t = false,
                c = true,
                a = "trunk"
            })
        end

        if currentAction then
            currentAction = nil
        end
    end

    miner:setCurrentAction("home")
    miner:goHome(miner.aware.state.axis.branch .. miner.aware.state.axis.trunk .. "y")
    miner:unload("up")
    miner:setCurrentAction("done")
    miner:guiStats() -- show the final state
    miner.aware:deleteState()
end

function listen()
    while true do
        local event = os.pullEvent()

        if event == "stateSaved" and running then
            miner:guiStats()
        end
    end
end

parallel.waitForAny(doIt, listen)