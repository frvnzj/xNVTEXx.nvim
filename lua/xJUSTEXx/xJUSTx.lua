local M = {}

local state = {
  job_id = nil,
  message_id = nil,
  cancelled = false,
}

local function get_main_file_name()
  local justfile_path = vim.fn.getcwd() .. "/.justfile"
  local file = io.open(justfile_path, "r")
  if not file then
    return nil
  end

  local content = file:read("*a")
  file:close()

  -- Buscar la línea que define el archivo principal
  local main_file = content:match('main_file%s*:=%s*"([^"]+)"')
  return main_file
end

--- Function to execute a "just" command with optional progress reporting
---@param command string: The "just" command to execute
function M.xCOMPILEx(command)
  if state.job_id then
    vim.notify("A compile is already running", vim.log.levels.WARN)
    return
  end

  local cmd = "just " .. command
  local file_name = get_main_file_name() or vim.fn.expand("%:t")

  local message_id = "xJUSTEXx"

  state.message_id = message_id
  state.cancelled = false

  vim.api.nvim_echo({ { "Compiling " .. file_name .. "...", "None" } }, false, {
    id = message_id,
    kind = "progress",
    source = "xJUSTEXx",
    title = "Just: " .. command,
    status = "running",
    percent = 0,
  })

  --TODO: Tal vez parsear la salida de latexmk
  state.job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = true,

    on_stdout = function(_, data)
      if state.cancelled then
        return
      end

      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            vim.api.nvim_echo({ { "xJUSTEXx compile: " .. file_name .. "...", "None" } }, false, {
              id = message_id,
              kind = "progress",
              source = "xJUSTEXx",
              status = "running",
              percent = 0,
            })
            break
          end
        end
      end
    end,

    on_stderr = function(_, data)
      if state.cancelled then
        return
      end

      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            vim.api.nvim_echo({ { "Processing with warnings", "WarningMsg" } }, false, {
              id = message_id,
              kind = "progress",
              source = "xJUSTEXx",
              status = "running",
              percent = 60,
            })
            break
          end
        end
      end
    end,

    on_exit = function(_, code)
      if state.cancelled then
        state.cancelled = false
        state.job_id = nil
        return
      end

      if code == 0 then
        vim.api.nvim_echo({ { "Compilation finished successfully!", "MoreMsg" } }, true, {
          id = message_id,
          kind = "progress",
          source = "xJUSTEXx",
          status = "success",
          percent = 100,
        })
      else
        vim.api.nvim_echo({ { "Compilation failed! Exit code: " .. code, "ErrorMsg" } }, true, {
          id = message_id,
          kind = "progress",
          source = "xJUSTEXx",
          status = "failed",
          percent = 100,
        })
      end

      state.job_id = nil
    end,
  })
end

function M.xCANCELx()
  if state.job_id and state.job_id > 0 then
    state.cancelled = true
    vim.fn.jobstop(state.job_id)

    vim.api.nvim_echo({ { "Compilation cancelled", "WarningMsg" } }, false, {
      id = state.message_id or "xJUSTEXx",
      kind = "progress",
      source = "xJUSTEXx",
      status = "cancel",
      percent = 100,
    })

    state.job_id = nil
  else
    vim.notify("No active job to cancel", vim.log.levels.WARN)
  end
end

return M
