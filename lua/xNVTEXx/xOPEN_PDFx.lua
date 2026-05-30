local M = {}

local config = require("xNVTEXx.config")
local u = require("xNVTEXx.utils")

local VIEWERS_CONFIG = {
  zathura = function(pdf, tex, line, col)
    return {
      "zathura",
      "--synctex-forward",
      string.format("%d:%d:%s", line, col, tex),
      pdf,
    }
  end,
  sioyek = function(pdf, tex, line, col)
    return {
      "sioyek",
      "--reuse-window",
      "--forward-search-file",
      tex,
      "--forward-search-line",
      tostring(line),
      "--forward-search-column",
      tostring(col),
      pdf,
    }
  end,
}

---Calculate the absolute path of the PDF
---@return string
local function get_pdf_path()
  local main_file, project_root = u.get_main_file_name()
  if main_file and project_root then
    local pdf_file = main_file:gsub("%.tex$", ".pdf")
    return vim.fs.joinpath(project_root, pdf_file)
  end

  return vim.fn.expand("%:p:r") .. ".pdf"
end

---Build the specific command for the selected viewer
---@param viewer string
---@param pdf_path string
---@param tex_path string
---@param line integer
---@param col integer
---@return string[]
local function build_viewer_cmd(viewer, pdf_path, tex_path, line, col)
  local builder = VIEWERS_CONFIG[viewer]
  if builder then
    return builder(pdf_path, tex_path, line, col)
  end
  return { viewer, pdf_path }
end

function M.xVIEW_PDFx()
  local viewer = config.options.pdf_viewer or "zathura"
  local file_pdf = get_pdf_path()

  if vim.fn.filereadable(file_pdf) == 0 then
    u.notify_warn(
      "PDF not found: "
        .. vim.fn.fnamemodify(file_pdf, ":t")
        .. ". Make sure the project is compiled."
    )
    return
  end

  local current_tex = vim.fn.expand("%:p")
  local line = vim.fn.line(".")
  local col = vim.fn.col(".")

  local cmd = build_viewer_cmd(viewer, file_pdf, current_tex, line, col)

  vim.system(cmd, { detach = true }, function(obj)
    if obj.code ~= 0 and obj.code ~= nil then
      vim.schedule(function()
        u.notify_err("Error opening viewer: " .. viewer)
      end)
    end
  end)

  u.notify("Opening " .. viewer .. "...")
end

return M
