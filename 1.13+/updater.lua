if not turtle then
    printError("Turtle required")
end

local files = {
    ["R0NKhzE6"] = "Aware.lua",
    ["7vun2WwB"] = "Miner.lua",
    ["r8gawpWC"] = "mine.lua",
    ["BDEmJuZ1"] = "startup.lua",
    ["rnatyneZ"] = "utils.lua",
}

for code, name in pairs(files) do
    shell.run("rm " .. name)
    shell.run("pastebin get " .. code .. " " .. name)
end