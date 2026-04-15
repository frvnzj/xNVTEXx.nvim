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
  local sanitized = str:gsub("[%z\1-\127\194-\244][\128-\191]*", accents)
  return sanitized:gsub("%s+", "_"):gsub('[/\\:%*%?"<>|]', "")
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
  local stat = vim.uv.fs_stat(project_path)

  if stat and stat.type == "directory" then
    local confirm = vim.fn.confirm("Overwrite existing project '" .. correct_name .. "'?", "&Yes\n&No", 2)
    if confirm ~= 1 then
      return
    end
    vim.fn.delete(project_path, "rf")
  end

  vim.fn.mkdir(project_path, "p")
  vim.system({ "git", "init" }, { cwd = project_path })

  local main_tex = join(project_path, correct_name .. ".tex")
  local justfile = join(project_path, ".justfile")

  vim.fn.writefile(vim.split(template_content, "\n"), main_tex)
  vim.fn.writefile(vim.split(config.set_file_justfile(correct_name), "\n"), justfile)

  vim.cmd("edit " .. vim.fn.fnameescape(main_tex))
  vim.notify("Project  " .. correct_name .. " ready!", vim.log.levels.INFO)
end

--- Function to create a new project
function M.xNEW_PROJECTx()
  local dirs = config.options.project_dirs
  local templates = config.options.tex_templates

  local function proceed_with_template(selected_dir)
    vim.ui.select(vim.tbl_keys(templates), {
      prompt = "Select Template:",
      format_item = function(k)
        return templates[k].name
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

  if #dirs == 0 then
    vim.notify("No project directories defined", vim.log.levels.WARN)
  elseif #dirs == 1 then
    proceed_with_template(dirs[1])
  else
    vim.ui.select(dirs, { prompt = "Select Directory:" }, proceed_with_template)
  end
end

--- Function to open LaTeX documentation for the word under the cursor
function M.xTEXDOCx()
  local package = vim.fn.expand("<cword>")

  if package == "" then
    return
  end

  vim.system({ "texdoc", package }, {}, function(obj)
    if obj.code ~= 0 then
      vim.schedule(function()
        vim.notify("No doc found for " .. package, vim.log.levels.WARN)
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
    vim.schedule(function()
      if obj.code ~= 0 and obj.stdout == "" then
        vim.notify("pplatex failed", vim.log.levels.ERROR)
        return
      end

      local buf = vim.api.nvim_create_buf(false, true)
      local width = math.floor(vim.o.columns * 0.8)
      local height = math.floor(vim.o.lines * 0.8)

      vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = (vim.o.lines - height) / 2,
        col = (vim.o.columns - width) / 2,
        style = "minimal",
        border = "rounded",
        title = "Justex Log",
      })

      vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(obj.stdout, "\n"))
      vim.bo[buf].modifiable = false
      vim.keymap.set("n", "q", "<cmd>close<cr>", { buf = buf, silent = true })
    end)
  end)
end

return M
