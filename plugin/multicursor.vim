" Vim plugin to add MultiCursor support
" Maintainer: Daniel Thau (paradigm@bedrocklinux.org)
" Version: 0.2
" Description: Allows Vim to use multiple cursors simultaneously
" Last Change: 2012-12-11
" Location: plugin/multicursor.vim
" Website: https://github.com/paradigm/vim-multicursor
"
" See multicursor.txt for documentation.

" ------------------------------------------------------------------------------
" - prereq_checks                                                              -
" ------------------------------------------------------------------------------

" ensure plugin is only sourced once
if exists('g:multicursor_loaded')
	finish
endif
let g:multicursor_loaded = 1

" ensure has Vim 7.3, since prior versions did not have undotree()
if v:version < 703
	finish
endif

" ------------------------------------------------------------------------------
" - initialize_vars                                                            -
" ------------------------------------------------------------------------------

" initialize variables
let s:cursor_columns   = []
let s:cursor_lines     = []
let s:cursor_syntaxes  = []
let s:cursor_registers = []


" ------------------------------------------------------------------------------
" - public_functions                                                           -
" ------------------------------------------------------------------------------
" these are the functions the end-user is expected to call to use MultiCursor.
" if you are following the path of execution to understand the code, start at
" these.

" remove cursors
function! MultiCursorRemoveCursors()
	" remove syntax highlighting for virtual cursors
	if exists("s:cursor_syntaxes")
		for l:index in range(0,len(s:cursor_syntaxes)-1)
			call matchdelete(s:cursor_syntaxes[l:index])
		endfor
	endif

	" clear cursor variables
	let s:cursor_columns   = []
	let s:cursor_lines     = []
	let s:cursor_syntaxes  = []
	let s:cursor_registers = []

	redraw
	echo "MultiCursor: Cursors Removed"
endfunction

" manually place a cursor
function! MultiCursorPlaceCursor()
	" ensure the extra cursor syntax highlighting is enabled
	call s:EnsureSyntaxHighlighting()

	" set new cursor's position
	let s:cursor_lines = add(s:cursor_lines,line("."))
	let s:cursor_columns = add(s:cursor_columns,col("."))

	" set new cursor's syntax highlight
	let s:cursor_syntaxes = add(s:cursor_syntaxes, matchadd("MultiCursor", '\%'.line(".").'l\%'.col(".").'c.'))

	" set new cursor's registers
	let s:cursor_registers = add(s:cursor_registers,{})
	call s:SetRegisters(len(s:cursor_registers)-1)

	redraw
	echo "MultiCursor: Placed cursor at (".line(".").",".col(".").")"
endfunction

" begin using multicursor, utilizing manually placed cursors
function! MultiCursorManual()
	" ensure quit mapping has been set
	if !s:EnsureCanQuit()
		return -1
	endif

	" ensure at least one cursor has been placed
	if !exists("s:cursor_syntaxes") || len(s:cursor_syntaxes) == 0
		redraw
		echohl ErrorMsg
		echo "MultiCursor: No cursors appear to have been placed."
		echohl Normal
		return -1
	endif

	" prepare for the main loop
	return s:InitLoop()
endfunction

" begin using multicursor, utilizing cursors from visual mode range
function! MultiCursorVisual()
	" ensure quit mapping has been set
	if !s:EnsureCanQuit()
		return -1
	endif

	" clear any existing cursors
	call MultiCursorRemoveCursors()

	" gather cursors from visual range, one for every v:count1 lines
	for l:line in range(line("'<"),line("'>"),v:count1)
		" move cursor to the new location
		call cursor(l:line, col("'<"))
		" create cursor
		call MultiCursorPlaceCursor()
	endfor

	" prepare for the main loop
	call s:InitLoop()
endfunction

" begin using multicursor, utilizing cursors from search results
function! MultiCursorSearch(search_pattern)
	" ensure quit mapping has been set
	if !s:EnsureCanQuit()
		return -1
	endif

	" clear any existing cursors
	call MultiCursorRemoveCursors()

	" if no search pattern is given in the argument, prompt for one
	if a:search_pattern == ""
		redraw
		let l:search_pattern = input("/")
	else
		let l:search_pattern = a:search_pattern
	endif

	" ensure search pattern was given
	if l:search_pattern == ""
		redraw
		echohl ErrorMsg
		echo "MultiCursor: No search pattern given."
		echohl Normal
		return -1
	endif

	" store the initial cursor position so we can reset it if we don't end up
	" finding any matches
	let l:init_cursor_line = line(".")
	let l:init_cursor_column = col(".")

	" move cursor to top of buffer so the search covers everything
	call cursor(1,1)

	" search the buffer for the search pattern
	while search(l:search_pattern, 'W') > 0
		" found a match, create a cursor there
		call MultiCursorPlaceCursor()
	endwhile

	" ensure at least one match was found
	if len(s:cursor_syntaxes) < 1
		" restore cursor position
		call cursor(l:init_cursor_line,l:init_cursor_column)

		redraw
		echohl ErrorMsg
		echo "MultiCursor: No search results found."
		echohl Normal
		return -1
	endif

	" prepare for the main loop
	call s:InitLoop()
