MultiCursor
===========

MultiCursor USER MANUAL - by Daniel Thau

If you'd like to skip the whole "reading" nonsense and watch a nice, wholesome
video which explains MultiCursor instead, see
[here](http://www.youtube.com/watch?v=Umb59mMvCxA).

Description
-----------

This plugin will allow Vim to utilize multiple cursors simultaneously.  This
can be used to do things such as refactor many lines at the same time.

Setup
-----

MultiCursor currently requires Vim 7.3 for undotree().

MultiCursor can be installed like most other Vim plugins.  On a Unixy system
without a plugin manager, the multicursor.vim file should be located at:

    ~/.vim/plugin/multicursor.vim

On a Unixy system with pathogen, the multicursor.vim file should be located at:

    ~/.vim/bundle/multicursor/plugin/multicursor.vim

On a Windows system without a plugin manager, the multicursor.vim file should be located at:

    %USERPROFILE%\vimfiles\plugin\multicursor.vim

On a Windows system with pathogen, the multicursor.vim file should be located at:

    %USERPROFILE%\vimfiles\bundle\multicursor\plugin\multicursor.vim

If you are using a plugin manager other than pathogen, see its documentation
for how to install MultiCursor - it should be comparable to other plugins.

If you would like the documentation to also be installed, include multicursor.txt
into the relevant directory described above, replacing "plugin" with "doc".

There are a few ways to access MultiCursor's functionality, none of which have
mappings out of the box; you will have to create your own mappings.

If you would like to manually place cursors by moving your cursor above each
location and pressing a keybinding, set the keybinding like so, setting {keys}
as desired:

    nnoremap {keys} :<c-u>call MultiCursorPlaceCursor()<cr>

To actually utilize these manually placed cursors you will need to call another
mapping:

    nnoremap {keys} :<c-u>call MultiCursorManual()<cr>

If you would like to cancel manually placed cursors without utilizing them:

    nnoremap {keys} :<c-u>call MultiCursorRemoveCursors()<cr>

You can also create cursors from visual mode:

    xnoremap {keys} :<c-u>call MultiCursorVisual()<cr>

This will create one cursor per visually selected line.  Moreover, with this
mapping, you can prepend {keys} with a number.  This number will tell
MultiCursor to only create one cursor per that many lines.  For example,
running 2{keys} will create a cursor on every other line of the visually
selected area.

Finally, you can create cursors by searching the buffer via regular
expressions.  To have MultiCursor prompt you for the search pattern:

    nnoremap {keys} :<c-u>call MultiCursorSearch('')<cr>

If the argument to the function in the above mapping is a non-empty string,
that will be the pattern which will be searched for.  This can be utilized to
do things such as create a cursor at every word like the word under the cursor:

    nnoremap {keys} :<c-u>call MultiCursorSearch('<c-r><c-w>')<cr>

Or every group of characters like those visually selected:

    xnoremap {keys} "*y<Esc>:call MultiCursorSearch('<c-r>=substitute(escape(@*, '\/.*$^~[]'), "\n", '\\n', "g")<cr>')<cr>

Some of the above magic was borrowed from the [SearchParty
plugin](https://github.com/dahu/SearchParty).

Finally, you should set a keybinding to stop using multiple cursors (and fall
back to the normal single cursor) like so:

    let g:multicursor_quit = "{keys}"

This will quit multicursor from normal mode (ie, if pressed in another mode
such as insert or visual it will act as though there is no special mapping).
This functions somewhat like `mapleader`, except that it is limited to what can
be provided by a single `getchar()` (after it has been run through
`nr2char()`).  If `g:multicursor_quit` does not seem to work, you can fall back
to `ctrl-c`.

In addition to creating mappings, you can override the color scheme used by
MultiCursor for the cursors by setting the "MultiCursor" highlight group.  See
`:highlight`.

Usage
-----

To utilize multiple cursors, you must first create the extra cursors.  There
are several methods to do so.  The setup method for each is described above in
`multicursor-setup`.  They are summarized here as well.

- You can move the (normal, singular) cursor over each location at which you
  would like to create a cursor, then press a mapping to create a cursor at
  that location.  You can then either cancel about-to-be-created cursors with
  another mapping, or begin utilizing all of the cursors you've created with
  yet another mapping.
- You can visually select an area and run a mapping to create a cursor on every
  line of the visually selected area (in the left-most column).  Moreover, you
  can prefix the mapping with a `count` to tell MultiCursor to only create one
  cursor for however many lines.
- You can create a cursor at every position which matches a regular expression
  search.  Mappings can be made to expand on this; for example, mappings can be
  made to search for the word under the cursor or the characters in the
  visually selected area.


Once the cursors are created and being used, most commands entered into Vim
will be applied at each of the cursor positions.  For example, "diw" will
delete the word under each of the cursors.  You can stop using multiple cursors
by typing `g:multicursor_quit` or, if that is not working, fall back to
`ctrl-c`.

Known Issues
------------

- Insert mode works; however, the output is not updated in the buffer until it
  has been completed (ie, the mode as returned to normal mode.)  Do note that
  the pending command is shown at the bottom to allow you to see what you are
  typing.  Interactive UI, such as popup menus for `ins-completion` will not
  work.

- Visual mode mostly works; however, like insert mode, the result is not
  updated in the buffer until it has been completed.  Again, like insert mode,
  you can see the pending command at the bottom to help create the in-progress
  command.

- The cmdline works, but like insert and visual mode it has limitations; you
  won't get to see things like the wildmenu.  Additionally, output from
  commands such as `:ls` don't work.  Note that cmdline commands are run for
  every cursor.  This is not necessarily an "issue", as it is useful if one
  wants to run a :substitute at every cursor, but it is potentially confusing
  at first.

- Multi-key normal-mode maps do not work.  Insert-mode and visual-mode maps do
  work, although their end may not be recognized and they may not trigger
  instantly; see item below.

- In some situations, particularly with either visual mode and
  mappings/plugins, MultiCursor does not detect that a command has finished.
  To resolve this, simply continue entering other commands - either useful
  commands, or just empty escapes - until MultiCursor figures it out.

- Most things which should be stored per-cursor, such as the jump list, are
  not.  The exception is registers; each cursor gets its own set of all of the
  registers.  Undo should work as expected - the changes by all of the cursors
  are grouped into one undo block.

- Cursors can be be moved on top of each other.  It could be nice if
  MultiCursor detected this situation and rejected the command to avoid such
  situations, as having stacked cursors is almost never useful but often
  troublesome.

- MultiCursor will move around cursors to reflect the change in the buffer due
  to other cursors.  For example, if the top-most cursor deletes the first
  line, all cursors below that line should be moved up by one line - this
  works.  However, it assumes that all cursors will change the same number of
  lines, which is not also true.  Also, it only works on lines; if there are
  multiple cursors in the same line which change characters within that line,
  the other cursors on the same line will not move horizontally as expected.

- The Vim window does not redraw on events such as resizing until a key is
  entered.

- Cursors on areas without characters (such as blank lines) aren't visible.

Debug
-----

If you would like to hack at MultiCursor, the debug mode can be turned on by
placing the following in your vimrc, or running it in the cmdline in a running
Vim before calling MultiCursor mappings:

    let g:multicursor_debug = 1

Enabling debug results in two things.  First, in the bottom line you will see
something along the lines of the following:

    I:"" M:"n" U:"0v0,0"

The quoted area after "I:" indicates the In-progress command; this is what
MultiCursor normally outputs at the bottom without debug.  This will be blank
if the last key you've entered into Vim was acted upon.

The quoted area after "M:" indicates the current Mode you are in.  If it is
empty, this means your current in-progress command cannot be executed as it is
for some reason.  This could indicate operator-pending mode, but not always -
it also comes up for custom mappings/plugins that aren't technically
operator-pending mode.

The quoted section after "U:" is used for debugging undo history and contains
three fields.  The first indicates the undo level just prior to running the
previous command.  The second indicates the current undo level.  If you have
just run a command which should not create an undo point, these should should
be identical.  The third field indicates whether MultiCursor forced an undo for
the last keystroke.  This should occur when both conditions are true:

- An uncompleted command, such as a command that left Vim in operator-pending
  mode, is the current in-progress command.

- The uncompleted command changed the buffer (ie, created an undo point).

The second result of enabling debug is that the try/catch block is disabled.
The try/catch block is typically used to ensure that if the user attempts to
stop MultiCursor with `ctrl-c`, MultiCursor will also clean up.  However, the
try/catch block will also hide errors - if an error occurs (without debug),
MultiCursor will still remove the cursors and exit cleanly.  The down side to
this is that it makes debugging difficult, as errors are hidden.  Hence, with
debugging on, the try/catch block is disabled.

Changelog
---------

0.2 (2012-12-11):
 - various bugfixes

0.1 (2012-12-11):
 - initial release
