--- Module for handling ISBN validation, fetching book data, and generating BibTeX entries.
local M = {}

local u = require("xNVTEXx.utils")

local OPENLIBRARY_API = "https://openlibrary.org/api/books?bibkeys=ISBN:%s&jscmd=data&format=json"
local BIBTEX_FILE = "refs.bib"

--- Extracts and normalizes book data from the Open Library API response.
--- @param value table
--- @return table Data
local function extract_book_data(value)
  if not value or type(value) ~= "table" then
    return {}
  end

  local first_author = value.authors and value.authors[1] and value.authors[1].name or "Unknown"
  local year = (value.publish_date and value.publish_date:match("(%d%d%d%d)")) or "????"

  return {
    title = value.title or "Untitled",
    subtitle = value.subtitle or "",
    first_author = first_author,
    authors = value.authors or {},
    year = year,
    publisher = (value.publishers and value.publishers[1] and value.publishers[1].name) or "",
    address = (value.publish_places and value.publish_places[1] and value.publish_places[1].name)
      or "",
    pages = (value.number_of_pages and tostring(value.number_of_pages)) or "",
    raw = value,
  }
end

--- Extracts the last word from an author's name (typically surname).
--- @param author_name string The full author name.
--- @return string surname
local function get_author_surname(author_name)
  if not author_name or author_name == "" then
    return "Unknown"
  end
  return author_name:match("([^%s]+)$") or author_name
end

--- Extracts the first meaningful word from a title (word > 3 characters).
--- @param title string
--- @return string word
local function get_title_word(title)
  if not title or title == "" then
    return "Book"
  end

  for word in title:gmatch("[%wáàèìòùéíóúüÁÀÉÈÍÌÓÒÚÙÜßñÑ]+") do
    if vim.fn.strcharlen(word) > 3 then
      return word
    end
  end

  return title:match("[%w]+") or "Book"
end

--- Generates a BibTeX citation key from book data.
--- @param book_data table
--- @return string key
local function generate_bibkey(book_data)
  local author = get_author_surname(book_data.first_author)
  local year = book_data.year
  local title_word = get_title_word(book_data.title)

  local key = string.format("%s%s%s", author, year, title_word)
  local key_gsub = key:gsub("[%s%p]", "")
  return key_gsub
end

--- Builds a formatted list of authors for BibTeX.
--- @param authors table
--- @return string Authors formatted as "Name1 and Name2 and ..."
local function format_authors(authors)
  local authors_list = {}
  if authors and #authors > 0 then
    for _, author in ipairs(authors) do
      if author.name then
        table.insert(authors_list, author.name)
      end
    end
  end
  return #authors_list > 0 and table.concat(authors_list, " and ") or ""
end

--- Builds a BibTeX entry from the given book data.
--- @param book_data table
--- @param isbn string
--- @return string fields
local function build_bibtex_entry(book_data, isbn)
  local bibkey = generate_bibkey(book_data)
  local authors_str = format_authors(book_data.authors)

  local fields = {
    string.format("@book{%s,", bibkey),
    string.format("  title        = {%s},", book_data.title),
  }

  if book_data.subtitle ~= "" then
    table.insert(fields, string.format("  subtitle     = {%s},", book_data.subtitle))
  end

  table.insert(fields, string.format("  author       = {%s},", authors_str))

  if book_data.publisher ~= "" then
    table.insert(fields, string.format("  publisher    = {%s},", book_data.publisher))
  end

  table.insert(fields, string.format("  year         = {%s},", book_data.year))

  table.insert(fields, string.format("  isbn         = {%s},", isbn))

  table.insert(fields, string.format("  pagetotal    = {%s},", book_data.pages))

  table.insert(fields, string.format("  address      = {%s},", book_data.address))

  table.insert(fields, "}")

  return table.concat(fields, "\n")
end

--- Saves the selected BibTeX entry to a file and opens it in a split window.
--- @param selected_bibtex string
local function save_and_open_bib(selected_bibtex)
  local _, project_root = u.get_main_file_name()

  if not project_root then
    local buf_name = vim.api.nvim_buf_get_name(0)
    project_root = buf_name ~= "" and vim.fs.dirname(buf_name) or vim.fn.getcwd()
  end

  local stat = vim.uv.fs_stat(project_root)
  if not stat or stat.type ~= "directory" then
    u.debug_log("Target directory does not exist: " .. project_root)
    return
  end

  local bib_file = vim.fs.joinpath(project_root, BIBTEX_FILE)

  local file, err = io.open(bib_file, "a")
  if not file then
    u.notify("Error opening .bib file: " .. (err or "Unknown"))
    return
  end

  local success, write_err = file:write("\n" .. selected_bibtex .. "\n")
  file:close()

  if not success then
    u.notify_err("Error writing to .bib: " .. (write_err or "Unknown"))
    return
  end

  u.notify("Entry added to " .. bib_file)
  vim.cmd("vsplit " .. vim.fn.fnameescape(bib_file))
end

--- Validates and formats an ISBN string.
--- @param isbn_input string
--- @return string|nil ISBN
local function validate_isbn(isbn_input)
  if not isbn_input or isbn_input == "" then
    return nil
  end

  local format_isbn = isbn_input:gsub("[^%dX]", "")
  if #format_isbn ~= 10 and #format_isbn ~= 13 then
    u.notify_err("Invalid ISBN (must be 10 or 13 digits)")
    return nil
  end

  return format_isbn
end

--- Parses the API response and builds book options for selection.
--- @param data table
--- @return table BibTeX
local function build_book_options(data)
  local options = {}

  for key, value in pairs(data) do
    local isbn_found = key:gsub("ISBN:", "")
    local book_data = extract_book_data(value)
    local bibtex_entry = build_bibtex_entry(book_data, isbn_found)

    table.insert(options, {
      label = string.format("%s | %s", book_data.first_author, book_data.title),
      bibtex = bibtex_entry,
    })
  end

  return options
end

--- Main function to search for a book by ISBN and handle user interaction.
function M.xSEARCH_ISBNx()
  vim.ui.input({ prompt = " Enter ISBN (may include hyphens) " }, function(isbn_input)
    local format_isbn = validate_isbn(isbn_input)
    if not format_isbn then
      return
    end

    local url = string.format(OPENLIBRARY_API, format_isbn)

    u.notify("Searching Open Library...")

    u.http_get(url, nil, function(body, http_err)
      if http_err or not body then
        return u.notify_err(http_err or "No data received")
      end

      local ok, data = pcall(vim.fn.json_decode, body)
      if not ok or not data or vim.tbl_isempty(data) then
        return u.notify_warn("No data found")
      end

      local options = build_book_options(data)

      if #options == 0 then
        return u.notify_warn("No books found")
      elseif #options == 1 then
        save_and_open_bib(options[1].bibtex)
      else
        vim.ui.select(options, {
          prompt = " Select an entry ",
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
