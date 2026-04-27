local M = {}

local CTAN_MIRROR = "https://mirrors.mit.edu/CTAN"
local CTAN_API_BASE = "https://www.ctan.org/json/2.0"
local CACHE_DIR = "ctan_docs"

local FILE_ICONS = {
  pdf = " ",
  md = " ",
  html = " ",
  txt = " ",
}

---@param msg string
---@param level integer|nil
local function notify(msg, level)
  vim.notify("xCTANx: " .. msg, level or vim.log.levels.INFO)
end

---@param url string
---@param cb function
local function http_get(url, cb)
  vim.system({ "curl", "-sSL", url }, { text = true }, function(obj)
    vim.schedule(function()
      if obj.code ~= 0 then
        cb(nil, "Error fetching data: " .. obj.code)
      else
        cb(obj.stdout, nil)
      end
    end)
  end)
end

---@param doc_path string
---@return string URL
local function build_full_url(doc_path)
  local clean_path = doc_path:gsub("^ctan:", ""):gsub("^/+", "")
  return CTAN_MIRROR .. "/" .. clean_path:gsub(" ", "%%20")
end

---@param path string
---@return string extension
local function get_file_extension(path)
  return path:match("%.([%a%d]+)$") or ""
end

---@param path string
---@return boolean
local function is_readme_file(path)
  return path:match("README") ~= nil
end

---@return string
local function get_cache_dir()
  local cache_path = vim.fn.stdpath("cache") .. "/" .. CACHE_DIR .. "/"
  vim.fn.mkdir(cache_path, "p")
  return cache_path
end

---@param path string
---@return string filename
local function generate_cache_filename(path)
  local filename = path:match("([^/]+)$"):gsub("%%20", "_")
  if not filename:match("%.") then
    filename = filename .. ".txt"
  end
  return filename
end

---@param url string
local function open_pdf(url)
  notify("Opening PDF with Zathura...")
  vim.system({ "zathura", url }, { detach = true })
end

---@param url string
local function open_html(url)
  notify("Opening in browser...")
  vim.system({ "xdg-open", url }, { detach = true })
end

---@param url string
---@param path string
local function open_text_document(url, path)
  local cache_dir = get_cache_dir()
  local filename = generate_cache_filename(path)
  local tmp_file = cache_dir .. filename

  notify("Downloading document...")

  vim.system({ "curl", "-sSL", "-o", tmp_file, url }, {}, function(obj)
    vim.schedule(function()
      if obj.code == 0 and vim.fn.filereadable(tmp_file) == 1 then
        vim.cmd("view " .. vim.fn.fnameescape(tmp_file))
      else
        notify("Error downloading: " .. url, vim.log.levels.ERROR)
      end
    end)
  end)
end

---@param url string
---@param path string
local function open_document(url, path)
  local ext = get_file_extension(path)
  local is_readme = is_readme_file(path)

  if ext == "pdf" then
    open_pdf(url)
  elseif ext == "html" then
    open_html(url)
  elseif ext == "md" or ext == "txt" or is_readme then
    open_text_document(url, path)
  else
    notify("Unsupported format: " .. ext, vim.log.levels.WARN)
  end
end

---@param cb function
local function fetch_package_list(cb)
  http_get(CTAN_API_BASE .. "/packages", function(body, err)
    if err or not body then
      return cb(nil, err or "No response body")
    end

    local ok, packages = pcall(vim.fn.json_decode, body)
    if not ok or not packages then
      return cb(nil, "Error decoding JSON response")
    end

    cb(packages, nil)
  end)
end

---@param package_key string
---@param cb function
local function fetch_package_docs(package_key, cb)
  http_get(CTAN_API_BASE .. "/pkg/" .. package_key, function(body, err)
    if err or not body then
      return cb(nil, err or "Empty response")
    end

    local ok, pkg_data = pcall(vim.fn.json_decode, body)
    if not ok or not pkg_data or not pkg_data.documentation then
      return cb(nil, "No documentation available")
    end

    cb(pkg_data.documentation, nil)
  end)
end

---@param packages table
---@return table
local function build_package_list(packages)
  local package_list = {}
  for _, pkg in ipairs(packages) do
    table.insert(package_list, {
      display = string.format("%s - %s", pkg.key, pkg.caption or "No description"),
      key = pkg.key,
    })
  end
  return package_list
end

---@param documentation table
---@return table
local function build_doc_list(documentation)
  local doc_list = {}
  for _, doc in ipairs(documentation) do
    table.insert(doc_list, {
      display = string.format("%s - %s", doc.details or "Documentation", doc.href),
      href = doc.href,
    })
  end
  return doc_list
end

---@param item table
---@return string
local function format_package_item(item)
  return " " .. item.display
end

---@param item table
---@return string
local function format_doc_item(item)
  local ext = get_file_extension(item.href)
  local icon = FILE_ICONS[ext] or ""
  return icon .. item.display
end

function M.xSEARCH_CTANx()
  notify("Fetching package list...")

  fetch_package_list(function(packages, err)
    if err or not packages then
      return notify(err or "Failed to fetch packages", vim.log.levels.ERROR)
    end

    local package_list = build_package_list(packages)

    vim.ui.select(package_list, {
      prompt = "CTAN package  > ",
      format_item = format_package_item,
    }, function(selected)
      if not selected then
        return
      end

      notify("Fetching documentation...")
      fetch_package_docs(selected.key, function(docs, doc_err)
        if doc_err or not docs then
          return notify(doc_err or "No documentation found", vim.log.levels.ERROR)
        end

        local doc_list = build_doc_list(docs)

        vim.ui.select(doc_list, {
          prompt = selected.key .. " Documentation > ",
          format_item = format_doc_item,
        }, function(doc_selected)
          if not doc_selected then
            return
          end

          local full_url = build_full_url(doc_selected.href)
          open_document(full_url, doc_selected.href)
        end)
      end)
    end)
  end)
end

return M
