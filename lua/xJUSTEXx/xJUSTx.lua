local M = {}

local config = require("xJUSTEXx.config")

local state = {
  job_id = nil,
  message_id = "xJUSTEXx",
  cancelled = false,
}

local command_meta = {
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
    id = state.message_id,
    kind = "progress",
    source = "xJUSTEXx",
    status = status,
    percent = percent,
  })
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

--- Function to execute a "just" command with progress reporting
---@param command string: The "just" command to execute
function M.xCOMPILEx(command)
  if state.job_id then
    vim.notify("A compile is already running", vim.log.levels.WARN)
    return
  end

  local cwd = vim.uv.cwd()
  local main_file = get_main_file_name()

  if not main_file then
    vim.notify("xJUSTEXx: No .justfile found in current directory", vim.log.levels.ERROR)
    return
  end

  local meta = command_meta[command] or command_meta.default
  local target_display = (command == "cleanall") and "" or main_file

  state.cancelled = false
  update_progress(meta.icon .. " " .. meta.start .. target_display, "None", "running", 10)

  state.job_id = vim.fn.jobstart({ "just", command }, {
    cwd = cwd,
    stdout_buffered = false,

    on_stdout = function(_, data)
      if state.cancelled or not data or (data[1] == "" and #data == 1) then
        return
      end

      update_progress(meta.icon .. " xJUSTEXx: " .. command .. "...", "None", "running", 40)
    end,

    on_stderr = function(_, data)
      if state.cancelled or not data or (data[1] == "" and #data == 1) then
        return
      end

      if not command:find("clean") then
        update_progress("Processing with warnings...", "WarningMsg", "running", 70)
      end
    end,

    on_exit = function(_, code)
      local was_cancelled = state.cancelled
      state.job_id = nil

      if was_cancelled then
        return
      end

      if code == 0 then
        update_progress(meta.icon .. " " .. meta.success, "MoreMsg", "success", 100)
      else
        update_progress("Failed " .. command .. " (Code " .. code .. ")", "ErrorMsg", "failed", 100)
      end
    end,
  })
end

function M.xCANCELx()
  if state.job_id then
    state.cancelled = true
    vim.fn.jobstop(state.job_id)
    state.job_id = nil
    update_progress("Compilation cancelled", "WarningMsg", "cancel", 100)
  else
    vim.notify("No active job to cancel", vim.log.levels.WARN)
  end
end

return M
