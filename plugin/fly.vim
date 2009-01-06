" -------------------- Copyright Header Begin ---------------------------------
" Plugin:      fly.vim
" Description: Facilitates code fly-through. (Details in the User Guide)
" Version:     1.0
" Author:      Pranay Pogde
" Copyright:   Pranay Pogde [2005 Onwards]
" License:     VIM license. [vimdoc.sourceforge.net/htmldoc/uganda.html#license]
" Disclaimer:  The plugin comes with no warranty of any kind, either expressed 
"              or implied. In no event will the copyright holder and maintainers 
"              be liable for any damages resulting from the use of this plugin.
" Feedback:    fly.vim@live.com
"              o Bugs with/without fixes.
"              o Wish list of features with/without your changes to this plugin.
" Usage:       Please read documentation supplied with this distribution.
" -------------------- Copyright Header End -----------------------------------
"
"
" Overview for maintainers/contributors: 
"
" The file is divided into following sections. You may add yours or update these
" if/when you choose to enhance the plugin.
"
" + Data Structures.
" + Static Variables.
" + Initialization.
" + Utility Functions.
" + Commands
"   + LS (LiSt directory)  
"   + BD (Build CSCOPE Databases)  
"   + LD (List CSCOPE Databases)  
"   + CS (Query CScope)  
"   + LK (List stacK)  
"   + LB (List Buffers)  
"   + MK (build, MaKe)  
"   + RD (ReaD build log)  
"   + RS (Restore Session)  
"   + GR (GRep)  
"   + WS (Web Search)
"   + Core Functions 
"   + Core Utility Functions 
"   + Result Tab Functions 
"   + Help Tab Functions 
"   + Settings Tab Functions 
"   + Cache Tab Functions 
"   + Navigation Functions 
"   + Overall Display Management 
"   + Multiple Sandboxes 
"   + Web Pages 
"   + UNIX Man Pages 
" + Wish List
" + Mappings
"
" Details will be added later based on the interest of userbase and developers.
"
"
" ----------------------------- Data Structures -------------------------------
" Generic Stack
function s:StackInit(stack)
    let s:{a:stack}_top = -1
    let s:{a:stack}_end = -1
endfunction

function s:StackEmpty(stack)
    if s:{a:stack}_top == 0
	return 1
    endif
    return 0
endfunction

function s:StackFull(stack)
    if s:{a:stack}_top == s:{a:stack}_end
	return 1
    endif
    return 0
endfunction

function s:StackTop(stack)
    return "s:".a:stack ."_".s:{a:stack}_top
endfunction

function s:StackPush(stack)
    let s:{a:stack}_top = s:{a:stack}_top + 1
    if s:{a:stack}_top > s:{a:stack}_end
    	let s:{a:stack}_end = s:{a:stack}_top
    endif
    return s:StackTop(a:stack)
endfunction

function s:StackPop(stack)
    if s:{a:stack}_top == -1
        return ""
    endif
    let l:reference =  "s:".a:stack ."_".s:{a:stack}_top
    let s:{a:stack}_top = s:{a:stack}_top - 1
    return l:reference
endfunction

" Generic Doubly-Linked List of unique items (no duplicates should be added)
function s:ListAppend(list, item)
    if !exists(a:list."_first")
        let {a:list}_first = a:item
        return 1
    endif
    let l:i = 2
    let l:item = {a:list}_first
    while exists(l:item."_next")
        let l:item = {l:item."_next"}
        let l:i = l:i + 1
    endwhile
    let {l:item}_next = a:item
    let {a:item}_prev = l:item
    return l:i
endfunction

function s:ListLoop(list, func)
    if !exists(a:list."_first")
        return
    endif

    let l:i = 1
    call {a:func}({a:list."_first"}, l:i)
    let l:item = {a:list}_first
    while exists(l:item."_next")
        let l:i = l:i + 1
        call {a:func}({l:item."_next"}, l:i)
        let l:item = {l:item."_next"}
    endwhile
endfunction

"TODO unlet the l:item too?
function s:ListDestroy(list)
    if !exists(a:list."_first")
        return 1
    endif
    let l:i = 2
    let l:item = {a:list}_first
    while exists(l:item."_next")
        if exists(l:item."_prev")
            unlet {l:item}_prev
        endif
        let l:temp = l:item
        let l:item = {l:item."_next"}
        unlet {l:temp}_next
        let l:i = l:i + 1
    endwhile
    if exists(l:item."_prev")
        unlet {l:item}_prev
    endif
    unlet {a:list}_first
endfunction

function s:ListRemove(list, item)
    if exists(a:item."_prev") && exists(a:item."_next")
        let {{a:item}_prev}_next = {a:item."_next"}
        let {{a:item}_next}_prev = {a:item."_prev"}
        unlet {a:item}_next
        unlet {a:item}_prev
    elseif exists(a:item."_next")
        let {a:list}_first = {a:item."_next"}
        unlet {{a:item}_next}_prev
        unlet {a:item}_next
    elseif exists(a:item."_prev")
        unlet {{a:item}_prev}_next
        unlet {a:item}_prev
    else
        unlet {a:list}_first
    endif
endfunction

function s:PrintNode(node, i)
    echo {a:node}_val
endfunction

function s:MyListTest()
    let s:a1_val = 1
    let s:a2_val = 2

    call s:ListAppend("s:mylist", "s:a1")
    call s:ListAppend("s:mylist", "s:a2")
    call s:ListLoop("s:mylist", "s:PrintNode")
endfunction

function s:CheckTies()
    if s:TiedToSandbox == 1
        if s:TiedWin != -1
            exe s:TiedWin . "wincmd w"
            exe "bd"
        endif
        let l:tempWin = winnr()
        call s:Diffit()
        let s:TiedWin = winnr()
        if l:tempWin == s:TiedWin
            let s:TiedWin = -1
        endif
        exe l:tempWin . "wincmd w"
    endif
    if s:TiedToCVS == 1
        if s:TiedCVSWin != -1
            exe s:TiedCVSWin . "wincmd w"
            exe "bd"
        endif
        let l:tempWin = winnr()
        exe ":CVSVimDiff"
        let s:TiedCVSWin = winnr()
        if l:tempWin == s:TiedCVSWin
            let s:TiedCVSWin = -1
        endif
        exe l:tempWin . "wincmd w"
    endif
    if s:TiedToSVN == 1
        if s:TiedSVNWin != -1
            exe s:TiedSVNWin . "wincmd w"
            exe "bd"
        endif
        let l:tempWin = winnr()
        exe ":SVNVimDiff"
        let s:TiedSVNWin = winnr()
        if l:tempWin == s:TiedSVNWin
            let s:TiedSVNWin = -1
        endif
        exe l:tempWin . "wincmd w"
    endif
endfunction

" Operations only on stack of files
function s:MoveRight(stack)
    if s:{a:stack}_top == s:{a:stack}_end
        return
    endif
    let s:{a:stack}_{s:{a:stack}_top}_line = line('.')
    let s:{a:stack}_top = s:{a:stack}_top + 1
    exe "edit " . s:{a:stack}_{s:{a:stack}_top}_file
    exe s:{a:stack}_{s:{a:stack}_top}_line
    call s:CheckTies()
endfunction

function s:MoveLeft(stack)
    if s:{a:stack}_top == 0
        return
    endif
    let s:{a:stack}_{s:{a:stack}_top}_line = line('.')
    let s:{a:stack}_top = s:{a:stack}_top - 1
    exe "edit " . s:{a:stack}_{s:{a:stack}_top}_file
    exe s:{a:stack}_{s:{a:stack}_top}_line
    call s:CheckTies()
endfunction

" ----------------------------- Static Variables ------------------------------
" A user may change directories inside vim, hence using the absolute paths.
let s:FlyControlWinTitle = $HOME . "/.fly.vim/__FlyControl"
let s:FlyFutureWinTitle  = $HOME . "/.fly.vim/__FlyFuture"
let s:FlyManWinTitle     = $HOME . "/.fly.vim/__FlyMan"
let s:FlyWebWinTitle     = $HOME . "/.fly.vim/__FlyWeb"

" ----------------------------- Initialization  -------------------------------
" Fly Init
" You could add following types of commands to the plugin.
" 1) The ones which eventually execute some shell command/script.
" 2) The ones which eventually execute some vim command.
" 3) The ones for which you could get results from the Fly data structures.

" Defining a new command involves following.
" Set up the methods for the new command object 'newcmd'.
"    let s:SetUp{newcmd} = s:SetUpCmd_newcmd
"    let s:RunIt{newcmd} = s:RunShellCmd
"    let s:Parse{newcmd} = s:Result_newcmd
"    let s:ShowR{newcmd} = s:PopulateResultList
"    let s:OnHit{newcmd} = s:OnHit_newcmd
" Define s:SetUpCmd_newcmd, s:Result_newcmd and s:OnHit_newcmd.
"    SetUpCmd_... initializes attributes for the command object. 
"    Result_... populates the result member (which is a vector) of the newcmd.
"    OnHit_...  defines the response to hitting the <Enter> key on result line.
" Some of the common functions could be reused while defining new commands.
"    RunShellCmd, Result_explore, PopulateResult, PopulateResultList.
"    OnHit_fl.

function s:InitCmdVectors()
    " list files in same dir as of the currently opened file.
    let s:SetUp{"ls"} = "s:SetUpCmd_ls"
    let s:RunIt{"ls"} = "s:RunShellCmd"
    let s:Parse{"ls"} = "s:Result_explore"
    let s:ShowR{"ls"} = "s:PopulateResultList"
    let s:OnHit{"ls"} = "s:OnHit_ls"

    " list cscope databases
    let s:SetUp{"db"} = "s:SetUpCmd_db"
    let s:RunIt{"db"} = "s:RunShellCmd"
    let s:Parse{"db"} = "s:Result_explore"
    let s:ShowR{"db"} = "s:PopulateResultList"
    let s:OnHit{"db"} = "s:OnHit_db"

    " query cscope databases
    let s:SetUp{"cs"} = "s:SetUpCmd_cs"
    let s:RunIt{"cs"} = "s:RunShellCmd"
    let s:Parse{"cs"} = "s:Result_cscopeQuery"
    let s:ShowR{"cs"} = "s:PopulateResult"
    let s:OnHit{"cs"} = "s:OnHit_fl"

    " list stack of open files
    let s:SetUp{"lk"} = "s:SetUpCmd_lk"
    let s:RunIt{"lk"} = "NOP"
    let s:Parse{"lk"} = "s:Result_stackOpenFiles"
    let s:ShowR{"lk"} = "s:PopulateResult"
    let s:OnHit{"lk"} = "s:OnHit_fl"

    " list buffers
    let s:SetUp{"lb"} = "s:SetUpCmd_lb"
    let s:RunIt{"lb"} = "NOP"
    let s:Parse{"lb"} = "s:Result_listBuffers"
    let s:ShowR{"lb"} = "s:PopulateResult"
    let s:OnHit{"lb"} = "s:OnHit_fl"

    " build 
    let s:SetUp{"mk"} = "s:SetUpCmd_mk"
    let s:RunIt{"mk"} = "s:RunVimCmd"
    let s:Parse{"mk"} = "s:Read_buildLogFile"
    let s:ShowR{"mk"} = "s:PopulateResult"
    let s:OnHit{"mk"} = "s:OnHit_fl"

    " read previously stored cscope result file
    let s:SetUp{"rs"} = "s:SetUpCmd_rs"
    let s:RunIt{"rs"} = "s:RunShellCmd"
    let s:Parse{"rs"} = "s:Result_Read_CS_resultfile"
    let s:ShowR{"rs"} = "s:PopulateResult"
    let s:OnHit{"rs"} = "s:OnHit_fl"

    " read a build log file
    let s:SetUp{"rd"} = "s:SetUpCmd_rd"
    let s:RunIt{"rd"} = "s:RunVimCmd"
    let s:Parse{"rd"} = "s:Read_buildLogFile"
    let s:ShowR{"rd"} = "s:PopulateResult"
    let s:OnHit{"rd"} = "s:OnHit_fl"

    " grep for a pattern in current result files/directories 
    let s:SetUp{"gr"} = "s:SetUpCmd_gr"
    let s:RunIt{"gr"} = "s:RunShellCmd"
    let s:Parse{"gr"} = "s:Read_buildLogFile"
    let s:ShowR{"gr"} = "s:PopulateResult"
    let s:OnHit{"gr"} = "s:OnHit_fl"

    " google search 
    let s:SetUp{"ws"} = "s:SetUpCmd_gs"
    let s:RunIt{"ws"} = "s:RunShellCmd"
    let s:Parse{"ws"} = "s:Result_WebSearch"
    let s:ShowR{"ws"} = "s:PopulateResult"
    let s:OnHit{"ws"} = "s:OnHit_link"
endfunction

" Sets up the Cache display. Also runs a few commands initially so that they
" are available in cache.
function s:InitFlyCache()
    call s:Cmd("lb", 2)
    call s:Cmd("lk", 2)
    call s:Cmd("db", 2)
    let s:curCmd = s:db
    let s:CurCache = 3
    let s:CurSetting = 7
    let s:CurHelp = 2

    let s:db_leaf = 1
    let s:cs_leaf = 0
    let s:lk_leaf = 1
    let s:lb_leaf = 1
    let s:ls_leaf = 0
    let s:rd_leaf = 0
    let s:gr_leaf = 0

    let s:cs_text = "Cscope Queries (:CS [sgcdtefi] <name>)"
    let s:ls_text = "Explore Directories (:LS [<dir>])"
    let s:rd_text = "Read files (:RD <file>)"
    let s:gr_text = "Grep symbol (:GR [grep-options] <symbol>)"

    call s:ListAppend("s:NewCommands", "s:ls")
    call s:ListAppend("s:NewCommands", "s:rd")
    call s:ListAppend("s:NewCommands", "s:gr")
    call s:ListAppend("s:NewCommands", "s:cs")

    let s:ls_nextlevel = "s:ls"
    let s:rd_nextlevel = "s:rd"
    let s:gr_nextlevel = "s:gr"
    let s:cs_nextlevel = "s:cs"
    let s:ls_show = 0
    let s:rd_show = 0
    let s:gr_show = 0
    let s:cs_show = 1
    call s:UpdateFlyCache()
    call s:HighLightLines()
endfunction

