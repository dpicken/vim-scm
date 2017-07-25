""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Implementation detail

let s:common_buffer_observer_calls = {}

function s:common_buffer_observer_calls.onBufLeave() dict
  let self.winview = winsaveview()
endfunction

function s:common_buffer_observer_calls.onBufEnter() dict
  if self.hasLinkedBufferObserver()
    let linked_winview = self.getLinkedBufferObserver().winview
    let winview = {}
    let winview['lnum'] = linked_winview['lnum']
    let winview['topline'] = linked_winview['topline']
    let winview['topfill'] = linked_winview['topfill']
    call winrestview(winview)
  endif
endfunction

function s:MakeCommonBufferObserver(bufnr)
  let buffer_observer = scm#buffer_observer#MakeBufferObserver(a:bufnr)

  call extend(buffer_observer, s:common_buffer_observer_calls)
  call buffer_observer.registerCallbacks()

  return buffer_observer
endfunction

let s:blame_buffer_observer_calls = {}

function s:blame_buffer_observer_calls.onBufDelete() dict
  if self.hasLinkedBufferObserver()
    call self.getLinkedBufferObserver().destruct()
  endif
endfunction

function s:blame_buffer_observer_calls.actionEchoCommitComment() dict
  let revision_id = self.scm_accessor.getRevisionId(getline("."))
  echo self.scm_accessor.getCommitComment(self.source_file, revision_id)
endfunction

function s:blame_buffer_observer_calls.actionCloseBlametool() dict
  call self.deleteBuffer()
endfunction

function s:MakeBlameBufferObserver(bufnr, source_file, scm_accessor)
  let buffer_observer = s:MakeCommonBufferObserver(a:bufnr)

  call extend(buffer_observer, s:blame_buffer_observer_calls)
  call buffer_observer.registerCallbacks()

  call buffer_observer.mapKeySequence("c", "actionEchoCommitComment")
  call buffer_observer.mapKeySequence("q", "actionCloseBlametool")

  let buffer_observer.scm_accessor = a:scm_accessor
  let buffer_observer.source_file = a:source_file

  return buffer_observer
endfunction

function s:CreateBlameWindow(source_file, scm_accessor)
  let blame_file = scm#misc#MakeUniqueBufferPath(a:source_file . ".Blametool")
  execute "silent aboveleft vertical split " . blame_file

  setlocal number
  24 wincmd |

  let blame = a:scm_accessor.getBlame(a:source_file)
  call scm#misc#SetCurrentBufferContent(blame)
  call scm#misc#SetCurrentBufferTemp()
  call scm#misc#SetCurrentBufferNonModifiable()

  let blame_buffer_observer = s:MakeBlameBufferObserver(winbufnr(0), a:source_file, a:scm_accessor)
  return blame_buffer_observer
endfunction


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" API

function Blametool(scm_accessor)
  let source_file = expand("%:p")
  if !filereadable(source_file)
    echo "blametool: current file is not readable"
    return
  endif

  let source_file = scm#misc#ReducePath(source_file, a:scm_accessor.getRoot())

  let source_buffer_observer = s:MakeCommonBufferObserver(winbufnr(0))
  setlocal scrollbind

  let blame_buffer_observer = s:CreateBlameWindow(source_file, a:scm_accessor)
  setlocal scrollbind

  call source_buffer_observer.setLinkedBufferObserver(blame_buffer_observer)
  call blame_buffer_observer.setLinkedBufferObserver(source_buffer_observer)

  call blame_buffer_observer.onBufEnter()
  syncbind
endfunction
