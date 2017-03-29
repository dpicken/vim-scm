""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" API

function OpenSCMTool(tool)
  let scm_accessor = scm#accessor_factory#GetAccessorUsingCurrentFileOrDirectory()
  if empty(scm_accessor)
    echo "scm: current file/directory is not in a supported scm repository"
    return
  endif

  call call(a:tool, [scm_accessor])
endfunction