function s:InitCscope()
    let s:CscopeCmdText{0} = "find symbol"
    let s:CscopeCmdText{1} = "find definition"
    let s:CscopeCmdText{2} = "find functions called by"
    let s:CscopeCmdText{3} = "find functions calling"
    let s:CscopeCmdText{4} = "find text string"
    let s:CscopeCmdText{5} = "change text string"
    let s:CscopeCmdText{6} = "find egrep pattern"
    let s:CscopeCmdText{7} = "find file"
    let s:CscopeCmdText{8} = "find files including"
endfunction

function s:InitFly()
    let s:FlyFutureWin  = bufwinnr(s:FlyFutureWinTitle)
    let s:FlyControlWin = bufwinnr(s:FlyControlWinTitle)

    let s:CscopeDB = ""

    let s:numCmds = 0

    call s:InitCmdVectors()

    call s:InitCscope()
endfunction

" ----------------------------- Utility Functions -----------------------------

" Run Shell Command
function s:RunShellCmd(cmd)
    if strlen(a:cmd) > 0
        let result  = system(a:cmd)
        let {s:curCmd}_resultBuf = result
    else
        let {s:curCmd}_resultBuf = "Type in any command in the command line i.e. the very first line beginning with :\n"
    endif
endfunction

" Parses a list of files/directories in cmd.resultBuf to produce result tree.
function s:Result_explore()
    let i = 1
    let temp = {s:curCmd}_resultBuf
    let line = strpart(temp, 0, stridx(temp, "\n"))
    let temp = strpart(temp, stridx(temp, "\n") + 1)
    while temp != ''
        let line = strpart(temp, 0, stridx(temp, "\n"))
	let temp = strpart(temp, stridx(temp, "\n") + 1)
        if isdirectory(line)
            let {s:curCmd}_result{i}_text = strpart(line, strridx(line, "/") + 1)
            let {s:curCmd}_result{i}_leaf = 0
        else
            let {s:curCmd}_result{i}_text = strpart(line, strridx(line, "/") + 1)
            let {s:curCmd}_result{i}_leaf = 1
        endif
	let {s:curCmd}_result{i}_line = 1
	let {s:curCmd}_result{i}_file = line
        call s:ListAppend(s:curCmd."_result", s:curCmd."_result".i)
	let i = i + 1
    endwhile
    let {s:curCmd}_resultCount = i - 1
endfunction

" Populate the result window if that is currently on Display.
function s:PopulateResultList()
    let s:MenuChoice = "Result"
    if bufwinnr(s:FlyControlWinTitle) == -1
	return
    endif

    exe bufwinnr(s:FlyControlWinTitle) . "wincmd w"
    setlocal modifiable
    exe '1,$delete'
    call append(0, "/ Results \\ Cache | Settings | Help |")

    if {s:curCmd}_type == "db"
	if s:CscopeDB == ""
	    call append(1, "$ " . {s:curCmd}_resulttext . " [None selected yet]")
	else
	    call append(1, "$ " . {s:curCmd}_resulttext . " [Current: " . strpart(s:CscopeDB, strlen(s:CscopeDir)) . "]")
	endif
    else
	call append(1, "$ " . {s:curCmd}_resulttext)
    endif

    if {s:curCmd}_resultCount == 0
	call append(s:ResultLineStart, "No result!")
    else
        let s:i = 1
        let s:level = 0
        call s:ListLoop(s:curCmd."_result", "s:PrintResult")
    endif

    exe '$delete'
    if exists(s:curCmd."_CurResult") 
	let jumpLine = {s:curCmd}_CurResult
        exe ":" . jumpLine
    else
        let {s:curCmd}_CurResult = s:ResultLineStart + 1
        exe ":" . {s:curCmd}_CurResult
    endif
endfunction

" Open the file in edit window when user hits <ENTER> key on the result line.
" Given that the result line is name of a file.
function s:OnHit_fl(...)
    let i = a:1
    let result = a:2
    if {s:curCmd}_resultCount > 0
        if getwinvar({s:curCmd}_win, 'StackId') == {s:curCmd}_winStackId
            exec {s:curCmd}_win . "wincmd w"
            let s:EditWin = {s:curCmd}_win
            call s:GetStack()
        else
            call s:GoToPrimaryEditWin()
        endif

        let l:reference = s:StackTop(s:StackId)
        let {l:reference}_line = line('.')

        let l:reference = s:StackPush(s:StackId)
        let {l:reference}_file = {result}_file
        let {l:reference}_line = {result}_line
        if exists(result."_function") && exists(result."_context")
            let {l:reference}_function = {result}_function
            let {l:reference}_context = {result}_context
        endif

        exe 'edit ' . {result}_file
        exe {result}_line
        call s:CheckTies()
    endif
endfunction

" ----------------------------- LS (LiSt directory) command --------------------
function s:SetUpCmd_ls(cmd, ...)
    call s:GoToPrimaryEditWin()
    if a:0 == 0 || (a:0 == 1 && strpart(a:1, 0, 1) != "/")
	let l:fileIdx = strridx(expand("%"), "/")
	if l:fileIdx != -1 
	    let s:curDir = strpart(expand("%"), 0, l:fileIdx)
	else
	    let s:curDir = getcwd()
	endif
	if a:0 == 1 && strpart(a:1, 0, 1) != "/"
	    let s:curDir = s:curDir . "/" . a:1
	endif
    elseif (a:0 == 1)
	let s:curDir = a:1
    endif

    let cmd = "find ". s:curDir ." -follow -maxdepth 1"
    let {s:curCmd}_cmd  = cmd
    let {s:curCmd}_type = "ls"
    let {s:curCmd}_text = s:curDir
    let {s:curCmd}_resulttext = "explore " . s:curDir
endfunction

function s:OnHit_ls(...)
    let i = a:1
    let l:node = {s:curCmd}_tree{i}_node
    if isdirectory({l:node}_file) 
	call s:ShowHideSubtree(l:node)
	call s:HighLightLines()
    else
	call s:OnHit_fl(i, {s:curCmd}_tree{i}_node)
    endif
endfunction

" ---------------------- BD (Build CSCOPE Database) command -------------------
function s:cscopePatternSet()
    let g:cscopePattern = "\"*.[chCH]\" "
    let g:cscopePattern = g:cscopePattern . "-o -name \"*.py\" "
    let g:cscopePattern = g:cscopePattern . "-o -name \"*.pl\" "
    let g:cscopePattern = g:cscopePattern . "-o -name \"*.sql\" "
    let g:cscopePattern = g:cscopePattern . "-o -name \"*.php\" "
    let g:cscopePattern = g:cscopePattern . "-o -name \"*.[jJ]ava\" "
    let g:cscopePattern = g:cscopePattern . "-o -name \"*.sh\" "
    let g:cscopePattern = g:cscopePattern . "-o -name \"*.mk\" "
    let g:cscopePattern = g:cscopePattern . "-o -name \"*.mak\" "
    let g:cscopePattern = g:cscopePattern . "-o -name \"Makefile\" "
    let g:cscopePattern = g:cscopePattern . "-o -name \"Makefile.*\" "
endfunction

function s:BuildCscopeDB(...)
    if exists("s:startedFly") == 0
        call s:StartFly()
    endif
    if exists("g:root")
        let l:rootDir = g:root
    else
        let l:rootDir = getcwd()
    endif
    if a:0 == 0
        let l:dbName = strpart(l:rootDir, strridx(l:rootDir, "/") + 1)
        if l:dbName == ""
            let l:dbName = "cscope"
        endif
    else
        let l:dbName = a:1
    endif

    if s:CscopeDirSet == 0
        let s:CscopeDir = l:rootDir
    endif

    if !isdirectory(s:CscopeDir) 
        echo "The CSCOPE_DIR " . s:CscopeDir . " does not exist."
        call getchar()
        return
    endif

    call s:cscopePatternSet()

    let l:cmd = "("
    let l:cmd = l:cmd . "find " . l:rootDir ." -name " . g:cscopePattern . " > " . s:CscopeDir . "/" . l:dbName . ".lst;"
    let l:cmd = l:cmd . "cscope -b -q -k -i " . s:CscopeDir . "/" . l:dbName . ".lst -f " . s:CscopeDir . "/" . l:dbName . ".out;"
    let l:cmd = l:cmd . ") &"

    let l:result = system(l:cmd)
    let s:CscopeDB = s:CscopeDir . "/" . l:dbName . ".out"
    let l:cmd = {s:curCmd}_type
    call {s:ShowR{l:cmd}}()
endfunction

" ---------------------- LD (List CSCOPE Databases) command -------------------
function s:SetUpCmd_db(cmd, ...)
    if a:0 == 1
	let s:curDir = a:1
    else
	let s:curDir = s:CscopeDir
    endif
    if s:CscopeDir == ""
	let cmd = "echo ; echo Please set environment variable CSCOPE_DIR to dir containing cscope databases."
    else
	let cmd = "find ". s:curDir ." -follow -maxdepth 1 -type d -o -name \"*.db\" -o -name \"*.out\" \\! -name \"*.po*\" \\! -name \"*.in*\"" 
    endif
    if !isdirectory(s:CscopeDir) 
	let cmd = "echo ; echo The CSCOPE_DIR " . s:CscopeDir . " does not exist."
    endif

    let {s:curCmd}_cmd  = cmd
    let {s:curCmd}_type = "db"
    let {s:curCmd}_text = "List cscope databases (:LD)"
    let {s:curCmd}_resulttext = "Select a cscope database."
endfunction

function s:OnHit_db(...)
    let i = a:1
    let l:node = {s:curCmd}_tree{i}_node
    if isdirectory({l:node}_file) 
	call s:ShowHideSubtree(l:node)
    else
	let s:CscopeDB = {{s:curCmd}_tree{i}_node}_file
        if s:CscopeDirSet == 0
            let s:CscopeDir = strpart(s:CscopeDB, 0, strridx(s:CscopeDB, "/"))
        endif
	let l:db = strpart(s:CscopeDB, strlen(s:CscopeDir))
	let l:db = substitute(l:db, "\\/", "__", "g")
	let l:db = substitute(l:db, "\\.", "_", "g")
	let l:db = substitute(l:db, "\\-", "_", "g")
	call s:SetUpCscopeMenu(l:db)
	if exists(s:curCmd."_line_number")
	    let s:CurCache = {s:curCmd}_line_number 
	endif
	call {s:ShowR{{s:curCmd}_type}}()
    endif
    call s:HighLightLines()
endfunction

" ----------------------------- CS (Query Cscope) command -----------------------
function s:SetUpCmd_cs(cmd, ...)
    let l:ndx = s:GetCscopeQueryNum(a:1)

    let l:symbol = a:2
    let l:symbol = escape(l:symbol, "#?&;|%() ")
    if s:CscopeCase == "ignore"
	let cmd = "cscope -d -f " . s:CscopeDB . " -L -" . l:ndx . l:symbol . " | sort "
    else
	let cmd = "cscope -d -C -f " . s:CscopeDB . " -L -" . l:ndx . l:symbol . " | sort "
    endif

    let {s:curCmd}_ndx  = l:ndx
    let {s:curCmd}_cmd  = cmd
    let {s:curCmd}_type = "cs"
    if s:CscopeCase == "noignore"
	let {s:curCmd}_text = l:symbol . "(ic)"
    else
	let {s:curCmd}_text = l:symbol
    endif
    if s:CscopeCase == "noignore"
	let {s:curCmd}_resulttext = s:CscopeCmdText{l:ndx} . " " . l:symbol . " (case insensitive) in [" . strpart(s:CscopeDB, strlen(s:CscopeDir)) . "]"
    else
	let {s:curCmd}_resulttext = s:CscopeCmdText{l:ndx} . " " . l:symbol . " (case sensitive) in [" . strpart(s:CscopeDB, strlen(s:CscopeDir)) . "]"
    endif

    if l:ndx == 7
        let {s:curCmd}_filter = 1
	let {s:curCmd}_jump = 1
    else
	let {s:curCmd}_jump = 2
    endif
endfunction

function s:Result_cscopeQuery()
    let temp = {s:curCmd}_resultBuf
    let lastFile = ""
    let i = 1
    while temp != ''
	let line = strpart(temp, 0, stridx(temp, "\n"))
	let temp = strpart(temp, stridx(temp, "\n") + 1)

	" <file name> <function name> <line number> <context>
	let {s:curCmd}_result{i}_file = strpart(line, 0, stridx(line, " "))

        if strlen(line) != "" && strlen({s:curCmd}_result{i}_file) == 0
            let {s:curCmd}_result{i}_file = line
	    let {s:curCmd}_result{i}_text = {s:curCmd}_result{i}_file
            let {s:curCmd}_result{i}_line = 1
            let i = i + 1
            continue
        endif

	let line = strpart(line, stridx(line, " ") + 1)
	let {s:curCmd}_result{i}_function = strpart(line, 0, stridx(line, " "))

        if {s:curCmd}_filter == 1
            unlet {s:curCmd}_result{i}_function
	    let {s:curCmd}_result{i}_text = {s:curCmd}_result{i}_file
            let {s:curCmd}_result{i}_line = 1
            let i = i + 1
            continue
        endif

	let line = strpart(line, stridx(line, " ") + 1)
	let {s:curCmd}_result{i}_line = strpart(line, 0, stridx(line, " "))

	let line = strpart(line, stridx(line, " ") + 1)
	let {s:curCmd}_result{i}_context = line

	" aggregate results for one file
        if {s:curCmd}_result{i}_file == lastFile
	    if {s:curCmd}_ndx == 2 
		let {s:curCmd}_result{i}_text = "    " . {s:curCmd}_result{i}_line . " " . {s:curCmd}_result{i}_context 
	    else
		let {s:curCmd}_result{i}_text = "    " . {s:curCmd}_result{i}_function . " " . {s:curCmd}_result{i}_line . " " . {s:curCmd}_result{i}_context
	    endif
	else 
	    let {s:curCmd}_result{i}_text = {s:curCmd}_result{i}_file
	    let nextLine = i + 1
	    let {s:curCmd}_result{nextLine}_file = {s:curCmd}_result{i}_file
	    let {s:curCmd}_result{nextLine}_line = {s:curCmd}_result{i}_line
	    let {s:curCmd}_result{nextLine}_context = {s:curCmd}_result{i}_context
	    let {s:curCmd}_result{nextLine}_function = {s:curCmd}_result{i}_function
	    let i = nextLine
	    if {s:curCmd}_ndx == 2 
		let {s:curCmd}_result{i}_text = "    " . {s:curCmd}_result{i}_line . " " . {s:curCmd}_result{i}_context 
	    else
		let {s:curCmd}_result{i}_text = "    " . {s:curCmd}_result{i}_function . " " . {s:curCmd}_result{i}_line . " " . {s:curCmd}_result{i}_context
	    endif
	    let lastFile = {s:curCmd}_result{i}_file
	endif

	let i = i + 1
    endwhile
    let {s:curCmd}_resultCount = i - 1
