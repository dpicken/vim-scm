""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Implementation detail

let s:scm_accessors = []


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" API

function scm#accessor_factory#RegisterAccessor(scm_accessor)
  let s:scm_accessors += [a:scm_accessor]
endfunction

function scm#accessor_factory#GetAccessorUsingCurrentFileOrDirectory()
  let path = expand("%:p:h")
  if path == ""
    let path = getcwd()
  endif

  for scm_accessor in s:scm_accessors
    let scm_accessor = deepcopy(scm_accessor)
    if scm_accessor.setRoot(path)
      return scm_accessor
    endif
  endfor

  return {}
endfunction
