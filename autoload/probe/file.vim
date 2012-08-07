" File caching
let s:file_caches = {}
let s:file_cache_order = []
let s:max_file_cache_size = 90000
let s:max_depth = 15
let s:max_file_caches = 1
let s:file_cache_dir = expand('$HOME/.probe_cache')


function! probe#file#scan()
    let dir = getcwd()
    " use cache if possible
    if has_key(s:file_caches, dir)
        return s:file_caches[dir]
    endif
    let cache_filepath = s:cache_filepath(dir)
    if g:probe_persist_cache && filereadable(cache_filepath)
        let s:file_caches[dir] = readfile(cache_filepath)
        return s:file_caches[dir]
    endif

    " init new cache
    if !has_key(s:file_caches, dir)
        let s:file_caches[dir] = []
        cal add(s:file_cache_order, dir)
    endif

    " pare caches
    if len(s:file_caches) > s:max_file_caches
        unlet s:file_caches[s:file_cache_order[0]]
        let s:file_cache_order = s:file_cache_order[1:]
    endif

    " recursively scan for files
    let s:file_caches[dir] = s:scan_files(dir, [], 0)

    if g:probe_persist_cache
        cal s:save_cache(dir, s:file_caches[dir])
    endif

    cal prompt#render()
    return s:file_caches[dir]
endfunction

function! probe#file#open(filepath)
    let filepath = escape(a:filepath, '\\|%# "')
    let filepath = fnamemodify(filepath, ':.')
    exe printf('edit %s', filepath)
endfunction

function! probe#file#refresh()
    let dir = getcwd()
    if has_key(s:file_caches, dir)
        unlet s:file_caches[dir]
    endif
    cal delete(s:cache_filepath(dir))
endfunction


function! s:scan_files(dir, files, current_depth)
    " ignore dirs past max_depth
    if a:current_depth > s:max_depth
        return
    endif

    " scan dir recursively
    redraw
    echo "Scanning " . a:dir
    for name in split(globpath(a:dir, '*', 1), '\n')
        if len(a:files) >= s:max_file_cache_size
            break
        endif
        if s:match_some(name, g:probe_ignore_files)
            continue
        endif
        if isdirectory(name)
            cal s:scan_files(name, a:files, a:current_depth+1)
            continue
        endif
        cal add(a:files, fnamemodify(name, ':.'))
    endfor

    return a:files
endfunction

function! s:match_some(str, patterns)
    for pattern in a:patterns
        if match(a:str, pattern) != -1
            return 1
        endif
    endfor
    return 0
endfunction

function! s:save_cache(dir, files)
    if !isdirectory(s:file_cache_dir)
        cal mkdir(s:file_cache_dir)
    endif
    cal writefile(a:files, s:cache_filepath(a:dir))
endfunction

function! s:cache_filepath(dir)
    return printf('%s/%x', s:file_cache_dir, probe#util#rshash(a:dir))
endfunction