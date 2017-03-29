""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Implementation detail

let s:buffer_observer = {}

function s:MakeUniqueBufferObserverVarName(bufnr)
  let var_name = "g:scm_buffer_observer_" . a:bufnr
  if exists(var_name)
    let i = 1
    while exists(var_name . "_" . i)
      let i = i + 1
    endwhile
    let var_name = var_name . "_" . i
  endif
  return var_name
endfunction

function s:buffer_observer.construct(bufnr)
  let self.bufnr = a:bufnr
  let self.name = s:MakeUniqueBufferObserverVarName(a:bufnr)
  let self.augroup_name = substitute(self.name, "^g:", "", "")
  let self.linked_buffer_observers = {}
  execute "let " . self.name . " = self"
endfunction

function s:buffer_observer.destruct()
  call self.deregisterCallbacks()
  execute "unlet " . self.name
endfunction

function s:buffer_observer.deleteBuffer()
  execute "bdelete " . self.bufnr
endfunction

function s:buffer_observer.switchToWindow() dict
  let winnr = bufwinnr(self.bufnr)
  if winnr == -1
    return 0
  endif

  execute winnr . "wincmd w"
  return 1
endfunction

function s:buffer_observer.getContent() dict
  return getbufline(self.bufnr, 1, "$")
endfunction

function s:buffer_observer.setLinkedBufferObservers(buffer_observers) dict
  let self.linked_buffer_observers = {}
  for buffer_observer in a:buffer_observers
    let self.linked_buffer_observers[buffer_observer.name] = buffer_observer
  endfor
endfunction

function s:buffer_observer.hasNamedLinkedBufferObserver(name) dict
  return has_key(self.linked_buffer_observers, a:name)
endfunction

function s:buffer_observer.getNamedLinkedBufferObservers(name) dict
  return self.linked_buffer_observers[a:name]
endfunction

function s:buffer_observer.setLinkedBufferObserver(buffer_observer) dict
  call self.setLinkedBufferObservers([a:buffer_observer])
endfunction

function s:buffer_observer.hasLinkedBufferObserver() dict
  return len(self.linked_buffer_observers) == 1
endfunction

function s:buffer_observer.getLinkedBufferObserver() dict
  return values(self.linked_buffer_observers)[0]
endfunction

function s:buffer_observer.removeSelfFromLinkedBufferObservers() dict
  for buffer_observer in values(self.linked_buffer_observers)
    unlet buffer_observer.linked_buffer_observers[self.name]
  endfor
endfunction

function s:buffer_observer.deleteLinkedBuffers() dict
  for linked_buffer_observer in values(self.linked_buffer_observers)
    execute "bdelete " . linked_buffer_observer.bufnr
  endfor
endfunction

function s:OnBufDelete(name)
  if exists("*" . a:name . ".onBufDelete")
    execute "call " . a:name . ".onBufDelete()"
  endif
  execute "call " . a:name . ".removeSelfFromLinkedBufferObservers()"
  execute "call " . a:name . ".destruct()"
endfunction

function s:GetEvent(buffer_observer, key)
  if type(a:buffer_observer[a:key]) != type(function("type"))
    return ""
  endif

  if a:key !~# '^on.*'
    return ""
  endif

  return substitute(a:key, '^on', "", "")
endfunction

function s:buffer_observer.registerCallbacks()
  execute "augroup " . self.augroup_name
    autocmd!
    execute "autocmd BufDelete <buffer=" . self.bufnr . "> call s:OnBufDelete(\"" . self.name . "\")"
    for key in keys(self)
      let event = s:GetEvent(self, key)
      if event != "" && event !=# "BufDelete"
        execute "autocmd " . event . " <buffer=" . self.bufnr . "> call " . self.name . ".on" . event . "()"
      endif
    endfor
  augroup END
endfunction

function s:buffer_observer.deregisterCallbacks()
  execute "augroup " . self.augroup_name
    autocmd!
  augroup END
  execute "augroup! " . self.augroup_name
endfunction

function s:buffer_observer.mapKeySequence(key_sequence, callback_name)
  execute "noremap <buffer> <silent> " . a:key_sequence . " <esc>:call " . self.name . "." . a:callback_name . "()<CR>"
endfunction

function s:buffer_observer.mapKeySequenceWithVisualRange(key_sequence, callback_name)
  call self.mapKeySequence(a:key_sequence, a:callback_name)
  execute "vnoremap <buffer> <silent> " . a:key_sequence . " <esc>:'<,'>call " . self.name . "." . a:callback_name . "()<CR>"
endfunction


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" API

function scm#buffer_observer#MakeBufferObserver(bufnr)
  let buffer_observer = deepcopy(s:buffer_observer)
  call buffer_observer.construct(a:bufnr)
  return buffer_observer
endfunction
