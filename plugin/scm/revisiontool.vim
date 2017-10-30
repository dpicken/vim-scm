""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Implementation detail

function s:RefreshCurrentBufferContent(content)
  call scm#misc#SetCurrentBufferModifiable()
  call scm#misc#SetCurrentBufferContent(a:content)
  call scm#misc#SetCurrentBufferNonModifiable()
endfunction

function s:Search(pattern, search_command)
  let @/ = a:pattern
  try
    execute 'silent normal! ' . a:search_command
  catch "E486: Pattern not found"
    return 0
  endtry
  return 1
endfunction

function s:SwitchToLinkedBufferAndSearch(buffer_observer, linked_buffer_observer_name, pattern, search_command)
  if a:buffer_observer.hasNamedLinkedBufferObserver(a:linked_buffer_observer_name)
    if a:buffer_observer.getNamedLinkedBufferObservers(a:linked_buffer_observer_name).switchToWindow()
      if s:Search(a:pattern, a:search_command)
        return 1
      endif
    endif
  endif
  return 0
endfunction

function s:SwitchToCurrentRevisionAndJumpToFirstChange(buffer_observer)
  if a:buffer_observer.hasNamedLinkedBufferObserver(a:buffer_observer.current_revision_buffer_observer_name)
    if a:buffer_observer.getNamedLinkedBufferObservers(a:buffer_observer.current_revision_buffer_observer_name).switchToWindow()
      normal! gg]c
      return 1
    endif
  endif
  return 0
endfunction

function s:MakeWordPattern(word)
  return '\m\<' . a:word . '\>'
endfunction

function s:MakeCommitCommentFilePattern(file)
  return '\m^\s*' . escape(a:file, '~') . '\(\(:\s*.*\)\|\($\)\)'
endfunction

function s:AugmentCommitCommentWithUncommentedFiles(commit_comment, commit_files)
  let uncommented_commit_files = []
  for commit_file in a:commit_files
    let commit_file_commented = (match(a:commit_comment, s:MakeCommitCommentFilePattern(commit_file)) != -1)
    if !commit_file_commented
      let uncommented_commit_files += [commit_file]
    endif
  endfor
  return a:commit_comment + (empty(uncommented_commit_files) ? [] : [''] + uncommented_commit_files)
endfunction

function s:RefreshCommitBuffer(history_buffer_observer, source_file, revision_id)
  if a:history_buffer_observer.hasNamedLinkedBufferObserver(a:history_buffer_observer.commit_buffer_observer_name)
    let commit_buffer_observer = a:history_buffer_observer.getNamedLinkedBufferObservers(a:history_buffer_observer.commit_buffer_observer_name)
    if commit_buffer_observer.switchToWindow()
      let commit_buffer_observer.current_line_number = 0
      let commit_buffer_observer.commit_id = a:history_buffer_observer.scm_accessor.getCommitId(a:source_file, a:revision_id)
      let commit_buffer_observer.commit_files = a:history_buffer_observer.scm_accessor.getCommitFiles(a:source_file, a:revision_id)
      let commit_comment = split(a:history_buffer_observer.scm_accessor.getCommitComment(a:source_file, a:revision_id), '\n')
      let commit_buffer_content = s:AugmentCommitCommentWithUncommentedFiles(commit_comment, commit_buffer_observer.commit_files)
      call s:RefreshCurrentBufferContent(commit_buffer_content)
      call a:history_buffer_observer.switchToWindow()
      call a:history_buffer_observer.actionContextSearchOfLinkedBuffer()
      call a:history_buffer_observer.switchToWindow()
      return 1
    endif
  endif
  return 0
endfunction

function s:RefreshRevisionBuffer(buffer_observer, revision_buffer_observer_name, source_file, revision_id)
  if a:buffer_observer.hasNamedLinkedBufferObserver(a:revision_buffer_observer_name)
    let revision_buffer_observer = a:buffer_observer.getNamedLinkedBufferObservers(a:revision_buffer_observer_name)
    if revision_buffer_observer.switchToWindow()
      let revision_buffer_observer.current_source_file = a:source_file
      let revision_buffer_observer.current_revision_id = a:revision_id
      let revision_buffer_content = (a:revision_id != "") ? a:buffer_observer.scm_accessor.getBlameAndContent(a:source_file, a:revision_id) : ""
      diffoff
      call s:RefreshCurrentBufferContent(revision_buffer_content)
      diffthis
      normal! zR
      call a:buffer_observer.switchToWindow()
      call a:buffer_observer.actionContextSearchOfLinkedBuffer()
      call a:buffer_observer.switchToWindow()
      return 1
    endif
  endif
  return 0
endfunction

let s:common_buffer_observer_calls = {}

function s:common_buffer_observer_calls.actionCloseRevisiontool() dict
  call self.deleteLinkedBuffers()
  call self.deleteBuffer()
endfunction

