local M = {}

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
  local cmd = "just " .. command
  local file_name = get_main_file_name() or vim.fn.expand("%:t")

  local message_id = "xJUSTEXx"

  vim.api.nvim_echo({ { "Compiling " .. file_name .. "...", "none" } }, false, {
    id = message_id,
    kind = "progress",
    title = "Just: " .. command,
    status = "running",
    percent = 0,
  })

  --TODO: Tal vez parsear la salida de latexmk
  vim.fn.jobstart(cmd, {
    stdout_buffered = true,

    on_stdout = function(_, data)
      if data and #data > 0 then
        local message = "Compiling " .. file_name .. "..."

        vim.api.nvim_echo({ { message .. "...", "None" } }, false, {
          id = message_id,
          kind = "progress",
          status = "running",
          percent = 60,
        })
      end
    end,

    on_stderr = function(_, data)
      if data and #data > 0 then
        vim.api.nvim_echo({ { "Processing with warnings...", "WarningMsg" } }, false, {
          id = message_id,
          kind = "progress",
          status = "running",
          percent = 50,
        })
      end
    end,

    on_exit = function(_, code)
      if code == 0 then
        vim.api.nvim_echo({ { "Compilation finished successfully!", "MoreMsg" } }, true, {
          id = message_id,
          kind = "progress",
          status = "success",
          percent = 100,
        })
      else
        vim.api.nvim_echo({ { "Compilation failed! Exit code: " .. code, "ErrorMsg" } }, true, {
          id = message_id,
          kind = "progress",
          status = "failed",
          percent = 100,
        })
      end
    end,
  })
end

return M
