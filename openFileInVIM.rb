require 'find'
require 'osx/cocoa'
include OSX

# the full path of the executable used to open the 
# selected file in a vim instance.
MAC_VIM_EXECUTABLE='/Users/schluete/Applications/MacVim.app/Contents/MacOS/Vim'

# the file to which the starter script writes the directory
# path to start the directory listing in
PATH_TMP_FILE='/tmp/open_file_in_vim_path'


class MyTableView < NSTableView
  # called if the user pressed a key while the table
  # view holds the keyboard focus. If a [return] was 
  # pressed we're going to open the current selected 
  # file, otherwise the tableview itself should take
  # care of the input.
  def keyDown(event)
    case event.keyCode
    when 36                   # [return]
      self.delegate.on_entry_activation(self)
    when 53                   # [escape]
      NSApp.stop(self)
    else
      super_keyDown(event)
    end
  end
end

class FilesDataSource < NSObject
  ib_outlet :table

  # Initialize and register everything
  def awakeFromNib
    @table.setTarget(self)
    @table.setDoubleAction('on_entry_activation:')
    @table.setDelegate(self)
    create_list_of_files
    filter_files(nil)
  end

  # NSTableView data source: returns the number of rows in the table
  def numberOfRowsInTableView(tableView)
    @filtered_files ? @filtered_files.size : 0
  end

  # NSTableView data source: returns the content of the table cell
  def tableView_objectValueForTableColumn_row(tableView,tableColumn,row)
    path_len=@path.length+1
    case tableColumn.identifier.to_s
    when 'filename'
      File.basename(@filtered_files[row])
    when 'path'
      @filtered_files[row][path_len .. -1]
    end
  end

  # NSTableView delegate: a key was pressed in the tableview
  def control_textView_doCommandBySelector(control,textView,commandSelector)
    case commandSelector.to_s
    when 'cancelOperation:'
      NSApp.stop(self)
    when 'moveDown:'
      @table.window.makeFirstResponder(@table)
      if @table.selectedRow==-1
        @table.selectRow_byExtendingSelection(0,false)
      end
      true
    when 'insertNewline:'
      @filtered_files.size==1 ? open_file_in_editor(0) : false
    else
      false
    end
  end

  # called if an entry was either doubleclicked or selected
  # by pressing [return] on the keyboard.
  def on_entry_activation(sender)
    idx=@table.selectedRow
    open_file_in_editor(idx)
  end

  # run the vim with the given filename
  def open_file_in_editor(index)
    # get the selected filename
    filename=@filtered_files[index]

    # launch the vim executable
    task=NSTask.new
    task.setLaunchPath(MAC_VIM_EXECUTABLE)
    task.setArguments(['-g','--remote-tab-silent',filename])
    task.launch

    # that's it for ourself, let's go home.
    NSApp.stop(self)
    true
  end

  # traverse the directory up until a Rakefile was found, then
  # return this path
  def find_rakefile
    # zuerst lesen wir den Startpfad aus der Datei ein
    unless File.exists?(PATH_TMP_FILE) and (base_path=IO.read(PATH_TMP_FILE).strip)
      NSRunInformationalAlertPanel('Invalid start directory!',
        "No directory information could be found in the configuration file '#{PATH_TMP_FILE}'!",
        'OK',nil,nil)
      NSApp.stop(self)
    end

    # jetzt gehen wir max. 5 Ebenen nach oben und suchen
    # nach einem Rakefile im Verzeichnis
    path=base_path
    (0..5).each do |step|
      Dir.entries(path).each do |entry|
        return path if entry=~/Rakefile/
      end
      path+="/.."
    end

    # no reasonable rakefile was found, let's just use
    # the current directory for the files
    base_path # Dir.pwd
  end

  # search the directory tree for all files we could possibly
  # want to edit
  def create_list_of_files
    @path=find_rakefile
    @table.window.setTitle(@path)
    @files=[]
    Find.find(@path) do |file|
      # we don't want any files from a repository in the list 
      next if file=~/(\.hg|\.svn|\.git)/ 

      # neither do we want dotfiles in the list
      next if File.basename(file)=~/^\./ 
      
      # file matches, add it to the resulting list
      @files << file if FileTest.file?(file)
    end
    @files.sort_by { |match| File.basename(match) }
  end

  # filter the list of files by the given pattern
  def filter_files(pattern)
    regexp=Regexp.new(pattern || '.*')
    @filtered_files=@files.inject([]) do |matches,file| 
      matches << file if file=~regexp
      matches
    end
    @table.reloadData
  end

  # called if the user changed the search pattern
  def update(sender)
    pattern=Regexp.new(sender.stringValue)
    filter_files(pattern)
  end
end

# the main application controller class
class AppController < NSObject
  ib_outlets :main_window
  ib_outlets :searchfield
  ib_outlets :data_source

  def awakeFromNib
    @main_window.center
    @searchfield.setDelegate(@data_source)
  end

  ib_action :windowShouldClose do |sender|
    NSApp.stop(self)
    true
  end
end

# called to load all application ruby scripts
def rb_main_init
  path=OSX::NSBundle.mainBundle.resourcePath.fileSystemRepresentation
  rbfiles=Dir.entries(path).select { |x| /\.rb\z/=~x }
  rbfiles-=[File.basename(__FILE__)]
  rbfiles.each do |path|
    require(File.basename(path))
  end
end

# program entry point
if $0==__FILE__ then
  rb_main_init
  NSApplicationMain(0,nil)
end
