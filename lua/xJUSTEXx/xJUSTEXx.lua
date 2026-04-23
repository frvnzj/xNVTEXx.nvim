local M = {}

local config = require("xJUSTEXx.config")

local function notify(msg, level)
  vim.notify("xJUSTEXx: " .. msg, level or vim.log.levels.INFO)
end

---Sanitize the project name internationally
---@param str string
---@return string
local function sanitize_project_name(str)
  local translation_table = {
    ["á"] = "a",
    ["é"] = "e",
    ["í"] = "i",
    ["ó"] = "o",
    ["ú"] = "u",
    ["ü"] = "u",
    ["ñ"] = "n",
    ["ç"] = "c",
    ["Á"] = "A",
    ["É"] = "E",
    ["Í"] = "I",
    ["Ó"] = "O",
    ["Ú"] = "U",
    ["Ü"] = "U",
    ["Ñ"] = "N",
    ["Ç"] = "C",
    ["à"] = "a",
    ["è"] = "e",
    ["ì"] = "i",
    ["ò"] = "o",
    ["ù"] = "u",
    ["â"] = "a",
    ["ê"] = "e",
    ["î"] = "i",
    ["ô"] = "o",
    ["û"] = "u",
    ["ä"] = "a",
    ["ë"] = "e",
    ["ï"] = "i",
    ["ö"] = "o",
    ["ß"] = "ss",
  }

  local sanitized = str:gsub("[%z\1-\127\194-\244][\128-\191]*", function(c)
    return translation_table[c] or c
  end)

  sanitized = sanitized:gsub("[%s%.]+", "_")
  sanitized = sanitized:gsub("[^%w%-_]", "")

  if sanitized == "" then
    sanitized = "project"
  end
  if sanitized:sub(1, 1) == "-" then
    sanitized = "p" .. sanitized
  end

  return sanitized
end

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

local function prepare_directory(project_path)
  local stat = vim.uv.fs_stat(project_path)

  if stat then
    local confirm = vim.fn.confirm("Overwrite existing project?", "&Yes\n&No", 2)
    if confirm ~= 1 then
      return false
    end

    local ok = pcall(vim.fn.delete, project_path, "rf")
    if not ok then
      notify("Failed to remove existing directory", vim.log.levels.ERROR)
      return false
    end
  end

  local ok = pcall(vim.fn.mkdir, project_path, "p")
  if not ok then
    notify("Failed to create project directory", vim.log.levels.ERROR)
    return false
  end

  return true
end

local function create_project_files(project_path, project_name, template_content)
  local main_tex = vim.fs.joinpath(project_path, project_name .. ".tex")
  local justfile = vim.fs.joinpath(project_path, ".justfile")

  vim.fn.writefile(vim.split(template_content, "\n"), main_tex)

  local justfile_content = config.set_file_justfile(project_name)
  vim.fn.writefile(vim.split(justfile_content, "\n"), justfile)

  return main_tex
end

--- Function to set up the project directory and files
---@param name string: Name of the project
---@param dir string: Directory where the project will be created
---@param template string: Content of the template to use
local function setup_project(name, dir, template)
  local clean_name = sanitize_project_name(name)
  if clean_name == "" then
    return notify("Invalid project name", vim.log.levels.ERROR)
  end

  local project_path = vim.fs.joinpath(dir, clean_name)

  if not prepare_directory(project_path) then
    return
  end

  vim.system({ "git", "init" }, { cwd = project_path }, function(obj)
    vim.schedule(function()
      if obj.code ~= 0 then
        notify("Can't initialize Git", vim.log.levels.ERROR)
      end

      local main_tex = create_project_files(project_path, clean_name, template)

      vim.cmd("edit " .. vim.fn.fnameescape(main_tex))
      vim.notify("Project  " .. clean_name .. " ready!")
    end)
  end)
end

--- Function to create a new project
function M.xNEW_PROJECTx()
  local dirs = config.options.project_dirs
  local templates = config.options.tex_templates

  if #dirs == 0 then
    vim.notify("No project directories defined", vim.log.levels.WARN)
    return
  end

  local function start_wizard(selected_dir)
    vim.ui.select(vim.tbl_keys(templates), {
      prompt = "Select Template:",
      format_item = function(key)
        return templates[key].name
      end,
    }, function(template_key)
      if not template_key then
        return
      end

      vim.ui.input({ prompt = "Project name: " }, function(name)
        if name and name ~= "" then
          setup_project(name, selected_dir, templates[template_key].content)
        end
      end)
    end)
  end

  if #dirs == 1 then
    start_wizard(dirs[1])
  else
    vim.ui.select(dirs, { prompt = "Select Directory:" }, start_wizard)
  end
end

return M
