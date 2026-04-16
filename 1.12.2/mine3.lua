if not turtle then
    error("Turtle required!")
end

local GUIUtils = require("GUIUtils")
local Miner = require("Miner")
local Logger = require("Logger")

write("Initializing")
textutils.slowPrint("...", 5)

local function setup()
    -- user inputs we will be collecting
    local branchCount, branchLength, branchGap, startY, minY, maxY, floorGap, doRecursion

    while branchCount == nil do
        print("");
        print("How many branches should be mined?")

        local input = read();
        branchCount = tonumber(input)

        if branchCount == nil then
            print("'" .. input .. "' should be a number")
        end
    end

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

    while floorGap == nil do
        print("");
        print("How many blocks between layers?")

        local input = read();
        floorGap = tonumber(input)

        if floorGap == nil then
            print("'" .. input .. "' should be a number")
        end
    end

    while startY == nil do
        print("");
        print("What is the startY of the turtle?")

        local input = read();
        startY = tonumber(input)

        if startY == nil then
            print("'" .. input .. "' should be a number")
        end
    end

    while minY == nil do
        print("");
        print("What is the minY?")

        local input = read();
        minY = tonumber(input)

        if minY == nil then
            print("'" .. input .. "' should be a number")
        end
    end

    while maxY == nil do
        print("");
        print("What is the maxY?")

        local input = read();
        maxY = tonumber(input)

        if maxY == nil then
            print("'" .. input .. "' should be a number")
        end
    end

    while doRecursion == nil do
        print("");
        print("Should we check for ores recursively? Enter 'yes' or 'no'")

        local input = read();

        if input == 'yes' then
            doRecursion = true
        elseif input == 'no' then
            doRecursion = false
        end

        if doRecursion == nil then
            print("'" .. input .. "' should be a 'yes' or 'no'")
        end
    end

    return branchCount, branchLength, branchGap, startY, minY, maxY, floorGap, doRecursion
end

function main()
    local logger = Logger.create({
        level = Logger.LEVELS.DEBUG,
        clean = true
    })

    logger.debug("Running setup to collect user inputs")

    -- collect user inputs
    local branchCount, branchLength, branchGap, startY, minY, maxY, floorGap, doRecursion = setup()

    logger.debug("User inputs: " .. textutils.serialize({
        branchCount = branchCount,
        branchLength = branchLength,
        branchGap = branchGap,
        startY = startY,
        minY = minY,
        maxY = maxY,
        floorGap = floorGap,
        doRecursion = doRecursion
    }))

    local miner = Miner.create({
        branchCount = branchCount,
        branchLength = branchLength,
        branchGap = branchGap,
        startY = startY,
        minY = minY,
        maxY = maxY,
        floorGap = floorGap,
        doRecursion = doRecursion,
        shouldCheckLeft = false,
        shouldCheckRight= false,
        shouldCheckUp = true,
        shouldCheckDown = true,
        trash = {
            ["minecraft:dirt"] = true,
            ["minecraft:stone"] = true,     -- covers stone, granite, diorite, andesite (all metadata variants)
            ["minecraft:cobblestone"] = true,
            ["minecraft:gravel"] = true,
        },
        storage = {
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
            ["minecraft:black_shulker_box"] = true,
            ["ironchest:gold_chest"] = true
        }
    }, logger)

    local guiUtils = GUIUtils.create()

    logger.debug("Drawing GUI Frame")

    -- draw the border gui frame thing
    guiUtils.drawFrame()

    logger.debug("Executing run and listen tasks")

    parallel.waitForAny(miner.run, miner.listen)
end

main()