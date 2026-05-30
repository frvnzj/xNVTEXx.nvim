---@description Module for creating and initializing LaTeX projects with Git integration
---Provides utilities for project scaffolding, file generation, and workspace setup

local M = {}

local config = require("xNVTEXx.config")
local u = require("xNVTEXx.utils")

---Sanitize project name for filesystem compatibility
---Removes accents, replaces spaces with underscores, removes special characters
---@param str string The raw project name
---@return string Sanitized project name
---@example
---local sanitized = sanitize_project_name("Proyecto Español")
--- -- returns: "Proyecto_Espanol"
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

---Validate project setup parameters
---@param name string|nil The project name
---@param dir string|nil The target directory
---@return boolean is_valid
---@return string|nil error_message
local function validate_setup(name, dir)
  if not name or name == "" then
    return false, "Project name is required and cannot be empty"
  end

  if not dir or dir == "" then
    return false, "Target directory is required and cannot be empty"
  end

  if not vim.fn.isdirectory(dir) then
    return false, string.format("Directory '%s' does not exist", dir)
  end

  return true
end

---Request user confirmation for overwriting existing project
---@param project_path string Path to existing project
---@return boolean user_confirmed
local function confirm_overwrite(project_path)
  local choice =
    vim.fn.confirm(string.format("'%s' already exists. Overwrite?", project_path), "&Yes\n&No", 2)
  return choice == 1
end

---Recursively delete directory contents
---@param project_path string Path to delete
---@return boolean success
---@return string|nil error_message
local function delete_directory_recursive(project_path)
  local result = vim.fn.delete(project_path, "rf")

  if result ~= 0 then
    return false, string.format("Failed to remove directory '%s'", project_path)
  end

  return true
end

---Prepare project directory (create or confirm overwrite)
---@param project_path string Full path to project directory
---@return boolean success
---@return string|nil error_message
local function prepare_directory(project_path)
  local stat = vim.uv.fs_stat(project_path)

  if stat then
    if not confirm_overwrite(project_path) then
      return false, "Project creation cancelled by user"
    end

    local ok, err = delete_directory_recursive(project_path)
    if not ok then
      u.notify_err(tostring(err))
      return false, err
    end
  end

  local ok, err = pcall(vim.fn.mkdir, project_path, "p")
  if not ok then
    local msg = string.format("Failed to create project directory: %s", tostring(err))
    u.notify_err(msg)
    return false, msg
  end

  return true
end

---Write content to file
---@param file_path string Full path to file
---@param content string File content to write
---@return boolean success
---@return string|nil error_message
local function write_file(file_path, content)
  if not content or content == "" then
    return false, "Cannot write empty content to file"
  end

  local lines = vim.split(content, "\n")
  local ok = pcall(vim.fn.writefile, lines, file_path)

  if not ok then
    local msg = string.format("Failed to write file: %s", file_path)
    u.notify_err(msg)
    return false, msg
  end

  return true
end

---Create all project files (main.tex, .gitignore)
---@param project_path string Root project directory
---@param project_name string Sanitized project name
---@param template_content string Template content for main .tex file
---@return string|nil main_tex_path Path to created main .tex file, nil on error
local function create_project_files(project_path, project_name, template_content)
  local main_tex = vim.fs.joinpath(project_path, project_name .. ".tex")
  local gitignore = vim.fs.joinpath(project_path, ".gitignore")

  if not write_file(main_tex, template_content) then
    return nil
  end

  if config.options.gitignore and config.options.gitignore.enabled then
    local gitignore_content = config.options.gitignore.content or ""
    if not write_file(gitignore, gitignore_content) then
      return nil
    end
  end

  return main_tex
end

--- Open main LaTeX file in editor
---@param main_tex string Full path to main .tex file
local function open_main_file(main_tex)
  if not main_tex or main_tex == "" then
    u.notify_err("Invalid file path provided")
    return
  end

  vim.cmd("edit " .. vim.fn.fnameescape(main_tex))
end

