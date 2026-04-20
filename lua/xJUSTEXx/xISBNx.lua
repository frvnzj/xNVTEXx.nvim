--- Module for handling ISBN validation, fetching book data, and generating BibTeX entries.
local M = {}

local function notify(msg, level)
  vim.notify("xISBNx: " .. msg, level or vim.log.levels.INFO)
end

local function http_get(url, cb)
  vim.system({ "curl", "-sSL", url }, { text = true }, function(obj)
    vim.schedule(function()
      if obj.code ~= 0 then
        cb(nil, "Error de conexión (Código " .. obj.code .. ")")
      else
        cb(obj.stdout, nil)
      end
    end)
  end)
end

local function generate_bibkey(value, _)
  local author = "Unknown"
  if value.authors or value.authors[1] then
    author = value.authors[1].name:match("([^%s]+)$") or value.authors[1].name
  end

  local year = (value.publish_date and value.publish_date:match("(%d%d%d%d)")) or "????"

  local title_word = "Book"
  if value.title then
    for word in value.title:gmatch("[%wáéíóúÁÉÍÓÚñÑ]+") do
      if #word > 3 then
        title_word = word
        break
      end
    end

    if title_word == "Book" then
      title_word = value.title:match("[%w]+") or "Book"
    end
  end

  local key = string.format("%s%s%s", author, year, title_word)
  return key:gsub("[%s%p]", "")
end

--- Builds a BibTeX entry from the given book data.
--- @param value table The book data from the API.
--- @param isbn string The ISBN for the entry.
--- @return string The formatted BibTeX entry.
local function build_bibtex_entry(value, isbn)
  local bibkey = generate_bibkey(value, isbn)

  local authors_list = {}
  if value.authors then
    for _, author in ipairs(value.authors) do
      table.insert(authors_list, author.name)
    end
  end

  local translator = (value.authors and value.authors[2] and value.authors[2].name) or " "
  local publisher = (value.publishers and value.publishers[1] and value.publishers[1].name) or " "
  local year = (value.publish_date and value.publish_date:match("(%d%d%d%d)")) or " "
  local address = (
    value.publish_places
    and value.publish_places[1]
    and value.publish_places[1].name
  ) or " "

  local fields = {
    string.format("@book{%s,", bibkey),
    string.format("  title        = {%s},", value.title or " "),
    string.format("  subtitle     = {%s},", value.subtitle or " "),
    string.format("  author       = {%s},", table.concat(authors_list, " and ")),
    string.format("  translator   = {%s},", translator),
    string.format("  publisher    = {%s},", publisher),
    string.format("  year         = {%s},", year),
    string.format("  isbn         = {%s},", isbn),
    string.format(
      "  pagetotal    = {%s},",
      (value.number_of_pages and tostring(value.number_of_pages)) or " "
    ),
    string.format("  address      = {%s}", address),
    "}",
  }
  return table.concat(fields, "\n")
end

--- Saves the selected BibTeX entry to a file and opens it in a split window.
--- @param selected_bibtex string The BibTeX entry to save.
local function save_and_open_bib(selected_bibtex)
  local bib_file = vim.fn.expand("%:p:h") .. "/refs.bib"
  local file = io.open(bib_file, "a")
  if file then
    file:write("\n" .. selected_bibtex .. "\n")
    file:close()
    notify(" Entrada añadida a " .. bib_file)
    vim.cmd("vsplit " .. bib_file)
  else
    notify("󰮘 Error al abrir el archivo .bib", vim.log.levels.ERROR)
  end
end

--- Main function to search for a book by ISBN and handle user interaction.
function M.xSEARCH_ISBNx()
  vim.ui.input({ prompt = " Ingrese ISBN (puede incluir guiones): " }, function(isbn_input)
    if not isbn_input or isbn_input == "" then
      return
    end

    local format_isbn = isbn_input:gsub("[^%dX]", "")
    if #format_isbn ~= 10 and #format_isbn ~= 13 then
      return notify("ISBN inválido (10 o 13 dígitos)", vim.log.levels.ERROR)
    end

    local url = string.format(
      "https://openlibrary.org/api/books?bibkeys=ISBN:%s&jscmd=data&format=json",
      format_isbn
    )

    notify("Buscando en Open Library...")

    http_get(url, function(body, http_err)
      if http_err or not body then
        return notify(http_err or "No se recibieron datos", vim.log.levels.ERROR)
      end

      local ok, data = pcall(vim.fn.json_decode, body)
      if not ok or not data or vim.tbl_isempty(data) then
        return notify("No se encontraron datos", vim.log.levels.WARN)
      end

      local options = {}
      for key, value in pairs(data) do
        local isbn_found = key:gsub("ISBN:", "")
        local bibtex_entry = build_bibtex_entry(value, isbn_found)
        local author_name = (value.authors and value.authors[1] and value.authors[1].name)
          or "Desconocido"

        table.insert(options, {
          label = string.format("%s | %s", author_name, value.title or "Sin título"),
          bibtex = bibtex_entry,
        })
      end

      if #options == 1 then
        save_and_open_bib(options[1].bibtex)
      elseif #options > 1 then
        vim.ui.select(options, {
          prompt = " Seleccione una entrada:",
          format_item = function(item)
            return item.label
          end,
        }, function(choice)
          if choice then
            save_and_open_bib(choice.bibtex)
          end
        end)
      end
    end)
  end)
end

return M
