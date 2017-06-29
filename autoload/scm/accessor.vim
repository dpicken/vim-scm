""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Implementation detail

let s:accessor = {}

function s:accessor.construct(scm_name)
  let self.scm_name = a:scm_name
  let self.root = ""
endfunction

function s:accessor.getSCMName()
  return self.scm_name
endfunction

function s:accessor.error(message)
  echo "scm#accessor: " . self.getSCMName() . ": " . a:message
endfunction

function s:accessor.system(cmd)
  let cmd_output = system(a:cmd)
  if v:shell_error != 0
    echom a:cmd . ": " . v:shell_error . ": " . cmd_output
  endif
  return v:shell_error == 0 ? cmd_output : ""
endfunction

function s:accessor.getRoot() dict
  return self.root
endfunction

function s:accessor.setRoot(path)
  call self.error("setRoot: not implemented")
  return 0
endfunction

function s:accessor.getChangedFiles()
  call self.error("getChangedFiles: not implemented")
  return []
endfunction

function s:accessor.getDiffs(file) dict
  call self.error("getDiffs: not implemented")
  return ""
endfunction

function s:accessor.discard(file) dict
  call self.error("discard: not implemented")
endfunction

function s:accessor.commit(files, comment_file) dict
  call self.error("commit: not implemented")
  return 1
endfunction

function s:accessor.getBlame(file) dict
  call self.error("getBlame: not implemented")
  return []
endfunction

function s:accessor.getBlameAndContent(file, revision_id) dict
  call self.error("getBlameAndContent: not implemented")
  return []
endfunction

function s:accessor.getRevisionHistory(file) dict
  call self.error("getRevisionHistory: not implemented")
  return []
endfunction

function s:accessor.getRevisionId(annotated_line)
  call self.error("getRevisionId: not implemented")
  return ""
endfunction

function s:accessor.getParentRevisionId(file, revision_id)
  call self.error("getParentRevisionId: not implemented")
  return ""
endfunction

function s:accessor.getCommitId(file, revision_id)
  call self.error("getCommitId: not implemented")
  return ""
endfunction

function s:accessor.getRevisionIdFromCommitId(file, commit_id) dict
  call self.error("getRevisionIdFromCommitId: not implemented")
  return []
endfunction

function s:accessor.getCommitComment(file, revision_id) dict
  call self.error("getCommitComment: not implemented")
  return ""
endfunction

function s:accessor.getCommitFiles(file, revision_id) dict
  call self.error("getCommitFiles: not implemented")
  return []
endfunction


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" API

function scm#accessor#MakeAccessor(scm_name)
  let accessor = deepcopy(s:accessor)
  call accessor.construct(a:scm_name)
  return accessor
endfunction
