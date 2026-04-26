local M = {}

local config = require("xJUSTEXx.config")

---@param msg string
---@param level integer|nil
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

  if sanitized:sub(1, 1) == "-" then
    sanitized = "p" .. sanitized
  end

  return sanitized
end

---@param name string
---@param dir string
---@return boolean, string|nil
local function validate_setup(name, dir)
  if not name or name == "" then
    return false, "Invalid project name"
  end
  if not dir or dir == "" then
    return false, "Invalid directory"
  end
  return true
end

---@param project_path string
---@return boolean
local function delete_existing_project(project_path)
  local confirm = vim.fn.confirm("Overwrite existing project?", "&Yes\n&No", 2)
  if confirm ~= 1 then
    return false
  end

  local delete = vim.fn.delete(project_path, "rf")
  if delete ~= 0 then
    notify("Failed to remove existing directory", vim.log.levels.ERROR)
    return false
  end

  return true
end

---@param project_path string
---@return boolean
local function prepare_directory(project_path)
  local stat = vim.uv.fs_stat(project_path)

  if stat and not delete_existing_project(project_path) then
    return false
  end

  local ok, err = pcall(vim.fn.mkdir, project_path, "p")
  if not ok then
    notify("Failed to create project directory: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end

  return true
end

---@param file_path string
---@param content string
---@return boolean
local function write_file(file_path, content)
  local ok = pcall(vim.fn.writefile, vim.split(content, "\n"), file_path)
  if not ok then
    notify("Failed to write file: " .. file_path, vim.log.levels.ERROR)
    return false
  end
  return true
end

---@param project_path string
---@param project_name string
---@param template_content string
---@return string|nil
local function create_project_files(project_path, project_name, template_content)
  local main_tex = vim.fs.joinpath(project_path, project_name .. ".tex")
  local justfile = vim.fs.joinpath(project_path, ".justfile")

  if not write_file(main_tex, template_content) then
    return nil
  end

  local justfile_content = config.set_file_justfile(project_name)
  if not write_file(justfile, justfile_content) then
    return nil
  end

  return main_tex
end

---@param main_tex string
local function open_main_file(main_tex)
  vim.cmd("edit " .. vim.fn.fnameescape(main_tex))
end

---@param project_path string
---@param clean_name string
---@param template_content string
local function initialize_git_and_files(project_path, clean_name, template_content)
  vim.system({ "git", "init" }, { cwd = project_path }, function(obj)
    vim.schedule(function()
      if obj.code ~= 0 then
        notify("Can't initialize Git", vim.log.levels.ERROR)
        return
      end

      local main_tex = create_project_files(project_path, clean_name, template_content)
      if not main_tex then
        return
      end

      open_main_file(main_tex)
      notify("Project  " .. clean_name .. " ready!")
    end)
  end)
end

---@param name string
---@param dir string
---@param template string
local function setup_project(name, dir, template)
  local is_valid, error_msg = validate_setup(name, dir)
  if not is_valid then
    return notify("Error: " .. error_msg, vim.log.levels.ERROR)
  end

  local clean_name = sanitize_project_name(name)
  if clean_name == "" then
    return notify("Invalid project name", vim.log.levels.ERROR)
  end

  local project_path = vim.fs.joinpath(dir, clean_name)

  if not prepare_directory(project_path) then
    return
  end

  initialize_git_and_files(project_path, clean_name, template)
end

---@param selected_dir string
local function show_template_and_name_wizard(selected_dir)
  local templates = config.options.tex_templates

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

--- Function to create a new project
function M.xNEW_PROJECTx()
  local dirs = config.options.project_dirs

  if #dirs == 0 then
    return notify("No project directories defined", vim.log.levels.WARN)
  end

  if #dirs == 1 then
    show_template_and_name_wizard(dirs[1])
  else
    vim.ui.select(dirs, { prompt = "Select Directory:" }, show_template_and_name_wizard)
  end
end

return M
