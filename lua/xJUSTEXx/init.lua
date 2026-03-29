local M = {}

local config = require("xJUSTEXx.config")
local xJUSTx = require("xJUSTEXx.xJUSTx")
local xJUSTEXx = require("xJUSTEXx.xJUSTEXx")
local xISBNx = require("xJUSTEXx.xISBNx")
local xISSNx = require("xJUSTEXx.xISSNx")
local xCTANx = require("xJUSTEXx.xCTANx")

function M.setup(opts)
  config.setup(opts)
end

M.xNEW_PROJECTx = xJUSTEXx.xNEW_PROJECTx
M.xCOMPILEx = xJUSTx.xCOMPILEx
M.xCANCELx = xJUSTx.xCANCELx
M.xTEXDOCx = xJUSTEXx.xTEXDOCx
M.xPPLATEXx = xJUSTEXx.xPPLATEXx
M.xISBNx = xISBNx.xSEARCH_ISBNx
M.xISSNx = xISSNx.xCROSSREFx
M.xCTANx = xCTANx.xCTANSEARCHx

return M
