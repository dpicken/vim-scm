" Implementation detail

let s:common_buffer_observer_calls = {}

function s:common_buffer_observer_calls.actionCloseCommittool() dict
  call self.deleteLinkedBuffers()
  call self.deleteBuffer()
endfunction

function s:common_buffer_observer_calls.switchToChangedFilesWindowAndDispatch(function_name) dict
  if self.hasNamedLinkedBufferObserver(self.changed_files_buffer_observer_name)
    let changed_files_buffer_observer = self.getNamedLinkedBufferObservers(self.changed_files_buffer_observer_name)
    if changed_files_buffer_observer.switchToWindow()
      execute "call changed_files_buffer_observer." . a:function_name . "()"
    endif
  endif
endfunction

function s:common_buffer_observer_calls.actionCommit() dict
  call self.switchToChangedFilesWindowAndDispatch("commit")
endfunction

function s:common_buffer_observer_calls.actionRefresh() dict
  call self.switchToChangedFilesWindowAndDispatch("refresh")
endfunction

function s:common_buffer_observer_calls.load() dict
  if !has_key(self, "persist_file") || !filereadable(self.persist_file)
    return
  endif

  let content = readfile(self.persist_file)
  call scm#misc#SetCurrentBufferContent(content)
endfunction

function s:common_buffer_observer_calls.hasSaveContent()
  return scm#misc#HasNonWhitespaceContent(self.getContent())
endfunction

function s:common_buffer_observer_calls.save() dict
  if !has_key(self, "persist_file")
    return 0
  endif

  if self.hasSaveContent()
    return writefile(self.getContent(), self.persist_file) == 0
  else
    return filereadable(self.persist_file) ? delete(self.persist_file) == 0 : 1
  endif
endfunction

function s:common_buffer_observer_calls.onBufWinLeave() dict
  call self.save()
endfunction

function s:MakeCommonBufferObserver(bufnr, scm_accessor)
  let buffer_observer = scm#buffer_observer#MakeBufferObserver(a:bufnr)
  call extend(buffer_observer, s:common_buffer_observer_calls)

  call buffer_observer.mapKeySequence("q", "actionCloseCommittool")
  call buffer_observer.mapKeySequence("'cc", "actionCommit")

  let buffer_observer.scm_accessor = a:scm_accessor

  return buffer_observer
endfunction

let s:changed_files_buffer_observer_calls = {}

let s:tag_and_file_pattern = '^\([-+]\)  \(.*\)$'

function s:getTag(line)
  return substitute(a:line, s:tag_and_file_pattern, '\1', "")
endfunction

function s:getFile(line)
  return substitute(a:line, s:tag_and_file_pattern, '\2', "")
endfunction

function s:changed_files_buffer_observer_calls.getTag(line_number) dict
  return s:getTag(getline(a:line_number))
endfunction

function s:changed_files_buffer_observer_calls.getFile(line_number) dict
  return s:getFile(getline(a:line_number))
endfunction

function s:changed_files_buffer_observer_calls.getCurrentTag() dict
  return self.getTag(line("."))
endfunction

function s:changed_files_buffer_observer_calls.getCurrentFile() dict
  return self.getFile(line("."))
endfunction

function s:changed_files_buffer_observer_calls.getTaggedFiles() dict
  let tagged_files = []
  let content = self.getContent()
  for line in content
    if s:getTag(line) == "+"
      let tagged_files += [s:getFile(line)]
    endif
  endfor
  return tagged_files
endfunction

function s:changed_files_buffer_observer_calls.toggleCurrentTag() dict
  let current_tag = self.getCurrentTag()
  let new_tag = (current_tag == "-" ? "+" : "-")
  let current_file = self.getCurrentFile()

  call scm#misc#SetCurrentBufferModifiable()
  call setline(".", new_tag . "  " . current_file)
  call scm#misc#SetCurrentBufferNonModifiable()

  return new_tag != "-"
endfunction

function! s:changed_files_buffer_observer_calls.hasSaveContent()
  let tagged_files = self.getTaggedFiles()
  return !empty(tagged_files)
endfunction

function s:changed_files_buffer_observer_calls.updateComments(file, is_tagged) dict
  if self.hasNamedLinkedBufferObserver(self.comments_buffer_observer_name)
    let comments_buffer_observer = self.getNamedLinkedBufferObservers(self.comments_buffer_observer_name)
    if comments_buffer_observer.switchToWindow()
      if a:is_tagged
        call comments_buffer_observer.addFile(a:file)
      else
        call comments_buffer_observer.removeFile(a:file)
      endif
    endif
    call self.switchToWindow()
  endif
endfunction

function s:changed_files_buffer_observer_calls.refreshDiffs() dict
  if self.hasNamedLinkedBufferObserver(self.diffs_buffer_observer_name)
    let diffs_buffer_observer = self.getNamedLinkedBufferObservers(self.diffs_buffer_observer_name)
    let diffs = scm#misc#IsCurrentBufferEmpty() ? [] : split(self.scm_accessor.getDiffs(self.getCurrentFile()), '\n')
    if diffs_buffer_observer.switchToWindow()
      call diffs_buffer_observer.setContent(diffs)
    endif
    call self.switchToWindow()
  endif
