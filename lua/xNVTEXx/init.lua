local M = {}

local config = require("xNVTEXx.config")
local xNVTEXx = require("xNVTEXx.xNVTEXx")
local xLATEXx = require("xNVTEXx.xLATEXx")
local xOPEN_PDFx = require("xNVTEXx.xOPEN_PDFx")
local xTEXDOCx = require("xNVTEXx.xTEXDOCx")
local xPPLATEXx = require("xNVTEXx.xPPLATEXx")
local xISBNx = require("xNVTEXx.xISBNx")
local xISSNx = require("xNVTEXx.xISSNx")
local xCTANx = require("xNVTEXx.xCTANx")
local xCITEPICKERx = require("xNVTEXx.xCITEPICKERx")

---@id xNVTEXx.config

---Initialize the xNVTEXx plugin with your custom configuration.
---@param opts xNVTEXxConfig|nil User configuration options
function M.setup(opts)
  config.setup(opts)
end

M.xNEW_PROJECTx = xNVTEXx.xNEW_PROJECTx
M.xGITIGNOREx = xNVTEXx.xGITIGNOREx
M.xCOMPILEx = xLATEXx.xCOMPILEx
M.xCANCELx = xLATEXx.xCANCELx
M.xVIEWERx = xOPEN_PDFx.xVIEW_PDFx
M.xTEXDOCx = xTEXDOCx.xTEXDOCx
M.xPPLATEXx = xPPLATEXx.xPPLATEXx
M.xISBNx = xISBNx.xSEARCH_ISBNx
M.xISSNx = xISSNx.xSEARCH_ISSNx
M.xLAST_ARTICLEx = xISSNx.xLAST_ARTICLEx
M.xLAST_RESULTSx = xISSNx.xLAST_RESULTSx
M.xCTANx = xCTANx.xSEARCH_CTANx
M.xCITEPICKERx = xCITEPICKERx.xCITEPICKERx

return M
