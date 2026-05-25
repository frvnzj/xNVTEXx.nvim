local M = {}

local config = require("xJUSTEXx.config")

---@enum NotifyLevel
local LOG = {
  ERROR = vim.log.levels.ERROR,
  WARN = vim.log.levels.WARN,
  INFO = vim.log.levels.INFO,
}

local JUSTFILE_NAME = ".justfile"
local ROOT_PATTERNS = { ".git", JUSTFILE_NAME }
local COMMON_MAIN_FILES = { "main.tex", "root.tex", "index.tex", "master.tex" }
local CONFIRMATION_YES = 1

---@class xJUSTEXx.ProgressStages
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
---@field name string
---@field start string
---@field success string
---@field icon string
---@field is_clean boolean

---@type table<string, CommandMeta>
local COMMAND_META = {
  lualatex = {
    name = "lualatex",
    start = "Compiling with LuaLaTeX: ",
    success = "LuaLaTeX: Success",
    icon = "󰚔 ",
    is_clean = false,
  },
  pdflatex = {
    name = "pdflatex",
    start = "Compiling with PDFLaTeX: ",
    success = "PDFLaTeX: Success",
    icon = "󰚔 ",
    is_clean = false,
  },
  pdfxe = {
    name = "pdfxe",
    start = "Compiling with XeLaTeX: ",
    success = "XeLaTeX: Success",
    icon = "󰚔 ",
    is_clean = false,
  },
  cleanmain = {
    name = "cleanmain",
    start = "Cleaning project: ",
    success = "Clean project",
    icon = "󰃢 ",
    is_clean = true,
  },
  cleanall = {
    name = "cleanall",
    start = "Full outputs cleanup: ",
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
  message_id = "xJUSTEXx",
  cancelled = false,
}

---Notify user with consistent prefix
---@param msg string The notification message
---@param level integer|nil Notification level (defaults to INFO)
local function notify(msg, level)
  vim.notify("xJUSTEXx: " .. msg, level or LOG.INFO)
end

-- Initial global cache to avoid forbidden calls in fast-event threads (E5560)
local IS_DEBUG = vim.env.XJUSTEXX_DEBUG == "1"

---Log internal debug message
---@param msg_cb function|string
---@param level integer|nil
local function debug_log(msg_cb, level)
  if IS_DEBUG then
    local msg = type(msg_cb) == "function" and msg_cb() or msg_cb
    vim.notify("[DEBUG] xJUSTEXx: " .. msg, level or LOG.INFO)
  end
end

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
    source = "xJUSTEXx",
    status = status,
    percent = percent,
    title = "xJUSTEXx",
  })

  if not ok then
    debug_log("Error updating progress - " .. err, LOG.ERROR)
  end

  return ok
end

---Check if should ignore data incoming
---@param data string|nil
---@return boolean
local function is_empty_output(data)
  return not data or data == "" or data == "\n"
end

---Request user confirmation
---@param question string
---@param yes_label string
---@param no_label string
---@return boolean confirmed
local function confirm(question, yes_label, no_label)
  local choice = vim.fn.confirm(question, "&" .. yes_label .. "\n&" .. no_label, 2)
  return choice == CONFIRMATION_YES
end

---Get command metadata with fallback
---@param command string
---@return CommandMeta
local function get_command_meta(command)
  return COMMAND_META[command] or COMMAND_DEFAULT
end

---Find the main candidate file
---@param project_root string
---@return string
local function find_main_candidate(project_root)
  for _, name in ipairs(COMMON_MAIN_FILES) do
    local found = vim.fs.find(name, { path = project_root, limit = 1 })[1]
    if found then
      local result = vim.fn.fnamemodify(found, ":t:r")
      debug_log("Found common main file - " .. result)
      return result
    end
  end

  local result = vim.fn.fnamemodify(project_root, ":t")
  if result ~= "" then
    return result
  end

  result = vim.fn.expand("%:t:r")
  return result ~= "" and result or ""
end

---Create .justfile with configuration
---@param path string
---@param main_candidate string
---@return boolean success
local function create_justfile(path, main_candidate)
  local content, is_valid = config.set_file_justfile(main_candidate)
  if not is_valid or not content then
    return false
  end

  local ok, err = pcall(vim.fn.writefile, vim.split(content, "\n"), path)

  if not ok then
    notify("Failed to create .justfile - " .. err, LOG.ERROR)
    return false
  end

  return true
end

---Read justfile and extract main_file variable
---@param path string
---@return string|nil
local function read_justfile(path)
  local ok, lines = pcall(vim.fn.readfile, path)

  if not ok then
    notify("Failed to read .justfile", LOG.ERROR)
    return nil
  end

  for _, line in ipairs(lines) do
    local main_file = line:match('main_file%s*:=%s*"([^"]+)"')
    if main_file then
      debug_log("Extracted main_file from justfile - " .. main_file)
      return main_file
    end
  end

  notify("Could not find main_file definition in .justfile", LOG.WARN)
  return nil
end

---Gets the name of the main project file
---Find or create a `.justfile` file in the current directory
---@return string|nil main_file
---@return string|nil project_root
local function get_main_file_name()
  local buf_file_name = vim.api.nvim_buf_get_name(0)
  local current_dir = (buf_file_name ~= "" and vim.bo.buftype == "")
      and vim.fs.dirname(buf_file_name)
    or vim.fn.getcwd()

  local project_root = vim.fs.root(current_dir, ROOT_PATTERNS) or current_dir
  local justfile_path = vim.fs.joinpath(project_root, JUSTFILE_NAME)

  if vim.uv.fs_stat(justfile_path) == nil then
    local ft = vim.bo.filetype
    if ft ~= "tex" and ft ~= "plaintex" then
      return nil, nil
    end

    local main_candidate = find_main_candidate(project_root)

    if main_candidate == "" then
      notify("Could not determine a main file name. Save your file first", LOG.WARN)
      return nil, nil
    end

    if not confirm("Do you want to create .justfile to compile?", "Yes", "No") then
      notify(".justfile was not created. Cannot compile with xJUSTEXx", LOG.WARN)
      return nil, nil
    end

    if not create_justfile(justfile_path, main_candidate) then
      return nil, nil
    end

    notify(".justfile has been created for root target - " .. main_candidate)
  end

  return read_justfile(justfile_path), project_root
end

---Execute a "just" command with progress reporting
---@param command string
---@return boolean success
function M.xCOMPILEx(command)
  if not command or type(command) ~= "string" then
    notify("Invalid command type", LOG.ERROR)
    return false
  end

  if STATE.obj then
    notify("A compile is already running", LOG.WARN)
    return false
  end

  local main_file, cwd = get_main_file_name()

  if not main_file or not cwd then
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
  obj = vim.system({ "just", command }, {
    cwd = cwd,
    stdout = function(err, data)
      if err or is_empty_output(data) or STATE.cancelled then
        return
      end

      vim.schedule(function()
        debug_log(function()
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
        debug_log(function()
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
      debug_log(function()
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
    notify("Failed to start compilation job", LOG.ERROR)
    return false
  end

  STATE.obj = obj
  debug_log(function()
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
    debug_log("Job cancelled")
    return true
  else
    notify("No active job to cancel", LOG.WARN)
    return false
  end
end

return M
