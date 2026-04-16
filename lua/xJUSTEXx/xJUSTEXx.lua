local M = {}

local config = require("xJUSTEXx.config")

local function join(...)
  return vim.fs.joinpath(...)
end

local function remove_accents(str)
  local accents = {
    ["á"] = "a",
    ["é"] = "e",
    ["í"] = "i",
    ["ó"] = "o",
    ["ú"] = "u",
    ["Á"] = "A",
    ["É"] = "E",
    ["Í"] = "I",
    ["Ó"] = "O",
    ["Ú"] = "U",
    ["ñ"] = "n",
    ["Ñ"] = "N",
  }
  local sanitized = str:gsub("[áéíóúÁÉÍÓÚñÑ]", accents)
  return sanitized:gsub("%s+", "_"):gsub('[/\\:%*%?"<>|]', "")
end

local function safe_execute(fn, error_msg)
  local success, err = pcall(fn)
  if not success then
    vim.notify(error_msg .. ": " .. tostring(err), vim.log.levels.ERROR)
  end
  return success
end

local function schedule(fn)
  vim.schedule(fn)
end

local function get_window_config(width, height)
  return {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
  }
end

local function create_floating_window(title, content)
  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)

  local win_config = get_window_config(width, height)
  win_config.title = title

  local win = vim.api.nvim_open_win(buf, true, win_config)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)

  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype = "nofile"
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buf = buf, silent = true })
  vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", { buf = buf, silent = true })

  return buf, win
end

local function validate_and_create_directory(project_path)
  local stat = vim.uv.fs_stat(project_path)

  if stat and stat.type == "directory" then
    local confirm = vim.fn.confirm("Overwrite existing project?", "&Yes\n&No", 2)
    if confirm ~= 1 then
      return false
    end
    if
      not safe_execute(function()
        vim.fn.delete(project_path, "rf")
      end, "Failed to remove existing directory")
    then
      return false
    end

    return safe_execute(function()
      vim.fn.mkdir(project_path, "p")
    end, "Failed to create project directory")
  end

  return safe_execute(function()
    vim.fn.mkdir(project_path, "p")
  end, "Failed to create project directory")
end

local function init_git_repo(project_path, callback)
  vim.system({ "git", "init" }, { cwd = project_path }, function(obj)
    if obj.code ~= 0 then
      schedule(function()
        vim.notify("Git initialization warning", vim.log.levels.WARN)
      end)
    else
      schedule(function()
        if callback then
          callback()
        end
      end)
    end
  end)
end

local function create_project_files(project_path, project_name, template_content)
  local main_tex = join(project_path, project_name .. ".tex")
  local justfile = join(project_path, ".justfile")

  safe_execute(function()
    vim.fn.writefile(vim.split(template_content, "\n"), main_tex)
  end, "Failed to create main .tex file")

  safe_execute(function()
    local justfile_content = config.set_file_justfile(project_name)
    vim.fn.writefile(vim.split(justfile_content, "\n"), justfile)
  end, "Failed to create .justfile")

  return main_tex
end

--- Function to set up the project directory and files
---@param project_name string: Name of the project
---@param project_dir string: Directory where the project will be created
---@param template_content string: Content of the template to use
local function setup_project(project_name, project_dir, template_content)
  local correct_name = remove_accents(project_name)

  if correct_name == "" then
    vim.notify("Invalid project name", vim.log.levels.ERROR)
    return
  end

  local project_path = join(project_dir, correct_name)

  if not validate_and_create_directory(project_path) then
    return
  end

  init_git_repo(project_path, function()
    local main_tex = create_project_files(project_path, correct_name, template_content)

    vim.cmd("edit " .. vim.fn.fnameescape(main_tex))
    vim.notify("Project  " .. correct_name .. " ready!", vim.log.levels.INFO)
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

  local function select_template(selected_dir)
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
    select_template(dirs[1])
  else
    vim.ui.select(dirs, { prompt = "Select Directory:" }, select_template)
  end
end

--- Function to open LaTeX documentation for the word under the cursor
function M.xTEXDOCx()
  local package = vim.fn.expand("<cword>")

  if package == "" then
    vim.notify("No package selected", vim.log.levels.WARN)
    return
  end

  vim.system({ "texdoc", package }, {}, function(obj)
    if obj.code ~= 0 then
      schedule(function()
        vim.notify("No doc found for '" .. package .. "'", vim.log.levels.WARN)
      end)
    end
  end)
end

--- Function to run pplatex on the current file and display the log
function M.xPPLATEXx()
  local log_file = vim.fn.expand("%:p:r") .. ".log"

  if vim.fn.filereadable(log_file) == 0 then
    vim.notify("Log file not found", vim.log.levels.WARN)
    return
  end

  vim.system({ "pplatex", "-i", log_file }, { text = true }, function(obj)
    schedule(function()
      if obj.code ~= 0 and obj.stdout == "" then
        vim.notify("pplatex failed", vim.log.levels.ERROR)
        return
      end

      local lines = vim.split(obj.stdout, "\n")
      create_floating_window("xJUSTEXx log", lines)
    end)
  end)
end

return M
