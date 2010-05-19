h2. vImputManager - Let's open files the easy way


h3. Abstract

The vImputManager is a small helper application written in RubyCocoa 
to let MacVim (or any other Vim-Implementation on the Mac) display a 
list of files and let the user select one to open it in the editor. 
It is inspired by the "Go to File..." functionality from TextMate.


h3. How to configure VIM

Put the following little script into your .vimrc file (your VIM must
be compiled to support ruby scripts), then open a file within your 
project in VIM. Now when pressing [CTRL-T] a new window will appear
displaying a list of files in your current project. Just select a 
file, then press [RETURN] or doubleclick the filename to open it in 
the current VIM window.

    map <C-t> :call BrowseFiles()<CR>
    function! BrowseFiles()
    ruby << EOF
    	path=File.dirname($curbuf.name)
      PATH_TMP_FILE='/tmp/open_file_in_vim_path'
      File.open(PATH_TMP_FILE,'w') { |fh| fh.puts path }
      `open /path/to/the/OpenFileInVIM.app`
    EOF
    endfunction

