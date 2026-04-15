local M = {}

local state = {
  job_id = nil,
  message_id = "xJUSTEXx",
  cancelled = false,
}

local function update_progress(msg, level, status, percent)
  vim.api.nvim_echo({ { msg, level } }, false, {
    id = state.message_id,
    kind = "progress",
    source = "xJUSTEXx",
    status = status,
    percent = percent,
  })
end

local function get_main_file_name()
  local justfile_path = vim.fs.find(".justfile", { upward = true, stop = vim.uv.os_homedir() })[1]

  if not justfile_path then
    return nil
  end

  local file = io.open(justfile_path, "r")

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
  local justfile_dir = vim.fs.dirname(vim.fs.find(".justfile", { upward = true, stop = vim.uv.os_homedir() })[1])
  local cwd = justfile_dir or vim.fn.expand("%:p:h")

  state.cancelled = false

  update_progress("Compiling " .. file_name .. "...", "None", "running", 0)

  --TODO: Tal vez parsear la salida de latexmk
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
    vim.fn.jobstop(state.job_id)

    update_progress("Compilation cancelled", "WarningMsg", "cancel", 100)
    state.job_id = nil
  else
    vim.notify("No active job to cancel", vim.log.levels.WARN)
  end
end

return M