endfunction

" Adds a cscope commands cache subtree to the Cache data structure.
function s:SetUpCscopeMenu(db)
    let l:db = a:db
    if exists("s:cs_" . l:db . "_added")
	return
    endif
    let s:cs_{l:db}_leaf = 0
    let s:cs_{l:db}_text = a:db 
    let s:cs_{l:db}_0_text = s:CscopeCmdText{0} . " (\\s)"
    let s:cs_{l:db}_1_text = s:CscopeCmdText{1} . " (\\g)"
    let s:cs_{l:db}_2_text = s:CscopeCmdText{2} . " (\\c)"
    let s:cs_{l:db}_3_text = s:CscopeCmdText{3} . " (\\d)"
    let s:cs_{l:db}_4_text = s:CscopeCmdText{4} . " (\\t)"
    let s:cs_{l:db}_5_text = s:CscopeCmdText{5} . " (\\x)"
    let s:cs_{l:db}_6_text = s:CscopeCmdText{6} . " (\\e)"
    let s:cs_{l:db}_7_text = s:CscopeCmdText{7} . " (\\f)"
    let s:cs_{l:db}_8_text = s:CscopeCmdText{8} . " (\\i)"

    let s:cs_{l:db}_0_leaf = 0
    let s:cs_{l:db}_1_leaf = 0
    let s:cs_{l:db}_2_leaf = 0
    let s:cs_{l:db}_3_leaf = 0
    let s:cs_{l:db}_4_leaf = 0
    let s:cs_{l:db}_5_leaf = 0
    let s:cs_{l:db}_6_leaf = 0
    let s:cs_{l:db}_7_leaf = 0
    let s:cs_{l:db}_8_leaf = 0

    let s:cs_{l:db}_0_show = 1
    let s:cs_{l:db}_1_show = 1
    let s:cs_{l:db}_2_show = 1
    let s:cs_{l:db}_3_show = 1
    let s:cs_{l:db}_4_show = 1
    let s:cs_{l:db}_5_show = 1
    let s:cs_{l:db}_6_show = 1
    let s:cs_{l:db}_7_show = 1
    let s:cs_{l:db}_8_show = 1

    let s:cs_{l:db}_0_nextlevel =  "s:cs_" . l:db . "_0"
    let s:cs_{l:db}_1_nextlevel =  "s:cs_" . l:db . "_1"
    let s:cs_{l:db}_2_nextlevel =  "s:cs_" . l:db . "_2"
    let s:cs_{l:db}_3_nextlevel =  "s:cs_" . l:db . "_3"
    let s:cs_{l:db}_4_nextlevel =  "s:cs_" . l:db . "_4"
    let s:cs_{l:db}_5_nextlevel =  "s:cs_" . l:db . "_5"
    let s:cs_{l:db}_6_nextlevel =  "s:cs_" . l:db . "_6"
    let s:cs_{l:db}_7_nextlevel =  "s:cs_" . l:db . "_7"
    let s:cs_{l:db}_8_nextlevel =  "s:cs_" . l:db . "_8"

    call s:ListAppend("s:cs", "s:cs_" . l:db)
    let s:cs_{l:db}_added = 1

    call s:ListAppend("s:cs_" . l:db, "s:cs_" . l:db . "_0")
    call s:ListAppend("s:cs_" . l:db, "s:cs_" . l:db . "_1")
    call s:ListAppend("s:cs_" . l:db, "s:cs_" . l:db . "_2")
    call s:ListAppend("s:cs_" . l:db, "s:cs_" . l:db . "_3")
    call s:ListAppend("s:cs_" . l:db, "s:cs_" . l:db . "_4")
    call s:ListAppend("s:cs_" . l:db, "s:cs_" . l:db . "_6")
    call s:ListAppend("s:cs_" . l:db, "s:cs_" . l:db . "_7")
    call s:ListAppend("s:cs_" . l:db, "s:cs_" . l:db . "_8")

    let s:cs_{l:db}_nextlevel = "s:cs_" . l:db
    let s:cs_{l:db}_show = 1
endfunction

" A helper function to translate user input into arguments expected by cscope
function s:GetCscopeQueryNum(query)
    if (a:query == "s" || a:query == "0")
	let l:ndx = 0
    elseif (a:query == "g" || a:query == "1")
	let l:ndx = 1
    elseif (a:query == "c" || a:query == "2")
	let l:ndx = 2
    elseif (a:query == "d" || a:query == "3")
	let l:ndx = 3
    elseif (a:query == "t" || a:query == "4")
	let l:ndx = 4
    elseif (a:query == "e" || a:query == "6")
	let l:ndx = 6
    elseif (a:query == "f" || a:query == "7")
	let l:ndx = 7
    elseif (a:query == "i" || a:query == "8")
	let l:ndx = 8
    else
	let l:ndx = -1
    endif
    return l:ndx
endfunction

" Helper function to do the opposite of above.
function s:GetCscopeQuerySym(query)
    if (a:query == "s" || a:query == "0")
	let l:sym = "s"
    elseif (a:query == "g" || a:query == "1")
	let l:sym = "g"
    elseif (a:query == "c" || a:query == "2")
	let l:sym = "c"
    elseif (a:query == "d" || a:query == "3")
	let l:sym = "d"
    elseif (a:query == "t" || a:query == "4")
	let l:sym = "t"
    elseif (a:query == "e" || a:query == "6")
	let l:sym = "e"
    elseif (a:query == "f" || a:query == "7")
	let l:sym = "f"
    elseif (a:query == "i" || a:query == "8")
	let l:sym = "i"
    endif
    return l:sym
endfunction

" ----------------------------- LK (List stacK) command ------------------------
function s:SetUpCmd_lk(cmd, ...)
    let {s:curCmd}_cmd  = "Stack"
    let {s:curCmd}_type = "lk"
    let {s:curCmd}_text = "List tag/file stack (:LK)"
    let {s:curCmd}_resulttext = "List tag/file stack"
endfunction

function s:Result_stackOpenFiles()
    let l:stack = s:StackId 
    let i = 1
    let stackTop = s:{l:stack}_top
    while stackTop >= 0 
        if strlen(s:{l:stack}_{stackTop}_file) > 0
	    let {s:curCmd}_result{i}_file = s:{l:stack}_{stackTop}_file
	    let {s:curCmd}_result{i}_line = s:{l:stack}_{stackTop}_line
            if exists("s:{l:stack}_{stackTop}_function") && exists("s:{l:stack}_{stackTop}_context")
                let {s:curCmd}_result{i}_text = {s:curCmd}_result{i}_file 
		let i = i + 1
		let {s:curCmd}_result{i}_file = s:{l:stack}_{stackTop}_file
		let {s:curCmd}_result{i}_line = s:{l:stack}_{stackTop}_line
                let {s:curCmd}_result{i}_text = "    " . s:{l:stack}_{stackTop}_function . "(..) {.. " . s:{l:stack}_{stackTop}_line . " " . s:{l:stack}_{stackTop}_context  . " ..}"
            else
                let {s:curCmd}_result{i}_text = {s:curCmd}_result{i}_file . " " . s:{l:stack}_{stackTop}_line
            endif
            let i = i + 1
        endif
	let stackTop = stackTop - 1
    endwhile
    let {s:curCmd}_resultCount = i - 1
endfunction


" ----------------------------- LB (List Buffers) command ----------------------
function s:SetUpCmd_lb(cmd, ...)
    let {s:curCmd}_cmd  = "Buffers"
    let {s:curCmd}_type = "lb"
    let {s:curCmd}_text = "List buffers (:LB)"
    let {s:curCmd}_resulttext = "List buffers"
endfunction

function s:Result_listBuffers()
    let nBuf = bufnr('$')
    let i = 1
    let rsltIdx = 1

    while i <= nBuf
	let bufName = bufname(i)
	if(getbufvar(i, '&buflisted') == 1 && strlen(bufName))
	    let {s:curCmd}_result{rsltIdx}_file = bufName
	    let {s:curCmd}_result{rsltIdx}_line = getbufvar(i, ".")
	    let {s:curCmd}_result{rsltIdx}_text = bufName . " " . {s:curCmd}_result{rsltIdx}_line
	    let {s:curCmd}_result{rsltIdx}_buffer = i
	    let rsltIdx = rsltIdx + 1
	endif
	let i = i + 1
    endwhile
    let {s:curCmd}_resultCount = rsltIdx - 1
endfunction

" ----------------------------- MK (build) command -------------------------
function s:SetUpCmd_mk(cmd, ...)
    let {s:curCmd}_cmd = ":silent make!"
    let {s:curCmd}_ndx = 0
    let {s:curCmd}_type = "mk"
    let {s:curCmd}_text = "List build errors (:MK)"
    let {s:curCmd}_resulttext = "List build errors"
endfunction

" ----------------------------- RD (build log) command -------------------------
function s:SetUpCmd_rd(cmd, ...)
    let {s:curCmd}_cmd = ":silent cgetfile! " . a:1
    let {s:curCmd}_ndx = 0
    let {s:curCmd}_type = "rd"
    let {s:curCmd}_text = a:1
    let {s:curCmd}_resulttext = "Read file " . a:1 .":" 
endfunction


" ----------------------------- RS (Restore Session) command -------------------
function s:SetUpCmd_rs(cmd, ...)
    let {s:curCmd}_cmd = "cat " . a:1
    let {s:curCmd}_ndx = 0
    let {s:curCmd}_type = "rs"
    let {s:curCmd}_text = a:1
    let {s:curCmd}_resulttext = "Restore session from " . a:1 .":" 
endfunction

function s:Result_Read_CS_resultfile()
    let temp = {s:curCmd}_resultBuf
    let i = 1
    while temp != ''
	let line = strpart(temp, 0, stridx(temp, "\n"))
	let temp = strpart(temp, stridx(temp, "\n") + 1)
	if strpart(line, 0, 1) == "$" || strpart(line, 0, 1) == "#" || strpart(line, 0, 10) == "/ Results " 
	    continue
	endif
	let filename = line
	let {s:curCmd}_result{i}_file = filename
	let {s:curCmd}_result{i}_text = line
	if temp != '' && strpart(temp, 0, 1) == " "
	    let line = strpart(temp, 0, stridx(temp, "\n"))

	    let mytemp = strpart(line, 4)
	    let {s:curCmd}_result{i}_function = strpart(mytemp, 0, stridx(mytemp, " "))
	    let mytemp = strpart(mytemp, stridx(mytemp, " ") + 1)
	    let {s:curCmd}_result{i}_line = strpart(mytemp, 0, stridx(mytemp, " "))
	    let mytemp = strpart(mytemp, stridx(mytemp, " ") + 1)
	    let {s:curCmd}_result{i}_context = strpart(mytemp, 0, stridx(mytemp, " "))
	    let i = i + 1
	endif
	while temp != '' && strpart(temp, 0, 1) == " "
	    let {s:curCmd}_result{i}_file = filename
	    let {s:curCmd}_result{i}_text = line

	    let mytemp = strpart(line, 4)
	    let {s:curCmd}_result{i}_function = strpart(mytemp, 0, stridx(mytemp, " "))
	    let mytemp = strpart(mytemp, stridx(mytemp, " ") + 1)
	    let {s:curCmd}_result{i}_line = strpart(mytemp, 0, stridx(mytemp, " "))
	    let mytemp = strpart(mytemp, stridx(mytemp, " ") + 1)
	    let {s:curCmd}_result{i}_context = strpart(mytemp, 0, stridx(mytemp, " "))
	    let i = i + 1
	    let temp = strpart(temp, stridx(temp, "\n") + 1)
	    let line = strpart(temp, 0, stridx(temp, "\n"))
	endwhile
    endwhile
    let {s:curCmd}_resultCount = i - 1
endfunction

" ----------------------------- GR (GRep) command --------------------------------
function s:SetUpCmd_gr(cmd, ...)
    if (a:0 == 0)
	return
    endif

    let l:argc = 1
    let {s:curCmd}_ndx = 0
    let {s:curCmd}_resulttext = {s:prevCmd}_resulttext . " | xargs grep "
    if exists(s:prevCmd . "_ndx")
        let {s:curCmd}_text = {s:prevCmd}_type . " " . s:GetCscopeQuerySym({s:prevCmd}_ndx) . " " . {s:prevCmd}_text
    else
        let {s:curCmd}_text = {s:prevCmd}_type 
    endif
    if s:CscopeCase == "ignore"
	let {s:curCmd}_text = {s:curCmd}_text . " " . "[noic] | gr"
    else
	let {s:curCmd}_text = {s:curCmd}_text . " " . "[ic] | gr"
    endif

    let {s:curCmd}_cmd = {s:prevCmd}_cmd . "| cut -d\":\" -f1 | cut -d\" \" -f1 | uniq | xargs grep -nH "
    while l:argc <= a:0
        let {s:curCmd}_cmd = {s:curCmd}_cmd . " " . a:{l:argc}
	let {s:curCmd}_resulttext = {s:curCmd}_resulttext . " " . a:{l:argc}
	let {s:curCmd}_text = {s:curCmd}_text . " " . a:{l:argc}
        let l:argc = l:argc + 1
    endwhile


    let {s:curCmd}_cmd = {s:curCmd}_cmd . "| grep -v \"^Binary \" "

    let {s:curCmd}_type = "gr"
endfunction

