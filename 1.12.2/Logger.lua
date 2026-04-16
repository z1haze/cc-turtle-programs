-- logger.lua
-- A simple logging module for ComputerCraft

local Logger = {}

-- Log levels
local LEVELS = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
    FATAL = 5
}

-- Level names for pretty printing
local LEVEL_NAMES = {
    [1] = "DEBUG",
    [2] = "INFO",
    [3] = "WARN",
    [4] = "ERROR",
    [5] = "FATAL"
}

-- Terminal colors (using ComputerCraft color values)
-- Define these directly to avoid relying on colors API which might not be available
local COLORS = {
    [1] = 8,  -- lightGray
    [2] = 1,  -- white
    [3] = 4,  -- yellow
    [4] = 16, -- red
    [5] = 16  -- red
}

-- Create a new logger instance
-- @param options table Configuration options
--   - filename (string): Path to log file
--   - level (number): Minimum log level to record (defaults to DEBUG)
--   - console (boolean): Whether to output to console (defaults to true)
--   - timestamps (boolean): Whether to include timestamps (defaults to true)
-- @return Logger instance
function Logger.create(options)
    options = options or {}

    local instance = {}

    local filename = options.filename or "app.log"
    local level = options.level or LEVELS.DEBUG
    local console = options.console == true  -- Default to false
    local timestamps = options.timestamps == true  -- Default to false

    -- Attempt to open the log file
    local fileMode = options.clean and "w" or "a" -- Use "w" for fresh file, "a" for append
    local file = fs.open(filename, fileMode)

    if file then
        file.close()
    else
        print("Warning: Could not open log file: " .. filename)
    end

    -- Format a log message
    -- @param logLevel number Log level
    -- @param message string The message to log
    -- @param ... any Additional values to include in the log
    -- @return string Formatted log message
    local function format(logLevel, message, ...)
        local args = {...}
        local prefix = ""

        -- Add timestamp if enabled
        if timestamps then
            prefix = os.date("[%Y-%m-%d %H:%M:%S] ")
        end

        -- Add level tag
        prefix = prefix .. "[" .. LEVEL_NAMES[logLevel] .. "] "

        -- Format the message with any additional arguments
        local result = prefix .. message
        for i = 1, #args do
            result = result .. " " .. tostring(args[i])
        end

        return result
    end

    -- Write a message to the log file
    -- @param message string The message to write
    local function writeToFile(message)
        local file = fs.open(filename, "a")

        if file then
            file.writeLine(message)
            file.close()
        end
    end

    -- Log a message at a specific level
    -- @param logLevel number Log level
    -- @param message string The message to log
    -- @param ... any Additional values to include in the log
    instance.log = function(logLevel, message, ...)
        if logLevel >= level then
            local formatted = format(logLevel, message, ...)

            -- Write to file
            writeToFile(formatted)

            -- Write to console if enabled
            if console then
                -- Only attempt to use colors on advanced computers
                if term.isColor() then
                    local oldColor = term.getTextColor()
                    term.setTextColor(COLORS[logLevel])
                    print(formatted)
                    term.setTextColor(oldColor)
                else
                    -- Regular output for non-advanced computers
                    print(formatted)
                end
            end
        end
    end

    -- Write a line directly to the log file without formatting
    -- @param message string The line to write
    instance.writeLine = function(message)
        writeToFile(message)

        if console then
            print(message)
        end
    end

    -- Close the logger (currently a no-op, but good for API consistency)
    instance.close = function()
        -- Nothing to do here for now, but could be used for cleanup
    end

    -- Convenience methods for different log levels
    instance.debug = function(message, ...)
        return instance.log(LEVELS.DEBUG, message, ...)
    end

    instance.info = function(message, ...)
        return instance.log(LEVELS.INFO, message, ...)
    end

    instance.warn = function(message, ...)
        return instance.log(LEVELS.WARN, message, ...)
    end

    instance.error = function(message, ...)
        return instance.log(LEVELS.ERROR, message, ...)
    end

    instance.fatal = function(message, ...)
        return instance.log(LEVELS.FATAL, message, ...)
    end

    -- Expose constants
    instance.LEVELS = LEVELS

    return instance
end

-- Expose constants at module level too
Logger.LEVELS = LEVELS

return Logger