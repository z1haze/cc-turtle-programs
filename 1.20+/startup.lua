if not turtle then
    error("Turtle required!")
end

local resume = fs.exists(fs.combine("database", "mine.lua", "state"))

if resume then
    shell.run("mine.lua")
end