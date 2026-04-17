if not turtle then
    printError("Turtle required")
end

local files = {
    ["3NKq6eVh"] = "mine.lua",
    ["rbEuHDXm"] = "Miner.lua",
    ["AbvVBMrM"] = "Aware.lua",
    ["VstKVZYw"] = "TurtleUtils.lua",
    ["Bg2hsB5R"] = "Logger.lua",
    ["urxNRmJN"] = "GUIUtils.lua"
}

for code, name in pairs(files) do
    if fs.exists(name) then
        shell.run("rm " .. name)
    end
    shell.run("pastebin get " .. code .. " " .. name)
end