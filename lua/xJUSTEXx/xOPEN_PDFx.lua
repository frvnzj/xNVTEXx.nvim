local M = {}

local config = require("xJUSTEXx.config")

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
      "forward-search-column",
      tostring(col),
      pdf,
    }
  end,
}

local function get_main_file_name()
  local cwd = vim.uv.cwd()
  local justfile = vim.fs.joinpath(cwd, ".justfile")
  if vim.uv.fs_stat(justfile) == nil then
    return nil
  end

  local lines = vim.fn.readfile(justfile)
  for _, line in ipairs(lines) do
    local main_file = line:match('main_file%s*:=%s*"([^"]+)"')
    if main_file then
      return vim.fs.joinpath(cwd, main_file)
    end
  end
  return nil
end

local function get_pdf_path()
  local main_tex = get_main_file_name()
  if main_tex then
    return main_tex:gsub("%.tex$", ".pdf")
  end
  return vim.fn.expand("%:p:r") .. ".pdf"
end

local function build_viewer_cmd(viewer, pdf_path, tex_path, line, col)
  local builder = VIEWERS_CONFIG[viewer]
  if builder then
    return builder(pdf_path, tex_path, line, col)
  end
  return { viewer, pdf_path }
end

function M.xVIEW_PDFx()
  local viewer = config.options.pdf_viewer
  local file_pdf = get_pdf_path()

  if vim.fn.filereadable(file_pdf) == 0 then
    return vim.notify(
      "PDF not found: "
        .. vim.fn.fnamemodify(file_pdf, ":t")
        .. ". Make sure the project is compiled.",
      vim.log.levels.WARN
    )
  end

  local current_tex = vim.fn.expand("%:p")
  local line = vim.fn.line(".")
  local col = vim.fn.col(".")

  local cmd = build_viewer_cmd(viewer, file_pdf, current_tex, line, col)

  vim.system(cmd, { detach = true }, function(obj)
    if obj.code ~= 0 and obj.code ~= nil then
      vim.schedule(function()
        vim.notify("Error opening viewer: " .. viewer, vim.log.levels.ERROR)
      end)
    end
  end)

  vim.notify("Opening " .. viewer .. "...", vim.log.levels.INFO)
end

return M