function s:Read_buildLogFile()
    let l:temp = {s:curCmd}_resultBuf . "\n"
    let lastFile = ""
    let i = 1
    while l:temp != ''
	let line = strpart(l:temp, 0, stridx(l:temp, "\n"))
	let l:temp = strpart(l:temp, stridx(l:temp, "\n") + 1)

        if line == ""
            continue
        endif
	if strpart(line, 0, 14) == " 1: / Results "
            echo "Please use RS command to restore session"
            call getchar()
            let {s:curCmd}_resultCount = 0
	    return
	endif
        if match(line, "^[ ]*[0-9]*: \f*") != -1
            "n: <file name>
            let tmpidx = stridx(line, ":")
            let {s:curCmd}_result{i}_file = strpart(line, tmpidx + 2)
	    let {s:curCmd}_result{i}_text = {s:curCmd}_result{i}_file
            let {s:curCmd}_result{i}_line = 1
            let i = i + 1
            continue
        else
            "<file name>:<line number>:<context>
            let tmpidx = stridx(line, ":")
            if tmpidx == -1
                let tmpidx = stridx(line, " ")
            endif
            let l:tmpo = strpart(line, 0, tmpidx)
            let tmpoidx = strridx(l:tmpo, " ")
            if tmpoidx == -1
                 let tmpoidx = 0
            else 
                 let tmpoidx = tmpoidx + 1
            endif
        endif

	let {s:curCmd}_result{i}_file = strpart(l:tmpo, tmpoidx, tmpidx)

        if strlen(line) != "" && strlen({s:curCmd}_result{i}_file) == 0
            let {s:curCmd}_result{i}_file = line
	    let {s:curCmd}_result{i}_text = {s:curCmd}_result{i}_file
            let {s:curCmd}_result{i}_line = 1
            let i = i + 1
            continue
        endif

	let line = strpart(line, tmpidx + 1)

	let tmpidx = stridx(line, ":")
	if tmpidx == -1
	    let tmpidx = stridx(line, " ")
	endif
	let {s:curCmd}_result{i}_line = strpart(line, 0, tmpidx)

	let tmpidx = stridx(line, ":")
	if tmpidx == -1
	    let tmpidx = stridx(line, " ")
	endif
	let line = strpart(line, tmpidx + 1)
	let {s:curCmd}_result{i}_context = line

	" aggregate results for one file
        if {s:curCmd}_result{i}_file == lastFile
	    if {s:curCmd}_ndx == 2 
		let {s:curCmd}_result{i}_text = "    " . {s:curCmd}_result{i}_line . " " . {s:curCmd}_result{i}_context 
	    else
		let {s:curCmd}_result{i}_text = "    " . {s:curCmd}_result{i}_line . " " . {s:curCmd}_result{i}_context
	    endif
	else 
	    let {s:curCmd}_result{i}_text = {s:curCmd}_result{i}_file
	    let nextLine = i + 1
	    let {s:curCmd}_result{nextLine}_file = {s:curCmd}_result{i}_file
	    let {s:curCmd}_result{nextLine}_line = {s:curCmd}_result{i}_line
	    let {s:curCmd}_result{nextLine}_context = {s:curCmd}_result{i}_context
	    let i = nextLine
	    if {s:curCmd}_ndx == 2 
		let {s:curCmd}_result{i}_text = "    " . {s:curCmd}_result{i}_line . " " . {s:curCmd}_result{i}_context 
	    else
		let {s:curCmd}_result{i}_text = "    " . {s:curCmd}_result{i}_line . " " . {s:curCmd}_result{i}_context
	    endif
	    let lastFile = {s:curCmd}_result{i}_file
	endif

	let i = i + 1
    endwhile
    let {s:curCmd}_resultCount = i - 1
endfunction

" ----------------------------- Web Search Command --------------------------------
function s:SetUpCmd_gs(cmd, ...)
    let l:sym = a:1
    let l:sym = escape (l:sym, " #?&;|%")
    if s:SearchEngine == "Yahoo"
        let l:searchURL = "http://search.yahoo.com/"
        let l:searchTxt = "Yahoo"
        let l:rsltQuery = "n"
    else
        let l:searchURL = "http://www.google.com/"
        let l:searchTxt = "Google"
        let l:rsltQuery = "num"
    endif
    let l:cmd = "elinks -dump ". l:searchURL . "search?" . l:rsltQuery . "=" . s:SearchCount . "&hl=en&q=" 
    let l:cmd  = escape (cmd, "#?&;|%")

    let {s:curCmd}_cmd  = l:cmd . l:sym 
    let {s:curCmd}_type = "ws"
    let {s:curCmd}_text = l:sym 
    let {s:curCmd}_resulttext = l:searchTxt . " search " . l:sym
endfunction

function s:Result_WebSearch()
    let l:temp = {s:curCmd}_resultBuf
    let l:result_index = ''
    let i = 1
    let l:parse = 0

    if s:SearchEngine == "Yahoo"
        "Yahoo
        let l:ResultsTitle = "WEB RESULTS"  
    else
        "Google
        let l:ResultsTitle = "Search Results"  
    endif

    while l:temp != ''
	let l:line = strpart(l:temp, 0, stridx(l:temp, "\n"))
	let l:temp = strpart(l:temp, stridx(l:temp, "\n") + 1)

	if l:parse == 0 && l:line != l:ResultsTitle && l:line != "References"
	    continue
	endif
	if l:parse == 0 && l:line == l:ResultsTitle
	    let l:parse = 1
	    continue
	endif
	if (l:parse == 1 || l:parse == 0) && l:line == "References"
	    let l:parse = 2
	    continue
	endif

	" parsing starts here


	if l:parse == 1
	    " parse Results section

	    " ignore empty lines
	    if l:line == ''
		continue
	    endif

	    if match(l:line, '^[ ]\+[0-9]\+\.') != -1
		let l:temp_index = 0
		let l:result_index = matchstr(l:line, '[0-9]\+\.')
		let l:url_index_str = matchstr(l:line, '\[[0-9]\+]')
		let l:url_index = matchstr(l:url_index_str, '[0-9]\+')
		if l:url_index != ''
		    let l:url_{l:url_index}_{l:temp_index} = i
		endif
		let l:result_text_index = match(l:line, '\]') + 1
		let l:result_text = strpart(l:line, l:result_text_index) . "\n"
		let {s:curCmd}_result{i}_text = l:result_index . " " . l:result_text
		let l:skip = 0
	    else
		if l:skip == 1
		    continue
		endif
		if match(l:line, '^[ ]\+[a-zA-Z_\-\.]\+\/') != -1 
		    let l:skip=1
		    continue
		endif
		" in case the line with N. does not contain the url index.
		" use any url index from the subsequent lines.
		if l:url_index == ''
		    let l:url_index_str = matchstr(l:line, '\[[0-9]\+]')
		    let l:url_index = matchstr(l:url_index_str, '[0-9]\+')
		    let l:url_{l:url_index}_{l:temp_index} = i-1
		endif
		let {s:curCmd}_result{i}_text = l:line
		let l:temp_index = l:temp_index + 1
		if l:url_index != ''
		    let l:url_{l:url_index}_{l:temp_index} = i
		endif
	    endif
	    let i = i + 1
	elseif l:parse == 2
	    " parse References section

	    " ignore empty lines
	    if l:line == ''
		continue
	    endif
	    if l:line == "   Visible links"
		continue
	    endif
	    if match(l:line, '^[ ]\+[0-9]\+\.') != -1
                let l:url_index_str = matchstr(l:line, '^[ ]\+[0-9]\+\.')
		let l:url_index = matchstr(l:url_index_str, '[0-9]\+')
		let l:temp_index = 0
		while exists("l:url_" . l:url_index . "_" . l:temp_index) == 1
		    let l:result_index = {"l:url_" . l:url_index . "_" . l:temp_index}
		    let {s:curCmd}_result{l:result_index}_file = matchstr(l:line, 'http:.*$')

		    let l:temp_index = l:temp_index + 1
		endwhile
	    endif
	endif
    endwhile
    let {s:curCmd}_resultCount = i - 1
endfunction

" ----------------------------- Core Functions --------------------------------
function s:SetDefaults()
    let {s:curCmd}_jump = 0
    let {s:curCmd}_filter = 0
endfunction

function s:AllocSingletonCmd(cmd, hide)
    let s:numCmds = s:numCmds + 1
    let s:curCmd = "s:Commands".s:numCmds
    if a:hide == 0 || a:hide == 2
	let l:i = s:ListAppend("s:NewCommands", s:curCmd)
	let s:cmdVector{l:i} = s:curCmd
    endif
endfunction

function s:AllocCmd(cmd, hide)
    let s:numCmds = s:numCmds + 1
    let s:prevCmd = s:curCmd
    let s:curCmd = "s:Commands".s:numCmds
    if a:hide == 0 || a:hide == 2
	let l:i = s:ListAppend("s:" . a:cmd, s:curCmd)
	let s:cmdVector{l:i} = s:curCmd
    endif
endfunction

" Execute a cmd
function s:Cmd(cmd, hide, ...)
    if exists("s:startedFly") == 0
        call s:StartFly()
        let s:existFlywins = 0
    else
        let s:existFlywins = 1
    endif
    if exists("s:MenuChoice") && s:MenuChoice == "Help"
        let i = line('.')
        let s:CurHelp = i
    endif

    if winnr() != bufwinnr(s:FlyFutureWinTitle) && winnr() != bufwinnr(s:FlyControlWinTitle) && winnr() != bufwinnr("__Tag_List__") && winnr() != bufwinnr("__FlyMan")
	call s:GetStack()
    endif

    if (a:hide == 0 || a:hide == 2) && (a:cmd == "lk" || a:cmd == "lb")
	if exists("s:".a:cmd)
	    let s:curCmd = s:{a:cmd}
	    if exists(s:curCmd."_line_number")
		let s:CurCache = {s:curCmd}_line_number
	    endif
	    call s:UpdateFlyCache()
	    call s:HighLightLines()
	    let l:reference = s:StackPush(s:CommandStackId)
	    let {l:reference}_cmd = s:curCmd
            let {s:curCmd}_win = winnr()
            let {s:curCmd}_winStackId = s:StackId
	    return
	else
	    call s:AllocSingletonCmd(a:cmd, a:hide)
	    let s:{a:cmd} = s:curCmd
	    call s:SetDefaults()
	endif
    elseif (a:hide == 0 || a:hide == 2) && (a:cmd == "db")
	if exists("s:".a:cmd)
	    let s:curCmd = s:{a:cmd}
            call s:ListDestroy(s:curCmd."_result")
        else
            call s:AllocSingletonCmd(a:cmd, a:hide)
	    let s:{a:cmd} = s:curCmd
        endif
        call s:SetDefaults()
    elseif a:cmd == "cs"
        if s:CscopeDB == ""
            "TODO may be show a notice to user
            echo "Please select a cscope database to work with."
            call getchar()
            return
        endif
        if !filereadable(s:CscopeDB)
            echo s:CscopeDB . " is not ready yet. Please select another cscope database to work with."
            call getchar()
            return
        endif
	let l:ndx = s:GetCscopeQueryNum(a:1)
        if l:ndx == -1
            echo "Invalid Cscope command."
            call getchar()
            return
        endif
	let l:db = strpart(s:CscopeDB, strlen(s:CscopeDir))
	let l:db = substitute(l:db, "\\/", "__", "g")
	let l:db = substitute(l:db, "\\.", "_", "g")
	let l:db = substitute(l:db, "\\-", "_", "g")
        let l:symbol = substitute(a:2, "\\.", "_", "g")
        let l:symbol = substitute(l:symbol, "[^a-zA-Z0-9_]", "_", "g")
        let l:symbol = substitute(l:symbol, "[\s]", "_", "g")
	if exists("s:" . a:cmd . "_" . l:db . "_" . l:ndx . "_" . l:symbol ."__" . s:CscopeCase . "__")
	    let s:curCmd = s:{a:cmd}_{l:db}_{l:ndx}_{l:symbol}__{s:CscopeCase}__ 
	    call s:UpdateFlyCache()
	    if exists(s:curCmd."_line_number")
		let s:CurCache = {s:curCmd}_line_number
	    endif
	    call s:HighLightLines()
	    let l:reference = s:StackPush(s:CommandStackId)
	    let {l:reference}_cmd = s:curCmd
	    return
	else
	    call s:AllocCmd(a:cmd . "_" . l:db . "_" . l:ndx, a:hide)
	    if l:ndx != 4 && l:ndx != 6
		let s:{a:cmd}_{l:db}_{l:ndx}_{l:symbol}__{s:CscopeCase}__ = s:curCmd
	    endif
	    call s:SetDefaults()
	endif
    elseif a:cmd == "rd" || a:cmd == "rs"
        if !filereadable(a:1)
            echo a:1 . " does not exist."
            call getchar()
            return
        endif
    else 
        if a:cmd == "gr" && {s:curCmd}_type != "cs" && {s:curCmd}_type != "ls" && {s:curCmd}_type != "gr"
            "TODO may be show a notice to user
            return
        endif
	call s:AllocCmd(a:cmd, a:hide)
	call s:SetDefaults()
    endif

    let {s:curCmd}_win = winnr()
    let {s:curCmd}_winStackId = s:StackId

    if (a:0 == 0)
	call {s:SetUp{a:cmd}}(a:cmd)
    elseif (a:0 == 1)
	call {s:SetUp{a:cmd}}(a:cmd, a:1)
    elseif (a:0 == 2)
	call {s:SetUp{a:cmd}}(a:cmd, a:1, a:2)
    elseif (a:0 == 3)
	call {s:SetUp{a:cmd}}(a:cmd, a:1, a:2, a:3)
    elseif (a:0 == 4)
	call {s:SetUp{a:cmd}}(a:cmd, a:1, a:2, a:3, a:4)
    elseif (a:0 == 5)
	call {s:SetUp{a:cmd}}(a:cmd, a:1, a:2, a:3, a:4, a:5)
    endif

    if s:RunIt{a:cmd} != "NOP"
	call {s:RunIt{a:cmd}}({s:curCmd}_cmd)
    endif
    call {s:Parse{a:cmd}}()

    if a:hide == 0 
	call {s:ShowR{a:cmd}}()
	if exists(s:curCmd."_line_number")
	    let s:CurCache = {s:curCmd}_line_number
	endif
	call s:HighLightLines()
        let l:reference = s:StackPush(s:CommandStackId)
        let {l:reference}_cmd = s:curCmd
    endif
endfunction

"TODO
function s:OnResponseDel()
    if {s:curCmd}_type != "lb"
	return
    endif

    let i = line('.') - 1

    if i == 0
	return
    endif

    let l:window = bufwinnr({s:curCmd}_result{i}_buffer)
    echo l:window
    call getchar()
    if l:window == -1
	echo "deleting"
	call getchar()
	exe ":bdelete " .  {s:curCmd}_result{i}_buffer
    else
	echo "emptying"
	call getchar()
	exe l:window . "wincmd w"
	exe "enew "
	exe bufwinnr(s:FlyControlWinTitle) . "wincmd w"
	exe ":bdelete " .  {s:curCmd}_result{i}_buffer
    endif

    call {s:Parse{{s:curCmd}_type}}()
    call {s:ShowR{{s:curCmd}_type}}()