endfunction


" ------------------------------------------------------------------------------
" - private_functions                                                          -
" ------------------------------------------------------------------------------
" these functions aren't expected to be interfaced with directly by the end
" user; they're all scoped to the script.

" setup requirements for the main loop.
" every method the user uses to start multicursor will pass through here on
" the way to the main loop
function! s:InitLoop()
	" ensure the extra cursor syntax highlighting is enabled
	call s:EnsureSyntaxHighlighting()

	" will hold the mode
	let s:mode = ""
	" will hold the latest entered key (from getchar())
	let s:input = ""
	" will hold the in-progress command.  s:input will be appeneded to it
	" until it is complete, at which time it will be :normal'd and cleared.
	let s:total_input = ""
	" :normal is used both to execute the user's input as well as test if the
	" input needs to be executed.  If the test fails but the buffer changes
	" from the :normal, the changes need to be undone.  This tracks that
	" state.
	let s:undo = 0
	" this simple tracks whether s:undo was triggered in the previous loop.
	" it does not actually change anyting; only used for debugging output
	let s:undo_triggered = 0

	" setup <plug> maps.  these are appeneded to s:total_input when it is
	" :normal'd.  if s:mode changes, this indicates these mappings were
	" called, which indicates the :normal successfully ran the entire
	" s:total_input.
	nnoremap <plug> <esc>:<c-u>let s:mode = "n"<cr>
	inoremap <plug> <esc>:<c-u>let s:mode = "i"<cr>
	vnoremap <plug> <esc>:<c-u>let s:mode = "v"<cr>
	onoremap <plug> <esc>:<c-u>let s:mode = "o"<cr>

	" the "real" cursor position no longer matters - set it to the first
	" virtual cursor's position.
	call cursor(s:cursor_lines[0], s:cursor_columns[0])

	" everything is ready for the main loop.
	" begin taking input from the user and applying it to all of the cursors
	call s:MainLoop()
endfunction

" ensure user set g:multicursor_quit - don't run if the user can't cleanly
" exit.
function! s:EnsureCanQuit()
	" ensure g:multicursor_quit exists
	if  !exists("g:multicursor_quit") || g:multicursor_quit == ""
		" clear any existing cursors - don't want to leave a mess
		call MultiCursorRemoveCursors()
		redraw
		" notify user that quitting key needs to be set up

		echohl ErrorMsg
		echo "MultiCursor: No mapping set to quit; refusing to run.  See ':help g:multicursor_quit'"
		echohl Normal
		return 0
	endif
	return 1
endfunction

" if the MultiCursor syntax group either doesn't exist or is cleared, set it
" to a sane default.
function! s:EnsureSyntaxHighlighting()
	let l:need_highlight = 0
	if hlexists("MultiCursor")
		let l:highlight_status = ""
		redir => l:highlight_status
			silent highlight MultiCursor
		redir END
		if split(l:highlight_status)[2] == "cleared"
			let l:need_highlight = 1
		endif
	else
		let l:need_highlight = 1
	endif
	if l:need_highlight
		highlight MultiCursor guifg = bg
		highlight MultiCursor guibg = fg
		if &background == "light"
			highlight MultiCursor ctermfg = 231
			highlight MultiCursor ctermbg = 0
		else
			highlight MultiCursor ctermfg = 0
			highlight MultiCursor ctermbg = 231
		endif
	endif
endfunction

" move the syntax highlighting for a cursor to match the real cursor's
" position.  this is used to move the visual representation of the cursors
" around.
function! s:MoveCursor(index)
	" remove old syntax highlight
	call matchdelete(s:cursor_syntaxes[a:index])
	" add new syntax highlight
	let s:cursor_syntaxes[a:index] = matchadd("MultiCursor", '\%'.line('.').'l\%'.col('.').'c.')
endfunction

