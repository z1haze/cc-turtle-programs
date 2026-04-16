-- GUI util module for programs
local GUIUtils = {}

function GUIUtils.create()
    local instance = {}

    function instance.clearLine()
        local x, y = term.getCursorPos()

        term.setCursorPos(1, y)
        write("|                                     |")
        term.setCursorPos(x, y)
    end

    function instance.drawFrame()
        term.clear()

        -- side borders
        for i = 1, 13 do
            term.setCursorPos(1, i)
            write("|")
            term.setCursorPos(39, i)
            write("|")
        end

        -- top border
        term.setCursorPos(1, 1)
        write("O-------------------------------------O")

        -- middle line
        term.setCursorPos(1, 5)
        write("O-------------------------------------O")

        -- bottom border
        term.setCursorPos(1, 13)
        write("O-------------------------------------O")

        -- move cursor to bottom
        local _, h = term.getSize()
        term.setCursorPos(1, h)
    end
    
    return instance
end

return GUIUtils