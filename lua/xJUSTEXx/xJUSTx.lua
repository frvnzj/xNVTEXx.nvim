local M = {}

local state = {
  job_id = nil,
  message_id = "xJUSTEXx",
  cancelled = false,
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
  local justfile_paths = vim.fs.find(".justfile", { upward = true, stop = vim.uv.os_homedir() })

  if not justfile_paths or #justfile_paths == 0 then
    return nil
  end

  local file = io.open(justfile_paths[1], "r")

  if not file then
    return nil
  end

  local main_file = nil
  for line in file:lines() do
    main_file = line:match('main_file%s*:=%s*"([^"]+)"')
    if main_file then
      break
    end
  end
  file:close()
  return main_file
end

--- Function to execute a "just" command with progress reporting
---@param command string: The "just" command to execute
function M.xCOMPILEx(command)
  if state.job_id then
    vim.notify("A compile is already running", vim.log.levels.WARN)
    return
  end

  local cmd = { "just", command }
  local file_name = get_main_file_name() or vim.fn.expand("%:t")
  local justfile_paths = vim.fs.find(".justfile", { upward = true, stop = vim.uv.os_homedir() })
  local justfile_dir = justfile_paths and #justfile_paths > 0 and vim.fs.dirname(justfile_paths[1])
    or nil
  local cwd = justfile_dir or vim.fn.expand("%:p:h")

  state.cancelled = false

  update_progress("Compiling " .. file_name .. "...", "None", "running", 0)

  state.job_id = vim.fn.jobstart(cmd, {
    cwd = cwd,
    stdout_buffered = false,

    on_stdout = function(_, data)
      if state.cancelled or not data or (data[1] == "" and #data == 1) then
        return
      end

      update_progress("xJUSTEXx: " .. file_name .. "...", "None", "running", 30)
    end,

    on_stderr = function(_, data)
      if state.cancelled or not data or (data[1] == "" and #data == 1) then
        return
      end

      update_progress("Processing with warnings...", "WarningMsg", "running", 60)
    end,

    on_exit = function(_, code)
      local was_cancelled = state.cancelled
      state.job_id = nil
      state.cancelled = false

      if was_cancelled then
        return
      end

      if code == 0 then
        update_progress("Compilation finished!", "MoreMsg", "success", 100)
      else
        update_progress("Compilation failed! (Code " .. code .. ")", "ErrorMsg", "failed", 100)
      end
    end,
  })
end

function M.xCANCELx()
  if state.job_id then
    state.cancelled = true

    pcall(vim.fn.jobstop, state.job_id)

    update_progress("Compilation cancelled", "WarningMsg", "cancel", 100)
    state.job_id = nil
  else
    vim.notify("No active job to cancel", vim.log.levels.WARN)
  end
end

return M