" store "real" registers into a variable so we can pull them back up for a
" given cursor
function! s:SetRegisters(index)
	for l:register in ['"', "0", "1", "2", "3", "4", "5", "6", "7", "8",
				\ "9","-", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l",
				\ "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"]
		execute "let s:cursor_registers[a:index]['".l:register."'] = @".l:register
	endfor
endfunction

" get the cursors stored in this cursor's register dictionary and change each
" "real" register accordingly
function! s:GetRegisters(index)
	for l:register in ['"', "0", "1", "2", "3", "4", "5", "6", "7", "8",
				\ "9","-", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l",
				\ "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"]
		execute "let @".l:register." = s:cursor_registers[a:index]['".l:register."']"
	endfor
endfunction

" output the in-progress command for the user.  this helps significantly with
" non-normal mode commands which are not updated in the buffer until
" completed.  additionally, if debug is set, output debug info
function! s:Output()
	" move cursor to first cursor's position to move window to first cursor's
	" position
	call cursor(s:cursor_lines[0], s:cursor_columns[0])
	redraw
	if s:multicursor_debug
		" show debug output
		echo 'I:"'.s:total_input.'" M:"'.s:mode.'" U:"'.s:undo.'v'.undotree()['seq_cur'].','.s:undo_triggered.'"'
		let s:undo_triggered = 0
	else
		" show mode and partial command
		if s:total_input == ""
			echo "  MC (type a command)\r"
		elseif s:mode == "i"
			echo "  MC (partial insert) '".s:total_input."'\r"
		elseif s:mode == "v"
			echo "  MC (partial visual) '".s:total_input."'\r"
		elseif s:mode == "o"
			echo "  MC (partial opertr) '".s:total_input."'\r"
		else
			echo "  MC (partial normal) '".s:total_input.."'\r"
		endif
	endif
endfunction

" get s:input from user and append it to s:total_input
function! s:Input()
	let s:input = getchar()
	if type(s:input) == 0
		let s:input = nr2char(s:input)
	endif
	let s:total_input .= s:input
endfunction

" we need to figure out of the pending command from s:total_input
" is a complete command which can be run for every cursor.  vim
" does not have a good way to do this out-of-the-box.  the plan is
" thus:
" by utilizing the <plug> mappings, we can tell if :normal succeeds in running
" the given command.  if so, we can use them.  however, this method alone
" returns false positives, such as when it can run just a prefix count or a
" prefix register.  use l:run_command below to rule out such false positives
" before we try to detect success from :normal
function! s:CheckCommand()
	let l:run_command = 1

	" don't try to run with just a prefix count
	if s:total_input =~ '^\d*$' && s:total_input != '0'
		let l:run_command = 0
	endif

	" don't try to run with just a prefixed register
	if s:total_input[0] == '"' && strlen(s:total_input) < 3
		let l:run_command = 0
	endif

	" don't run something in insert mode until it is completed
	" check for single-char commands to enter insert mode
	let l:input_chars = substitute(s:total_input,"^[0-9]*","","")[0]
	for l:chars in ["A","a","I","i","O","o","C","c","S","s","R"]
		if l:input_chars ==# l:chars && s:input != "\<esc>"
			let l:run_command = 0
			let s:mode = "i"
		endif
	endfor
	" check for double-char commands to enter insert mode
	let l:input_chars = substitute(s:total_input,"^[0-9]*","","")[0:1]
	for l:chars in ["cc","gR","gI","gi"]
		if l:input_chars ==# l:chars && s:input != "\<esc>"
			let l:run_command = 0
			let s:mode = "i"
		endif
	endfor

	" don't run something in the cmdline until it is completed
	if s:total_input[0] == ':' && s:input != "\<cr>"
		let l:run_command = 0
	endif


	return l:run_command
endfunction

function! s:RunCommand()
	" the command will be run with the first cursor - move the real cursor to
	" the proper position
	call cursor(s:cursor_lines[0], s:cursor_columns[0])
	" save certain values just before running to compare to post-run situation
	
	" the command could add or remove lines from the buffer.  the cursors will
	" have to move accordingly.  save where the cursors are before the move to
	" reference.
	let s:pre_cursor_lines = s:cursor_lines
	" save the number of lines in the buffer before the command is run to
	" later find the number of lines the command added or removed
	let l:pre_line_count = line("$")
	" store the current position in the undo tree
	let l:pre_undo = undotree()['seq_cur']

	" each cursor gets its own set of the registers.  pull up the real/first
	" cursor's registers
	call s:GetRegisters(0)

	" run the command.  explicitly set the register to be used to the unnamed
	" register.  if the user input a register prefix, that will take
	" precidence.
	execute 'silent! normal ""'.s:total_input."\<plug>"

	" save this cursor's registers, which might have changed in the above
	" command
	call s:SetRegisters(0)

	" compare the pre_ variables to the current state
	
	" store the line count change due to this command
	let s:line_delta = line("$") - l:pre_line_count

	" store whether the undo state has changed
	if l:pre_undo == undotree()['seq_cur']
		let s:undo = 0
	else
		let s:undo = 1
	endif
