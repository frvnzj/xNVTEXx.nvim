if vim.g.loaded_xNVTEXx then
  return
end
vim.g.loaded_xNVTEXx = 1

local xNVTEXx = require("xNVTEXx")
local config = require("xNVTEXx.config")

local function complete_compile_commands(arg_lead, _, _)
  local options = {}
  local active_commands = config.options and config.options.commands or {}

  for cmd_name, _ in pairs(active_commands) do
    if vim.startswith(cmd_name, arg_lead) then
      table.insert(options, cmd_name)
    end
  end

  table.sort(options)
  return options
end

vim.api.nvim_create_user_command("NVTexNewProject", function()
  xNVTEXx.xNEW_PROJECTx()
end, {})

vim.api.nvim_create_user_command("NVTexGitIgnore", function()
  xNVTEXx.xGITIGNOREx()
end, {})

vim.api.nvim_create_user_command("NVTexCompile", function(opts)
  local cmd = (opts.args ~= "") and opts.args or "lualatex"
  xNVTEXx.xCOMPILEx(cmd)
end, {
  nargs = "?",
  complete = complete_compile_commands,
  desc = "xNVTEXx commands",
})

vim.api.nvim_create_user_command("NVTexCancelComp", function()
  xNVTEXx.xCANCELx()
end, {})

vim.api.nvim_create_user_command("NVTexOpenPDF", function()
  xNVTEXx.xVIEWERx()
end, {})

vim.api.nvim_create_user_command("NVTexDoc", function()
  xNVTEXx.xTEXDOCx()
end, {})

vim.api.nvim_create_user_command("NVTexLog", function()
  xNVTEXx.xPPLATEXx()
end, {})

vim.api.nvim_create_user_command("NVTexSearchBook", function()
  xNVTEXx.xISBNx()
end, {})

vim.api.nvim_create_user_command("NVTexSearchJournal", function(opts)
  local subcmd = opts.fargs[1]

  if subcmd == "last_article" then
    xNVTEXx.xLAST_ARTICLEx()
  elseif subcmd == "last_results" then
    xNVTEXx.xLAST_RESULTSx()
  elseif subcmd == "search" or subcmd == nil then
    xNVTEXx.xISSNx()
  else
    vim.notify("xISSNx: unknown subcommand '" .. subcmd .. "'", vim.log.levels.ERROR)
  end
end, {
  nargs = "?",
  complete = function(ArgLead)
    local subcommands = { "search", "last_article", "last_results" }
    return vim.tbl_filter(function(cmd)
      return cmd:find("^" .. ArgLead)
    end, subcommands)
  end,
})

vim.api.nvim_create_user_command("NVTexSearchCTAN", function()
  xNVTEXx.xCTANx()
end, {})