function s:MakeCommonBufferObserver(bufnr, scm_accessor)
  let buffer_observer = scm#buffer_observer#MakeBufferObserver(a:bufnr)
  call extend(buffer_observer, s:common_buffer_observer_calls)

  call buffer_observer.mapKeySequence("q", "actionCloseRevisiontool")

  let buffer_observer.scm_accessor = a:scm_accessor

  return buffer_observer
endfunction

let s:history_buffer_observer_calls = {}

function s:history_buffer_observer_calls.onCursorMoved() dict
  if scm#misc#IsCurrentBufferEmpty()
    return
  endif

  let current_line_number = line(".")
  if self.current_line_number == current_line_number
    return
  endif
  let self.current_line_number = current_line_number

  let current_revision_id = self.scm_accessor.getRevisionId(getline(current_line_number))
  let previous_revision_id = self.scm_accessor.getParentRevisionId(self.source_file, current_revision_id)

  if s:RefreshCommitBuffer(self, self.source_file, current_revision_id)
    let commit_buffer_observer = self.getNamedLinkedBufferObservers(self.commit_buffer_observer_name)
    call commit_buffer_observer.switchToWindow()
    call commit_buffer_observer.onCursorMoved()
    call self.switchToWindow()
  else
    call s:RefreshRevisionBuffer(self, self.current_revision_buffer_observer_name, self.source_file, current_revision_id)
    call s:RefreshRevisionBuffer(self, self.previous_revision_buffer_observer_name, self.source_file, previous_revision_id)
  endif
endfunction

function s:history_buffer_observer_calls.actionContextSearchOfLinkedBuffer() dict
  if scm#misc#IsCurrentBufferEmpty()
    return
  endif

  if !s:SwitchToLinkedBufferAndSearch(self, self.commit_buffer_observer_name, s:MakeCommitCommentFilePattern(self.source_file), "G$n")
    call s:SwitchToCurrentRevisionAndJumpToFirstChange(self)
  endif
endfunction

function s:CreateHistoryWindow(scm_accessor, source_file)
  let history_bufname = scm#misc#MakeUniqueBufferPath(a:source_file . "/Revisiontool_History")
  execute "silent tabedit " . history_bufname

  let history = a:scm_accessor.getRevisionHistory(a:source_file)
  call s:RefreshCurrentBufferContent(history)
  call scm#misc#SetCurrentBufferTemp()
  call scm#misc#SetCurrentWindowCursorLineIfNotEmpty()
  normal! gg

  let history_buffer_observer = s:MakeCommonBufferObserver(winbufnr(0), a:scm_accessor)
  call extend(history_buffer_observer, s:history_buffer_observer_calls)

  let history_buffer_observer.source_file = scm#misc#ReducePath(a:source_file, a:scm_accessor.getRoot())
  let history_buffer_observer.current_line_number = 0

  call history_buffer_observer.registerCallbacks()
  call history_buffer_observer.mapKeySequence("<Return>", "actionContextSearchOfLinkedBuffer")

  return history_buffer_observer
endfunction

let s:commit_buffer_observer_calls = {}

function s:commit_buffer_observer_calls.currentLineToFile() dict
  let line = getline(".")
  for commit_file in self.commit_files
    if match(line, s:MakeCommitCommentFilePattern(commit_file)) != -1
      return commit_file
    endif
  endfor
  return ""
endfunction

function s:commit_buffer_observer_calls.onCursorMoved() dict
  let current_line_number = line(".")
  if self.current_line_number == current_line_number
    return
  endif
  let self.current_line_number = current_line_number

  let source_file = self.currentLineToFile()
  let current_revision_id = source_file != "" ? self.scm_accessor.getRevisionIdFromCommitId(source_file, self.commit_id) : ""
  let previous_revision_id = source_file != "" ? self.scm_accessor.getParentRevisionId(source_file, current_revision_id) : ""

  call s:RefreshRevisionBuffer(self, self.current_revision_buffer_observer_name, source_file, current_revision_id)
  call s:RefreshRevisionBuffer(self, self.previous_revision_buffer_observer_name, source_file, previous_revision_id)
endfunction

function s:commit_buffer_observer_calls.actionEditFile() dict
  if scm#misc#IsCurrentBufferEmpty()
    return
  endif

  let file = self.currentLineToFile()
  call scm#misc#EditFile(self.scm_accessor.getRoot() . "/" . file)
endfunction

function s:commit_buffer_observer_calls.actionContextSearchOfLinkedBuffer() dict
  if scm#misc#IsCurrentBufferEmpty()
    return
  endif

  call s:SwitchToCurrentRevisionAndJumpToFirstChange(self)
endfunction