endfunction

" Callback for <Enter> key hit on a line in __FlyControl
function s:OnResponseHit()
    let i = line('.') - 1
    if i == 0
	let column = col('.')
	if column >= 1 && column <= 10
	    call {s:ShowR{{s:curCmd}_type}}()
	    if exists(s:curCmd."_line_number")
	        let s:CurCache = {s:curCmd}_line_number
	    endif
	    call s:HighLightLines()
	    return
	elseif column >= 11 && column <= 18
	    call s:PopulateFlyCache()
	    call s:HighLightLines()
	    return
	elseif column >= 19 && column <= 29
	    call s:FillSettings()
	    exe s:CurSetting
	    call s:HighLightLines()
	    return
	else 
	    call s:FillHelp()
	    exe s:CurHelp
	    call s:HighLightLines()
	    return
	endif
    elseif i == 1
        if s:MenuChoice != "Result"
	    return
	endif
	" do the following only if it is a result window
	let line = getline(s:ResultLineStart)
	let tempLen = strlen({s:curCmd}_resulttext)

	let l:prevCmd = s:curCmd

	if {l:prevCmd}_type == "cs"
	    let l:db = strpart(s:CscopeDB, strlen(s:CscopeDir))
	    let l:db = substitute(l:db, "\\/", "__", "g")
	    let l:db = substitute(l:db, "\\.", "_", "g")
	    let l:db = substitute(l:db, "\\-", "_", "g")
	    call s:AllocCmd({l:prevCmd}_type . "_" . l:db . "_" . {l:prevCmd}_ndx, 0)
	    call s:SetDefaults()
	else
	    call s:AllocCmd({l:prevCmd}_type, 0)
	    call s:SetDefaults()
	endif

	if {l:prevCmd}_resulttext == strpart(line, 2, tempLen)
	    let {s:curCmd}_cmd  = {l:prevCmd}_cmd . strpart(line, tempLen + 3)
	    let {s:curCmd}_text = {l:prevCmd}_text . strpart(line, tempLen + 3)
	    let {s:curCmd}_type = {l:prevCmd}_type 
	    let {s:curCmd}_resulttext = strpart(line, 2)
    	    if exists(l:prevCmd . "_ndx")
    	        let {s:curCmd}_ndx  = {l:prevCmd}_ndx
	    endif

	    let {s:curCmd}_jump = {l:prevCmd}_jump 
	    let {s:curCmd}_filter = {l:prevCmd}_filter 
	else
	    let {s:curCmd}_cmd  = strpart(line, 1)
	    let {s:curCmd}_text = strpart(line, 1)
	    let {s:curCmd}_type = "oh"
	endif

	if s:RunIt{{s:curCmd}_type} != "NOP"
	    call {s:RunIt{{s:curCmd}_type}}({s:curCmd}_cmd)
	endif
	call {s:Parse{{s:curCmd}_type}}()

	"if s:Visible{a:cmd} == 1
	    call {s:ShowR{{s:curCmd}_type}}()
	"endif
	return
    endif
    if s:MenuChoice == "Result"
        let {s:curCmd}_CurResult = i+1
        call s:HighLightLines()
        let i = i - s:ResultLineStart + 1
        call {s:OnHit{{s:curCmd}_type}}(i, "{s:curCmd}_result{i}")
    elseif s:MenuChoice == "Cache"
	call s:OnCacheHit()
    elseif s:MenuChoice == "Settings"
	call s:OnSettingsHit()
    elseif s:MenuChoice == "Help"
	call s:OnHelpHit()
    endif
endfunction

" ----------------------------- Core Utility Functions -------------------------
" Expand/Collapse explorer trees
function s:ShowHideSubtree(node)
    let l:node = a:node
    if !exists(l:node."_nextlevel")
	let l:curCmd = s:curCmd
	call s:Cmd({s:curCmd}_type, 1, {l:node}_file)
	let {l:node}_nextlevel = s:curCmd."_result"
	let {l:node}_show = 1 
	let s:curCmd = l:curCmd
	call s:PopulateResultList()
    elseif exists(l:node."_show")
	if {l:node}_show == 0
	    let {l:node}_show = 1 
	else
	    let {l:node}_show = 0
	endif
	"TODO free up {l:node}_nextlevel and corresponding command
	"TODO compare last modification time of directory and then
	"only run this command
	"let l:curCmd = s:curCmd
	"call Cmd({s:curCmd}_type, 1, {l:node}_file)
	"let {l:node}_nextlevel = s:curCmd."_result"
	"let s:curCmd = l:curCmd

	call s:PopulateResultList()
    endif
endfunction

" Highlight current line depending on which Tab is selected.
function s:HighLightLines()
    if s:MenuChoice == "Result"
        call s:HighLightLine({s:curCmd}_CurResult, s:FlyControlWinTitle)
    elseif s:MenuChoice == "Cache" 
        let l:tempLineNum = s:CurCache + s:EnvSectionLen + 1
        call s:HighLightLine(l:tempLineNum, s:FlyControlWinTitle)
    elseif s:MenuChoice == "Settings"
        call s:HighLightLine(s:CurSetting, s:FlyControlWinTitle)
    elseif s:MenuChoice == "Help"
        call s:HighLightLine(s:CurHelp, s:FlyControlWinTitle)
    endif
endfunction

" Highlight a line with ">>"
function s:HighLightLine(i, bufferName)
    if bufwinnr(a:bufferName) == -1
	return
    endif
    exe ":sign unplace 1 buffer=" . winbufnr(bufwinnr(a:bufferName))
    sign define piet text=>> texthl=Search
    exe ":sign place 1 line=" . a:i . " name=piet buffer=" . winbufnr(bufwinnr(a:bufferName))
endfunction

" populate a read only __Fly* window with contents of given file
function s:FlyPopulate(file)
    setlocal modifiable
    exe '1,$delete'

    try
       exe 'read ' . a:file
    catch /E484:/
       echo "Sorry, the file cannot be found."
    endtry

    setlocal nomodifiable
endfunction

" launch a __Fly* window with contents (url, man pages, ...)
function s:FlyLaunch(arg, file)
    call s:GoToPrimaryEditWin()
    if exists("s:startedFly{a:arg}") == 0 || bufwinnr(s:Fly{a:arg}WinTitle) == -1
	call s:StartFlyWin(a:arg)
    endif
    
    call s:GoToWin(s:Fly{a:arg}WinTitle)
    let l:reference = s:StackPush(s:{a:arg}StackId)
    let {l:reference}_file = a:file
    let {l:reference}_line = 1
    call s:FlyPopulate(a:file)
endfunction

" TODO This could be made more generic (not just clist).
function s:RunVimCmd(cmd)
    exe {s:curCmd}_cmd
    exe ":"
    exe ":set nomore"
    exe ":redir @\""
    exe ":silent clist"
    exe ":"
    exe ":redir END"
    exe ":set more"
    let {s:curCmd}_resultBuf = @"
endfunction

function s:Nop()
endfunction
" ----------------------------- Result Tab Functions -------------------------
function s:GoToResults()
    if exists("s:startedFly") == 0
        call s:StartFly()
    endif
    if bufwinnr(s:FlyControlWinTitle) == -1
	return
    endif
    if s:MenuChoice == "Help"
        let i = line('.')
        let s:CurHelp = i
    endif
    exe bufwinnr(s:FlyControlWinTitle) . "wincmd w"
    exe ":1"
    normal 0
    call s:OnResponseHit()
endfunction

function s:EmptyResult()
    if bufwinnr(s:FlyControlWinTitle) == -1
	return
    endif
    exe bufwinnr(s:FlyControlWinTitle) . "wincmd w"
    setlocal modifiable
    exe '1,$delete'
    setlocal nomodifiable
endfunction

function s:PopulateResult()
    let s:MenuChoice = "Result"
    if bufwinnr(s:FlyControlWinTitle) == -1
	return
    endif
    exe bufwinnr(s:FlyControlWinTitle) . "wincmd w"
    setlocal modifiable
    exe '1,$delete'
    call append(0, "/ Results \\ Cache | Settings | Help |")
    call append(1, "$ " . {s:curCmd}_resulttext)

    if {s:curCmd}_resultCount == 0
	call append(s:ResultLineStart, "No result!")
    else
	let i = 1
	while i <= {s:curCmd}_resultCount
		call append(i + s:ResultLineStart -1, {s:curCmd}_result{i}_text)
		let i = i + 1
	endwhile
    endif
    exe '$delete'
    if exists(s:curCmd."_CurResult") 
        exe ":" . {s:curCmd}_CurResult
    else
        let {s:curCmd}_CurResult = s:ResultLineStart + 1
        exe ":" . {s:curCmd}_CurResult
    endif

    if ({s:curCmd}_resultCount == 1 && {s:curCmd}_jump == 1) ||  ({s:curCmd}_resultCount == 2 && {s:curCmd}_jump == 2)
        call s:OnResponseHit()
	if s:existFlywins == 0
	    call s:QuitWins()
	endif
    endif
endfunction

function s:PrintResult(node, i)
    let l:i = 0
    let l:text2display = {a:node}_text
    if exists(a:node."_nextlevel") 
	if {a:node}_show == 1
	    let l:text2display = "- ".l:text2display
	else
	    let l:text2display = "+ ".l:text2display
	endif
    else
        if exists(a:node . "_leaf") 
	    if {a:node}_leaf == 0
		let l:text2display = "+ ".l:text2display
	    else
		let l:text2display = "| ".l:text2display
	    endif
	else
	    let l:text2display = "  ".l:text2display
	endif
    endif
    while l:i < s:level 
        let l:text2display = "  ".l:text2display
        let l:i = l:i + 1
    endwhile

    call append(s:i + s:ResultLineStart - 1, l:text2display)

    let {s:curCmd}_tree{s:i}_node = a:node
    if exists(a:node."_nextlevel") && {a:node}_show == 1
        let s:i = s:i + 1
        let s:level = s:level + 1
        call s:ListLoop({a:node}_nextlevel, "s:PrintResult")
        let s:level = s:level - 1
        let s:i = s:i - 1
    endif
    let s:i = s:i + 1
endfunction

"TODO This should call OnHit function with a third argument (sp/vsp)
"Or else the command won't work for results of ls, rd etc.
" open the file on the result line in a new window
function s:spFile(spcmd)
    let i = line('.') - 1
    if i == 0 || i == 1
        return
    endif
    if s:OnHit{{s:curCmd}_type} != "s:OnHit_fl"
        return
    endif
    let i = i - 1
    call s:GoToPrimaryEditWin()
    exec a:spcmd . ' ' . {s:curCmd}_result{i}_file
    exec {s:curCmd}_result{i}_line
    call s:CheckTies()
endfunction

" ----------------------------- Help Tab Functions -------------------------
function s:GoToHelp()
    if exists("s:startedFly") == 0
        call s:StartFly()
    endif
    if bufwinnr(s:FlyControlWinTitle) == -1
	return
    endif
    exe bufwinnr(s:FlyControlWinTitle) . "wincmd w"
    exe ":1"
    normal 7w
    call s:OnResponseHit()
endfunction

