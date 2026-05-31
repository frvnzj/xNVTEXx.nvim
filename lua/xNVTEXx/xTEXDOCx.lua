local M = {}

local u = require("xNVTEXx.utils")

--- Function to open LaTeX documentation for the word under the cursor
function M.xTEXDOCx()
  local package = vim.fn.expand("<cword>")
  if package == "" then
    return
  end

  u.notify("Looking doc for " .. package .. "...")

  vim.system({ "texdoc", package }, {}, function(obj)
    if obj.code ~= 0 then
      vim.schedule(function()
        u.notify_warn("No doc found for '" .. package .. "'")
      end)
    end
  end)
end

return M
