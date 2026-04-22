local M = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO)
end

local function urlencode(str)
  return (
    str:gsub("([^%w%-_%.~])", function(c)
      return string.format("%%%02X", string.byte(c))
    end)
  )
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
        cb(nil, "Error " .. obj.code)
      else
        cb(obj.stdout, nil)
      end
    end)
  end)
end

-- Main function to search for journals and articles
function M.xSEARCH_ISSNx()
  vim.ui.select({ "Keywords", "ISSN" }, { prompt = "Buscar revista por:" }, function(search_type)
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

        local data = vim.fn.json_decode(body)
        local items = search_type == "Keywords" and data.message.items or { data.message }

        if not items or #items == 0 then
          return notify("No se encontraron revistas", vim.log.levels.WARN)
        end

        local journal_map = {}
        for _, item in ipairs(items) do
          local issn = (item.ISSN and item.ISSN[1])
            or (item["issn-type"] and item["issn-type"][1].value)
            or "N/A"
          local title = type(item.title) == "table" and item.title[1] or item.title or "Sin título"
          local label = string.format("%s (ISSN: %s)", title, issn)
          table.insert(journal_map, { label = label, issn = issn })
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
            http_get(art_url, nil, function(art_body)
              local art_data = vim.fn.json_decode(art_body)
              local articles = art_data.message.items

              if #articles == 0 then
                return notify("No hay artículos", vim.log.levels.WARN)
              end

              vim.ui.select(articles, {
                prompt = "Selecciona artículo:",
                format_item = function(item)
                  local yr = (item.created and item.created["date-parts"][1][1]) or "????"
                  local t = item.title and item.title[1] or "Sin título"
                  return string.format("[%s] %s", yr, t)
                end,
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

function M.handle_article_actions(article)
  local options = { "BibTeX" }
  local pdf_url = nil
  local epub_url = nil

  for _, link in ipairs(article.link or {}) do
    local ctype = link["content-type"] or ""
    if ctype:find("pdf") then
      pdf_url = link.URL
    elseif ctype:find("epub") then
      epub_url = link.URL
    end
  end

  if pdf_url then
    table.insert(options, "PDF")
  end

  if epub_url then
    table.insert(options, "EPUB")
  end

  vim.ui.select(options, { prompt = "Acción: " }, function(choice)
    if choice == "BibTeX" then
      http_get("https://doi.org/" .. article.DOI, { Accept = "application/x-bibtex" }, function(bib)
        if not bib then
          return
        end

        local formatted_bib = bib:gsub(",%s*", ",\n  "):gsub("%s*}%s*$", "\n}")

        local bib_path = vim.fn.expand("%:p:h") .. "/refs.bib"
        local bib_file = io.open(bib_path, "a")
        if bib_file then
          bib_file:write("\n" .. formatted_bib .. "\n")
          bib_file:close()
          notify("Guardado en refs.bib")
          vim.cmd("vsplit " .. bib_path)
        end
      end)
    elseif choice == "PDF" and pdf_url then
      vim.system({ "zathura", pdf_url }, { detach = true })
    elseif choice == "EPUB" and epub_url then
      local raw_title = (article.title and article.title[1] or "articulo_xJUSTEXx")
      local clean_title = raw_title:gsub("%s+", "_"):gsub("[%c%?%*\\/<>|:\"']", "")

      local download_dir = vim.fn.expand("~/Downloads/")
      local filename = download_dir .. clean_title .. ".epub"

      if vim.fn.isdirectory(download_dir) == 0 then
        return notify("Error: no existe la carpeta " .. download_dir, vim.log.levels.ERROR)
      end

      notify("Iniciando descarga EPUB...")

      vim.system({ "curl", "-L", "-o", filename, epub_url }, { detach = true }, function(obj)
        vim.schedule(function()
          if obj.code == 0 then
            notify("Descargado: " .. clean_title .. ".epub")
          else
            local detail = obj.stderr or string.format("Código %d", obj.code)
            notify("Error al descargar: " .. detail, vim.log.levels.ERROR)
          end
        end)
      end)
    end
  end)
end

return M
