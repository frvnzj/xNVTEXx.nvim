local M = {}

local u = require("xNVTEXx.utils")

local MACRO_CONFIG = {
  single = { "cite", "parencite", "textcite", "footcite" },
  multiple = { "cites", "parencites", "textcites", "footcites", "cite", "parencite" },
}

---Determines the bibliography file path
---@return string|nil
local function get_bib_target_path()
  local _, project_root = u.get_main_file_name()

  if not project_root then
    local buf_name = vim.api.nvim_buf_get_name(0)
    project_root = buf_name ~= "" and vim.fs.dirname(buf_name) or vim.fn.getcwd()
  end

  local bib_path = vim.fs.joinpath(project_root, "refs.bib")

  if vim.fn.filereadable(bib_path) == 0 then
    return nil
  end

  return bib_path
end

---Parses a BibTeX file and extracts bibliography entries
---Handles multi-line entries and preserves formatting for preview
---@param filepath string Path to the .bib file
---@return table Array of items with text, key, and preview fields
local function parse_bib_file(filepath)
  local items = {}
  local file = io.open(filepath, "r")

  if not file then
    return items
  end

  local current_key = nil
  local entry_lines = {}

  for line in file:lines() do
    -- Match BibTeX entry headers: @type{key,
    local match_type, match_key = line:match("^%s*@(%w+)%s*{%s*([^,]+),")

    if match_type and match_key then
      if current_key then
        table.insert(items, {
          text = current_key,
          key = current_key,
          preview = table.concat(entry_lines, "\n"),
        })
      end

      current_key = match_key:gsub("%s+", "")
      entry_lines = { line }
    elseif current_key then
      table.insert(entry_lines, line)

      if line:match("^}%s*$") then
        table.insert(items, {
          text = current_key,
          key = current_key,
          preview = table.concat(entry_lines, "\n"),
        })
        current_key = nil
        entry_lines = {}
      end
    end
  end

  if current_key then
    table.insert(items, {
      text = current_key,
      key = current_key,
      preview = table.concat(entry_lines, "\n"),
    })
  end

  file:close()
  return items
end

---Formats citation command based on macro type and number of keys
---Handles plural macros (e.g., \cites{...}{...}) and singular macros (e.g., \cite{...})
---@param macro string Citation macro name (e.g., "cite", "parencite")
---@param keys table Array of bibliography keys to cite
---@return string Formatted citation command
local function format_citation(macro, keys)
  if #keys == 1 then
    return string.format("\\%s{%s}", macro, keys[1])
  end

  if macro:sub(-1) == "s" then
    local keys_formatted = ""
    for _, k in ipairs(keys) do
      keys_formatted = keys_formatted .. string.format("{%s}", k)
    end
    return string.format("\\%s%s", macro, keys_formatted)
  else
    return string.format("\\%s{%s}", macro, table.concat(keys, ","))
  end
end

---Inserts citation command at current cursor position
---Handles multi-line insertions and cursor positioning
---@param macro string Citation macro name
---@param keys table Array of bibliography keys
local function insert_citation(macro, keys)
  local formatted_citation = format_citation(macro, keys)

  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()

  local new_line = line:sub(1, col) .. formatted_citation .. line:sub(col + 1)
  vim.api.nvim_set_current_line(new_line)

  vim.api.nvim_win_set_cursor(0, { row, col + #formatted_citation })
end

---Creates and displays the citation picker
---Allows multi-selection of bibliography entries and macro selection
---@function M.xCITEPICKx
function M.xCITEPICKERx()
  local bib_file = get_bib_target_path()

  if not bib_file then
    u.notify_warn("No .bib file found in project root")
    return
  end

  local items = parse_bib_file(bib_file)

  if #items == 0 then
    u.notify_warn("The .bib file is empty or could not be parsed")
    return
  end

  Snacks.picker.pick({
    title = "xNVTEXx - xCITEPICKx",
    items = items,
    format = "text",
    preview = function(ctx)
      local preview_text = tostring(ctx.item.preview or "")
      local lines = vim.split(preview_text, "\n")
      ctx.preview:set_lines(lines)
      ctx.preview:highlight({ ft = "bib" })
    end,
    actions = {
      confirm = function(picker)
        picker:close()

        local selected_items = picker:selected({ fallback = true })
        local keys = {}

        for _, it in ipairs(selected_items) do
          table.insert(keys, it.key)
        end

        if #keys == 0 then
          return
        end

        local macro_options = #keys == 1 and MACRO_CONFIG.single or MACRO_CONFIG.multiple
        local prompt = string.format(" Selecciona el macro para %d cita(s) ", #keys)

        vim.ui.select(macro_options, {
          prompt = prompt,
          format_item = function(choice)
            return "\\" .. choice
          end,
        }, function(choice)
          if choice then
            insert_citation(choice, keys)
          end
        end)
      end,
    },
  })
end

return M
