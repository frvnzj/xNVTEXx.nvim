local M = {}

---@class TemplateConfig
---@field name string The readable name of the template (e.g. "Article")
---@field content string The embedded LaTeX content for the initial file

---@class GitignoreConfig
---@field enabled? boolean Defines whether to create the .gitignore file automatically
---@field content? string The default content for the .gitignore file

---@class xJUSTEXxConfig
---@field project_dirs? string[] List of absolute or relative paths where projects are saved
---@field pdf_viewer? "zathura"|"sioyek"|string The default viewer to use SyncTex
---@field tex_templates? table<string, TemplateConfig> Dictionary with available templates (article, book, presentation)
---@field justfile_content? string The ".justfile" file template that is generated to manage the compilation
---@field gitignore? GitignoreConfig Configuration for generating .gitignore files

---Returns the default configuration of the plugin
---@return xJUSTEXxConfig
local function set_default_config()
  return {
    project_dirs = {
      vim.fs.normalize("~/Documents/xJUSTEXx/Articles"),
      vim.fs.normalize("~/Documents/xJUSTEXx/Research"),
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
    justfile_content = [[
main_file := "%s.tex"

lualatex:
  @latexmk -lualatex -interaction=nonstopmode -synctex=-1 "{{main_file}}"

pdflatex:
  @latexmk -pdf -interaction=nonstopmode -synctex=-1 "{{main_file}}"

pdfxe:
  @latexmk -pdfxe -interaction=nonstopmode -synctex=-1 "{{main_file}}"

cleanmain:
  @latexmk -c "{{main_file}}"

cleanall:
  @latexmk -c
]],
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

---@type xJUSTEXxConfig|{}
M.options = {}

---Initialize the plugin with the user's custom options
---@param opts xJUSTEXxConfig|nil User-provided configuration options
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

---General the final content of the ".justfile" file formatted with the project name
---@param project_name string The name of the main LaTeX file (without extension)
---@return string|nil content The formatted content or nil if invalid
---@return boolean is_valid True if formatting was successful, false otherwise
function M.set_file_justfile(project_name)
  -- Defensive check to see of '%s' is present
  if not string.find(M.options.justfile_content, "%%s") then
    vim.notify(
      "[xJUSTEXx] Error: Your custom justfile_content is missing the '%s' placeholder to inject the project name.",
      vim.log.levels.ERROR
    )
    return nil, false
  end
  return string.format(M.options.justfile_content, project_name), true
end

return M
