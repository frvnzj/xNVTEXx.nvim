if vim.g.loaded_xJUSTEXx then
  return
end
vim.g.loaded_xJUSTEXx = 1

local xJUSTEXx = require("xJUSTEXx")

local function complete_justex(_, _, _)
  local options = {}
  local justfile_path = vim.fs.find(".justfile", { upward = true, stop = vim.uv.os_homedir() })[1]

  if justfile_path and vim.fn.filereadable(justfile_path) == 1 then
    local lines = vim.fn.readfile(justfile_path)
    for _, line in ipairs(lines) do
      local option = line:match("^([%w%-_]+):")
      if option then
        table.insert(options, option)
      end
    end
  end

  return options
end

vim.api.nvim_create_user_command("JustexNewProject", function()
  xJUSTEXx.xNEW_PROJECTx()
end, {})

vim.api.nvim_create_user_command("JustexCompile", function(opts)
  local cmd = (opts.args ~= "") and opts.args or "lualatex"
  xJUSTEXx.xCOMPILEx(cmd)
end, {
  nargs = "?",
  complete = complete_justex,
  desc = "Default LuaLaTeX",
})

vim.api.nvim_create_user_command("JustexCancelComp", function()
  xJUSTEXx.xCANCELx()
end, {})

vim.api.nvim_create_user_command("JustexDoc", function()
  xJUSTEXx.xTEXDOCx()
end, {})

vim.api.nvim_create_user_command("JustexLog", function()
  xJUSTEXx.xPPLATEXx()
end, {})

vim.api.nvim_create_user_command("JustexSearchBook", function()
  xJUSTEXx.xISBNx()
end, {})

vim.api.nvim_create_user_command("JustexSearchJournal", function()
  xJUSTEXx.xISSNx()
end, {})

vim.api.nvim_create_user_command("JustexSearchCTAN", function()
  xJUSTEXx.xCTANx()
end, {})
