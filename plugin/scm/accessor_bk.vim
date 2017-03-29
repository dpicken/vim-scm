""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Implementation detail

let s:accessor_bk = scm#accessor#MakeAccessor("bk")

function! s:accessor_bk.setRoot(path)
  let root = substitute(system("bk --cd=" . a:path . " root"), "\n$", "", "")
  if v:shell_error != 0
    return 0
  endif

  let self.root = root
  return 1
endfunction

function s:accessor_bk.bk(cmd) dict
  let cmd = "unset BK_GUI && bk --cd=" . self.getRoot() . " " . a:cmd
  return self.system(cmd)
endfunction

function! s:accessor_bk.getChangedFiles()
  return split(self.bk("sfiles -c -x -p -g"))
endfunction

function! s:accessor_bk.getDiffs(file) dict
  return self.bk("diffs -u -N " . a:file)
endfunction

function! s:accessor_bk.discard(file) dict
  call delete(self.getRoot() . '/' . a:file)
  call self.bk("edit " . a:file)
endfunction

function! s:accessor_bk.commit(files, comment_file) dict
  for file in a:files
    call self.bk("ci -a -Y" . a:comment_file . ' ' . file)
    if v:shell_error != 0
      return 0
    endif
  endfor

  silent !clear
  call self.bk("commit -Y" . a:comment_file)
  return v:shell_error == 0
endfunction

let s:user_and_revision_id_pattern = '\([A-z\/ ]\+\)\([0-9.]\+\)'
let s:annotate_pattern = s:user_and_revision_id_pattern . ' \+| \(.*\)'

let s:max_variable_width_cell = "            "
let s:max_variable_width_cell_len = len(s:max_variable_width_cell)

let s:blame_sub = '\=strpart(submatch(1) . s:max_variable_width_cell, 0, s:max_variable_width_cell_len) . "  " . strpart(submatch(2) . s:max_variable_width_cell, 0, s:max_variable_width_cell_len)'

function! s:accessor_bk.getBlame(file) dict
  let blame = split(self.bk("annotate -Aur " . a:file), '\n')
  return map(blame, 'substitute(v:val, s:annotate_pattern, s:blame_sub, "")')
endfunction

function! s:accessor_bk.getBlameAndContent(file, revision_id) dict
  return split(self.bk("annotate -Aur -r" . a:revision_id . " " . a:file), '\n')
endfunction

let s:history_sub = '\=strpart(submatch(1) . s:max_variable_width_cell, 0, s:max_variable_width_cell_len) . "  " . strpart(submatch(2) . s:max_variable_width_cell, 0, s:max_variable_width_cell_len)'

function! s:accessor_bk.getRevisionHistory(file) dict
  let history = split(self.bk("log -d':USER:  :REV:  :D_:  $first(:C:){(:C:)}\\n' " . a:file), '\n')
  return map(history, 'substitute(v:val, s:user_and_revision_id_pattern, s:history_sub, "")')
endfunction

function! s:accessor_bk.getRevisionId(annotated_line)
  return substitute(a:annotated_line, s:user_and_revision_id_pattern . '.*', '\2', "")
endfunction

function! s:accessor_bk.getParentRevisionId(file, revision_id)
  return self.bk("log -r" . a:revision_id . " -d':PREV:' " . a:file)
endfunction

function! s:accessor_bk.getCommitId(file, revision_id)
  return substitute(self.bk("r2c -r" . a:revision_id . " " . a:file), '\n', "", "g")
endfunction

function! s:accessor_bk.getRevisionIdFromCommitId(file, commit_id) dict
  let annotated_lines = split(self.bk("changes -r"  . a:commit_id . " -v -d':USER:  :REV:  :GFILE:\\n'"), '\n')
  let annotated_line_index = match(annotated_lines, '.*\<' . escape(a:file, '~') . '\>.*')
  return self.getRevisionId(annotated_lines[annotated_line_index])
endfunction

function! s:accessor_bk.getCommitComment(file, revision_id) dict
  return self.bk("log -d'$each(:C:){(:C:)\\n}' -r" . a:revision_id . " " . a:file)
endfunction

function! s:accessor_bk.getCommitFiles(file, revision_id) dict
  let cset_id = self.getCommitId(a:file, a:revision_id)
  let cset = split(self.bk("rset -r" . cset_id), '\n')
  call remove(cset, 0)
  return map(cset, 'substitute(v:val, "|.*", "", "")')
endfunction


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Initialization

call scm#accessor_factory#RegisterAccessor(s:accessor_bk)