function s:FillHelp()
    let s:MenuChoice = "Help"
    setlocal modifiable
    exe '1,$delete'
    call append(0, "| Results | Cache | Settings / Help \\")

    call append(1, "________________________________________________________________________________")
    call append(1, "                               the other window.")
    call append(1, ":diffput        <Leader>p      Put the diff from the current window in focus to ")
    call append(1, "                               window in focus.")
    call append(1, ":diffget        <Leader>l      Pull the diff from the other window to current ")
    call append(1, " Following are just mappings to pull diff from or put diff to the other window.")
    call append(1, "________________________________________________________________________________")
    call append(1, "                               using fly commands, vimdiff is shown as well.")
    call append(1, "                               for every file that is opened in the edit window")
    call append(1, "                               the one specified by let g:sandbox=\"...\"")
    call append(1, "TIE                            TIE the sandbox selected by Cscope database and ")
    call append(1, "                               and corresponding file in the other sandbox.")
    call append(1, "DF      <Leader>z              Do a vim diff of file in current window in focus ")
    call append(1, "")
    call append(1, "     let g:sandbox=\"/absolute/path/to/root_of_sandbox\"  ")
    call append(1, "")
    call append(1, " diffs. The other sandbox may belong to any user.")
    call append(1, " with another source base (another sandbox). Useful for comparing and merging ")
    call append(1, " Following commands are useful to vimdiff source base (current cscope database)")
    call append(1, "________________________________________________________________________________")
    call append(1, "                               You must have svncommand.vim plugin installed.")
    call append(1, "                               using fly commands, SVN vimdiff is shown as well.")
    call append(1, "                               for every file that is opened in the edit window")
    call append(1, "TSVN                           Tie the current source base selection with SVN.")
    call append(1, "                               You must have cvscommand.vim plugin installed.")
    call append(1, "                               using fly commands, CVS vimdiff is shown as well.")
    call append(1, "                               for every file that is opened in the edit window")
    call append(1, "TCVS                           Tie the current source base selection with CVS.")
    call append(1, "________________________________________________________________________________")
    call append(1, "                               (For now, this works only for CS results)")
    call append(1, "RS <file>                      Restore session saved earlier from fly window.")
    call append(1, "________________________________________________________________________________")
    call append(1, "                               does not work for Man pages or Web pages window.")
    call append(1, "LK                             List buffer stack for edit window in focus. This")
    call append(1, "________________________________________________________________________________")
    call append(1, "RT          <Leader>.          Go up the stack in current window in focus.  (>)")
    call append(1, "LF          <Leader>,          Go down the stack in current window in focus.(<)")
    call append(1, " Following commands apply to edit windows and all fly windows (Control/Man/Web).")
    call append(1, "________________________________________________________________________________")
    call append(1, "TM                             Toggle Man Page Window.")
    call append(1, "                <Leader>mN     argument N is optional - man section in {1..8}")
    call append(1, "                               system calls and library APIs in man pages. The")
    call append(1, "                               yank include files and example code snippets for ")
    call append(1, "MAN [N] <sym>   <Leader>m      Get the UNIX man page for <sym>. It's useful to ")
    call append(1, "________________________________________________________________________________")
    call append(1, "TW                             Toggle Web Page Window.")
    call append(1, "            <Leader><Leader>o  Open a Web URL that is present in current line. ")
    call append(1, "OW <text>   <Leader>o          Open a URL <text> typed on the command line.")
    call append(1, "")
    call append(1, "    engine is Google.")
    call append(1, "    Yahoo. A choice can be made by going to Settings window. Default search ")
    call append(1, "    There are two choices for internet search engines as of now. Google and ")
    call append(1, "                               visually. ")
    call append(1, "            <Leader><Leader>w  Web Search for text under cursor or highlighted ")
    call append(1, "WS <text>   <Leader>w          Internet Search for <text> typed at command line.")
    call append(1, "________________________________________________________________________________")
    call append(1, "                               This <file> may just be a list of files as well.")
    call append(1, "RD <file>                      Read a build log (output of gmake/gcc/:clist/etc)")
    call append(1, "________________________________________________________________________________")
    call append(1, "                               Also, makeprg should have been set if applicable.")
    call append(1, "                               command line to the dir where builds are done.")
    call append(1, "MK          <Leader>b          Build the source. You must have done \"cd\" at vim")
    call append(1, "________________________________________________________________________________")
    call append(1, "                               only for results of CS/LS/GR command.")
    call append(1, "                               options to UNIX grep. The command currently works")
    call append(1, "                               the result window. The options are command line ")
    call append(1, "GR [options] <sym>             Grep for <sym> in all files currently listed in ")
    call append(1, "________________________________________________________________________________")
    call append(1, "    and likewise...")
    call append(1, "         <Leader><Leader>g     Search for definition of symbol under cursor.")
    call append(1, "         <Leader><Leader>s     Search for occurrences of symbol under cursor.")
    call append(1, "")
    call append(1, "  visually highlighted just prefix another <Leader> to above mappings, e.g.")
    call append(1, "  In order to run the same set of queries for symbol under cursor OR symbol")
    call append(1, "")
    call append(1, "  CS d <sym>     <Leader>d     Search for f() called by f() <sym>.")
    call append(1, "  CS i <sym>     <Leader>i     Search for files #including file <sym>.")
    call append(1, "  CS f <sym>     <Leader>f     Search for file <sym>.")
    call append(1, "  CS e <sym>     <Leader>e     Egrep Search for the symbol <sym>.")
    call append(1, "  CS t <sym>     <Leader>t     Search for text <sym>.")
    call append(1, "  CS c <sym>     <Leader>c     Search for calls to the function <sym>.")
    call append(1, "  CS g <sym>     <Leader>g     Search for definition of symbol <sym>.")
    call append(1, "  CS s <sym>     <Leader>s     Search for occurrences of symbol <sym>.")
    call append(1, "CS                             Query in currently selected Cscope Database. ")
    call append(1, "BD                             Build Cscope database in $CSCOPE_DIR.")
    call append(1, "LD                             List Cscope databases pre-built in $CSCOPE_DIR.")
    call append(1, "________________________________________________________________________________")
    call append(1, "LB          <Leader>lb         List all buffers currently open in vim.")
    call append(1, "LS <path>                      List all files in directory absolute <path>.")
    call append(1, "                               opened file in current edit window in focus.")
    call append(1, "LS          <Leader>ls         List all files in directory containing the ")
    call append(1, "________________________________________________________________________________")
    call append(1, "SW          <Leader>y          Toggle display of fly window.")
    call append(1, "________________________________________________________________________________")
    call append(1, "            <Leader>4          Go to Help Tab")
    call append(1, "            <Leader>3          Go to Settings Tab")
    call append(1, "            <Leader>2          Go to Cache Tab")
    call append(1, "            <Leader>1          Go to Results Tab")
    call append(1, "________________________________________________________________________________")
    call append(1, " A quick reference only. Please refer to the User Guide for details.")

endfunction

function s:OnHelpHit()
endfunction
" ----------------------------- Settings Tab Functions -------------------------
function s:GoToSettings()
    if exists("s:startedFly") == 0
        call s:StartFly()
    endif
    if bufwinnr(s:FlyControlWinTitle) == -1
	return
    endif
    if s:MenuChoice == "Help"
        let i = line('.')
        let s:CurHelp = i
    endif
    exe bufwinnr(s:FlyControlWinTitle) . "wincmd w"
    exe ":1"
    normal 5w
    call s:OnResponseHit()
endfunction

function s:FillSettings()
    let s:MenuChoice = "Settings"
    setlocal modifiable
    exe '1,$delete'
    call append(0, "| Results | Cache / Settings \\ Help |")
    call append(s:ResultLineStart, "Environment Variables")

    if s:CscopeDir == ""
	call append(s:ResultLineStart + 1, "  Cscope DB [location: Not set, Please specify.]")
    else
	call append(s:ResultLineStart + 1, "  Cscope DB [location: " . s:CscopeDir . "]")
    endif
    if s:CscopeDB == ""
	call append(s:ResultLineStart + 2, "    Not set, Please specify")
    else
	call append(s:ResultLineStart + 2, "    " . strpart(s:CscopeDB, strlen(s:CscopeDir)))
    endif
    call append(s:ResultLineStart + 3, "Toggle")
    if s:CscopeCase == "ignore"
	call append(s:ResultLineStart + 4, "  Cscope queries         - Case insensitive [ic]")
    else
	call append(s:ResultLineStart + 4, "  Cscope queries         - Case sensitive [noic]")
    endif
    if s:SearchEngine == "Google"
	call append(s:ResultLineStart + 5, "  Web search engine      - Google")
    else
	call append(s:ResultLineStart + 5, "  Web search engine      - Yahoo")
    endif

    if s:SearchCount == 10
        call append(s:ResultLineStart + 6, "  Search Result count    - 10")
    elseif s:SearchCount == 15
        call append(s:ResultLineStart + 6, "  Search Result count    - 15")
    elseif s:SearchCount == 20
        call append(s:ResultLineStart + 6, "  Search Result count    - 20")
    elseif s:SearchCount == 30
        call append(s:ResultLineStart + 6, "  Search Result count    - 30")
    elseif s:SearchCount == 40
        call append(s:ResultLineStart + 6, "  Search Result count    - 40")
    elseif s:SearchCount == 100
        call append(s:ResultLineStart + 6, "  Search Result count    - 100")
    else
        call append(s:ResultLineStart + 6, "  Search Result count    - 10")
    endif

    if s:WindowSplit == "vertical"
        call append(s:ResultLineStart + 7, "  Fly Window Split       - Vertical")
    else
        call append(s:ResultLineStart + 7, "  Fly Window Split       - Horizontal")
    endif
    call append(s:ResultLineStart + 8, "FlushCache")
    call append(s:ResultLineStart + 9, "  Web pages")
    call append(s:ResultLineStart + 10, "  Man pages")
endfunction

function s:OnSettingsHit()
    let i = line('.')
    let s:CurSettings = i
    if i == 4 || i == 5
	let s:curCmd = s:db
	if exists(s:curCmd."_line_number")
	    let s:CurCache = {s:curCmd}_line_number
	endif
	call s:UpdateFlyCache()
	call s:HighLightLines()
	return
    endif

    if i == 7
	if s:CscopeCase == "ignore"
	    let s:CscopeCase = "noignore"
	else
	    let s:CscopeCase = "ignore"
	endif
	call s:FillSettings()
	exe ":7"
	call s:HighLightLine(7, s:FlyControlWinTitle)
	return
    endif
    if i == 8
	if s:SearchEngine == "Google"
	    let s:SearchEngine = "Yahoo"
	else
	    let s:SearchEngine = "Google"
	endif

	call s:FillSettings()
	exe ":8"
	call s:HighLightLine(8, s:FlyControlWinTitle)
	return
    endif

    if i == 9
	if s:SearchCount == 10
	    let s:SearchCount = 15
	elseif s:SearchCount == 15
	    let s:SearchCount = 20
	elseif s:SearchCount == 20
	    let s:SearchCount = 30
	elseif s:SearchCount == 30
	    let s:SearchCount = 40
	elseif s:SearchCount == 40
	    let s:SearchCount = 100
	elseif s:SearchCount == 100
	    let s:SearchCount = 10
	else
	    let s:SearchCount = 10
	endif

	call s:FillSettings()
	exe ":9"
	call s:HighLightLine(9, s:FlyControlWinTitle)
	return
    endif
    if i == 10
	if s:WindowSplit == "vertical"
	    let s:WindowSplit = ""
        else
	    let s:WindowSplit = "vertical"
        endif
	call s:FillSettings()
	exe ":10"
	call s:HighLightLine(10, s:FlyControlWinTitle)
	return
    endif
    if i == 12
	let l:result = system("rm -rf " . s:webcachedir)
    endif
    if i == 13
	let l:result = system("rm -rf " . s:mancachedir)
    endif
endfunction

" ----------------------------- Cache Tab Functions -------------------------
function s:ShowHideFlyCache(node)
    let l:node = a:node
    if !exists(l:node."_nextlevel")
	let {l:node}_show = 1 
	call s:PopulateFlyCache()
    elseif exists(l:node."_show")
	if {l:node}_show == 0
	    let {l:node}_show = 1 
	    call s:PopulateFlyCache()
	else
	    let {l:node}_show = 0
	    call s:PopulateFlyCache()
	endif
    endif
endfunction

function s:GoToCache()
    if exists("s:startedFly") == 0
        call s:StartFly()
    endif
    if bufwinnr(s:FlyControlWinTitle) == -1
	return
    endif
    if s:MenuChoice == "Help"
        let i = line('.')
        let s:CurHelp = i
    endif
    exe bufwinnr(s:FlyControlWinTitle) . "wincmd w"
    exe ":1"
    normal 3w
    call s:OnResponseHit()
endfunction

function s:PrintCacheList(node, i)
    let l:i = 0
    let l:text2display = {a:node}_text
    if exists(a:node."_nextlevel") 
	if {a:node}_show == 1
	    let l:text2display = "- ".l:text2display
	else
	    let l:text2display = "+ ".l:text2display
	endif
    else
        if exists(a:node . "_leaf") 
	    if {a:node}_leaf == 0
		let l:text2display = "+ ".l:text2display
	    else
		let l:text2display = "| ".l:text2display
	    endif
	else
	    let l:text2display = "| ".l:text2display
	endif
    endif
    while l:i < s:level
        let l:text2display = "  ".l:text2display
        let l:i = l:i + 1
    endwhile

    let l:textLocation = s:i + s:EnvSectionLen
    call append(l:textLocation, l:text2display)

    let s:CacheTree{s:i}_node = a:node
    let {a:node}_line_number = s:i
    if s:curCmd == a:node
	let s:CurCache = s:i
    endif
    if exists(a:node."_nextlevel") && {a:node}_show == 1
        let s:i = s:i + 1
        let s:level = s:level + 1
        call s:ListLoop({a:node}_nextlevel, "s:PrintCacheList")
        let s:level = s:level - 1
        let s:i = s:i - 1
    endif
    let s:i = s:i + 1
endfunction

function s:PopulateFlyCache()
    let s:MenuChoice = "Cache"
    setlocal modifiable
    exe '1,$delete'
    call append(0, "| Results / Cache \\ Settings | Help |")

    let s:EnvSectionLen = 1

    let s:i = 1
    let s:level = 0
    call s:ListLoop("s:NewCommands", "s:PrintCacheList")

    setlocal nomodifiable
    if !exists("s:CurCache") 
        let s:CurCache = 1
    endif
    let l:tempLineNum = s:CurCache + s:EnvSectionLen + 1
    exe ":" . l:tempLineNum
endfunction

" --- Commands on cache window ---

"TODO Delete stuff from cache
function s:DelCmdFromCache()
endfunction

" Select a command from cache list
function s:UpdateFlyCache()
    if {s:curCmd}_type == "lk" || {s:curCmd}_type == "lb"
	call {s:Parse{{s:curCmd}_type}}()
    endif
    call {s:ShowR{{s:curCmd}_type}}()
endfunction

function s:OnCacheHit()
    let i = line('.') - s:EnvSectionLen - 1
    if i <= 0 
    	return
    endif

    let l:node = s:CacheTree{i}_node
    if exists(l:node . "_leaf") && {l:node}_leaf == 0
	call s:ShowHideFlyCache(l:node)
    else
	let s:curCmd = l:node
	if exists(s:curCmd."_line_number")
	    let s:CurCache = {s:curCmd}_line_number
	endif
	call s:UpdateFlyCache()
    endif
    let s:CurCache = i
    let l:tempLineNum = s:CurCache + s:EnvSectionLen + 1
    exe l:tempLineNum
    call s:HighLightLines()
    let l:reference = s:StackPush(s:CommandStackId)
    let {l:reference}_cmd = s:curCmd
endfunction

" TODO Rerun a command from cache list
function s:RerunCommand()
endfunction

" ----------------------------- Navigation Functions ---------------------------
function s:GetStack()
    let w:PrimaryEditWin = "Current Edit Window"
    if getwinvar(winnr(), "StackId") == ""
        let w:StackId = "s" . s:LastStackId
        let s:StackId = w:StackId
        call s:StackInit(w:StackId)
        let s:LastStackId = s:LastStackId + 1
        let l:reference = s:StackPush(w:StackId)
        let {l:reference}_file = expand("%:p")
        let {l:reference}_line = line('.')
    else
        let s:StackId = w:StackId
    endif
endfunction

function s:GetWin(winName, setName)
    let l:result = -1
    let l:winNum = 1
    while winbufnr(l:winNum) != -1
	if getwinvar(l:winNum, 'PrimaryEditWin') == a:winName
	    :call setwinvar(l:winNum, "PrimaryEditWin", a:setName)
	    let l:result = l:winNum
	endif
	let l:winNum = l:winNum + 1
    endwhile
    return l:result
endfunction

function s:GoToWin(WinTitle)
    if bufwinnr(a:WinTitle) == -1
	return
    endif
    exe bufwinnr(a:WinTitle) . "wincmd w"
    exe ":1"
    normal 0
endfunction

