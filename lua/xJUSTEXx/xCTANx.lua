local M = {}

local ctan_mirror = "https://mirrors.mit.edu/CTAN"

local function notify(msg, level)
  vim.notify("xCTANx: " .. msg, level or vim.log.levels.INFO)
end

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

local function build_full_url(doc_path)
  local clean_path = doc_path:gsub("^ctan:", ""):gsub("^/+", "")
  return ctan_mirror .. "/" .. clean_path:gsub(" ", "%%20")
end

local function open_document(url, path)
  local ext = path:match("%.([%a%d]+)$") or ""
  local is_readme = path:match("README")

  if ext == "pdf" then
    notify("Abriendo PDF con Zathura...")
    vim.system({ "zathura", url }, { detach = true })
  elseif ext == "html" then
    notify("Abriendo en navegador...")
    vim.system({ "xdg-open", url }, { detach = true })
  elseif ext == "md" or ext == "txt" or is_readme then
    local tmp_dir = vim.fn.stdpath("cache") .. "/ctan_docs/"
    local filename = path:match("([^/]+)$"):gsub("%%20", "_")
    if not filename:match("%.") then
      filename = filename .. ".txt"
    end
    local tmp_file = tmp_dir .. filename

    vim.fn.mkdir(tmp_dir, "p")
    notify("Descargando documento...")

    vim.system({ "curl", "-sSL", "-o", tmp_file, url }, {}, function(obj)
      vim.schedule(function()
        if obj.code == 0 and vim.fn.filereadable(tmp_file) == 1 then
          vim.cmd("view " .. vim.fn.fnameescape(tmp_file))
        else
          notify("Error al descargar: " .. url, vim.log.levels.ERROR)
        end
      end)
    end)
  else
    notify("Formato no soportado: " .. ext, vim.log.levels.WARN)
  end
end

function M.xCTANSEARCHx()
  notify("Obteniendo lista de paquetes...")

  http_get("https://www.ctan.org/json/2.0/packages", function(body, err)
    if err or not body then
      return notify(err or "No body", vim.log.levels.ERROR)
    end

    local ok, packages = pcall(vim.fn.json_decode, body)
    if not ok then
      return notify("Error decodificando JSON", vim.log.levels.ERROR)
    end

    local package_list = {}
    for _, pkg in ipairs(packages) do
      table.insert(package_list, {
        display = string.format("%s - %s", pkg.key, pkg.caption or "Sin descripción"),
        key = pkg.key,
      })
    end

    vim.ui.select(package_list, {
      prompt = "Package  > ",
      format_item = function(item)
        return " " .. item.display
      end,
    }, function(selected)
      if not selected then
        return
      end

      notify("Buscando documentación...")
      http_get("https://www.ctan.org/json/2.0/pkg/" .. selected.key, function(p_body, p_err)
        if p_err or not p_body then
          return notify("Error al obtener detalles: " .. (p_err or "vacío"), vim.log.levels.ERROR)
        end

        local p_ok, pkg_data = pcall(vim.fn.json_decode, p_body)
        if not p_ok or not pkg_data.documentation then
          return notify("No hay documentación disponible", vim.log.levels.WARN)
        end

        local doc_list = {}
        for _, doc in ipairs(pkg_data.documentation) do
          table.insert(doc_list, {
            display = string.format("%s - %s", doc.details or "Doc", doc.href),
            href = doc.href,
          })
        end

        vim.ui.select(doc_list, {
          prompt = selected.key .. " Docs  > ",
          format_item = function(item)
            local icons = { pdf = "󰈦 ", md = " ", html = " ", txt = "󰈙 " }
            local ext = item.href:match("%.([%a%d]+)$") or ""
            return (icons[ext] or "󰈙 ") .. item.display
          end,
        }, function(doc_selected)
          if not doc_selected then
            return
          end
          open_document(build_full_url(doc_selected.href), doc_selected.href)
        end)
      end)
    end)
  end)
end

return M
