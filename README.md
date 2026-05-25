# xJUSTEXx

![xJUSTEXx](assets/xJUSTEXx.png)

Hice este plugin con la idea de facilitar la creación de mis ensayos con LaTeX
a través de Neovim. Mezclo la creación de proyectos (una estructura básica de
workspace e inicialización de repositorio git) con el fácil acceso a los
comandos de TeXlive para compilar a través Just y justfile.

I made this plugin with the idea of create project articleas easy with LaTeX
and Neovim. This plugin create a project directory with the name of the
project, a main.tex and a .justfile for compile.

## Tabla de Contenidos

- [Dependencias](#dependencias)
- [Instalación](#install)
- [Configuración](#configuration)
- [Uso](#use)
- [Opciones de Configuración](#change-default-configuration)
- [Contribuciones](#contribuciones)

## Dependencias

- Neovim >= 0.12
- Git
- Just
- Zathura
- Curl
- ¡Obviamente TeXlive!

## Install

Para instalar puedes usar el plugin manager que prefieras. El siguiente ejemplo
es con [lazy.nvim](https://github.com/folke/lazy.nvim).

To install you can use the plugin manager you prefer. The following example is
with [lazy.nvim](https://github.com/folke/lazy.nvim).

```lua
{
  "frvnzj/xJUSTEXx.nvim",
  config = function()
    require("xJUSTEXx").setup()
  end,
}

-- or if you are a noice.nvim user

{
  {
    "frvnzj/xJUSTEXx.nvim",
    config = function()
      require("xJUSTEXx").setup()
    end,
  },
  {
    "folke/noice.nvim",
    opts = {
      routes = {
        {
          filter = {
            event = "msg_show",
            kind = "progress",
          },
          view = "mini",
          opts = {
            replace = true,
          },
        },
      },
    },
  },
}

```

> 🗒️
> Para mostrar el progreso de la compilación usé nvim_echo().
> To show the build progress I used nvim_echo().

## Configuration

La configuración del plugin tiene cinco opciones:

- definición de los directorios de los proyectos
- visualizador pdf con synctex
- plantillas o contenidos con el que se iniciará el main tex
- el contenido del .justfile que declara los comandos a usar
- inclusión del archivo gitignore

Las opciones por default son las siguientes:

The plugin configuration has five options:

- definition of the project directories
- pdf viewer with synctex
- templates or contents with which the main tex will be started
- the co ntent of the .justfile that declares the commands to use
- inclusion of the gitignore file

The default options are the following:

```lua
{
  project_dirs = {
    vim.fs.normalize("~/Documents/xJUSTEXx/Articles"),
    vim.fs.normalize("~/Documents/xJUSTEXx/Research"),
  },
  -- "zathura" or "sioyek" for synctex; you can use another one but it will not have synctex functionality available
  pdf_viewer = "zathura",
  tex_templates = {
    article = {
      name = 'Article',
      content = [[
\documentclass{article}


\begin{document}

\title{Title}
\author{Author}
\date{\today}
\maketitle


\section{Introduction}

This is an article template.


\end{document}
      ]],
    },
    book = {
      name = 'Book',
      content = [[
\documentclass{book}


\begin{document}

\title{Title}
\author{Author}
\date{\today}
\maketitle


\chapter{Introduction}

This is a book template.


\end{document}
      ]],
    },
    presentation = {
      name = 'Presentation',
      content = [[
\documentclass{beamer}


\begin{document}
\title{Title}
\author{Author}
\date{\today}
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
```

> ⚠️
> Para abrir el PDF compilado puedes establecer Zathura, Sioyek u otro vizor de
> PDF en la opción pdf_viewer; sin embargo, los comandos JustexSearchCTAN y
> JustexSearchJournal siguen dependiendo de Zathura para abrir PDF.

> ⚠️
> To open the compiled PDF you can set Zathura, Sioyek or another PDF viewer to
> the pdf_viewer option; however, the JustexSearchCTAN and JustexSearchJournal
> commands still rely on Zathura to open PDF.

## Use

![JustexNewProject](assets/JustexNewProject.png)

![JustexSearchCTAN](assets/JustexSearchCTAN.png)

![JustexSearchJournal](assets/JustexSearchJournal.png)

xJUSTEXx ofrece diez comandos:

- **JustexNewProject**: crea un proyecto nuevo (directorio del proyecto,
  repositorio Git y tex file con el nombre del proyecto).

- **JustexCompile**: compila utilizando optativamente LuaLaTeX, pdfLaTeX o
  XeLaTeX (dependiendo de tu `justfile_content`) con la ayuda/dependencia de
  [Just](https://github.com/casey/just).
  - `:JustexCompile lualatex`
  - `:JustexCompile pdflatex`
  - `:JustexCompile pdfxe`
  - `:JustexCompile cleanmain`
  - `:JustexCompile cleanall`

  > ℹ️
  > Si ya tienes un proyecto que no fue creado con xJUSTEXx, al ejecutar
  > `JustexCompile` el plugin te preguntará si deseas que cree el archivo
  > .justfile para compilar ya que depende de este.

- **JustexCancelComp**: cancela la compilación cuando lo creas necesario.

- **JustexOpenPDF**: abre el PDF del main file con zathura(default) o sioyek;
  si estás ubicado en un archivo dependiente del main file, también se abrirá el
  PDF del proyecto.

- **JustexSearchCTAN**: enlista todos los paquetes de CTAN para buscar
  documentación. Los PDF's se abrirán en Zathura, la documentación HTMl en el
  navegador y los archivos de texto en Neovim, estos últimos se descargarán al
  caché, `stdpath('cache')`.

- **JustexDoc**: abre la documentación del package bajo el cursor con el uso de
  texdoc.

- **JustexLog**: abre el logfile para visualizar errores (requiere pplatex).

- **JustexSearchBook**: busca referencias con ISBN y las añade al archivo
  refs.bib, que se creará automáticamente en el directorio raíz del proyecto, al
  confirmar la entrada.

  > ❕
  > Para buscar las referencias bibliográficas, el plugin hace uso del api de
  > Open Library, por lo que algunas referencias pueden no ser encontradas o
  > algunos campos pueden estar vacíos y tendrán que definirse manualmente. Por
  > ahora sólo busca referencias de libros.

- **JustexSearchJournal**: busca referencias por medio de CrossRef, tiene mayor
  versatilidad este comando gracias a su API y por el mismo índice de revistas
  académicas.
  - **JustexSearchJournal last_article**: con este subcomando podras abrir las
    opciones para el último artículo consultado.
  - **JustexSearchJournal last_results**: con este subcomando podras consultar
    la última búsqueda de artículos.

  > ❕
  > Comienza por hacer la búsqueda de la revista académica, ya sea por palabras
  > clave o por el ISSN; después, busca artículos por palabras clave. Del
  > artículo seleccionado podrás agregar la referencia en formato biblatex en
  > el archivo refs.bib (se creará automáticamente), podrás abrir y descargar
  > el PDF del artículo en Zathura (es el único viewer configurado por ahora) o
  > descargar el EPUB. La accesibilidad a PDF's o EPUB's depende de la
  > disponibilidad de las revistas.

- **JustexGitIgnore**: Si ya tienes un proyecto existente, este comando genera
  el archivo .gitignore, útil para ignorar los archivos auxiliares que genera
  LaTeX en la compilación y eliminar el ruido al controlar los cambios en el
  proyecto.

---

xJUSTEXx offers ten commands:

- **JustexNewProject**: Create a new project (Project Board, Git repository and
  Tex File with the name of the project).

- **JustexCompile**: Compila using optionally LuaLaTeX, pdfLaTeX or XeLaTeX
  (depending on your `justfile_content`) with
  [Just's](https://github.com/casey/just) help.
  - `:JustexCompile lualatex`
  - `:JustexCompile pdflatex`
  - `:JustexCompile pdfxe`
  - `:JustexCompile cleanmain`
  - `:JustexCompile cleanall`

  > ℹ️
  > If you already have a project that was not created with xJUSTEXx, when you
  > run `JustexCompile` the plugin will ask you if you want it to create the
  > .justfile file to compile since it depends on it.

- **JustexCancelComp**: cancel the compilation when you think it is necessary.

- **JustexOpenPDF**: open the PDF of the main file with zathura(default) or
  sioyek; If you are located in a file dependent on the main file, the PDF of the
  project will also open.

- **JustexSearchCTAN**: List all CTAN packages to search for documentation. The
  PDF's will open in Zathura, the HTML documentation in the browser and the text
  files in Neovim, the latter will be downloaded to the cache, `stdpath
('cache')`.

- **JustexDoc**: Open the Package documentation under the cursor with the use
  of Texdoc.

- **JustexLog**: Open the logfile to visualize errors (requires pplatex).

- **JustexSearchBook**: Look for references with ISBN and add them to the
  refs.bib file, which will be automatically created in the root directory of the
  project, confirming the entrance.

  > ❕
  > To look for bibliographic references, the plugin makes use of the Open
  > Library API, so some references may not be found or some fields may be
  > empty and will have to be defined manually. For now it only looks for book
  > references.

- **JustexSearchJournal**: Look for references through Crossref, this command
  has greater versatility thanks to its API and the same index of academic
  journals.
  - **JustexSearchJournal last_article**: with this subcommand you can open the
    options for the last article consulted.
  - **JustexSearchJournal last_results**: with this subcommand you can consult
    the last article search.

  > ❕
  > Start by searching for the academic journal, either by keywords or by ISSN;
  > then search for articles by keywords. For the selected article you can add
  > the reference in biblatex format in the refs.bib file (it will be created
  > automatically), you can open and download the PDF of the article in Zathura
  > (it is the only viewer configured for now) or download the EPUB.
  > Accessibility to PDF's or EPUB's depends on the availability of the
  > journals.

- **JustexGitIgnore**: If you already have an existing project, this command
  generates the .gitignore file, useful to ignore the auxiliary files that LaTeX
  generates in the compilation and eliminate noise when controlling changes in
  the project.

## Change default configuration

![xPLANTILLAx](assets/xPLANTILLAx.png)

La configuración no se limita a las 3 opciones disponibles a modificar del
plugin. Por ejemplo, la configuración de uso personal para iniciar proyectos de
ensayo:

You can change the default configuration, for example, I set my own template
and directories:

```lua
require("xJUSTEXx").setup({
  tex_templates = {
    article = {
      name = "Article",
      content = [[
\documentclass[doc,12pt]{apa7}

% Font option: Arial[Arial], Carlito[Carlito], Droid Serif[Droid],
% GFS Didot [GFSDidot](default), IM FELL English[IMFELLEnglish], Kerkis[Kerkis], Times New Roman[TNR].
\usepackage{xJAVx-apa7}

\addbibresource{refs.bib}

% \hypersetup{
%  pdftitle={<++>},
%  pdfkeywords={<++>}
% }


\begin{document}

\authorsnames{<++>}
\authorsaffiliations{<++>}
\title{<++>}
\shorttitle{<++>}

% \abstract{<++>}
% \keywords{<++>}

% \authornote{<++>}

\maketitle

% \fontsize{12pt}{14pt}\selectfont\doublespacing{}
\fontsize{12pt}{14pt}\selectfont\onehalfspacing{}

<++>


% ----- Bibliografía -----
% \printbibliography
\end{document}]],
    },
  },
  project_dirs = {
    vim.fn.expand("$HOME") .. "/Documentos/Ensayos",
    "~/Documentos/Research",
    "/home/$USER/Documentos/Presentations"
  },
})
```

También puedes definir tu propia plantilla siguiendo la tabla de `tex_templates`:

Also you can define your own template following the table of `tex_templates`:

```lua
tex_templates = {
    myTemplate = {
        name = 'MyTemplate',
        content = [[
This is MyTemplate]],
    },
},
```

---

![xJUSTx](assets/xJUSTx.png)

También es recomendable el uso de
[which-key](https://github.com/folke/which-key.nvim) o nvim_set_keymap() en
`ftplugin/tex.lua` y `ftplugin/plaintex.lua`, por ejemplo:

It is also recommended to use
[which-key](https://github.com/folke/which-key.nvim) or nvim_set_keymap() in
`ftplugin/tex.lua` y `ftplugin/plaintex.lua`, for example:

```lua
local function keymap(map, command, desc)
  vim.keymap.set("n", map, command, { silent = true, desc = desc })
end

keymap("<leader>aa", "<cmd>JustexCompile lualatex<cr>", "xLUALATEXx")
keymap("<leader>acc", "<cmd>JustexCompile pdflatex<cr>", "xLATEXx")
keymap("<leader>acx", "<cmd>JustexCompile pdfxe<cr>", "xXELATEXx")
keymap("<leader>add", "<cmd>JustexCompile cleanmain<cr>", "xCLEAN-MAINx")
keymap("<leader>ada", "<cmd>JustexCompile cleanall<cr>", "xCLEAN-ALLx")
keymap("<leader>aq", "<cmd>JustexCancelComp<cr>", "Cancel Comp")

keymap("<leader>ai", "<cmd>JustexSearchBook<cr>", "JustexISBN")
keymap("<leader>ajj", "<cmd>JustexSearchJournal<cr>", "SEARCHxISSN")
keymap("<leader>aja", "<cmd>JustexSearchJournal last_article<cr>", "lastXarticle")
keymap("<leader>ajs", "<cmd>JustexSearchJournal last_results<cr>", "lastXresults")

keymap("<leader>am", "<cmd>JustexSearchCTAN<cr>", "JustexCTAN")
keymap("<leader>at", "<cmd>JustexDoc<cr>", "JustexTexdoc")

keymap("<leader>ao", "<cmd>JustexLog<cr>", "JustexLog")

keymap("<leader>az", "<cmd>JustexOpenPDF<cr>", "JustexPDF")
```

## Contribuciones

Si deseas contribuir mejorando el plugin o reportar errores, quedo atento.

### License MIT
