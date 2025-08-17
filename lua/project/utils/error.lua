local levels = vim.log.levels

local ERROR, WARN, INFO, DEBUG, TRACE =
    levels.ERROR, levels.WARN, levels.INFO, levels.DEBUG, levels.TRACE

---@class Project.Utils.Error
local M = {}

M.ERROR = ERROR
M.WARN = WARN
M.INFO = INFO
M.DEBUG = DEBUG
M.TRACE = TRACE

---@param msg string
function M.error(msg)
    error(msg, M.ERROR)
end

---@param msg string
function M.warn(msg)
    error(msg, M.WARN)
end

---@param msg string
function M.info(msg)
    error(msg, M.INFO)
end

---@param msg string
function M.debug(msg)
    error(msg, M.DEBUG)
end

---@param msg string
function M.trace(msg)
    error(msg, M.TRACE)
end

---@type table|Project.Utils.Error|fun(msg: string)
local Error = setmetatable(M, {
    __index = M,

    ---@param self Project.Utils.Error
    ---@param k integer|string
    ---@param v any
    ---@diagnostic disable-next-line:unused-local
    __newindex = function(self, k, v)
        self.error('Error module is read-only!')
    end,

    ---@param self Project.Utils.Error
    ---@param msg string
    __call = function(self, msg)
        self.error(msg)
    end,
})

return Error

--- vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
