"==================================================
" File:         code_complete.vim修改版
"使用Ctrl+j实现函数参数类型以及数目的补全提示，常用结构的补全均使用snippets
"使用Ctrl+]实现函数参数的补全
"==================================================
if v:version < 700
    finish
endif

" Variable Definitions: {{{1
" options, define them as you like in vimrc:
if !exists("g:completekey")
    let g:completekey = "<C-j>"   "hotkey
endif

if !exists("g:rs")
    let g:rs = '`<'    "region start
endif

if !exists("g:re")
    let g:re = '>`'    "region stop
endif

" ----------------------------
let s:expanded = 0  "in case of inserting char after expand
let s:signature_list = []
let s:jumppos = -1
let s:doappend = 1

" Autocommands: {{{1
autocmd BufReadPost,BufNewFile * call CodeCompleteStart()

" Menus:
menu <silent>       &Tools.Code\ Complete\ Start          :call CodeCompleteStart()<CR>
menu <silent>       &Tools.Code\ Complete\ Stop           :call CodeCompleteStop()<CR>

" Function Definitions: {{{1

function! CodeCompleteStart()
    exec "silent! iunmap  <buffer> ".g:completekey
    exec "inoremap <buffer> ".g:completekey." <c-r>=CodeComplete()<cr><c-r>=SwitchRegion()<cr>"
    exec "inoremap <buffer> "."<C-]>"." <c-r>=CodeCompleteTab()<cr><c-r>=SwitchRegion()<cr>"
endfunction

function! CodeCompleteStop()
    exec "silent! iunmap <buffer> ".g:completekey
endfunction

function! FunctionComplete(fun)
    let s:signature_list=[]
    let signature_word=[]
    let ftags=taglist("^".a:fun."$")
    if type(ftags)==type(0) || ((type(ftags)==type([])) && ftags==[])
        return ''
    endif
    let tmp=''
    for i in ftags
        if match(i.cmd,'^/\^.*\(\*'.a:fun.'\)\(.*\)\;\$/')>=0
            if match(i.cmd,'(\s*void\s*)')<0 && match(i.cmd,'(\s*)')<0
                    let tmp=substitute(i.cmd,'^/\^','','')
                    let tmp=substitute(tmp,'.*\(\*'.a:fun.'\)','','')
                    let tmp=substitute(tmp,'^[\){1}]','','')
                    let tmp=substitute(tmp,';\$\/;{1}','','')
                    let tmp=substitute(tmp,'\$\/','','')
                    let tmp=substitute(tmp,';','','')
		    let tmp=substitute(tmp,',',g:re.', '.g:rs,'g')		       "修改的部分
                    let tmp=substitute(tmp,'(\(.*\))',g:rs.'\1'.g:re.')','g')

                    "let tmp=substitute(tmp,'(\(.*\))',' '.g:rs.'\1'.g:re.' )','g')    "'('后有空格的版本
            else
                    let tmp=''
            endif
            if (tmp != '') && (index(signature_word,tmp) == -1)
                let signature_word+=[tmp]
                let item={}
                let item['word']=tmp
                let item['menu']=i.filename
                let s:signature_list+=[item]
            endif
        endif
        if has_key(i,'kind') && has_key(i,'name') && has_key(i,'signature')
            if (i.kind=='p' || i.kind=='f') && i.name==a:fun  " p is declare, f is definition
                if match(i.signature,'(\s*void\s*)')<0 && match(i.signature,'(\s*)')<0
                    let tmp=substitute(i.signature,',',g:re.', '.g:rs,'g')		"修改的部分
                    let tmp=substitute(tmp,'(\(.*\))',g:rs.'\1'.g:re.')','g')
	
                    "let tmp=substitute(tmp,'(\(.*\))',' '.g:rs.'\1'.g:re.' )','g') 	"')'前有空格的版本
                else
                    let tmp=''
                endif
                if (tmp != '') && (index(signature_word,tmp) == -1)
                    let signature_word+=[tmp]
                    let item={}
                    let item['word']=tmp
                    let item['menu']=i.filename
                    let s:signature_list+=[item]
                endif
            endif
        endif
    endfor
    if s:signature_list==[]
        return ')'
    endif
    if len(s:signature_list)==1
        return s:signature_list[0]['word']
    else
        call  complete(col('.'),s:signature_list)
        return ''
    endif
endfunction

function! ExpandTemplate(cword)
    "let cword = substitute(getline('.')[:(col('.')-2)],'\zs.*\W\ze\w*$','','g')
    if has_key(g:template,&ft)
        if has_key(g:template[&ft],a:cword)
            let s:jumppos = line('.')
            return "\<c-w>" . g:template[&ft][a:cword]
        endif
    endif
    if has_key(g:template['_'],a:cword)
        let s:jumppos = line('.')
        return "\<c-w>" . g:template['_'][a:cword]
    endif
    return ''
endfunction

