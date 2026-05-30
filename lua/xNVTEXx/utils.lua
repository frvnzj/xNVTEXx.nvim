local M = {}

---@enum NotifyLevel
M.LOG = {
  ERROR = vim.log.levels.ERROR,
  WARN = vim.log.levels.WARN,
  INFO = vim.log.levels.INFO,
}

local ROOT_PATTERNS = { ".git", ".gitignore" }
local COMMON_MAIN_FILES = { "main.tex", "root.tex", "index.tex", "master.tex" }

---Notify user with consistent prefix
---@param msg string The notification message
function M.notify(msg)
  vim.notify("xNVTEXx: " .. msg, M.LOG.INFO)
end

---Notify user with consistent prefix
---@param msg string The notification message
function M.notify_err(msg)
  vim.notify("xNVTEXx: " .. msg, M.LOG.ERROR)
end

---Notify user with consistent prefix
---@param msg string The notification message
function M.notify_warn(msg)
  vim.notify("xNVTEXx: " .. msg, M.LOG.WARN)
end

-- Initial global cache to avoid forbidden calls in fast-event threads (E5560)
local IS_DEBUG = vim.env.XNVTEXX_DEBUG == "1"

---Log internal debug message
---@param msg_cb function|string
---@param level integer|nil
function M.debug_log(msg_cb, level)
  if IS_DEBUG then
    local msg = type(msg_cb) == "function" and msg_cb() or msg_cb
    vim.notify("[DEBUG] xNVTEXx: " .. msg, level or M.LOG.INFO)
  end
end

---Check if a tex file contains 'begin document'
---@param file_path string
---@return boolean
local function file_has_document_start(file_path)
  if vim.fn.filereadable(file_path) ~= 1 then
    return false
  end
  local lines = vim.fn.readfile(file_path, "", 150)
  for _, line in ipairs(lines) do
    if line:match("\\begin%s*{document}") then
      return true
    end
  end
  return false
end

---Search directories for the main file
---@param start_dir string
---@return string|nil main_file file name
---@return string|nil project_root Root directory path
local function scan_tree_for_main(start_dir)
  local dir = start_dir

  for _ = 1, 4 do
    if not dir or dir == "" or dir == vim.env.HOME or dir == "/" then
      M.debug_log("Tree scanner stopped safely before scanning system/home directory")
      break
    end

    local files = vim.fn.globpath(dir, "*.tex", true, true)
    for _, file_path in ipairs(files) do
      if file_has_document_start(file_path) then
        local main_file = vim.fn.fnamemodify(file_path, ":t")
        M.debug_log("Tree scanner found master file " .. main_file .. " at " .. dir)
        return main_file, dir
      end
    end

    local parent = vim.fs.dirname(dir)
    if parent == dir then
      break
    end
    dir = parent
  end

  return nil, nil
end

---Find the main file
---@param project_root string
---@return string|nil
local function find_main_file(project_root)
  local current_file = vim.fn.expand("%:t")
  local is_tex = vim.bo.filetype == "tex" or vim.bo.filetype == "plaintex"

  for _, name in ipairs(COMMON_MAIN_FILES) do
    local found = vim.fs.find(name, { path = project_root, limit = 1 })[1]
    if found then
      local result = vim.fn.fnamemodify(found, ":t")
      M.debug_log("Found common main file - " .. result)
      return result
    end
  end

  local folder_name = vim.fn.fnamemodify(project_root, ":t")
  if folder_name ~= "" then
    local expected_file = folder_name .. ".tex"
    local found = vim.fs.find(expected_file, { path = project_root, limit = 1 })[1]
    if found then
      M.debug_log("Found main file matching folder name - " .. expected_file)
      return expected_file
    end
  end

  if current_file ~= "" and is_tex then
    M.debug_log("Fallback to current file")
    return current_file
  end

  return nil
end

---Gets the name of the main project file and project root
---@return string|nil main_file
---@return string|nil project_root
function M.get_main_file_name()
  local buf_file_name = vim.api.nvim_buf_get_name(0)
  local current_dir = (buf_file_name ~= "" and vim.bo.buftype == "")
      and vim.fs.dirname(buf_file_name)
    or vim.fn.getcwd()

  local is_tex = vim.bo.filetype == "tex" or vim.bo.filetype == "plaintex"

  if is_tex and buf_file_name ~= "" and file_has_document_start(buf_file_name) then
    M.debug_log("Current buffer is verified directly as main file")
    return vim.fn.fnamemodify(buf_file_name, ":t"), current_dir
  end

  local main_file, project_root = scan_tree_for_main(current_dir)

  if main_file and project_root then
    return main_file, project_root
  end

  project_root = vim.fs.root(current_dir, ROOT_PATTERNS) or current_dir
  main_file = find_main_file(project_root)

  if not main_file then
    M.notify_warn("Could not determine a main file name. Save your file first")
    return nil, nil
  end

  return main_file, project_root
end

return M