endfunction

function s:changed_files_buffer_observer_calls.setChangedFiles(changed_files, tagged_files) dict
  call map(a:changed_files, '(index(a:tagged_files, v:val) == -1 ? "-" : "+") . "  " . v:val')
  call scm#misc#SetCurrentBufferContent(a:changed_files)
endfunction

function s:changed_files_buffer_observer_calls.refresh() dict
  echo "committool: finding changed files..."
  let changed_files = self.scm_accessor.getChangedFiles()
  call sort(changed_files)
  call filter(changed_files, 'v:val !~# ".vim.committool_*"')
  redraw!

  let tagged_files = self.getTaggedFiles()
  for tagged_file in tagged_files
    if index(changed_files, tagged_file) == -1
      call self.updateComments(tagged_file, 0)
    endif
  endfor

  call scm#misc#SetCurrentBufferModifiable()
  call self.setChangedFiles(changed_files, tagged_files)
  call scm#misc#SetCurrentBufferNonModifiable()

  call self.refreshDiffs()
endfunction

function s:changed_files_buffer_observer_calls.commit() dict
  let tagged_files = self.getTaggedFiles()
  if empty(tagged_files)
    echo "committool: no files tagged for commit"
    return
  endif

  if !self.hasNamedLinkedBufferObserver(self.comments_buffer_observer_name)
    echo "committool: comments not available"
    return
  endif

  let comments_buffer_observer = self.getNamedLinkedBufferObservers(self.comments_buffer_observer_name)

  if !comments_buffer_observer.save()
    echo "committool: failed to save comments"
    return
  endif

  let committed = self.scm_accessor.commit(tagged_files, comments_buffer_observer.persist_file)
  if committed
    call comments_buffer_observer.switchToWindow()
    call scm#misc#SetCurrentBufferContent([])
    call self.switchToWindow()
  endif

  call self.refresh()

  if !committed
    echo "committool: commit failed"
  endif
endfunction

function s:changed_files_buffer_observer_calls.switchToCommentsWindow()
  if self.hasNamedLinkedBufferObserver(self.comments_buffer_observer_name)
    let comments_buffer_observer = self.getNamedLinkedBufferObservers(self.comments_buffer_observer_name)
    return comments_buffer_observer.switchToWindow()
  else
    return 0
  endif
endfunction

function! s:changed_files_buffer_observer_calls.actionRefresh() dict
  call self.refresh()
endfunction

function! s:changed_files_buffer_observer_calls.actionCommit() dict
  call self.commit()
endfunction

function s:changed_files_buffer_observer_calls.actionDiscard() dict range
  if scm#misc#IsCurrentBufferEmpty()
    return
  endif

  let discard_files = []
  for line_number in range(a:firstline, a:lastline)
    let file = self.getFile(line_number)
    let discard_files += [file]
  endfor

  let current_file = self.getCurrentFile()

  echo join(discard_files, "\n")
  if confirm("committool: are you sure you want to discard these changes?", "&y\n&n", 2) != 1
    return
  endif

  for file in discard_files
    call self.scm_accessor.discard(file)
  endfor

  call self.refresh()
endfunction

function s:changed_files_buffer_observer_calls.actionEditFile() dict
  if scm#misc#IsCurrentBufferEmpty()
    return
  endif

  let file = self.getCurrentFile()
  call scm#misc#EditFile(self.scm_accessor.getRoot() . "/" . file)
endfunction

function s:changed_files_buffer_observer_calls.actionToggleTag() dict
  if scm#misc#IsCurrentBufferEmpty()
    return
  endif

  let current_file_tagged = self.toggleCurrentTag()
  let current_file = self.getCurrentFile()
  call self.updateComments(current_file, current_file_tagged)

  return current_file_tagged
endfunction

function s:changed_files_buffer_observer_calls.actionToggleTagAndMoveFocusIfTagged() dict range
  let files_tagged = 0
  for line_number in range(a:firstline, a:lastline)
    execute "normal! " . line_number . "G"
    let files_tagged += self.actionToggleTag()
  endfor
  if files_tagged
    if self.switchToCommentsWindow()
      normal! G$
    endif
  endif
endfunction

function s:changed_files_buffer_observer_calls.onCursorMoved() dict
  if mode() != 'n'
    return
  endif

  let current_line_number = line(".")
  if self.current_line_number == current_line_number
    return
  endif

  let self.current_line_number = current_line_number
  call self.refreshDiffs()
endfunction

function s:MakeChangedFilesBufferObserver(bufnr, scm_accessor)
  let changed_files_buffer_observer = s:MakeCommonBufferObserver(a:bufnr, a:scm_accessor)
  call extend(changed_files_buffer_observer, s:changed_files_buffer_observer_calls)

  call changed_files_buffer_observer.registerCallbacks()
  call changed_files_buffer_observer.mapKeySequenceWithVisualRange("d", "actionDiscard")
  call changed_files_buffer_observer.mapKeySequence("e", "actionEditFile")
  call changed_files_buffer_observer.mapKeySequence("r", "actionRefresh")
  call changed_files_buffer_observer.mapKeySequenceWithVisualRange("T", "actionToggleTag")
  call changed_files_buffer_observer.mapKeySequenceWithVisualRange("t", "actionToggleTagAndMoveFocusIfTagged")

  return changed_files_buffer_observer
