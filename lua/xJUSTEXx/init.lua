local M = {}

local config = require("xJUSTEXx.config")
local xJUSTEXx = require("xJUSTEXx.xJUSTEXx")
local xJUSTx = require("xJUSTEXx.xJUSTx")
local xOPEN_PDFx = require("xJUSTEXx.xOPEN_PDFx")
local xTEXDOCx = require("xJUSTEXx.xTEXDOCx")
local xPPLATEXx = require("xJUSTEXx.xPPLATEXx")
local xISBNx = require("xJUSTEXx.xISBNx")
local xISSNx = require("xJUSTEXx.xISSNx")
local xCTANx = require("xJUSTEXx.xCTANx")

function M.setup(opts)
  config.setup(opts)
end

M.xNEW_PROJECTx = xJUSTEXx.xNEW_PROJECTx
M.xCOMPILEx = xJUSTx.xCOMPILEx
M.xCANCELx = xJUSTx.xCANCELx
M.xVIEWERx = xOPEN_PDFx.xVIEW_PDFx
M.xTEXDOCx = xTEXDOCx.xTEXDOCx
M.xPPLATEXx = xPPLATEXx.xPPLATEXx
M.xISBNx = xISBNx.xSEARCH_ISBNx
M.xISSNx = xISSNx.xSEARCH_ISSNx
M.xCTANx = xCTANx.xSEARCH_CTANx

return M
