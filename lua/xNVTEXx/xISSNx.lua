local M = {}

local u = require("xNVTEXx.utils")

M._last_article = nil
M._last_results = nil

local CROSSREF_API = "https://api.crossref.org"

local function get_bib_target_path()
  local _, project_root = u.get_main_file_name()

  if not project_root then
    local buf_name = vim.api.nvim_buf_get_name(0)
    project_root = buf_name ~= "" and vim.fs.dirname(buf_name) or vim.fn.getcwd()
  end

  return vim.fs.joinpath(project_root, "refs.bib")
end

local function get_media_target_dir()
  local _, project_root = u.get_main_file_name()
  local target = project_root and vim.fs.joinpath(project_root, "bibliography")
    or vim.fn.expand("~/Downloads")

  if vim.fn.isdirectory(target) == 0 then
    vim.fn.mkdir(target, "p")
  end

  return target
end

local function urlencode(str)
  return (
    str:gsub("([^%w%-_%.~])", function(c)
      return string.format("%%%02X", string.byte(c))
    end)
  )
end

---@param tbl table
---@param ... any
---@return any|nil
local function safe_get(tbl, ...)
  if not tbl then
    return nil
  end

  local keys = { ... }
  for _, key in ipairs(keys) do
    tbl = tbl[key]
    if not tbl then
      return nil
    end
  end
  return tbl
end

---@param json_str string
---@return table|nil, string|nil
local function safe_json_decode(json_str)
  if not json_str or json_str == "" then
    return nil, "Empty JSON"
  end

  local ok, result = pcall(vim.json.decode, json_str)
  if not ok then
    return nil, "JSON decode error: " .. tostring(result)
  end
  return result, nil
end

local function show_select(items, opts, callback)
  vim.ui.select(items, opts, callback)
end

local function extract_journal_info(item)
  local issn = safe_get(item, "ISSN", 1) or safe_get(item, "issn-type", 1, "value") or "N/A"

  local title = item.title
  if type(title) == "table" then
    title = title[1] or "Untitled"
  elseif not title then
    title = "Untitled"
  end

  return { label = string.format("%s (ISSN: %s)", title, issn), issn = issn }
end

local function extract_article_display(article)
  local year = safe_get(article, "created", "date-parts", 1, 1) or "????"
  local title = safe_get(article, "title", 1) or "Untitled"
  return string.format("[%s] %s", year, title)
end

local function extract_media_urls(article)
  local pdf_url, epub_url = nil, nil

  for _, link in ipairs(article.link or {}) do
    local ctype = link["content-type"] or ""
    if ctype:find("pdf") then
      pdf_url = link.URL
    elseif ctype:find("epub") then
      epub_url = link.URL
    end
  end

  return pdf_url, epub_url
end

local function extract_article_title(article)
  return u.sanitize_name(safe_get(article, "title", 1) or "article_xNVTEXx")
end

local handle_article_actions

local function handle_bibtex(article)
  u.http_get(
    "https://doi.org/" .. article.DOI,
    { Accept = "application/x-bibtex" },
    function(bib, err)
      if err or not bib then
        return u.notify_err("Error getting BibTeX: " .. (err or "No response"))
      end

      local formatted_bib = bib:gsub(",%s*", ",\n  "):gsub("%s*}%s*$", "\n}")

      local bib_options = {
        "Append to refs.bib",
        "Copy to clipboard",
        "Back to Article Options",
        "Exit",
      }

      show_select(bib_options, { prompt = " BibTeX Options " }, function(choice)
        if not choice or choice == "Exit" then
          return
        end

        if choice == "Back to Article Options" then
          handle_article_actions(article)
          return
        end

        if choice == "Append to refs.bib" then
          local bib_path = get_bib_target_path()
          local bib_file = io.open(bib_path, "a")

          if not bib_file then
            return u.notify_err("Cannot open refs.bib for writing")
          end

          bib_file:write("\n" .. formatted_bib .. "\n")
          bib_file:close()

          u.notify("Saved to: " .. vim.fn.fnamemodify(bib_path, ":t"))

          vim.defer_fn(function()
            handle_article_actions(article)
          end, 100)
        elseif choice == "Copy to clipboard" then
          vim.fn.setreg("+", formatted_bib)
          u.notify("BibTeX copied to clipboard")

          vim.defer_fn(function()
            handle_article_actions(article)
          end, 100)
        end
      end)
    end
  )
end

local function handle_pdf(article, pdf_url)
  if not pdf_url then
    u.notify_warn("No PDF available for this article")
    return
  end

  local pdf_options = {
    "Only view PDF",
    "Download and view PDF",
    "Only download PDF",
    "Back to Article Options",
    "Exit",
  }

  show_select(pdf_options, { prompt = " PDF options " }, function(choice)
    if not choice or choice == "Exit" then
      return
    end

    if choice == "Back to Article Options" then
      handle_article_actions(article)
      return
    end

    local clean_title = extract_article_title(article)
    local download_dir = get_media_target_dir()
    local filename = vim.fs.joinpath(download_dir, clean_title .. ".pdf")

    if choice == "Only view PDF" then
      u.notify("Opening PDF...")
      vim.system({ "zathura", pdf_url }, { detach = true })

      vim.defer_fn(function()
        handle_article_actions(article)
      end, 100)
    elseif choice == "Download and view PDF" or choice == "Only download PDF" then
      u.download_file(pdf_url, filename, {
        callback = function(success)
          if success and choice == "Download and view PDF" then
            vim.system({ "zathura", filename }, { detach = true })
          end

          vim.defer_fn(function()
            handle_article_actions(article)
          end, 100)
        end,
      })
    end
  end)