---Initialize Git repository and create project files
---@param project_path string Root project directory
---@param clean_name string Sanitized project name
---@param template_content string Template for main .tex file
local function initialize_git_and_files(project_path, clean_name, template_content)
  vim.system({ "git", "init" }, { cwd = project_path }, function(obj)
    vim.schedule(function()
      if obj.code ~= 0 then
        local err_msg = string.format("Git initialization failed (code: %d)", obj.code)
        u.notify_err(err_msg)
        return
      end

      local main_tex = create_project_files(project_path, clean_name, template_content)
      if not main_tex then
        return
      end

      open_main_file(main_tex)
      u.notify(string.format("Project '%s' ready!", clean_name))
    end)
  end)
end

---Setup a new LaTeX project with all scaffolding
---@param name string Raw project name (will be sanitized)
---@param dir string Target directory
---@param template string Template content for main .tex file
local function setup_project(name, dir, template)
  local is_valid, error_msg = validate_setup(name, dir)
  if not is_valid then
    u.notify_err(string.format("Setup error: %s", error_msg))
    return
  end

  local clean_name = sanitize_project_name(name)
  if clean_name == "" then
    u.notify_err("Project name cannot be empty after sanitization")
    return
  end

  local project_path = vim.fs.joinpath(dir, clean_name)

  if not prepare_directory(project_path) then
    return
  end

  initialize_git_and_files(project_path, clean_name, template)
end

---Show template selection and project name input
---@param selected_dir string Target directory for project
local function prompt_template_and_project_name(selected_dir)
  local templates = config.options.tex_templates

  if not templates or vim.tbl_isempty(templates) then
    u.notify_warn("No templates available. Check your configuration")
    return
  end

  vim.ui.select(vim.tbl_keys(templates), {
    prompt = " Select a template ",
    format_item = function(key)
      return templates[key].name or key
    end,
  }, function(template_key)
    if not template_key then
      u.notify("Template selection cancelled")
      return
    end

    vim.ui.input({ prompt = " Project name " }, function(name)
      if not name or name == "" then
        u.notify("Project creation cancelled: no name provided")
        return
      end

      local template_content = templates[template_key].content
      if not template_content then
        u.notify_err("Selected template has no content")
        return
      end

      setup_project(name, selected_dir, template_content)
    end)
  end)
end

---Create a new LaTeX project
---@public
function M.xNEW_PROJECTx()
  local dirs = config.options.project_dirs

  if not dirs or #dirs == 0 then
    u.notify_warn("No project directories configured. Check your setup")
    return
  end

  if #dirs == 1 then
    prompt_template_and_project_name(dirs[1])
  else
    vim.ui.select(dirs, { prompt = " Select a project directory " }, function(selected_dir)
      if not selected_dir then
        u.notify("Directory selection cancelled")
        return
      end
      prompt_template_and_project_name(selected_dir)
    end)
  end
end

---Generate .gitignore file in project root
---@public
function M.xGITIGNOREx()
  if not config.options.gitignore or not config.options.gitignore.enabled then
    u.notify_warn("gitignore option is disabled. Can't create .gitignore")
    return
  end

  local current_file = vim.api.nvim_buf_get_name(0)
  local current_dir = (current_file ~= "" and vim.bo.buftype == "") and vim.fs.dirname(current_file)
    or vim.fn.getcwd()

  local root_patterns = { ".git" }
  local root_dir = vim.fs.root(current_dir, root_patterns)

  if not root_dir then
    u.notify_err("Git repository or project root not found. Cannot create .gitignore")
    return
  end

  local gitignore_path = vim.fs.joinpath(root_dir, ".gitignore")
  local stat = vim.uv.fs_stat(gitignore_path)

  if stat then
    if not confirm_overwrite(gitignore_path) then
      u.notify(".gitignore overwrite cancelled by user")
      return
    end
  end

  local gitignore_content = config.options.gitignore.content or ""
  local ok, err = pcall(vim.fn.writefile, vim.split(gitignore_content, "\n"), gitignore_path)

  if ok then
    u.notify(".gitignore generated successfully at project root")
  else
    u.notify_err(string.format("Failed to write .gitignore: %s", tostring(err)))
  end
end

return M
