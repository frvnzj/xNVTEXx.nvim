local M = {}

local config = require("xNVTEXx.config")
local u = require("xNVTEXx.utils")

---@class xNVTEXx.ProgressStages
---@field start integer
---@field running integer|nil
---@field warning integer|nil
---@field complete integer
local PROGRESS_STAGES = {
  start = 0,
  running = nil,
  warning = nil,
  complete = 100,
}

---@class CommandMeta
---@field start string
---@field success string
---@field icon string
---@field is_clean boolean

---@type table<string, CommandMeta>
local COMMAND_META = {
  lualatex = {
    start = "Compiling with LuaLaTeX: ",
    success = "LuaLaTeX: Success",
    icon = "󰚔 ",
    is_clean = false,
  },
  pdflatex = {
    start = "Compiling with PDFLaTeX: ",
    success = "PDFLaTeX: Success",
    icon = "󰚔 ",
    is_clean = false,
  },
  xelatex = {
    start = "Compiling with XeLaTeX: ",
    success = "XeLaTeX: Success",
    icon = "󰚔 ",
    is_clean = false,
  },
  cleanmain = {
    start = "Cleaning project",
    success = "Clean project",
    icon = "󰃢 ",
    is_clean = true,
  },
  cleanall = {
    start = "Full outputs cleanup",
    success = "All outputs cleared",
    icon = "󰃢 ",
    is_clean = true,
  },
}

local COMMAND_DEFAULT = {
  name = "default",
  start = "Processing: ",
  success = "Task finished",
  icon = "󱁤 ",
  is_clean = false,
}

---@class ProgressState
---@field obj vim.SystemObj|nil
---@field message_id string
---@field cancelled boolean
local STATE = {
  obj = nil,
  message_id = "xNVTEXx",
  cancelled = false,
}

---Safe wrapper for vim.api.nvim_echo
---@param msg string
---@param level string
---@param status string
---@param percent integer|nil
---@param history boolean|nil
---@return boolean success
local function update_progress(msg, level, status, percent, history)
  local ok, err = pcall(vim.api.nvim_echo, { { msg, level } }, history or false, {
    id = STATE.message_id,
    kind = "progress",
    source = "xNVTEXx",
    status = status,
    percent = percent,
    title = "xNVTEXx",
  })

  if not ok then
    u.debug_log("Error updating progress - " .. err, u.LOG.ERROR)
  end

  return ok
end

---Check if should ignore data incoming
---@param data string|nil
---@return boolean
local function is_empty_output(data)
  return not data or data == "" or data == "\n"
end

---Get command metadata with fallback
---@param command string
---@return CommandMeta
local function get_command_meta(command)
  return COMMAND_META[command] or COMMAND_DEFAULT
end

---Execute a LaTeX compilation command with progress reporting
---@param command string The command to execute
---@return boolean success
function M.xCOMPILEx(command)
  if not command or type(command) ~= "string" then
    u.notify_err("Invalid command type")
    return false
  end

  if STATE.obj then
    u.notify_warn("A compile is already running")
    return false
  end

  local main_file, cwd = u.get_main_file_name()

  if not main_file or not cwd then
    return false
  end

  local sys_cmd = config.get_command(command, main_file)
  if not sys_cmd then
    u.notify_err("Command not configured - " .. command)
    return false
  end

  local meta = get_command_meta(command)
  local target_display = meta.is_clean and "" or main_file

  STATE.cancelled = false

  update_progress(
    meta.icon .. meta.start .. target_display,
    "None",
    "running",
    PROGRESS_STAGES.start,
    true
  )

  local obj
  obj = vim.system(sys_cmd, {
    cwd = cwd,
    stdout = function(err, data)
      if err or is_empty_output(data) or STATE.cancelled then
        return
      end

      vim.schedule(function()
        u.debug_log(function()
          return "stdout - " .. vim.inspect(data)
        end)

        update_progress(meta.icon .. command .. "...", "None", "running", PROGRESS_STAGES.running)
      end)
    end,
    stderr = function(err, data)
      if err or is_empty_output(data) or STATE.cancelled then
        return
      end

      vim.schedule(function()
        u.debug_log(function()
          return "stderr - " .. vim.inspect(data)
        end)

        if not meta.is_clean then
          update_progress(
            "Processing with warnings...",
            "WarningMsg",
            "running",
            PROGRESS_STAGES.warning
          )
        end
      end)
    end,
  }, function(completed)
    local exit_code = completed.code
    local was_cancelled = STATE.cancelled

    vim.schedule(function()
      STATE.obj = nil
      u.debug_log(function()
        return "Job exited with code - " .. exit_code .. ", cancelled - " .. tostring(was_cancelled)
      end)

      if was_cancelled then
        return
      end

      if completed.code == 0 then
        update_progress(
          meta.icon .. meta.success,
          "MoreMsg",
          "success",
          PROGRESS_STAGES.complete,
          true
        )
      else
        update_progress(
          "Failed " .. command .. " (Code " .. exit_code .. ")",
          "ErrorMsg",
          "failed",
          PROGRESS_STAGES.complete,
          true
        )
      end
    end)
  end)

  if not obj then
    u.notify_err("Failed to start compilation job")
    return false
  end

  STATE.obj = obj
  u.debug_log(function()
    return "Job started with command - " .. command
  end)
  return true
end

---Cancel the current build
---@return boolean success
function M.xCANCELx()
  if STATE.obj then
    STATE.cancelled = true
    STATE.obj:kill(15)
    STATE.obj = nil
    update_progress("Compilation cancelled", "WarningMsg", "cancel", PROGRESS_STAGES.complete, true)
    u.debug_log("Job cancelled")
    return true
  else
    u.notify_warn("No active job to cancel")
    return false
  end
end

return M
