require File.join(File.dirname(File.expand_path(__FILE__)), "/../spec_helper.rb")

describe AutomateIt::ShellManager, :shared => true do
  before(:all) do
    @a = AutomateIt.new(:verbosity => Logger::WARN)
    @m = @a.shell_manager
  end

  before(:each) do
    @a.preview = false
  end
end

describe AutomateIt::ShellManager, " with sh and which" do
  it_should_behave_like "AutomateIt::ShellManager"

  begin
    if INTERPRETER.tagged?(:windows)
      it "should run shell commands and detect their exit status (sh)" do
        @m.sh("dir > nul").should be_true
      end
    else
      INTERPRETER.which!("true")
      INTERPRETER.which!("false")

      it "should run shell commands and detect their exit status (sh)" do
        @m.sh("true").should be_true
        @m.sh("false").should be_false
      end
      
      it "should run shell commands raise an error in case of failure" do
        lambda{ @m.sys("false") }.should raise_error(ArgumentError)
        lambda{ @m.sys("true") }.should  !raise_error(ArgumentError)
      end
      
    end
  rescue NotImplementedError
    puts "NOTE: Can't check 'sh' on this platform, #{__FILE__}"
  end

  unless INTERPRETER.shell_manager.available?(:which)
    puts "NOTE: Can't use 'which' on this platform in #{__FILE__}"
  else
    it "should find which program is in the path (which)" do
      cmd = "ruby"
      @m.which(cmd).match(/#{cmd}/).nil?.should be_false
    end

    it "should not find programs that aren't in the path (which)" do
      @m.which("not_a_real_program").should be_nil
    end

    it "should throw exception if command isn't in path (which!)" do
      lambda{ @m.which!("not_a_real_program") }.should raise_error(ArgumentError, /not_a_real_program/)
    end
  end
end

describe AutomateIt::ShellManager, " in general" do
  it_should_behave_like "AutomateIt::ShellManager"

  it "should backup a file (backup)" do
    @m.mktempdircd do
      source = "myfile"
      @m.touch(source)

      target = @m.backup(source)

      target.should_not be_nil
      target.should_not == source
      File.exists?(target).should be_true
    end
  end

  it "should backup a directory with files (backup)" do
    @m.mktempdircd do
      dir = "mydir"
      file = File.join(dir, "myfile")
      @m.mkdir(dir)
      @m.touch(file)

      target_dir = @m.backup(dir)

      target_dir.should_not be_nil
      target_dir.should_not == dir
      File.exists?(target_dir).should be_true
      File.directory?(target_dir).should be_true

      target_file = File.join(target_dir, File.basename(file))
      File.exists?(target_file).should be_true
      File.directory?(target_file).should be_false
    end
  end

  it "should backup multiple files and directories (backup)" do
    @m.mktempdircd do
      @m.mkdir_p("foo/bar/baz")
      @m.touch("foo/bar/baz/feh")
      @m.mkdir_p("foo/bar/qux")
      @m.touch("foo/bar/qux/meh")
      @m.mkdir_p("qux/foo/bar")
      @m.touch("qux/foo/bar/bah")

      results = @m.backup("foo", "qux")
      results.should_not be_blank

      results[0].should =~ %r{#{File::SEPARATOR}foo\..+\.bak$}
      File.exists?(results[0]+"/bar/baz/feh")
      File.exists?(results[0]+"/bar/baz/meh")

      results[1].should =~ %r{#{File::SEPARATOR}qux\..+\.bak$}
      File.exists?(results[1]+"/foo/bar/bah")
    end
  end

  it "should change directories (cd)" do
    before = Dir.pwd
    target = Pathname.new("/").expand_path.to_s
    @m.cd(target)
    Dir.pwd.should == target
    @m.cd(before)
    Dir.pwd.should == before
  end

  it "should change directories using a block (cd)" do
    before = Dir.pwd
    target = Pathname.new("/").expand_path.to_s
    @m.cd(target) do
      Dir.pwd.should == target
    end
    Dir.pwd.should == before
  end

  it "should change back to a directory when there's an error (cd)" do
    before = Dir.pwd
    target = Pathname.new("/").expand_path.to_s
    lambda {
      @m.cd(target) do
        raise "42"
      end
    }.should raise_error("42")
    Dir.pwd.should == before
  end

  it "should fail to change to a non-existend directory (cd)" do
    lambda{ @m.cd("qweljkrusfauweqr") }.should raise_error(Errno::ENOENT)
  end

  it "should not fail to change to a non-existent directory in preview mode (cd)" do
    @m.preview = true
    @m.cd("qweljkrusfauweqr").should_not be_nil
  end

  it "should return if there's an error when pretending to cd into a non-existent directory in preview mode (cd)" do
    @m.preview = true
    before = Dir.pwd
    lambda {
      @m.cd("qweljkrusfauweqr") do
        Dir.pwd.should == before
        raise "42"
      end
    }.should raise_error("42")
    Dir.pwd.should == before
  end

  it "should locate the current directory (pwd)" do
    @m.pwd.should == Dir.pwd
  end

  it "should create a directory when needed (mkdir)" do
    @m.mktempdircd do
      target = "foo"
      File.directory?(target).should be_false

      @m.mkdir(target).should == [target]
      File.directory?(target).should be_true

      @m.mkdir(target).should be_false
    end
  end

  it "should create a directory and cd into it (mkdir)" do
    @m.mktempdircd do
      target = "foo"
      @m.mkdir(target) do |path|
        path.should == target
        File.basename(Dir.pwd).should == target
      end
    end
  end

  it "should fail to cd into multiple created directories (mkdir)" do
    @m.mktempdircd do
      lambda {
        @m.mkdir(%w(foo bar baz)) do |path|
          violated
        end
      }.should raise_error(ArgumentError)
    end
  end

  it "should create nested directories when needed (mkdir_p)" do
    @m.mktempdircd do
      target = "foo/bar/baz"
      File.directory?(target).should be_false

      @m.mkdir_p(target).should == [target]
      File.directory?(target).should be_true

      @m.mkdir_p(target).should be_false
    end
  end

  it "should remove directory when needed (rmdir)" do
    @m.mktempdircd do
      target = "foo"
      @m.mkdir(target).should == [target]

      @m.rmdir(target).should == [target]
      File.directory?(target).should be_false
    end
  end

  it "should create a temporary file (mktemp)" do
    @m.mktempdir do
      item = nil
      @m.mktemp do |path|
        item = path
        File.exists?(item).should be_true
      end
      File.exists?(item).should be_false
    end
  end

  #it "should create a temporary directory (mktempdir)"
  #it "should create a temporary directory and cd into it (mktempdircd)"

  it "should install a file to a file (install)" do
    @m.mktempdircd do
      source = "foo"
      target = "bar"
      mode1 = 0640 if @m.provides_mode?
      mode2 = 0100640

      @a.render(:text => "Hello", :to => source)
      File.exists?(source).should be_true
      File.exists?(target).should be_false

      @a.install(source, target, mode1).should == source
      File.exists?(target).should be_true
      File.stat(target).mode.should == mode2 if @m.provides_mode?

      @a.install(source, target, mode1).should be_false
    end
  end

  it "should copy a file to file (cp)" do
    @m.mktempdircd do
      source = "foo"
      target = "bar"

      @a.render(:text => "Hello", :to => source)
      File.exists?(source).should be_true
      File.exists?(target).should be_false

      @a.cp(source, target).should == source
      File.exists?(target).should be_true

      @a.cp(source, target).should be_false
    end
  end

  it "should copy a file to a directory (cp)" do
    @m.mktempdircd do
      source = "foo"
      target = "bar"

      @a.render(:text => "Hello", :to => source)
      @a.mkdir(target)
      File.exists?(source).should be_true
      File.exists?(target).should be_true

      @a.cp(source, target).should == source
      File.exists?("bar/foo").should be_true

      @a.cp(source, target).should be_false
    end
  end

  it "should copy files to a directory (cp)" do
    @m.mktempdircd do
      source1 = "foo"
      source2 = "bar"
      target = "baz"

      @a.render(:text => "Hello", :to => source1)
      @a.render(:text => "Hello", :to => source2)
      @a.mkdir(target)

      @a.cp([source1, source2], target).should == [source1, source2]
      File.exists?("baz/foo").should be_true
      File.exists?("baz/bar").should be_true

      @a.cp([source1, source2], target).should be_false
    end
  end

  it "should copy directory to a directory (cp)" do
    @m.mktempdircd do
      source_dir = "feh"
      source_file1 = "feh/file1"
      source_file2 = "feh/file2"
      target_dir = "meh"

      @a.mkdir(source_dir)
      @a.render(:text => "Hello", :to => source_file1)
      @a.render(:text => "Hello", :to => source_file2)
      @a.mkdir(target_dir)

      @a.cp_R(source_dir, target_dir).should == source_dir
      File.exists?("meh/feh/file1").should be_true
      File.exists?("meh/feh/file2").should be_true

      @a.cp(source_dir, target_dir).should be_false
    end
  end

  it "should copy files whose contents changed (cp)" do
    @m.mktempdircd do
      source = "file1"
      target = "file2"

      @a.render(:text => "Hello", :to => source)
      @a.render(:text => "olleH", :to => target)

      source_atime = File.atime(source)
      source_mtime = File.mtime(source)
      File.utime(source_atime, source_mtime, target)

      @a.cp(source, target).should == source
    end
  end

  it "should move files (mv)" do
    @m.mktempdircd do
      file1 = "foo"
      file2 = "bar"
      @m.touch(file1)
      File.exists?(file1).should be_true

      @m.mv(file1, file2).should == file1
      File.exists?(file1).should be_false
      File.exists?(file2).should be_true

      @m.mv(file1, file2).should be_false
    end
  end

  it "should move invalid symlinks (mv)" do
    @m.mktempdircd do
      file1 = "foo"
      file2 = "bar"
      @m.ln_s(file1, file2)

      @m.mv(file2, file1) == file2
      File.exists?(file1).should be_false
      File.symlink?(file1).should be_true
    end
  end

  it "should delete files (rm)" do
    @m.mktempdircd do
      file1 = "foo"
      file2 = "bar"
      @m.touch(file1)
      @m.touch(file2)
      File.exists?(file1).should be_true
      File.exists?(file2).should be_true

      @m.rm([file1, file2]) == [file1, file2]
      File.exists?(file1).should be_false
      File.exists?(file2).should be_false
    end
  end

  it "should delete invalid symlinks (rm)" do
    @m.mktempdircd do
      file1 = "foo"
      file2 = "bar"
      @m.ln_s(file1, file2)

      @m.rm(file2) == file1
      File.exists?(file2).should be_false
      File.symlink?(file2).should be_false
    end
  end

  it "should delete recursively (rm_r)" do
    @m.mktempdircd do
      dir = "foo/bar"
      file = dir+"/baz"
      @m.mkdir_p(dir)
      @m.touch(file)
      File.exists?(file).should be_true
      File.exists?(dir).should be_true

      @m.rm_r(dir) == [dir, file]
      File.exists?(file).should be_false
      File.exists?(dir).should be_false
    end
  end

  it "should delete forcefully (rm_f)" do
    @m.mktempdircd do
      target = "file1"

      @m.touch(target)
      @m.chmod(0000, target)

      @m.rm(target, :force => true).should == [target]

      File.exists?(target).should be_false
    end
  end

  it "should delete recursively and forcefully (rm_rf)" do
    @m.mktempdircd do
      dir = "foo/bar"
      file = dir+"/baz"
      @m.mkdir_p(dir)
      @m.touch(file)
      File.exists?(file).should be_true
      File.exists?(dir).should be_true

      @m.rm_rf(dir) == [file, dir]
      File.exists?(file).should be_false
      File.exists?(dir).should be_false
    end
  end
end

describe AutomateIt::ShellManager, " when touching files" do
  it_should_behave_like "AutomateIt::ShellManager"

  it "should create files and change their timestamps (touch)" do
    @m.mktempdircd do
      target = "foo"
      File.exists?(target).should be_false

      @m.touch(target)
      File.exists?(target).should be_true
      before = File.mtime(target)

      @m.touch(target)
      after = File.mtime(target)
      before.should <= after
    end
  end

  it "should touch files with a specific timestamp (touch)" do
    @m.mktempdircd do
      target = "foo"
      stamp = Time.now - 60
      stamp.should_not == Time.now

      @m.touch(target, :stamp => stamp).should == target
      stat = File.stat(target)
      stamp.to_i.should == stat.mtime.to_i

      @m.touch(target, :stamp => stamp).should be_false
    end
  end

  it "should touch files with a timestamp like other files (touch)" do
    @m.mktempdircd do
      source = "foo"
      target = "bar"
      stamp = Time.now - 60
      stamp.should_not == Time.now
      @m.touch(source, :stamp => stamp)

      @m.touch(target, :like => source).should == target
      stat = File.stat(target)
      stamp.to_i.should == stat.mtime.to_i

      @m.touch(target, :like => source).should be_false
    end
  end

  it "should not change timestamps in preview mode (touch)" do
    @m.mktempdircd do
      target = "foo"
      @m.touch(target)
      stamp = File.stat(target).mtime

      begin
        @m.preview = true
        @m.touch(target)
        File.stat(target).mtime.to_i == stamp.to_i
      ensure
        @m.preview = false
      end
    end
  end

  it "should raise errors when setting timestamps like non-existing files (touch)" do
    @m.mktempdircd do
      source = "source"
      target = "target"
      File.exists?(source).should be_false
      File.exists?(target).should be_false

      lambda { @m.touch(target, :like => source) }.should raise_error(Errno::ENOENT)
    end
  end

  it "should not raise errors when setting timestamps like non-existing files in preview mode (touch)" do
    @m.mktempdircd do
      source = "source"
      target = "target"
      File.exists?(source).should be_false
      File.exists?(target).should be_false

      begin
        @m.preview = true
        @m.touch(target, :like => source).should == target
      ensure
        @m.preview = false
      end
    end
  end
end

describe AutomateIt::ShellManager, " when managing modes" do
  it_should_behave_like "AutomateIt::ShellManager"

  unless INTERPRETER.shell_manager.provides_mode?
    puts "NOTE: Can't check permission modes on this platform, #{__FILE__}"
  else
    it "should change the permissions of files (chmod)" do
      @m.mktempdircd do
        target = "foo"
        mode = 0654
        @m.touch(target)
        (File.stat(target).mode ^ (mode | 0100000)).zero?.should be_false

        @m.chmod(mode, target).should == target
        (File.stat(target).mode ^ (mode | 0100000)).zero?.should be_true

        @m.chmod(mode, target).should be_false
      end
    end

    it "should change the permissions of files recursively (chmod_R)" do
      @m.mktempdircd do
        mode = 0754
        dir = "foo/bar"
        file = dir+"/baz"
        @m.mkdir_p(dir)
        @m.touch(file)
        File.exists?(file).should be_true
        File.exists?(dir).should be_true
        (File.stat(file).mode ^ (mode | 0100000)).zero?.should be_false
        (File.stat(dir).mode ^ (mode | 040000)).zero?.should be_false

        @m.chmod_R(mode, dir).should == dir
        (File.stat(file).mode ^ (mode | 0100000)).zero?.should be_true
        (File.stat(dir).mode ^ (mode | 04000)).zero?.should be_false

        @m.chmod_R(mode, dir).should be_false
      end
    end

    it "should copy files whose mode changed (cp)" do
      @m.mktempdircd do
        source = "file1"
        target = "file2"

        @a.render(:text => "Hello", :to => source)
        @a.cp(source, target)

        File.chmod(0754, target)
        source_atime = File.atime(source)
        source_mtime = File.mtime(source)
        File.utime(source_atime, source_mtime, target)

        @a.cp(source, target, :preserve => true).should == source
      end
    end

    it "should return umask value (umask)" do
      @m.umask.should == File::umask
    end

    it "should set the default mask (umask)" do
      @m.mktempdircd do
        source = "file1"
        previous_umask = File::umask

        begin
          @m.umask(0000)
          File::umask.should_not == previous_umask

          @a.touch(source)
          File.stat(source).mode.should == 0100666
        ensure
          File::umask(previous_umask)
        end
      end
    end

    it "should set the default mask within block (umask)" do
      @m.mktempdircd do
        source = "file1"
        previous_umask = File::umask

        begin
          @m.umask(0000) do
            File::umask.should_not == previous_umask

            @a.touch(source)
            File.stat(source).mode.should == 0100666
          end

          File::umask.should == previous_umask
        ensure
          File::umask(previous_umask)
        end
      end
    end

    it "should reset umask correctly after an exception within a block (umask)" do
      @m.mktempdircd do
        previous_umask = File::umask

        begin
          begin
            @m.umask(0000) do
              File::umask.should_not == previous_umask
              raise ArgumentError.new("OMFG")
            end
          rescue ArgumentError
            # Error was expected
          end

          File::umask.should == previous_umask
        ensure
          File::umask(previous_umask)
        end
      end
    end
  end
end

describe AutomateIt::ShellManager, " when managing permissions" do
  if not INTERPRETER.euid?
    puts "NOTE: Can't check 'euid' on this platform, #{__FILE__}"
  elsif not INTERPRETER.shell_manager.provides_ownership?
    puts "NOTE: Can't check ownership on this platform, #{__FILE__}"
  elsif INTERPRETER.superuser?
    it_should_behave_like "AutomateIt::ShellManager"

    before(:all) do
      @pwent, @grent = find_mortal_pwent_and_grent
      @user =  @pwent.name
      @uid = @pwent.uid
      @group = @grent.name
      @gid = @grent.gid
    end

    # Return a pwent and grent of a non-root user
    def find_mortal_pwent_and_grent
      while true
        pwent = Etc.getpwent
        # Root is usually 0, but Darwin's users can have negative UIDs
        break if pwent.uid > 0
      end
      Etc.endpwent
      grent = Etc.getgrgid(pwent.gid)
      return [pwent, grent]
    end

    it "should change the ownership of files (chown)" do
      @m.mktempdircd do
        target = "foo"

        @m.touch(target)
        stat = File.stat(target)
        (stat.uid == @uid).should be_false
        (stat.gid == @gid).should be_false

        @m.chown(@user, @group, target).should == target
        stat = File.stat(target)
        (stat.uid == @uid).should be_true
        (stat.gid == @gid).should be_true

        @m.chown(@uid, @group, target).should be_false
      end
    end

    it "should change the ownership of files recursively (chown_R)" do
      @m.mktempdircd do
        dir = "foo/bar"
        file = dir+"/baz"

        @m.mkdir_p(dir)
        @m.touch(file)
        File.exists?(file).should be_true
        File.exists?(dir).should be_true
        stat = File.stat(file)
        (stat.uid == @uid).should be_false
        (stat.gid == @gid).should be_false
        stat = File.stat(dir)
        (stat.uid == @uid).should be_false
        (stat.gid == @gid).should be_false

        @m.chown_R(@uid, @group, dir).should == dir
        stat = File.stat(file)
        (stat.uid == @uid).should be_true
        (stat.gid == @gid).should be_true
        stat = File.stat(dir)
        (stat.uid == @uid).should be_true
        (stat.gid == @gid).should be_true

        @m.chown_R(@uid, @group, dir).should be_false
      end
    end

    it "should translate :owner to :user for Cfengine refugees" do
      @m.mktempdircd do
        dir = "foo/bar"
        file = dir+"/baz"

        @m.mkdir_p(dir)
        @m.touch(file)

        @m.chperm(dir, :recursive => true, :owner => @user, :group => @group).should == dir

        stat = File.stat(file)
        (stat.uid == @uid).should be_true
        (stat.gid == @gid).should be_true
        stat = File.stat(dir)
        (stat.uid == @uid).should be_true
        (stat.gid == @gid).should be_true
      end
    end

    it "should copy files whose owner changed (cp)" do
      @m.mktempdircd do
        source = "file1"
        target = "file2"

        @a.render(:text => "Hello", :to => source)
        @a.cp(source, target)

        # TODO not portable
        File.chown(2, 2, target)
        source_atime = File.atime(source)
        source_mtime = File.mtime(source)
        File.utime(source_atime, source_mtime, target)

        @a.cp(source, target, :preserve => true).should == source
      end
    end

  else
    puts "NOTE: Must be root to check 'chown' in #{__FILE__}"
  end
end

describe AutomateIt::ShellManager, " when managing hard links" do
  if not INTERPRETER.shell_manager.available?(:ln)
    puts "NOTE: Can't check hard links on this platform, #{__FILE__}"
  else
    it_should_behave_like "AutomateIt::ShellManager"

    it "should provide links" do
      @m.provides_link?.should be_true
    end

    it "should create hard links when needed (ln)" do
      @m.mktempdircd do
        source = "foo"
        target = "bar"
        @m.touch(source)
        File.exists?(source).should be_true
        File.exists?(target).should be_false

        @m.ln(source, target).should == source
        File.stat(target).nlink.should > 1

        @m.ln(source, target).should be_false
      end
    end
  end
end

describe AutomateIt::ShellManager, " when managing symbolic links" do
  if not INTERPRETER.shell_manager.available?(:ln_s)
    puts "NOTE: Can't check symbolic links on this platform, #{__FILE__}"
  else
    it_should_behave_like "AutomateIt::ShellManager"

    it "should provide symlinks" do
      @m.provides_symlink?.should be_true
    end

    it "should create symlinks when needed (ln_s)" do
      @m.mktempdircd do
        source = "foo"
        target = "bar"
        @m.touch(source)
        File.exists?(source).should be_true
        File.exists?(target).should be_false

        @m.ln_s(source, target).should == source
        File.symlink?(target).should be_true
        Pathname.new(target).realpath == Pathname.new(source).realpath

        @m.ln_s(source, target).should be_false
      end
    end

    it "should create symlinks that replace existing entry (ln_sf)" do
      @m.mktempdircd do
        source = "foo"
        intermediate = "baz"
        target = "bar"
        @m.touch(source)
        @m.touch(intermediate)
        File.exists?(source).should be_true
        File.exists?(intermediate).should be_true
        File.exists?(target).should be_false

        @m.ln_s(intermediate, target).should == intermediate
        File.symlink?(target).should be_true

        @m.ln_sf(source, target).should == source
        File.symlink?(target).should be_true
        Pathname.new(target).realpath == Pathname.new(source).realpath
      end
    end
  end
end