end

local function handle_epub(article, epub_url)
  if not epub_url then
    u.notify_warn("No EPUB available for this article")
    return
  end

  local clean_title = extract_article_title(article)
  local download_dir = get_media_target_dir()
  local filename = vim.fs.joinpath(download_dir, clean_title .. ".epub")

  u.download_file(epub_url, filename, {
    callback = function(success)
      if success then
        vim.defer_fn(function()
          handle_article_actions(article)
        end, 100)
      end
    end,
  })
end

function handle_article_actions(article)
  if not article then
    return
  end

  M._last_article = article

  local options = { "Get BibTeX" }
  local pdf_url, epub_url = extract_media_urls(article)

  if pdf_url then
    table.insert(options, "View or download PDF")
  end

  if epub_url then
    table.insert(options, "Download EPUB")
  end

  if M._last_results and #M._last_results > 0 then
    table.insert(options, "Back to results")
  end

  table.insert(options, "Exit")

  show_select(options, { prompt = " Article Options " }, function(choice)
    if not choice or choice == "Exit" then
      return
    end

    if choice == "Get BibTeX" then
      handle_bibtex(article)
    elseif choice == "View or download PDF" then
      handle_pdf(article, pdf_url)
    elseif choice == "Download EPUB" then
      handle_epub(article, epub_url)
    elseif choice == "Back to results" then
      M.xLAST_RESULTSx()
    end
  end)
end

local function search_articles(issn, query)
  local url =
    string.format("%s/journals/%s/works?query=%s&rows=100", CROSSREF_API, issn, urlencode(query))

  u.notify("Searching for articles...")

  u.http_get(url, nil, function(body, err)
    if err or not body then
      return u.notify_err("Search failed: " .. (err or "No response"))
    end

    local data, decode_err = safe_json_decode(body)
    if not data then
      return u.notify_err(tostring(decode_err))
    end

    local articles = safe_get(data, "message", "items") or {}
    if #articles == 0 then
      return u.notify_warn("No articles found")
    end

    M._last_results = articles

    show_select(articles, {
      prompt = " Select an article ",
      format_item = extract_article_display,
    }, function(article)
      if article then
        handle_article_actions(article)
      end
    end)
  end)
end

local function search_journals(search_type, input)
  local url
  if search_type == "Keywords" then
    url = CROSSREF_API .. "/journals?query=" .. urlencode(input) .. "&rows=100"
  else
    url = CROSSREF_API .. "/journals/" .. urlencode(input:gsub("%s+", ""))
  end

  u.notify("Searching journals...")

  u.http_get(url, nil, function(body, err)
    if err or not body then
      return u.notify_err("Search failed: " .. (err or "No response"))
    end

    local data, decode_err = safe_json_decode(body)
    if not data then
      return u.notify_err(tostring(decode_err))
    end

    local items = search_type == "Keywords" and safe_get(data, "message", "items")
      or { safe_get(data, "message") }

    if not items or #items == 0 then
      return u.notify_warn("No journals found")
    end

    local journal_map = {}
    for _, item in ipairs(items) do
      table.insert(journal_map, extract_journal_info(item))
    end

    show_select(journal_map, {
      prompt = " Select a journal ",
      format_item = function(item)
        return item.label
      end,
    }, function(selected_journal)
      if not selected_journal or selected_journal.issn == "N/A" then
        return
      end

      vim.ui.input({ prompt = " Search articles (keyword) " }, function(query)
        if not query or query == "" then
          return
        end

        search_articles(selected_journal.issn, query)
      end)
    end)
  end)
end

-- Public API's
function M.xSEARCH_ISSNx()
  show_select({ "Keywords", "ISSN" }, { prompt = " Search journals by " }, function(search_type)
    if not search_type then
      return
    end

    vim.ui.input({ prompt = " Journal name or keyword " }, function(input)
      if not input or input == "" then
        return
      end

      search_journals(search_type, input)
    end)
  end)
end

function M.xLAST_ARTICLEx()
  if not M._last_article then
    return u.notify_warn("No recent article")
  end
  handle_article_actions(M._last_article)
end

function M.xLAST_RESULTSx()
  if not M._last_results or #M._last_results == 0 then
    return u.notify_warn("No recent searches")
  end

  show_select(
    M._last_results,
    { prompt = " Latest results ", format_item = extract_article_display },
    function(article)
      if article then
        handle_article_actions(article)
      end
    end
  )
end

return M