endfunction

" most commands should be run by each cursor.  some, however, should only be
" run once in total irrelevant of the number of cursors.  an obvious example
" is undo.  for these commands, just reset the cursor positions and clean
" input
function! s:HandleUniqueCmds()
	" restore cursor positions in case undo moved stuff around
	for l:index in range(0,len(s:cursor_syntaxes)-1)
		call cursor(s:cursor_lines[l:index], s:cursor_columns[l:index])
		call s:MoveCursor(l:index)
	endfor

	" clean input
	let s:total_input = ""
endfunction

" a command was successfully run in one cursor and we're in normal mode
" run the command with the rest of the cursors
function! s:HandleNormalCmds()
	" "real"/first cursor moved while executing commands.  Store that.
	let s:cursor_lines[0] = line(".")
	let s:cursor_columns[0] = col(".")

	" loop over all of the cursors
	for l:index in range(0,len(s:cursor_syntaxes)-1)
		" move cursor to reflect created/deleted lines in buffer above cursor
		for l:line in s:pre_cursor_lines
			if l:line < s:cursor_lines[l:index]
				let s:cursor_lines[l:index] += s:line_delta
			endif
		endfor
		" move "real" cursor to current cursor's new location
		call cursor(s:cursor_lines[l:index], s:cursor_columns[l:index])

		" the first cursor already ran the command; only run this for the other
		" cursors.
		if l:index != 0
			" restore this cursor's register
			call s:GetRegisters(l:index)

			" execute command for this cursor
			execute "silent! normal ".'""'.s:total_input

			" store new register
			call s:SetRegisters(l:index)
		endif
		
		" store new location
		let s:cursor_lines[l:index] = line(".")
		let s:cursor_columns[l:index] = col(".")

		" move syntax highlighting
		call s:MoveCursor(l:index)
	endfor

	" clean input
	let s:total_input = ""
endfunction

" get input from user
" test if it is something which can be run
" if so, run it
" if not, clean up any mess the test might have made
" repeat
function! s:MainLoop()
	if exists("g:multicursor_debug") && g:multicursor_debug
		let s:multicursor_debug = 1
	else
		let s:multicursor_debug = 0
	endif
	" if debug is off, use try/catch to make sure we clean up on exit, in case
	" user ctrl-c's or there is an error.  the conditional ternary operator is
	" used instead of the more common :if because vim will get confused if it
	" sees an :endif before an :if after a :try.  see ":help expr1" to learn
	" more about this syntax.
	execute s:multicursor_debug ? "" : "try"
	
	while 1
		" output situation to user
		call s:Output()

		" get input from user
		call s:Input()

		" check if user requested to quit; if so, do so.
		if g:multicursor_quit ==# s:input && s:mode == "n"
			call MultiCursorRemoveCursors()
			redraw
			echo "MultiCursor: g:multicursor_quit was called, quitting"
			return 0
		endif

		" reset s:mode to blank
		let s:mode = ""

		" check if we have a complete command to try to run. if we do, run the
		" command and deal with output.  if not, loop back around for more
		" input until we do.
		if s:CheckCommand()
			" run command
			call s:RunCommand()

			" handle result
			if s:mode == "n" && (
						\s:total_input ==? "u"
						\|| s:total_input ==# "\<c-r>"
						\|| s:total_input ==# "g-"
						\|| s:total_input ==# "g+"
						\)
				" some commands should only be run once total; handle these
				" specially
				call s:HandleUniqueCmds()
			elseif s:mode == "n"
				" a command was successfully run in one cursor.  apply this
				" command to the rest of the cursors
				call s:HandleNormalCmds()
			elseif s:undo
				" if a command changed the buffer (as noted by a change in the
				" undo tree) but did *not* register as a successfully
				" completed command, undo the change
				normal !u
				let s:undo_triggered = 1
			endif
		endif
	endwhile
	catch
	endtry
	call MultiCursorRemoveCursors()
	redraw
	echo "MultiCursor: either user hit ctrl-c or error occured.  See ':help multicursor-debug'"
	return 0
endfunction
