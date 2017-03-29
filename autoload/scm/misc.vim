""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" API

function scm#misc#IsCurrentBufferEmpty()
  return line("$") == 1 && getline(1) == ""
endfunction

function scm#misc#IsCurrentTabInUse()
  return len(tabpagebuflist()) > 1 || expand("%:p") != "" || &modified != 0 || !scm#misc#IsCurrentBufferEmpty()
endfunction

function scm#misc#SetCurrentBufferTemp()
  setlocal buftype=nofile
  setlocal bufhidden=wipe
  setlocal noswapfile
endfunction

function scm#misc#SetCurrentBufferNonModifiable()
  setlocal nomodifiable
  setlocal readonly
endfunction

function scm#misc#SetCurrentBufferModifiable()
  setlocal modifiable
  setlocal noreadonly
endfunction

function scm#misc#SetCurrentWindowCursorLineIfNotEmpty()
  if scm#misc#IsCurrentBufferEmpty()
    setlocal nocursorline
  else
    setlocal cursorline
  endif
endfunction

function scm#misc#SetCurrentBufferContent(content)
  silent 1,$delete _
  call append(0, a:content)
  $delete _
  normal! gg
endfunction

function scm#misc#HasNonWhitespaceContent(content)
  for line in a:content
    if line != "" && line !~ '^\s\+$'
      return 1
    endif
  endfor
  return 0
endfunction

function scm#misc#ReducePath(absolute_path, stem)
  return substitute(a:absolute_path, a:stem . "/", "", "")
endfunction

function scm#misc#MakeUniqueBufferPath(path)
  let path = a:path
  if bufexists(path)
    let i = 1
    while bufexists(path . "." . i)
      let i = i + 1
    endwhile
    let path = path . "." . i
  endif
  return path
endfunction

if !exists("g:scm_edit_cmd")
  let g:scm_edit_cmd = "tabedit"
endif

function scm#misc#EditFile(file)
  execute g:scm_edit_cmd . " " . a:file
endfunction
