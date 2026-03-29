local xJUSTEXx = require("xJUSTEXx")

local function complete_justex()
  local options = {}
  local justfile = vim.fn.getcwd() .. "/.justfile"

  if vim.fn.filereadable(justfile) == 1 then
    for line in io.lines(justfile) do
      local option = line:match("^([%w_]+):")
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
  xJUSTEXx.xCOMPILEx(opts.args)
end, {
  nargs = 1,
  complete = complete_justex,
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