function s:CreateCommitWindow(scm_accessor)
  let commit_bufname = scm#misc#MakeUniqueBufferPath(a:scm_accessor.getRoot() . "/Revisiontool_Commit")
  execute "silent botright split " . commit_bufname

  call scm#misc#SetCurrentBufferNonModifiable()
  call scm#misc#SetCurrentBufferTemp()
  setlocal cursorline
  setlocal wrap

  let commit_buffer_observer = s:MakeCommonBufferObserver(winbufnr(0), a:scm_accessor)
  call extend(commit_buffer_observer, s:commit_buffer_observer_calls)

  let commit_buffer_observer.current_line_number = 0
  let commit_buffer_observer.commit_id = ""
  let commit_buffer_observer.commit_files = []

  call commit_buffer_observer.registerCallbacks()
  call commit_buffer_observer.mapKeySequence("e", "actionEditFile")
  call commit_buffer_observer.mapKeySequence("<Return>", "actionContextSearchOfLinkedBuffer")

  return commit_buffer_observer
endfunction

let s:revision_buffer_observer_calls = {}

function s:revision_buffer_observer_calls.actionContextSearchOfLinkedBuffer() dict
  if scm#misc#IsCurrentBufferEmpty()
    return
  endif

  if self.hasNamedLinkedBufferObserver(self.history_buffer_observer_name)
    let history_buffer_observer = self.getNamedLinkedBufferObservers(self.history_buffer_observer_name)
    if self.current_source_file == history_buffer_observer.source_file
      let revision_id = self.scm_accessor.getRevisionId(getline("."))
      call s:SwitchToLinkedBufferAndSearch(self, self.history_buffer_observer_name, s:MakeWordPattern(revision_id), "G$N")
      return
    endif
  endif
  call s:SwitchToLinkedBufferAndSearch(self, self.commit_buffer_observer_name, s:MakeCommitCommentFilePattern(self.current_source_file), "G$n")
endfunction

function s:CreateRevisionWindow(scm_accessor, split, title_qualification)
  let revision_bufname = scm#misc#MakeUniqueBufferPath(a:scm_accessor.getRoot() . "/Revisiontool_" . a:title_qualification)
  execute "silent " . a:split . " " . revision_bufname

  call scm#misc#SetCurrentBufferNonModifiable()
  call scm#misc#SetCurrentBufferTemp()

  let revision_buffer_observer = s:MakeCommonBufferObserver(winbufnr(0), a:scm_accessor)
  call extend(revision_buffer_observer, s:revision_buffer_observer_calls)

  call revision_buffer_observer.registerCallbacks()
  call revision_buffer_observer.mapKeySequence("<Return>", "actionContextSearchOfLinkedBuffer")
  noremap <buffer> <C-J> ]c
  noremap <buffer> <C-K> [c

  return revision_buffer_observer
endfunction


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" API

function Revisiontool(scm_accessor)
  let source_file = expand("%:p")
  if !filereadable(source_file)
    echo "revisiontool: current file is not readable"
    return
  endif

  let current_line_number = line(".")

  let history_buffer_observer = s:CreateHistoryWindow(a:scm_accessor, source_file)
  let commit_buffer_observer = s:CreateCommitWindow(a:scm_accessor)
  let previous_revision_buffer_observer = s:CreateRevisionWindow(a:scm_accessor, "botright split", "PreviousRevision")
  let current_revision_buffer_observer = s:CreateRevisionWindow(a:scm_accessor, "belowright vsplit", "SelectedRevision")

  call history_buffer_observer.setLinkedBufferObservers([commit_buffer_observer, current_revision_buffer_observer, previous_revision_buffer_observer])
  call commit_buffer_observer.setLinkedBufferObservers([history_buffer_observer, current_revision_buffer_observer, previous_revision_buffer_observer])
  call current_revision_buffer_observer.setLinkedBufferObservers([history_buffer_observer, commit_buffer_observer, previous_revision_buffer_observer])
  call previous_revision_buffer_observer.setLinkedBufferObservers([history_buffer_observer, commit_buffer_observer, current_revision_buffer_observer])

  let history_buffer_observer.commit_buffer_observer_name = commit_buffer_observer.name
  let history_buffer_observer.current_revision_buffer_observer_name = current_revision_buffer_observer.name
  let history_buffer_observer.previous_revision_buffer_observer_name = previous_revision_buffer_observer.name

  let commit_buffer_observer.current_revision_buffer_observer_name = current_revision_buffer_observer.name
  let commit_buffer_observer.previous_revision_buffer_observer_name = previous_revision_buffer_observer.name

  let current_revision_buffer_observer.history_buffer_observer_name = history_buffer_observer.name
  let current_revision_buffer_observer.commit_buffer_observer_name = commit_buffer_observer.name

  let previous_revision_buffer_observer.history_buffer_observer_name = history_buffer_observer.name
  let previous_revision_buffer_observer.commit_buffer_observer_name = commit_buffer_observer.name

  call history_buffer_observer.switchToWindow()
  call history_buffer_observer.onCursorMoved()
  call current_revision_buffer_observer.switchToWindow()
  execute "normal! " . current_line_number . "gg"
  call current_revision_buffer_observer.actionContextSearchOfLinkedBuffer()
endfunction
