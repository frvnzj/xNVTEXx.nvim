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

---Makes an HTTP GET request using curl asynchronously
---@param url string
---@param headers table|nil Header Dictionary { ["Authorization"] = "Bearer ..." }
---@param cb function Function callback(stdout, stderr)
function M.http_get(url, headers, cb)
  local args = { "curl", "-sSL", url }

  if headers then
    for k, v in pairs(headers) do
      table.insert(args, "-H")
      table.insert(args, k .. ": " .. v)
    end
  end

  vim.system(args, { text = true }, function(obj)
    vim.schedule(function()
      if obj.code ~= 0 then
        local stderr_clean = obj.stderr and vim.trim(obj.stderr) or ""
        local error_msg = (stderr_clean ~= "") and stderr_clean
          or ("Connection error (Code " .. obj.code .. ")")
        cb(nil, error_msg)
      else
        cb(obj.stdout, nil)
      end
    end)
  end)
end

---Sanitize project name for filesystem compatibility
---Removes accents, replaces spaces with underscores, removes special characters
---@param str string The raw project/file name
---@return string Sanitized string
function M.sanitize_name(str)
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

---Request user confirmation for overwriting or appending an action
---@param prompt_msg string The message to show the user
---@return boolean user_confirmed
function M.confirm_action(prompt_msg)
  local choice = vim.fn.confirm(prompt_msg, "&Yes\n&No", 2)
  return choice == 1
end

---Write content string cleanly to a target file (Creates file if missing, overwrites if existing)
---@param file_path string Full path to file
---@param content string File content to write
---@return boolean success
function M.write_file(file_path, content)
  if not content or content == "" then
    return false
  end

  local lines = vim.split(content, "\n")
  local ok = pcall(vim.fn.writefile, lines, file_path)

  if not ok then
    M.notify_err("Failed to write file: " .. file_path)
    return false
  end

  return true
end

return M
