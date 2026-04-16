if not turtle then
    printError("Turtle required")
end

local files = {
    ["2YZEVMCY"] = "mine.lua",
    ["6XZpaN99"] = "Miner.lua",
    ["JyLntqAR"] = "Aware.lua",
    ["crFin3cA"] = "TurtleUtils.lua",
    ["Bg2hsB5R"] = "Logger.lua",
    ["urxNRmJN"] = "GUIUtils.lua"
}

for code, name in pairs(files) do
    if fs.exists(name) then
        shell.run("rm " .. name)
    end
    shell.run("pastebin get " .. code .. " " .. name)
end