local M = {}

---@param msg string
---@param level integer|nil
local function notify(msg, level)
  vim.notify("xISBNx: " .. msg, level or vim.log.levels.INFO)
end

local function urlencode(str)
  return (
    str:gsub("([^%w%-_%.~])", function(c)
      return string.format("%%%02X", string.byte(c))
    end)
  )
end

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

local function http_get(url, headers, cb)
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
        local error_msg = obj.stderr or ("Error" .. obj.code)
        cb(nil, error_msg)
      else
        cb(obj.stdout, nil)
      end
    end)
  end)
end

local function safe_json_decode(json_str)
  if not json_str or json_str == "" then
    return nil, "Empty JSON"
  end

  local ok, result = pcall(vim.fn.json_decode, json_str)
  if not ok then
    return nil, "Error parsing JSON: " .. tostring(result)
  end
  return result, nil
end

local function show_select(items, opts, callback)
  vim.ui.select(items, opts, callback)
end

local function extract_journal_info(item)
  local issn = safe_get(item, "ISSN", 1) or safe_get("issn-type", 1, "value") or "N/A"

  local title = item.title
  if type(title) == "table" then
    title = title[1] or "Sin título"
  elseif not title then
    title = "Sin título"
  end

  return { label = string.format("%s (ISSN: %s)", title, issn), issn = issn }
end

local function extract_article_display(article)
  local year = safe_get(article, "created", "date-parts", 1, 1) or "????"
  local title = safe_get(article, "title", 1) or "Sin título"
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

local function handle_bibtex(article)
  http_get(
    "https://doi.org/" .. article.DOI,
    { Accept = "application/x-bibtex" },
    function(bib, err)
      if err or not bib then
        return notify("Error getting BibTeX: " .. (err or "Unanswered"), vim.log.levels.ERROR)
      end

      local formatted_bib = bib:gsub(",%s*", ",\n  "):gsub("%s*}%s*$", "\n}")
      local bib_path = vim.fn.expand("%:p:h") .. "/refs.bib"

      local bib_file = io.open(bib_path, "a")
      if not bib_file then
        return notify("Error opening refs.bib", vim.log.levels.ERROR)
      end

      bib_file:write("\n" .. formatted_bib .. "\n")
      bib_file:close()
      notify("Saved in refs.bib")
      vim.cmd("vsplit " .. bib_path)
    end
  )
end

local function handle_pdf(pdf_url)
  if not pdf_url then
    return
  end

  vim.system({ "zathura", pdf_url }, { detach = true })
end

local function handle_epub(article, epub_url)
  if not epub_url then
    return
  end

  local raw_title = safe_get(article, "title", 1) or "articulo_xJUSTEXx"
  local clean_title = raw_title:gsub("%s+", "_"):gsub("[%c%?%*\\/<>|:\"']", "")
  local download_dir = vim.fn.expand("~/Downloads/")
  local filename = download_dir .. clean_title .. ".epub"

  if vim.fn.isdirectory(download_dir) == 0 then
    return notify("Directory " .. download_dir .. " does not exist", vim.log.levels.ERROR)
  end

  notify("Starting EPUB download...")

  vim.system({ "curl", "-L", "-o", filename, epub_url }, { detach = true }, function(obj)
    vim.schedule(function()
      if obj.code == 0 then
        notify("Discharged " .. clean_title .. ".epub")
      else
        local detail = obj.stderr or string.format("Código %d", obj.code)
        notify("Error downloading: " .. detail, vim.log.levels.ERROR)
      end
    end)
  end)
end

function M.handle_article_actions(article)
  local options = { "BibTeX" }
  local pdf_url, epub_url = extract_media_urls(article)

  if pdf_url then
    table.insert(options, "PDF")
  end

  if epub_url then
    table.insert(options, "EPUB")
  end

  show_select(options, { prompt = "Acción: " }, function(choice)
    if choice == "BibTeX" then
      handle_bibtex(article)
    elseif choice == "PDF" then
      handle_pdf(pdf_url)
    elseif choice == "EPUB" then
      handle_epub(article, epub_url)
    end
  end)
end

-- Main function to search for journals and articles
function M.xSEARCH_ISSNx()
  show_select({ "Keywords", "ISSN" }, { prompt = "Buscar revista por:" }, function(search_type)
    if not search_type then
      return
    end

    vim.ui.input({ prompt = "Consultar: " }, function(input)
      if not input or input == "" then
        return
      end

      local url
      if search_type == "Keywords" then
        url = "https://api.crossref.org/journals?query=" .. urlencode(input)
      else
        url = "https://api.crossref.org/journals/" .. urlencode(input:gsub("%s+", ""))
      end

      notify("Buscando revista...")
      http_get(url, nil, function(body, err)
        if err or not body then
          return notify("Error: " .. (err or "Not body"), vim.log.levels.ERROR)
        end

        local data, decode_err = safe_json_decode(body)
        if not data then
          return notify("Error JSON: " .. decode_err, vim.log.levels.ERROR)
        end

        local items = search_type == "Keywords" and safe_get(data, "message", "items")
          or { safe_get(data, "message") }
        if not items or #items == 0 then
          return notify("No magazines found", vim.log.levels.WARN)
        end

        local journal_map = {}
        for _, item in ipairs(items) do
          table.insert(journal_map, extract_journal_info(item))
        end

        vim.ui.select(journal_map, {
          prompt = "Seleccionar revista:",
          format_item = function(item)
            return item.label
          end,
        }, function(selected_journal)
          if not selected_journal or selected_journal.issn == "N/A" then
            return
          end

          vim.ui.input({ prompt = "Buscar artículos: " }, function(art_query)
            if not art_query or art_query == "" then
              return
            end

            local art_url = string.format(
              "https://api.crossref.org/journals/%s/works?query=%s",
              selected_journal.issn,
              urlencode(art_query)
            )

            notify("Buscando artículos...")
            http_get(art_url, nil, function(art_body, art_err)
              if art_err or not art_body then
                return notify("Error: " .. (art_err or "Unanswered"), vim.log.levels.ERROR)
              end

              local art_data, art_decode_err = safe_json_decode(art_body)
              if not art_data then
                return notify("Error JSON: " .. art_decode_err, vim.log.levels.ERROR)
              end

              local articles = safe_get(art_data, "message", "items") or {}
              if #articles == 0 then
                return notify("There are no articles", vim.log.levels.WARN)
              end

              show_select(articles, {
                prompt = "Selecciona artículo:",
                format_item = extract_article_display,
              }, function(article)
                if not article then
                  return
                end

                M.handle_article_actions(article)
              end)
            end)
          end)
        end)
      end)
    end)
  end)
end

return M
