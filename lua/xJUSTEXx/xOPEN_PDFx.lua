local M = {}

local config = require("xJUSTEXx.config")

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

function M.xVIEW_PDFx()
  local viewer = config.options.pdf_viewer
  local main_tex = get_main_file_name()
  local file_pdf

  if main_tex then
    file_pdf = main_tex:gsub("%.tex$", ".pdf")
  else
    file_pdf = vim.fn.expand("%:p:r") .. ".pdf"
  end

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

  local cmd = {}

  if viewer == "zathura" then
    cmd = {
      "zathura",
      "--synctex-forward",
      string.format("%d:%d:%s", line, col, current_tex),
      file_pdf,
    }
  elseif viewer == "sioyek" then
    cmd = {
      "sioyek",
      "--reuse-window",
      "--forward-search-file",
      current_tex,
      "--forward-search-line",
      tostring(line),
      "--forward-search-column",
      tostring(col),
      file_pdf,
    }
  else
    cmd = { viewer, file_pdf }
  end

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