" TODO needs to be straightened someday...
function s:GoToPrimaryEditWin()
    let winNum = 1
    let PEW = -1
    let REMEMBER = -1
    while winbufnr(winNum) != -1
	if getwinvar(winNum, 'PrimaryEditWin') == "Primary Edit Window"
	    :call setwinvar(winNum, "PrimaryEditWin", "")
	    let REMEMBER = winNum
	endif
	let winNum = winNum + 1
    endwhile
    let winNum = 1
    while winbufnr(winNum) != -1
	if getwinvar(winNum, 'PrimaryEditWin') == "Current Edit Window"
	    :call setwinvar(winNum, "PrimaryEditWin", "Primary Edit Window")
	    let PEW = winNum
	    break
	endif
	let winNum = winNum + 1
    endwhile
    if PEW == -1
	if REMEMBER == -1
	    let winNum = 1
	    while winbufnr(winNum) != -1
		if getwinvar(winNum, 'EditWin') == "Very First Window"
		    :call setwinvar(winNum, "PrimaryEditWin", "Primary Edit Window")
		    let PEW = winNum
		    break
		endif
		let winNum = winNum + 1
	    endwhile
	    if PEW == -1
		echo "Primary Edit Window disappeared! Using the first one"
		let PEW = 1
		:call setwinvar(PEW, "PrimaryEditWin", "Primary Edit Window")
	    endif
	else
	    let PEW = REMEMBER
	    :call setwinvar(PEW, "PrimaryEditWin", "Primary Edit Window")
	endif
    endif
    exec PEW . "wincmd w"
    let s:EditWin = PEW
    call s:GetStack()
endfunction

" move left on the stack of an edit window
function s:GoLeft()
    if winnr() != bufwinnr(s:FlyFutureWinTitle) && winnr() != bufwinnr(s:FlyControlWinTitle) && winnr() != bufwinnr(s:FlyManWinTitle) && winnr() != bufwinnr(s:FlyWebWinTitle)
	call s:GetStack()
        call s:MoveLeft(s:StackId) 
    elseif winnr() == bufwinnr(s:FlyControlWinTitle)
        let l:stackEmpty = s:StackEmpty(s:CommandStackId)
	if l:stackEmpty == 1
	    return
	endif

        let l:stackFull = s:StackFull(s:CommandStackId)
	let l:reference = s:StackPop(s:CommandStackId)
	let l:reference = s:StackTop(s:CommandStackId)
	if l:reference != ""
	    let l:temp = "original"
	    if l:reference != ""
		let s:curCmd = {l:reference}_cmd
		if exists(s:curCmd."_line_number")
		    let s:CurCache = {s:curCmd}_line_number
		endif
		let l:jumpState = {s:curCmd}_jump
		let {s:curCmd}_jump = 0
		call s:UpdateFlyCache()
		let {s:curCmd}_jump = l:jumpState
		call s:HighLightLines()
	    else
		call s:Debug()
		call getchar()
	    endif
	endif
    elseif winnr() == bufwinnr(s:FlyManWinTitle)
        call s:MoveLeftFly(s:ManStackId) 
    elseif winnr() == bufwinnr(s:FlyWebWinTitle)
        call s:MoveLeftFly(s:WebStackId) 
    endif
endfunction

" move right on the stack of an edit window
function s:GoRight()
    if winnr() != bufwinnr(s:FlyFutureWinTitle) && winnr() != bufwinnr(s:FlyControlWinTitle) && winnr() != bufwinnr(s:FlyManWinTitle) && winnr() != bufwinnr(s:FlyWebWinTitle)
	call s:GetStack()
        call s:MoveRight(s:StackId) 
    elseif winnr() == bufwinnr(s:FlyControlWinTitle)
	let l:stackFull = s:StackFull(s:CommandStackId)
	if l:stackFull == 1
	    return
	endif
	let l:reference = s:StackPush(s:CommandStackId)
	if exists(l:reference . "_cmd")
	    let s:curCmd = {l:reference}_cmd
	    if exists(s:curCmd."_line_number")
		let s:CurCache = {s:curCmd}_line_number
	    endif
	    let l:jumpState = {s:curCmd}_jump
	    let {s:curCmd}_jump = 0
	    call s:UpdateFlyCache()
	    let {s:curCmd}_jump = l:jumpState
	    call s:HighLightLines()
	else
	    call s:StackPop(s:CommandStackId)
	endif
    elseif winnr() == bufwinnr(s:FlyManWinTitle)
        call s:MoveRightFly(s:ManStackId) 
    elseif winnr() == bufwinnr(s:FlyWebWinTitle)
        call s:MoveRightFly(s:WebStackId) 
    endif
endfunction

" move left on the stack of a __Fly* window
function s:MoveLeftFly(stack)
    if s:{a:stack}_top == 0
        return
    endif
    let s:{a:stack}_{s:{a:stack}_top}_line = line('.')
    let s:{a:stack}_top = s:{a:stack}_top - 1
    call s:FlyPopulate(s:{a:stack}_{s:{a:stack}_top}_file)
endfunction

" move right on the stack of a __Fly* window
function s:MoveRightFly(stack)
    if s:{a:stack}_top == s:{a:stack}_end
        return
    endif
    let s:{a:stack}_{s:{a:stack}_top}_line = line('.')
    let s:{a:stack}_top = s:{a:stack}_top + 1
    call s:FlyPopulate(s:{a:stack}_{s:{a:stack}_top}_file)
endfunction

" -------------------- Overall Display Management -----------------------------
"TODO split this later for __Fly* and __FlyControl*
function s:SetAsFlyWin()
    setlocal nomodifiable

    silent! setlocal buftype=nofile
    silent! setlocal bufhidden=hide
    silent! setlocal noswapfile
    silent! setlocal nobuflisted

    syntax match Bar  '`*'
    syntax match File  '^\f\+\>'
    syntax match CacheHeading '^Commands Cache$'
    syntax match SettingHeading '^Environment Variables$'
    syntax match ToggleHeading '^Toggle$'
    syntax match FlushCacheHeading '^FlushCache$'
    syntax match ExploreHeading '^[ 	.]*[+-] .*$'
    syntax match WarningHeading 'Not set. Please specify'
    syntax match Numeric '\<[0-9][0-9]*\>'
    syntax match Selection '^>.\+$'
    syntax match MyHeading1 '/ Results \\'
    syntax match MyHeading2 '/ Cache \\'
    syntax match MyHeading3 /\/ Settings \\/
    syntax match MyHeading4 /\/ Help \\/
    syntax match GoogleSearch '^[0-9]\+\..*$' 
    syntax match Mappings '<Leader>.[^ ]* ' 

    if v:version >= 700
        set cursorline
    endif
    highlight link File type
    highlight link ExploreHeading type
    highlight link Numeric keyword
    highlight link GoogleSearch type
    highlight Bar term=bold cterm=bold
    highlight Heading term=bold cterm=bold
    highlight ResultHeading term=bold cterm=bold
    highlight CacheHeading term=bold cterm=bold
    highlight SettingHeading term=bold cterm=bold
    highlight ToggleHeading term=bold cterm=bold
    highlight FlushCacheHeading term=bold cterm=bold
    highlight WarningHeading term=bold cterm=bold
    highlight Selection term=reverse cterm=reverse
    highlight MyHeading1 term=bold,reverse cterm=bold,reverse
    highlight MyHeading2 term=bold,reverse cterm=bold,reverse
    highlight MyHeading3 term=bold,reverse cterm=bold,reverse
    highlight MyHeading4 term=bold,reverse cterm=bold,reverse
    highlight Mappings term=bold cterm=bold
    if v:version >= 700
        highlight cursorline term=bold,underline cterm=bold,underline
    endif
endfunction

function s:InitFlyControlWin()
    call s:SetAsFlyWin()
    nnoremap <buffer> <silent> <script> <CR> :call <SID>OnResponseHit()<CR>

    "TODO
    "nnoremap <buffer> <silent> <script> d :call s:OnResponseDel()<CR>
endfunction

function s:ToggleFly(...)
    if exists("s:startedFly") == 0
        call s:StartFly()
    else
        call s:QuitWins()
    endif
endfunction

" Start/Close __FlyControl window[s].
function s:StartFly(...)
        let s:startedFly = 1
        if exists("s:initDone") == 0
	    " cscope case sensitivity
            if exists("g:FlyCscopeCase")
                let s:CscopeCase = g:FlyCscopeCase
            else
                let s:CscopeCase = "ignore"
            endif
            
            " choice of search engine
            if exists("g:FlySearchEngine")
                let s:SearchEngine = g:FlySearchEngine
            else
                let s:SearchEngine = "Google"
            endif

            " number of search results
            if exists("g:FlySearchCount")
                let s:SearchCount = g:FlySearchCount
            else
                let s:SearchCount = 10
            endif

            " vertical or horizontal splits 
            if exists("g:FlyWindowSplit")
                let s:WindowSplit = g:FlyWindowSplit
            else
                let s:WindowSplit = "vertical"
            endif

            let s:CscopeDir = $CSCOPE_DIR
            if s:CscopeDir == ""
                let s:CscopeDirSet = 0
                let s:CscopeDir = getcwd()
            else
                let s:CscopeDirSet = 1
            endif

            " cache of man/web pages
            let s:webcachedir = "$HOME/.fly.vim/web"
            let s:mancachedir = "$HOME/.fly.vim/man"

	    " some magic
	    let s:EditWin = winnr()
            let w:PrimaryEditWin = "Primary Edit Window"
            let w:EditWin = "Very First Window"

	    " reserved stacks
	    let s:CommandStackId = "s1"
	    let s:ManStackId     = "s2"
	    let s:WebStackId     = "s3"
	    let s:LastStackId = 4

	    " per edit window stacks, starting with this one
	    let w:StackId = "s" . s:LastStackId
	    let s:StackId = w:StackId
	    let s:LastStackId = s:LastStackId + 1

	    " display related init
	    let s:ResultLineStart = 2
	    let s:ResultTabWidth  = 15
	    let s:CacheTabWidth  = 23
	    let s:SettingsTabWidth  = 34
        endif

	exe 'botright 15new ' . s:FlyControlWinTitle
	call s:InitFlyControlWin()

	let s:EnvSectionLen = 1

	call s:GoToPrimaryEditWin()

        if exists("s:initDone") == 0
            let s:initDone = 1
            call s:InitFly()
            call s:StackInit(s:CommandStackId)
            call s:StackInit(s:ManStackId)
            call s:StackInit(s:WebStackId)
            call s:StackInit(s:StackId)
            let l:reference = s:StackPush(s:StackId)
            let {l:reference}_file = expand("%:p")
            let {l:reference}_line = line('.')
	    call s:InitFlyCache()
	    let s:TiedToSandbox = 0
	    let s:TiedToCVS = 0
	    let s:TiedToSVN = 0
        endif
endfunction

function s:QuitWins()
    if exists("s:startedFly") == 1
        unlet s:startedFly
    endif
    if bufwinnr(s:FlyControlWinTitle) != -1
	exe bufwinnr(s:FlyControlWinTitle) . "wincmd w"
	exe bufwinnr(s:FlyControlWinTitle) . "wincmd q"
    endif
    if bufwinnr(s:FlyFutureWinTitle) != -1
	exe bufwinnr(s:FlyFutureWinTitle) . 'wincmd w'
	exe bufwinnr(s:FlyFutureWinTitle) . 'wincmd q'
    endif
endfunction

" Start/Close a __Fly* window.
function s:StartFlyWin(arg)
    if exists("s:startedFly") == 0
        call s:StartFly()
        call s:ToggleFly()
    endif
    let s:startedFly{a:arg} = 1
    exe ':' . s:WindowSplit . ' rightbelow new ' . s:Fly{a:arg}WinTitle
    call s:SetAsFlyWin()
endfunction

function s:QuitFlyWin(arg)
    if exists("s:startedFly" . a:arg) == 1
        unlet s:startedFly{a:arg}
    endif
    if bufwinnr(s:Fly{a:arg}WinTitle) != -1
	exe bufwinnr(s:Fly{a:arg}WinTitle) . "wincmd w"
	exe bufwinnr(s:Fly{a:arg}WinTitle) . "wincmd q"
    endif
    
endfunction

function s:ToggleFlyWin(arg)
    if exists("s:startedFly" . a:arg) == 0
        call s:StartFlyWin(a:arg)
    else
        call s:QuitFlyWin(a:arg)
    endif
endfunction

" ----------------------------- Multiple Sandboxes -----------------------------
function s:TieCVS()
    if exists("s:startedFly") == 0
        call s:StartFly()
        call s:ToggleFly()
    endif
    call s:GoToPrimaryEditWin()
    if winnr() != bufwinnr(s:FlyFutureWinTitle) && winnr() != bufwinnr(s:FlyControlWinTitle) && winnr() != bufwinnr("__Tag_List__") && winnr() != bufwinnr("__FlyMan") && winnr() != bufwinnr("__FlyWeb")
        if s:TiedToCVS == 0
            let l:tempWin = winnr()
            exe ":CVSVimDiff"
            let s:TiedCVSWin = winnr()
            if l:tempWin != s:TiedCVSWin
                let s:TiedToCVS = 1
            endif
            exe l:tempWin . "wincmd w"
        else
            let s:TiedToCVS = 0
            exe s:TiedCVSWin . "wincmd w"
            exe "bd"
        endif
    endif
endfunction

function s:TieSVN()
    if exists("s:startedFly") == 0
        call s:StartFly()
        call s:ToggleFly()
    endif
    call s:GoToPrimaryEditWin()
    if winnr() != bufwinnr(s:FlyFutureWinTitle) && winnr() != bufwinnr(s:FlyControlWinTitle) && winnr() != bufwinnr("__Tag_List__") && winnr() != bufwinnr("__FlyMan") && winnr() != bufwinnr("__FlyWeb")
        if s:TiedToSVN == 0
            let l:tempWin = winnr()
            exe ":SVNVimDiff"
            let s:TiedSVNWin = winnr()
            if l:tempWin != s:TiedSVNWin
                let s:TiedToSVN = 1
            endif
            exe l:tempWin . "wincmd w"
        else
            let s:TiedToSVN = 0
            exe s:TiedSVNWin . "wincmd w"
            exe "bd"
        endif
    endif
endfunction

function s:TieSandboxes()
    if exists("s:startedFly") == 0
        call s:StartFly()
        call s:ToggleFly()
    endif
    if !exists ("g:sandbox")
        echo "Please set the alternate sandbox."
        call getchar()
        return
    endif
    call s:GoToPrimaryEditWin()
    if winnr() != bufwinnr(s:FlyFutureWinTitle) && winnr() != bufwinnr(s:FlyControlWinTitle) && winnr() != bufwinnr("__Tag_List__") && winnr() != bufwinnr("__FlyMan") && winnr() != bufwinnr("__FlyWeb")
        if s:TiedToSandbox == 0
            let l:tempWin = winnr()
            call s:Diffit()
            let s:TiedWin = winnr()
            if l:tempWin != s:TiedWin
                let s:TiedToSandbox = 1
            endif
            exe l:tempWin . "wincmd w"
        else
            let s:TiedToSandbox = 0
            exe s:TiedWin . "wincmd w"
            exe "bd"
        endif
    endif
