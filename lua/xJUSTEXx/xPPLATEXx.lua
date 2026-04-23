local M = {}

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
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buf = buf, silent = true })
  vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", { buf = buf, silent = true })

  return buf, win
end

local function get_main_file_name()
  local cwd = vim.uv.cwd()
  local justfile = vim.fs.joinpath(cwd, ".justfile")
  if vim.uv.fs_stat(justfile) == nil then
    return nil
  end

  local lines = vim.fn.readfile(justfile)
  for _, line in ipairs(lines) do
    local main_file = line:match('main_file%s*:=%s*"([^"]+)"')
    if main_file then
      return vim.fs.joinpath(cwd, main_file)
    end
  end
  return nil
end

--- Function to run pplatex on the current file and display the log
function M.xPPLATEXx()
  local main_tex = get_main_file_name()

  if not main_tex then
    return vim.notify(
      "Justfile not found in the project root. Can't determine log file.",
      vim.log.levels.ERROR
    )
  end

  local log_file = main_tex:gsub("%.tex$", ".log")

  if vim.fn.filereadable(log_file) == 0 then
    return vim.notify("Log file not found", vim.log.levels.WARN)
  end

  vim.system({ "pplatex", "-i", log_file }, { text = true }, function(obj)
    vim.schedule(function()
      if obj.code ~= 0 and (not obj.stdout or obj.stdout == "") then
        return vim.notify("pplatex failed", vim.log.levels.ERROR)
      end

      local lines = vim.split(obj.stdout, "\n")
      create_floating_window("xJUSTEXx log", lines)
    end)
  end)
end

return M
