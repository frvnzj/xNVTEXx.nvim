local M = {}

local config = require("xJUSTEXx.config")

local PROGRESS_STAGES = {
  start = 10,
  running = 40,
  warning = 70,
  complete = 100,
}

local STATE = {
  job_id = nil,
  message_id = "xJUSTEXx",
  cancelled = false,
}

local COMMAND_META = {
  lualatex = {
    start = "xJUSTEXx with LuaLaTeX: ",
    success = "✓ LuaLaTeX: Success",
    icon = "󰚔",
  },
  pdflatex = {
    start = "xJUSTEXx with PDFLaTeX: ",
    success = "✓ PDFLaTeX: Success",
    icon = "󰚔",
  },
  pdfxe = {
    start = "xJUSTEXx with XeLaTeX: ",
    success = "✓ XeLaTeX: Success",
    icon = "󰚔",
  },
  cleanmain = {
    start = "Cleaning proyect: ",
    success = "✓ Clean project",
    icon = "󰃢",
  },
  cleanall = {
    start = "Total cleaning of temporary",
    success = "✓ Erased temporary",
    icon = "󰃢",
  },
  default = {
    start = "Running xJUSTEXx: ",
    success = "✓ Just finished",
    icon = "󱁤",
  },
}

---@param msg string
---@param level string
---@param status string
---@param percent integer
local function update_progress(msg, level, status, percent)
  pcall(vim.api.nvim_echo, { { msg, level } }, false, {
    id = STATE.message_id,
    kind = "progress",
    source = "xJUSTEXx",
    status = status,
    percent = percent,
  })
end

---@param data table|nil
---@return boolean
local function should_skip_callack(data)
  return STATE.cancelled or not data or (data[1] == "" and #data == 1)
end

---@return string|nil
local function get_main_file_name()
  local cwd = vim.uv.cwd()
  local justfile = vim.fs.joinpath(cwd, ".justfile")

  if vim.uv.fs_stat(justfile) == nil then
    local current_file = vim.fn.expand("%:t")
    local name_no_ext = vim.fn.expand("%:t:r")

    if vim.bo.filetype == "tex" then
      local content = config.set_file_justfile(name_no_ext)
      vim.fn.writefile(vim.split(content, "\n"), justfile)
      vim.notify(
        "xJUSTEXx: automatically generated .justfile for " .. current_file,
        vim.log.levels.INFO
      )
    else
      return nil
    end
  end

  local lines = vim.fn.readfile(justfile)
  for _, line in ipairs(lines) do
    local main_file = line:match('main_file%s*:=%s*"([^"]+)"')
    if main_file then
      return main_file
    end
  end
  return nil
end

---@param command string
---@return string
local function get_target_display(command, main_file)
  return (command == "cleanall") and "" or main_file
end

---@param command string
---@return boolean
local function is_clean_command(command)
  return command:find("clean") ~= nil
end

---@param command string
---@return table
local function build_job_callback(command, meta)
  return {
    on_stdout = function(_, data)
      if should_skip_callack(data) then
        return
      end
      update_progress(
        meta.icon .. " xJUSTEXx: " .. command .. "...",
        "None",
        "running",
        PROGRESS_STAGES.running
      )
    end,

    on_stderr = function(_, data)
      if should_skip_callack(data) then
        return
      end

      if not is_clean_command(command) then
        update_progress(
          "Processing with warnings...",
          "WarningMsg",
          "running",
          PROGRESS_STAGES.warning
        )
      end
    end,

    on_exit = function(_, code)
      local was_cancelled = STATE.cancelled
      STATE.job_id = nil

      if was_cancelled then
        return
      end

      if code == 0 then
        update_progress(
          meta.icon .. " " .. meta.success,
          "MoreMsg",
          "success",
          PROGRESS_STAGES.complete
        )
      else
        update_progress(
          "Failed " .. command .. " (Code " .. code .. ")",
          "ErrorMsg",
          "failed",
          PROGRESS_STAGES.complete
        )
      end
    end,
  }
end

--- Function to execute a "just" command with progress reporting
---@param command string: The "just" command to execute
function M.xCOMPILEx(command)
  if STATE.job_id then
    vim.notify("A compile is already running", vim.log.levels.WARN)
    return
  end

  local cwd = vim.uv.cwd()
  local main_file = get_main_file_name()

  if not main_file then
    vim.notify("xJUSTEXx: No .justfile found in current directory", vim.log.levels.ERROR)
    return
  end

  local meta = COMMAND_META[command] or COMMAND_META.default
  local target_display = get_target_display(command, main_file)

  STATE.cancelled = false
  update_progress(
    meta.icon .. " " .. meta.start .. target_display,
    "None",
    "running",
    PROGRESS_STAGES.start
  )

  STATE.job_id = vim.fn.jobstart(
    { "just", command },
    vim.tbl_extend("force", {
      cwd = cwd,
      stdout_buffered = false,
    }, build_job_callback(command, meta))
  )
end

function M.xCANCELx()
  if STATE.job_id then
    STATE.cancelled = true
    vim.fn.jobstop(STATE.job_id)
    STATE.job_id = nil
    update_progress("Compilation cancelled", "WarningMsg", "cancel", PROGRESS_STAGES.complete)
  else
    vim.notify("No active job to cancel", vim.log.levels.WARN)
  end
end

return M
