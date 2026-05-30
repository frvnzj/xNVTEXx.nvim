local M = {}

---@class TemplateConfig
---@field name string The readable name of the template (e.g. "Article")
---@field content string The embedded LaTeX content for the initial file

---@class GitignoreConfig
---@field enabled? boolean Defines whether to create the .gitignore file automatically
---@field content? string The default content for the .gitignore file

---@class xNVTEXxConfig
---@field commands? table<string, string[]> Tables of lists representing the command and arguments
---@field project_dirs? string[] List of absolute or relative paths where projects are saved
---@field pdf_viewer? "zathura"|"sioyek"|string The default viewer to use SyncTex
---@field tex_templates? table<string, TemplateConfig> Dictionary with available templates (article, book, presentation)
---@field gitignore? GitignoreConfig Configuration for generating .gitignore files

---Returns the default configuration of the plugin
---@return xNVTEXxConfig
local function set_default_config()
  return {
    commands = {
      lualatex = {
        "latexmk",
        "-lualatex",
        "-interaction=nonstopmode",
        "-synctex=-1",
        "{main_file}",
      },
      pdflatex = { "latexmk", "-pdf", "-interaction=nonstopmode", "-synctex=-1", "{main_file}" },
      xelatex = { "latexmk", "-pdfxe", "-interaction=nonstopmode", "-synctex=-1", "{main_file}" },
      cleanmain = { "latexmk", "-c", "{main_file}" },
      cleanall = { "latexmk", "-c" },
    },
    project_dirs = {
      vim.fs.normalize("~/Documents/xNVTEXx/Articles"),
      vim.fs.normalize("~/Documents/xNVTEXx/Research"),
    },
    -- "zathura" or "sioyek" for synctex; you can use another one but it will not have synctex functionality available
    pdf_viewer = "zathura",
    tex_templates = {
      article = {
        name = "Article",
        content = [[
\documentclass{article}

\title{Title}
\author{Author}
\date{\today}

\begin{document}
\maketitle


\section{Introduction}

This is an article template.


\end{document}
]],
      },
      book = {
        name = "Book",
        content = [[
\documentclass{book}

\title{Title}
\author{Author}
\date{\today}

\begin{document}
\maketitle


\chapter{Introduction}

This is a book template.


\end{document}
]],
      },
      presentation = {
        name = "Presentation",
        content = [[
\documentclass{beamer}

\title{Title}
\author{Author}
\date{\today}

\begin{document}
\frame{\titlepage}

\begin{frame}
\frametitle{Introduction}

This is a presentation template.

\end{frame}


\end{document}
]],
      },
    },
    gitignore = {
      enabled = true,
      content = [[
# LaTeX auxiliary files
*.aux
*.fdb_latexmk
*.fls
*.log
*.synctex.gz
*.synctex(busy)
*.synctex
*.run.xml
*.pdf
*.toc
*.nav
*.snm
*.out
*.bbl
*.bcf
*.blg

# Hidden files
.justfile

# Directorys
bibliography/

# Backup files
*~
*.bak
]],
    },
  }
end

---@type xNVTEXxConfig
M.options = set_default_config()

---Initialize the plugin with the user's custom options
---@param opts xNVTEXxConfig|nil User-provided configuration options
function M.setup(opts)
  local defaults = set_default_config()

  if opts and opts.project_dirs then
    for i, dir in ipairs(opts.project_dirs) do
      opts.project_dirs[i] = vim.fs.normalize(dir)
    end
  end

  -- Recursively merges user options with default options
  M.options = vim.tbl_deep_extend("force", defaults, opts or {})
end

---Get command arguments with main_file substitution
---@param cmd_key string The command identifier (e. g.: 'lualatex')
---@param main_file string The main file name
---@return string[]|nil cmd_args Executable array for vim.system or nil if not found
function M.get_command(cmd_key, main_file)
  local raw_cmd = M.options.commands[cmd_key]

  if not raw_cmd then
    local available = vim.tbl_keys(M.options.commands)
    vim.notify(
      string.format(
        "xNVTEXx: Command '%s' not found. Available '%s'",
        cmd_key,
        table.concat(available, ", ")
      ),
      vim.log.levels.WARN
    )
    return nil
  end

  local processed_cmd = {}
  for _, arg in ipairs(raw_cmd) do
    local processed_arg = arg:gsub("{main_file}", main_file)
    table.insert(processed_cmd, processed_arg)
  end

  return processed_cmd
end

return M