endfunction

function s:CreateChangedFilesWindow(scm_accessor)
  let changed_files_bufname = scm#misc#MakeUniqueBufferPath(a:scm_accessor.getRoot() . "/Committool_ChangedFiles")
  execute "silent " . (scm#misc#IsCurrentTabInUse() ? "tabedit " : "edit ") . changed_files_bufname

  call scm#misc#SetCurrentBufferTemp()

  if has("syntax")
    syntax match SelectedFilesTag  "^+  .*$"
    highlight link SelectedFilesTag DiffAdd
  endif

  let changed_files_buffer_observer = s:MakeChangedFilesBufferObserver(winbufnr(0), a:scm_accessor)

  let changed_files_buffer_observer.current_line_number = 0
  let changed_files_buffer_observer.persist_file = a:scm_accessor.getRoot() . "/.vim_committool_changed_files"
  call changed_files_buffer_observer.load()

  call scm#misc#SetCurrentBufferNonModifiable()

  return changed_files_buffer_observer
endfunction

let s:comments_buffer_observer_calls = {}

function s:comments_buffer_observer_calls.addFile(file) dict
  let comment = a:file . ": "
  if scm#misc#IsCurrentBufferEmpty()
    call setline(1, comment)
  else
    call append(line("$"), comment)
  endif
endfunction

function s:comments_buffer_observer_calls.removeFile(file) dict
  let comments = getline(1, line("$"))
  let file_pattern = (a:file . ': .*')
  let new_comments = []
  for comment in comments
    if comment !~# file_pattern
      let new_comments += [comment]
    endif
  endfor
  call scm#misc#SetCurrentBufferContent(new_comments)
endfunction

function s:CreateCommentsWindow(scm_accessor)
  let comments_bufname = scm#misc#MakeUniqueBufferPath(a:scm_accessor.getRoot() . "/Committool_Comments")
  execute "silent rightbelow vsplit " . comments_bufname

  call scm#misc#SetCurrentBufferTemp()
  setlocal spell
  setlocal wrap

  let comments_buffer_observer = s:MakeCommonBufferObserver(winbufnr(0), a:scm_accessor)
  call extend(comments_buffer_observer, s:comments_buffer_observer_calls)

  call comments_buffer_observer.registerCallbacks()

  let comments_buffer_observer.persist_file = a:scm_accessor.getRoot() . "/.vim_committool_comments"
  call comments_buffer_observer.load()

  return comments_buffer_observer
endfunction

let s:diffs_buffer_observer_calls = {}

function s:diffs_buffer_observer_calls.setContent(diffs) dict
  call scm#misc#SetCurrentBufferModifiable()
  call scm#misc#SetCurrentBufferContent(a:diffs)
  call scm#misc#SetCurrentBufferNonModifiable()
endfunction

function s:CreateDiffsWindow(scm_accessor)
  let diffs_bufname = scm#misc#MakeUniqueBufferPath(a:scm_accessor.getRoot() . "/Committool_Diffs")
  execute "silent botright split " . diffs_bufname

  call scm#misc#SetCurrentBufferTemp()
  call scm#misc#SetCurrentBufferNonModifiable()

  let diffs_buffer_observer = s:MakeCommonBufferObserver(winbufnr(0), a:scm_accessor)
  call extend(diffs_buffer_observer, s:diffs_buffer_observer_calls)

  call diffs_buffer_observer.registerCallbacks()

  return diffs_buffer_observer
endfunction


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" API

function Committool(scm_accessor)
  let s:scm_accessor = a:scm_accessor

  let changed_files_buffer_observer = s:CreateChangedFilesWindow(a:scm_accessor)
  let comments_buffer_observer = s:CreateCommentsWindow(a:scm_accessor)
  let diffs_buffer_observer = s:CreateDiffsWindow(a:scm_accessor)

  call changed_files_buffer_observer.setLinkedBufferObservers([comments_buffer_observer, diffs_buffer_observer])
  call comments_buffer_observer.setLinkedBufferObservers([changed_files_buffer_observer, diffs_buffer_observer])
  call diffs_buffer_observer.setLinkedBufferObservers([changed_files_buffer_observer, comments_buffer_observer])

  let changed_files_buffer_observer.comments_buffer_observer_name = comments_buffer_observer.name
  let changed_files_buffer_observer.diffs_buffer_observer_name = diffs_buffer_observer.name

  let comments_buffer_observer.changed_files_buffer_observer_name = changed_files_buffer_observer.name
  let diffs_buffer_observer.changed_files_buffer_observer_name = changed_files_buffer_observer.name

  call changed_files_buffer_observer.switchToWindow()
  call changed_files_buffer_observer.refresh()
endfunction