endfunction

function s:Diffit()
    if !exists ("g:sandbox")
        echo "Please set the alternate sandbox."
        call getchar()
        return
    endif
    if (strridx(g:sandbox, "/") + 1) != strlen(g:sandbox)
        let g:sandbox = g:sandbox . "/"
    endif
    let l:temp = strpart(g:sandbox, 0, strridx(g:sandbox, "/"))
    let g:SrcRoot = strpart(l:temp, strridx(l:temp, "/") + 1)

    let l:curfile = expand("%")
    if strpart(l:curfile, 0, 1) == "/"
        let l:srcidx  = stridx(l:curfile, g:SrcRoot)
        if l:srcidx != -1
            let l:srcidx = l:srcidx + 3
            let l:curfile = strpart(l:curfile, l:srcidx)
        endif
    endif
    let l:filename = g:sandbox . l:curfile
    exe ':set splitright'
    exe ':set splitbelow'
    exe ':' . s:WindowSplit . ' diffsplit ' . l:filename
endfunction

" ----------------------------- Web Pages -------------------------------------
function s:OnHit_link(...)
    let i = a:1
    let result = a:2
    call s:WebLaunch(0, {result}_file)
endfunction

function s:WebLaunch(...)
    if exists("s:startedFly") == 0
        call s:StartFly()
        call s:ToggleFly()
    endif
    "make sure cache exists
    if !isdirectory(s:webcachedir) 
	let l:result = system("mkdir -p " . s:webcachedir)
    endif

    if a:1 == 1
	let line = getline(".")
        let l:tempurl = matchstr(l:line, 'http:[^ ]*\|file:[^ ]*\|www\.[^ ]\+\|[^ \[\]]\+\.[^ \[\]]\+[^"]\>')
    else
        let l:tempurl = a:2
    endif

    if l:tempurl == ""
        echo "Sorry, the URL cannot be found/opened."
        return
    endif

    " build the cache file name
    let l:tempurl = escape(l:tempurl, "#?&;|%()")
    let l:escapeURL = substitute(l:tempurl, "\\/", "__", "g")
    let l:urlfile = s:webcachedir . "/" . l:escapeURL


    " build the contents if not there in cache
    if !filereadable(l:urlfile)
        let l:result = system("elinks -dump " . l:tempurl . " > " . l:urlfile)
    endif

    " open the contents in to a fly window.
    call s:FlyLaunch("Web", l:urlfile)
endfunction

" ----------------------------- UNIX Man Pages --------------------------------
function s:ManLaunch(section, symbol)
    if exists("s:startedFly") == 0
        call s:StartFly()
        call s:ToggleFly()
    endif
    if !isdirectory(s:mancachedir) 
	let l:result = system("mkdir -p " . s:mancachedir)
    endif

    " build the cache file name
    let l:manfile = s:mancachedir . "/" . a:symbol . "." . a:section

    " build the contents if not there in cache
    if !filereadable(l:manfile) 
	if a:section == 0
	    let l:result = system("man " . a:symbol. "|col -b > " . l:manfile)
	else
	    let l:result = system("man " . a:section. " " . a:symbol . "|col -b > " . l:manfile)
	endif
    endif

    " open the contents in to a fly window.
    call s:FlyLaunch("Man", l:manfile)
endfunction

function s:Man(symbol)
    call s:ManLaunch(0, a:symbol)
endfunction

function s:ManSection(...)
    if match(a:1, "[0-9]") == -1
        let l:section = 0
        let l:symbol = a:1
    else
        let l:section = a:1
        let l:symbol = a:2
    endif
    call s:ManLaunch(l:section, l:symbol)
endfunction

function s:CmdV(cmd, ...)
    if a:cmd == ":WS"
        let l:temp = escape(@", "#?&;|%() ")
        exe a:cmd . " " . l:temp 
    elseif a:cmd == ":OW"
        let l:temp = escape(@", "#?&;|%() ")
        exe a:cmd . " 0 " . l:temp
    else
        let l:temp = escape(@", "#?&;|%() ")
        exe a:cmd . " " . a:1 . " " . l:temp 
    endif
endfunction

" ----------------------------- Debug Functions ---------------------------------
function Debug()
    echo "s:TiedToCVS " . s:TiedToCVS 
    echo "s:TiedToSVN " . s:TiedToSVN
    echo "s:StackId " . s:StackId
    echo "s:{s:StackId}_top " . s:{s:StackId}_top
    echo "s:{s:StackId}_end " . s:{s:StackId}_end
    echo "StackTop(s:StackId) " . s:StackTop(s:StackId)
    echo "s:LastStackId " . s:LastStackId
    echo ""
    echo "s:CommandStackId " . s:CommandStackId
    echo "s:{s:CommandStackId}_top " . s:{s:CommandStackId}_top
    echo "s:{s:CommandStackId}_end " . s:{s:CommandStackId}_end
    echo "StackTop(s:CommandStackId) " . s:StackTop(s:CommandStackId)
    echo "{s:curCmd}_cmd " . {s:curCmd}_cmd
    echo "{s:curCmd}_ndx " . {s:curCmd}_ndx
    echo "{s:curCmd}_type " .  {s:curCmd}_type
    echo "{s:curCmd}_text " .  {s:curCmd}_text
    echo "{s:prevCmd}_cmd " . {s:curCmd}_cmd
    echo "{s:prevCmd}_ndx " . {s:curCmd}_ndx
    echo "{s:prevCmd}_type " .  {s:curCmd}_type
    echo "{s:prevCmd}_text " .  {s:curCmd}_text
    call getchar()
endfunction

" --------------------- Wish List (Future Enhancements) ------------------------
"
" + Selecting multiple cscope databases. Subsequent cscope queries will be on
"   the current selected set of databases.
" + List man pages (man -k) with titles matching a keyword (under cursor/typed)
" + Incremental database builds.
" + Rerun a command from the cache (instead of displaying cached results)
" + delete stuff from cache
" + delete stuff from result line (cases like LB, LK, LS, etc...)
" + support for elinks/lynx/w3m
" + order of listing of cscope databases.
"
" ------------------------------ Mappings Begin --------------------------------
" This section defines commands and mappings. User is free to change these.

" command definitions. this would replace your existing command definitions.
command! -nargs=* GO     :call <SID>StartFly(<f-args>)
command! -nargs=* SW     :call <SID>ToggleFly(<f-args>)
command! -nargs=* TM     :call <SID>ToggleFlyWin("Man")
command! -nargs=* TW     :call <SID>ToggleFlyWin("Web")
command! -nargs=* QW     :call <SID>QuitWins(<f-args>)
command! -nargs=* BD     :call <SID>BuildCscopeDB(<f-args>)
command! -nargs=* CS     :call <SID>Cmd("cs", 0, <f-args>)
command! -nargs=* LB     :call <SID>Cmd("lb", 0, <f-args>)
command! -nargs=* LK     :call <SID>Cmd("lk", 0, <f-args>)
command! -nargs=* LS     :call <SID>Cmd("ls", 0, <f-args>)
command! -nargs=* LD     :call <SID>Cmd("db", 0)
command! -nargs=* RS     :call <SID>Cmd("rs", 0, <f-args>)
command! -nargs=* RD     :call <SID>Cmd("rd", 0, <f-args>)
command! -nargs=* GR     :call <SID>Cmd("gr", 0, <f-args>)
command! -nargs=* WS     :call <SID>Cmd("ws", 0, <f-args>)
command! -nargs=* MK     :call <SID>Cmd("mk", 0, <f-args>)
command! -nargs=* DF     :call <SID>Diffit()
command! -nargs=* LF     :call <SID>GoLeft(<f-args>)
command! -nargs=* RT     :call <SID>GoRight(<f-args>)
command! -nargs=* OW     :call <SID>WebLaunch(<f-args>)
command! -nargs=* TIE    :call <SID>TieSandboxes(<f-args>)
command! -nargs=* TCVS   :call <SID>TieCVS()
command! -nargs=* TSVN   :call <SID>TieSVN()
command! -nargs=* MAN    :call <SID>ManSection(<f-args>)
command! -nargs=* VISW   :call <SID>CmdV(":WS", <f-args>)
command! -nargs=* VISQ   :call <SID>CmdV(":CS", <f-args>)
command! -nargs=* VISO   :call <SID>CmdV(":OW", <f-args>)

" key mappings. this would replace your existing key mappings.

" To toggle the display of Fly Control/Man window. Context is retained.
nmap <Leader>y :SW<cr><C-l>

" following mappings to switch among the sections in Fly Control window.
nmap <Leader>1 :call <SID>GoToResults()<cr>
nmap <Leader>2 :call <SID>GoToCache()<cr>
nmap <Leader>3 :call <SID>GoToSettings()<cr>
nmap <Leader>4 :call <SID>GoToHelp()<cr>

" cscope commands: command letters used here are same as in cscope_maps.vim from
" http://cscope.sourceforge.net/cscope_vim_tutorial.html

" following mappings are to seach 'the word under cursor' in cscope database 
nmap <Leader><Leader>s :CS s <c-r>=expand("<cword>")<cr><cr>
nmap <Leader><Leader>g :CS g <c-r>=expand("<cword>")<cr><cr>
nmap <Leader><Leader>d :CS d <c-r>=expand("<cword>")<cr><cr>
nmap <Leader><Leader>c :CS c <c-r>=expand("<cword>")<cr><cr>
nmap <Leader><Leader>t :CS t <c-r>=expand("<cword>")<cr><cr>
nmap <Leader><Leader>e :CS e <c-r>=expand("<cword>")<cr><cr>
nmap <Leader><Leader>f :CS f <c-r>=expand("<cword>")<cr><cr>
nmap <Leader><Leader>i :CS i <c-r>=expand("<cword>")<cr><cr>

" following mappings are to seach 'the word under cursor' in web search engine
nmap <Leader><Leader>w :WS <c-r>=expand("<cword>")<cr><cr>

" following mappings are to open URL in 'the line under cursor'
nmap <Leader><Leader>o :OW 1<cr>

" following mappings are to seach 'the visual selection' in cscope database 
vnoremap <Leader><Leader>s y<cr>:VISQ s <cr>
vnoremap <Leader><Leader>g y<cr>:VISQ g <cr>
vnoremap <Leader><Leader>d y<cr>:VISQ d <cr>
vnoremap <Leader><Leader>c y<cr>:VISQ c <cr>
vnoremap <Leader><Leader>t y<cr>:VISQ t <cr>
vnoremap <Leader><Leader>e y<cr>:VISQ e <cr>
vnoremap <Leader><Leader>f y<cr>:VISQ f <cr>
vnoremap <Leader><Leader>i y<cr>:VISQ i <cr>

" following mappings are to seach 'the visual selection' in web search engine
vnoremap <Leader><Leader>w y<cr>:VISW <cr>

" following mappings are to open URL in 'the visual selection'
vnoremap <Leader><Leader>o y<cr>:VISO <cr>

" following mappings are to type the word to be searched at command line 
nmap <Leader>s :CS s 
nmap <Leader>g :CS g 
nmap <Leader>d :CS d 
nmap <Leader>c :CS c 
nmap <Leader>t :CS t 
nmap <Leader>e :CS e 
nmap <Leader>f :CS f 
nmap <Leader>i :CS i 

nmap <Leader>w :WS 
nmap <Leader>o :OW 0 

" following mappings are to type the word to be searched at command line 
" the word is copied from visual selection.
vnoremap <Leader>s y<cr>:CS s <c-r>=expand(@")<cr>
vnoremap <Leader>g y<cr>:CS g <c-r>=expand(@")<cr> 
vnoremap <Leader>d y<cr>:CS d <c-r>=expand(@")<cr> 
vnoremap <Leader>c y<cr>:CS c <c-r>=expand(@")<cr> 
vnoremap <Leader>t y<cr>:CS t <c-r>=expand(@")<cr> 
vnoremap <Leader>e y<cr>:CS e <c-r>=expand(@")<cr> 
vnoremap <Leader>f y<cr>:CS f <c-r>=expand(@")<cr> 
vnoremap <Leader>i y<cr>:CS i <c-r>=expand(@")<cr> 

vnoremap <Leader>w y<cr>:WS <c-r>=expand(@")<cr> 
vnoremap <Leader>o y<cr>:OW 0 <c-r>=expand(@")<cr> 

" following mappings to traverse the stack up(right >) or down(left <)
nmap <Leader>, :call <SID>GoLeft()<cr>
nmap <Leader>. :call <SID>GoRight()<cr>

" following mappings to list files in the same directory as the file in window 
" and to list the buffers.
nmap <Leader>ls :LS<cr>
nmap <Leader>lb :LB<cr>

nmap <Leader>z :DF<cr>

nmap <Leader>b :MK<cr><C-l>

nmap <Leader>v :call <SID>spFile("vsp")<CR>
nmap <Leader>h :call <SID>spFile("sp")<CR>

" following mappings to get UNIX man pages for word under cursor or word typed
nmap <Leader>m  :MAN 0 
nmap <Leader>m2 :MAN 2 
nmap <Leader>m3 :MAN 3 
nmap <Leader>m4 :MAN 4 
nmap <Leader>m5 :MAN 5 
nmap <Leader>m6 :MAN 6 
nmap <Leader>m7 :MAN 7 
nmap <Leader>m8 :MAN 8 

nmap <Leader><Leader>m  :MAN 0 <c-r>=expand("<cword>")<cr><cr><C-l>
nmap <Leader><Leader>m2 :MAN 2 <c-r>=expand("<cword>")<cr><cr><C-l>
nmap <Leader><Leader>m3 :MAN 3 <c-r>=expand("<cword>")<cr><cr><C-l>
nmap <Leader><Leader>m4 :MAN 4 <c-r>=expand("<cword>")<cr><cr><C-l>
nmap <Leader><Leader>m5 :MAN 5 <c-r>=expand("<cword>")<cr><cr><C-l>
nmap <Leader><Leader>m6 :MAN 6 <c-r>=expand("<cword>")<cr><cr><C-l>
nmap <Leader><Leader>m7 :MAN 7 <c-r>=expand("<cword>")<cr><cr><C-l>
nmap <Leader><Leader>m8 :MAN 8 <c-r>=expand("<cword>")<cr><cr><C-l>

" ------------------------------ Mappings End   --------------------------------