function! SwitchRegion()
    if len(s:signature_list)>1
        let s:signature_list=[]
        return ''
    endif
    if s:jumppos != -1
        call cursor(s:jumppos,0)
        let s:jumppos = -1
    endif
    if match(getline('.'),g:rs.'.*'.g:re)!=-1 || search(g:rs.'.\{-}'.g:re)!=0
        normal 0
        call search(g:rs,'c',line('.'))
        normal v
        call search(g:re,'e',line('.'))
        if &selection == "exclusive"
            exec "norm l"
        endif
        return "\<c-\>\<c-n>gvo\<c-g>"
    else
        if s:doappend == 1
            if g:completekey == "<C-j>"
                "return "\<tab>"
            endif
        endif
        return ''
    endif
endfunction

function! CodeComplete()
    let s:doappend = 1
    let function_name = matchstr(getline('.')[:(col('.')-2)],'\zs\w*\ze\s*(\s*$')
    if function_name != ''
        let funcres = FunctionComplete(function_name)
        if funcres != ''
            let s:doappend = 0
        endif
        return funcres
    else
        let template_name = substitute(getline('.')[:(col('.')-2)],'\zs.*\W\ze\w*$','','g')
        let tempres = ExpandTemplate(template_name)
        if tempres != ''
            let s:doappend = 0
        endif
        return tempres
    endif
endfunction

" [Get converted file name like __THIS_FILE__ ]
function! GetFileName()
    let filename=expand("%:t")
    let filename=toupper(filename)
    let _name=substitute(filename,'\.','_',"g")
    "let _name="__"._name."__"
    return _name
endfunction

" ---------------------------------------------
" C templates
let g:template = {}
let g:template['c'] = {}

" ---------------------------------------------
" common templates		insert the (modify)time
let g:template['_'] = {}
let g:template['_']['xt'] = "\<c-r>=strftime(\"%Y-%m-%d %H:%M:%S\")\<cr>"








"参数补全
function! CodeCompleteTab()
    let s:doappend = 1
    let function_name = matchstr(getline('.')[:(col('.')-2)],'\zs\w*\ze\s*(\s*$')
    if function_name != ''
        let funcres = FunctionCompleteTab(function_name)
        if funcres != ''
            let s:doappend = 0
        endif
        return funcres
    else
        let template_name = substitute(getline('.')[:(col('.')-2)],'\zs.*\W\ze\w*$','','g')
        let tempres = ExpandTemplate(template_name)
        if tempres != ''
            let s:doappend = 0
        endif
        return tempres
    endif
endfunction

function! FunctionCompleteTab(fun)
    let s:signature_list=[]
    let signature_word=[]
    let ftags=taglist("^".a:fun."$")
    if type(ftags)==type(0) || ((type(ftags)==type([])) && ftags==[])
        return ''
    endif
    let tmp=''
    for i in ftags
        if match(i.cmd,'^/\^.*\(\*'.a:fun.'\)\(.*\)\;\$/')>=0
            if match(i.cmd,'(\s*void\s*)')<0 && match(i.cmd,'(\s*)')<0
                    let tmp=substitute(i.cmd,'^/\^','','')
                    let tmp=substitute(tmp,'.*\(\*'.a:fun.'\)','','')
                    let tmp=substitute(tmp,'^[\){1}]','','')
                    let tmp=substitute(tmp,';\$\/;{1}','','')
                    let tmp=substitute(tmp,'\$\/','','')
                    let tmp=substitute(tmp,';','','')
                    let tmp=substitute(tmp,',',',','g')
                    let tmp=substitute(tmp,'(\(.*\))','\1)','g')

		    "let tmp=substitute(tmp,'(\(.*\))',' \1 )','g')	"'('后有空格的版本
            else
                    let tmp=''
            endif
            if (tmp != '') && (index(signature_word,tmp) == -1)
                let signature_word+=[tmp]
                let item={}
                let item['word']=tmp
                let item['menu']=i.filename
                let s:signature_list+=[item]
            endif
        endif
        if has_key(i,'kind') && has_key(i,'name') && has_key(i,'signature')
            if (i.kind=='p' || i.kind=='f') && i.name==a:fun  " p is declare, f is definition
                if match(i.signature,'(\s*void\s*)')<0 && match(i.signature,'(\s*)')<0
                    let tmp=substitute(i.signature,',',',','g')
                    let tmp=substitute(tmp,'(\(.*\))','\1)','g')

		    "let tmp=substitute(tmp,'(\(.*\))',' \1 )','g')	"')'前有空格的版本
                else
                    let tmp=''
                endif
                if (tmp != '') && (index(signature_word,tmp) == -1)
                    let signature_word+=[tmp]
                    let item={}
                    let item['word']=tmp
                    let item['menu']=i.filename
                    let s:signature_list+=[item]
                endif
            endif
        endif
    endfor
    if s:signature_list==[]
        return ')'
    endif
    if len(s:signature_list)==1
        return s:signature_list[0]['word']
    else
        call  complete(col('.'),s:signature_list)
        return ''
    endif
endfunction
