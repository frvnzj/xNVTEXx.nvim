local M = {}

local function set_default_config()
  return {
    project_dirs = {
      vim.fs.normalize("~/Documents/xJUSTEXx/Articles"),
      vim.fs.normalize("~/Documents/xJUSTEXx/Research"),
    },
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
  @latexmk -lualatex -interaction=nonstopmode -synctex=-1 {{main_file}}

pdflatex:
  @latexmk -pdf -interaction=nonstopmode -synctex=-1 {{main_file}} 

pdfxe:
  @latexmk -pdfxe -interaction=nonstopmode -synctex=-1 {{main_file}} 

cleanmain:
  @latexmk -c {{main_file}}

cleanall:
  @latexmk -c
]],
  }
end

M.options = {}

function M.setup(opts)
  local defaults = set_default_config()

  if opts and opts.project_dirs then
    for i, dir in ipairs(opts.project_dirs) do
      opts.project_dirs[i] = vim.fs.normalize(dir)
    end
  end

  M.options = vim.tbl_deep_extend("force", defaults, opts or {})
end

function M.set_file_justfile(project_name)
  return string.format(M.options.justfile_content, project_name)
end

return M
