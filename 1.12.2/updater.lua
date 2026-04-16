if not turtle then
    printError("Turtle required")
end

local files = {
    ["59cMumAZ"] = "Aware.lua",
    ["zqsAEBD0"] = "Miner.lua",
    ["vnAMPtr9"] = "mine.lua",
    ["cxPfd3z7"] = "startup.lua",
    ["8xVqt0wz"] = "utils.lua",
}

for code, name in pairs(files) do
    shell.run("rm " .. name)
    shell.run("pastebin get " .. code .. " " .. name)
end