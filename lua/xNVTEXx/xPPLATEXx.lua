local M = {}

local u = require("xNVTEXx.utils")

---xPPLATEXx window
---@param title string
---@param content string[]
---@return integer buf, integer win
local function create_floating_window(title, content)
  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)

  local win_config = {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
  }

  local win = vim.api.nvim_open_win(buf, true, win_config)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)

  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buf = buf, silent = true })

  return buf, win
end

--- Function to run pplatex on the current file and display the log
function M.xPPLATEXx()
  local main_file, project_root = u.get_main_file_name()

  if not main_file or not project_root then
    return
  end

  local log_name = main_file:gsub("%.tex$", ".log")
  local log_file = vim.fs.joinpath(project_root, log_name)

  if vim.fn.filereadable(log_file) == 0 then
    u.notify_warn("Log file not found")
    return
  end

  vim.system({ "pplatex", "-i", log_file }, { text = true, cwd = project_root }, function(obj)
    vim.schedule(function()
      if obj.code ~= 0 and (not obj.stdout or obj.stdout == "") then
        u.notify_err("pplatex failed")
        return
      end

      local lines = vim.split(obj.stdout, "\n")
      create_floating_window("xNVTEXx: " .. log_name, lines)
    end)
  end)
end

return M
