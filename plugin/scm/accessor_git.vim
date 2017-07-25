""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Implementation detail

let s:accessor_git = scm#accessor#MakeAccessor("git")

function! s:accessor_git.setRoot(path)
  let root = substitute(system("git -C " . a:path . " rev-parse --show-toplevel"), "\n$", "", "")
  if v:shell_error != 0
    return 0
  endif

  let self.root = root
  return 1
endfunction

function s:accessor_git.git(cmd) dict
  let cmd = "git -C " . self.getRoot() . " " . a:cmd
  return self.system(cmd)
endfunction

function! s:accessor_git.getChangedFiles()
  let status = split(self.git("status --untracked-files --porcelain"), '\n')
  return map(status, 'substitute(v:val, "^...\\(.* -> \\)\\?", "", "")')
endfunction

function! s:accessor_git.getDiffs(file) dict
  let diffs = self.git("diff -- " . a:file)
  if diffs == ""
    let diffs = self.git("diff --cached -- " . a:file)
  endif
  if diffs == ""
    " The following git command appears to succeed but exit with 1:
    let diffs = self.git("diff --no-index -- /dev/null " . a:file . " || true")
  endif
  return diffs
endfunction

function! s:accessor_git.discard(file) dict
  call self.git("reset HEAD " . a:file)
  call delete(self.getRoot() . '/' . a:file)
  call self.git("checkout " . a:file)
endfunction

function! s:accessor_git.commit(files, comment_file) dict
  for file in a:files
    call self.git("add " . file)
    if v:shell_error != 0
      return 0
    endif
  endfor

  call self.git("commit --file " . a:comment_file)
  return v:shell_error == 0
endfunction

let s:revision_id_pattern = '\(\^\?[0-9a-f]\+\)'
let s:blame_pattern = s:revision_id_pattern . '.* (\([A-z ]\+\)\([0-9-:+ ]\+\)) \(.*\)'
let s:blame_sub = '\=strpart(submatch(1), 0, 8) . "  " . submatch(2)'
let s:blame_sub_with_content = '\=strpart(submatch(1), 0, 8) . "  " . printf("%.10s", submatch(2)) . repeat(" ", 10 - len(submatch(2))) . "| " . submatch(4)'

function! s:accessor_git.getBlame(file) dict
  let blame = split(self.git("blame --abbrev=8 -- " . a:file), '\n')
  return map(blame, 'substitute(v:val, s:blame_pattern, s:blame_sub, "")')
endfunction

function! s:accessor_git.getBlameAndContent(file, revision_id) dict
  let blame_and_content = split(self.git("blame --abbrev=8 -- " . a:file . " " . a:revision_id), '\n')
  return map(blame_and_content, 'substitute(v:val, s:blame_pattern, s:blame_sub_with_content, "")')
endfunction

function! s:accessor_git.getRevisionHistory(file) dict
  return split(self.git("log --pretty=format:\"%h  %<(15,trunc)%an  %ad  %s\" --date=short --abbrev=8 -- " . a:file), '\n')
endfunction

function! s:accessor_git.getRevisionId(annotated_line)
  return substitute(a:annotated_line, s:revision_id_pattern . '.*', '\1', "")
endfunction

function! s:accessor_git.getParentRevisionId(file, revision_id)
  return self.git("rev-list --max-count 1 " . a:revision_id . "^ " . a:file)
endfunction

function! s:accessor_git.getCommitId(file, revision_id)
  return a:revision_id
endfunction

function! s:accessor_git.getRevisionIdFromCommitId(file, commit_id) dict
  return a:commit_id
endfunction

function! s:accessor_git.getCommitComment(file, revision_id) dict
  return self.git("log -n 1 " . a:revision_id)
endfunction

function! s:accessor_git.getCommitFiles(file, revision_id)
  let commit_files = split(self.git("log -n 1 --name-only --pretty=format: " . a:revision_id), '\n')
  if count(commit_files, a:file) == 0
    let commit_files += [a:file]
  endif
  return commit_files
endfunction


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Initialization

call scm#accessor_factory#RegisterAccessor(s:accessor_git)
