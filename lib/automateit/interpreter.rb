module AutomateIt
  # == Interpreter
  #
  # The Interpreter runs AutomateIt commands.
  #
  # The TUTORIAL.txt[link:files/TUTORIAL_txt.html] file provides hands-on examples
  # for using the Interpreter.
  #
  # === Aliased methods
  #
  # The Interpreter provides shortcut aliases for certain plugin commands.
  #
  # For example, the following commands will run the same method:
  #
  #   shell_manager.sh "ls"
  #
  #   sh "ls"
  #
  # The full set of aliased methods:
  #
  # * cd -- AutomateIt::ShellManager#cd
  # * chmod -- AutomateIt::ShellManager#chmod
  # * chmod_R -- AutomateIt::ShellManager#chmod_R
  # * chown -- AutomateIt::ShellManager#chown
  # * chown_R -- AutomateIt::ShellManager#chown_R
  # * chperm -- AutomateIt::ShellManager#chperm
  # * cp -- AutomateIt::ShellManager#cp
  # * cp_r -- AutomateIt::ShellManager#cp_r
  # * edit -- AutomateIt::EditManager#edit
  # * download -- AutomateIt::DownloadManager#download
  # * download_if_modified -- AutomateIt::DownloadManager#download_if_modified
  # * hosts_tagged_with -- AutomateIt::TagManager#hosts_tagged_with
  # * install -- AutomateIt::ShellManager#install
  # * ln -- AutomateIt::ShellManager#ln
  # * ln_s -- AutomateIt::ShellManager#ln_s
  # * ln_sf -- AutomateIt::ShellManager#ln_sf
  # * lookup -- AutomateIt::FieldManager#lookup
  # * mkdir -- AutomateIt::ShellManager#mkdir
  # * mkdir_p -- AutomateIt::ShellManager#mkdir_p
  # * mktemp -- AutomateIt::ShellManager#mktemp
  # * mktempdir -- AutomateIt::ShellManager#mktempdir
  # * mktempdircd -- AutomateIt::ShellManager#mktempdircd
  # * mv -- AutomateIt::ShellManager#mv
  # * pwd -- AutomateIt::ShellManager#pwd
  # * render -- AutomateIt::TemplateManager#render
  # * rm -- AutomateIt::ShellManager#rm
  # * rm_r -- AutomateIt::ShellManager#rm_r
  # * rm_rf -- AutomateIt::ShellManager#rm_rf
  # * rmdir -- AutomateIt::ShellManager#rmdir
  # * sh -- AutomateIt::ShellManager#sh
  # * sys -- AutomateIt::ShellManager#sys
  # * tagged? -- AutomateIt::TagManager#tagged?
  # * tags -- AutomateIt::TagManager#tags
  # * tags_for -- AutomateIt::TagManager#tags_for
  # * touch -- AutomateIt::ShellManager#touch
  # * umask -- AutomateIt::ShellManager#umask
  # * which -- AutomateIt::ShellManager#which
  # * which! -- AutomateIt::ShellManager#which!
  # * scp_r -- AutomateIt::TransferManager#scp_r
  # * rsync -- AutomateIt::TransferManager#rsync
  # === Embedding the Interpreter
  #
  # The AutomateIt Interpreter can be embedded inside a Ruby program:
  #
  #   require 'rubygems'
  #   require 'automateit'
  #
  #   interpreter = AutomateIt.new
  #
  #   # Use the interpreter as an object:
  #   interpreter.sh "ls -la"
  #
  #   # Have it execute a recipe:
  #   interpreter.invoke "myrecipe.rb"
  #
  #   # Or execute recipes within a block
  #   interpreter.instance_eval do
  #     puts superuser?
  #     sh "ls -la"
  #   end
  #
  # See the #include_in and #add_method_missing_to methods for instructions on
  # how to more easily dispatch commands from your program to the Interpreter
  # instance.
  class Interpreter < Common
    include Nitpick

    # Plugin instance that instantiated the Interpreter.
    attr_accessor :parent
    private :parent
    private :parent=

    # Access IRB instance from an interactive shell.
    attr_accessor :irb

    # Project path for this Interpreter. If no path is available, nil.
    attr_accessor :project

    # Hash of parameters to make available to the Interpreter. Mostly useful
    # when needing to pass arguments to an embedded Interpreter before doing an
    # #instance_eval.
    attr_accessor :params

    # The Interpreter throws friendly error messages by default that make it
    # easier to see what's wrong with a recipe. These friendly messages display
    # the cause, a snapshot of the problematic code, shortened paths, and only
    # the relevant stack frames.
    #
    # However, if there's a bug in the AutomateIt internals, these friendly
    # messages may inadvertently hide the cause, and it may be necessary to
    # turn them off to figure out what's wrong.
    #
    # To turn off friendly exceptions:
    #
    #   # From a recipe or the AutomateIt interactive shell:
    #   self.friendly_exceptions = false
    #
    #   # For an embedded interpreter at instantiation:
    #   AutomateIt.new(:friendly_exceptions => false)
    #
    #   # From the UNIX command line when invoking a recipe:
    #   automateit --trace myrecipe.rb
    attr_accessor :friendly_exceptions

    # Setup the Interpreter. This method is also called from Interpreter#new.
    #
    # Options for users:
    # * :verbosity -- Alias for :log_level
    # * :log_level -- Log level to use, defaults to Logger::INFO.
    # * :preview -- Turn on preview mode, defaults to false.
    # * :project -- Project directory to use.
    # * :tags -- Array of tags to add to this run.
    #
    # Options for internal use:
    # * :parent -- Parent plugin instance.
    # * :log -- QueuedLogger instance.
    # * :guessed_project -- Boolean of whether the project path was guessed. If
    #   guessed, won't throw exceptions if project wasn't found at the
    #   specified path. If not guessed, will throw exception in such a
    #   situation.
    # * :friendly_exceptions -- Throw user-friendly exceptions that make it
    #   easier to see errors in recipes, defaults to true.
    def setup(opts={})
      super(opts.merge(:interpreter => self))

      self.params ||= {}

      if opts[:irb]
        @irb = opts[:irb]
      end

      if opts[:parent]
        @parent = opts[:parent]
      end

      if opts[:log]
        @log = opts[:log]
      elsif not defined?(@log) or @log.nil?
        @log = QueuedLogger.new($stdout)
        @log.level = Logger::INFO
      end

      if opts[:log_level] or opts[:verbosity]
        @log.level = opts[:log_level] || opts[:verbosity]
      end

      if opts[:preview].nil? # can be false
        self.preview = false unless preview?
      else
        self.preview = opts[:preview]
      end

      if opts[:friendly_exceptions].nil?
        @friendly_exceptions = true unless defined?(@friendly_exceptions)
      else
        @friendly_exceptions = opts[:friendly_exceptions]
      end

      # Instantiate core plugins so they're available to the project
      _instantiate_plugins

      # Add optional run-time tags
      tags.merge(opts[:tags]) if opts[:tags]

      if project_path = opts[:project] || ENV["AUTOMATEIT_PROJECT"] || ENV["AIP"]
        # Only load a project if we find its env file
        env_file = File.join(project_path, "config", "automateit_env.rb")
        if File.exists?(env_file)
          @project = File.expand_path(project_path)
          log.debug(PNOTE+"Loading project from path: #{@project}")

          lib_files = Dir[File.join(@project, "lib", "*.rb")] + Dir[File.join(@project, "lib", "**", "init.rb")]
          lib_files.each do |lib|
            log.debug(PNOTE+"Loading project library: #{lib}")
            invoke(lib)
          end

          tag_file = File.join(@project, "config", "tags.yml")
          if File.exists?(tag_file)
            log.debug(PNOTE+"Loading project tags: #{tag_file}")
            tag_manager[:yaml].setup(:file => tag_file)
          end

          field_file = File.join(@project, "config", "fields.yml")
          if File.exists?(field_file)
            log.debug(PNOTE+"Loading project fields: #{field_file}")
            field_manager[:yaml].setup(:file => field_file)
          end

          # Instantiate project's plugins so they're available to the environment
          _instantiate_plugins

          if File.exists?(env_file)
            log.debug(PNOTE+"Loading project env: #{env_file}")
            invoke(env_file)
          end
        elsif not opts[:guessed_project]
          raise ArgumentError.new("Couldn't find project at: #{project_path}")
        end
      end
    end

    # Hash of plugin tokens to plugin instances for this Interpreter.
    attr_accessor :plugins

    def _instantiate_plugins
      @plugins ||= {}
      # If a parent is defined, use it to prep the list and avoid re-instantiating it.
      if defined?(@parent) and @parent and Plugin::Manager === @parent
        @plugins[@parent.class.token] = @parent
      end
      plugin_classes = AutomateIt::Plugin::Manager.classes.reject{|t| t == @parent if @parent}
      for klass in plugin_classes
        _instantiate_plugin(klass)
      end
    end
    private :_instantiate_plugins

    def _instantiate_plugin(klass)
      token = klass.token
      unless plugin = @plugins[token]
        plugin = @plugins[token] = klass.new(:interpreter => self)
        #puts "!!! ip #{token}"
        unless respond_to?(token.to_sym)
          self.class.send(:define_method, token) do
            @plugins[token]
          end
        end
        _expose_plugin_methods(plugin)
      end
      plugin.instantiate_drivers
    end
    private :_instantiate_plugin

    def _expose_plugin_methods(plugin)
      return unless plugin.class.aliased_methods
      plugin.class.aliased_methods.each do |method|
        #puts "!!! epm #{method}"
        unless respond_to?(method.to_sym)
          # Must use instance_eval because methods created with define_method
          # can't accept block as argument. This is a known Ruby 1.8 bug.
          self.instance_eval <<-EOB
            def #{method}(*args, &block)
              @plugins[:#{plugin.class.token}].send(:#{method}, *args, &block)
            end
          EOB
        end
      end
    end
    private :_expose_plugin_methods

    # Set the QueuedLogger instance for the Interpreter.
    attr_writer :log

    # Get or set the QueuedLogger instance for the Interpreter, a special
    # wrapper around the Ruby Logger.
    def log(value=nil)
      if value.nil?
        return defined?(@log) ? @log : nil
      else
        @log = value
      end
    end

    # Set preview mode to +value+. See warnings in ShellManager to learn how to
    # correctly write code for preview mode.
    def preview(value)
      self.preview = value
    end

    # Is Interpreter running in preview mode?
    def preview?
      @preview
    end

    # Preview a block of custom commands. When in preview mode, displays the
    # +message+ but doesn't execute the +block+. When not previewing, will
    # execute the block and not display the +message+.
    #
    # For example:
    #
    #   preview_for("FOO") do
    #     puts "BAR"
    #   end
    #
    # In preview mode, this displays:
    #
    #   => FOO
    #
    # When not previewing, displays:
    #
    #   BAR
    def preview_for(message, &block)
      if preview?
        log.info(message)
        :preview
      else
        block.call
      end
    end

    # Set preview mode to +value.
    def preview=(value)
      @preview = value
    end

    # Set noop (no-operation mode) to +value+. Alias for #preview.
    def noop(value)
      self.noop = value
    end

    # Set noop (no-operation mode) to +value+. Alias for #preview=.
    def noop=(value)
      self.preview = value
    end

    # Are we in noop (no-operation) mode? Alias for #preview?.
    def noop?
      preview?
    end

    # Set writing to +value+. This is the opposite of #preview.
    def writing(value)
      self.writing = value
    end

    # Set writing to +value+. This is the opposite of #preview=.
    def writing=(value)
      self.preview = !value
    end

    # Is Interpreter writing? This is the opposite of #preview?.
    def writing?
      !preview?
    end

    # Does this platform provide euid (Effective User ID)?
    def euid?
      begin
        euid
        return true
      rescue
        return false
      end
    end

    # Return the effective user id.
    def euid
      begin
        return Process.euid
      rescue NoMethodError => e
        output = `id -u 2>&1`
        raise e unless output and $?.exitstatus.zero?
        begin
          return output.match(/(\d+)/)[1].to_i
        rescue IndexError
          raise e
        end
      end

    end

    # Does the current user have superuser (root) privileges?
    def superuser?
      euid.zero?
    end

    # Create an Interpreter with the specified +opts+ and invoke
    # the +recipe+. The opts are passed to #setup for parsing.
    def self.invoke(recipe, opts={})
      opts[:project] ||= File.join(File.dirname(recipe), "..")
      AutomateIt.new(opts).invoke(recipe)
    end

    # Invoke the +recipe+. The recipe may be expressed as a relative or fully
    # qualified path. When invoked within a project, the recipe can also be the
    # name of a recipe.
    #
    # Example:
    #  invoke "/tmp/recipe.rb"  # Run "/tmp/recipe.rb"
    #  invoke "recipe.rb"       # Run "./recipe.rb". If not found and in a
    #                           # project, will try running "recipes/recipe.rb"
    #  invoke "recipe"          # Run "recipes/recipe.rb" in a project
    def invoke(recipe)
      filenames = [recipe]
      filenames << File.join(project, "recipes", recipe) if project
      filenames << File.join(project, "recipes", recipe + ".rb") if project

      for filename in filenames
        log.debug(PNOTE+" invoking "+filename)
        if File.exists?(filename)
          data = File.read(filename)
          begin
            return instance_eval(data, filename, 1)
          rescue Exception => e
            if @friendly_exceptions
              # TODO Extract this routine and its companion in HelpfulERB

              # Capture initial stack in case we add a debug/breakpoint after this
              stack = caller

              # Extract trace for recipe after the Interpreter#invoke call
              preresult = []
              for line in e.backtrace
                # Stop at the Interpreter#invoke call
                break if line == stack.first
                preresult << line
              end

              # Extract the recipe filename
              preresult.last.match(/^([^:]+):(\d+):in `invoke'/)
              recipe = $1

              # Extract trace for most recent block
              result = []
              for line in preresult
                # Ignore manager wrapper and dispatch methods
                next if line =~ %r{lib/automateit/.+manager\.rb:\d+:in `.+'$}
                result << line
                # Stop at the first mention of this recipe
                break if line =~ /^#{recipe}/
              end

              # Extract line number
              if e.is_a?(SyntaxError)
                line_number = e.message.match(/^[^:]+:(\d+):/)[1].to_i
              else
                result.last.match(/^([^:]+):(\d+):in `invoke'/)
                line_number = $2.to_i
              end

              msg = "Problem with recipe '#{recipe}' at line #{line_number}\n"

              # Extract recipe text
              begin
                lines = File.read(recipe).split(/\n/)

                min = line_number - 7
                min = 0 if min < 0

                max = line_number + 1
                max = lines.size if max > lines.size

                width = max.to_s.size

                for i in min..max
                  n = i+1
                  marker = n == line_number ? "*" : ""
                  msg << "\n%2s %#{width}i %s" % [marker, n, lines[i]]
                end

                msg << "\n"
              rescue Exception => e
                # Ignore
              end

              msg << "\n(#{e.exception.class}) #{e.message}"

              # Append shortened trace
              for line in result
                msg << "\n  "+line
              end

              # Remove project path
              msg.gsub!(/#{@project}\/?/, '') if @project

              raise AutomateIt::Error.new(msg, e)
            else
              raise e
            end
          end
        end
      end
      raise Errno::ENOENT.new(recipe)
    end

    # Path of this project's "dist" directory. If a project isn't available or
    # the directory doesn't exist, this will throw a NotImplementedError.
    def dist
      if @project
        result = File.join(@project, "dist/")
        if File.directory?(result)
          return result
        else
          raise NotImplementedError.new("can't find dist directory at: #{result}")
        end
      else
        raise NotImplementedError.new("can't use dist without a project")
      end
    end

    # Set value to share throughout the Interpreter. Use this instead of
    # globals so that different Interpreters don't see each other's variables.
    # Creates a method that returns the value and also adds a #params entry.
    #
    # Example:
    #  set :asdf, 9 # => 9
    #  asdf         # => 9
    #
    # This is best used for frequently-used variables, like paths. For
    # infrequently-used variables, use #lookup and #params. A good place to use
    # the #set is in the  Project's <tt>config/automateit_env.rb</tt> file so
    # that paths are exposed to all recipes like this:
    #
    #  set :helpers, project+"/helpers"
    def set(key, value)
      key = key.to_sym
      params[key] = value
      eval <<-HERE
        def #{key}
          return params[:#{key}]
        end
      HERE
      value
    end

    # Retrieve a #params entry.
    #
    # Example:
    #  params[:foo] = "bar"  # => "bar"
    #  get :foo              # => "bar"
    def get(key)
      params[key.to_sym]
    end

    # Creates wrapper methods in +object+ to dispatch calls to an Interpreter instance.
    #
    # *WARNING*: This will overwrite all methods and variables in the target +object+ that have the same names as the Interpreter's methods. You should considerer specifying the +methods+ to limit the number of methods included to minimize surprises due to collisions. If +methods+ is left blank, will create wrappers for all Interpreter methods.
    #
    # For example, include an Interpreter instance into a Rake session, which will override the FileUtils commands with AutomateIt equivalents:
    #
    #   # Rakefile
    #
    #   require 'automateit'
    #   @ai = AutomateIt.new
    #   @ai.include_in(self, %w(preview? sh)) # Include #preview? and #sh methods
    #
    #   task :default do
    #     puts preview?   # Uses Interpreter#preview?
    #     sh "id"         # Uses Interpreter#sh, not FileUtils#sh
    #     cp "foo", "bar" # Uses FileUtils#cp, not Interpreter#cp
    #   end
    #
    # For situations where you don't want to override any existing methods, consider using #add_method_missing_to.
    def include_in(object, *methods)
      methods = [methods].flatten
      methods = unique_methods.reject{|t| t.to_s =~ /^_/} if methods.empty?

      object.instance_variable_set(:@__automateit, self)

      for method in methods
        object.instance_eval <<-HERE
          def #{method}(*args, &block)
            @__automateit.send(:#{method}, *args, &block)
          end
        HERE
      end
    end

    # Creates #method_missing in +object+ that dispatches calls to an Interpreter instance. If a #method_missing is already present, it will be preserved as a fall-back using #alias_method_chain.
    #
    # For example, add #method_missing to a Rake session to provide direct access to Interpreter instance's methods whose names don't conflict with the names existing variables and methods:
    #
    #   # Rakefile
    #
    #   require 'automateit'
    #   @ai = AutomateIt.new
    #   @ai.add_method_missing_to(self)
    #
    #   task :default do
    #     puts preview? # Uses Interpreter#preview?
    #     sh "id"       # Uses FileUtils#sh, not Interpreter#sh
    #   end
    #
    # For situations where it's necessary to override existing methods, such as the +sh+ call in the example, consider using #include_in.
    def add_method_missing_to(object)
      object.instance_variable_set(:@__automateit, self)
      chain = object.respond_to?(:method_missing)

      # XXX The solution below is evil and ugly, but I don't know how else to solve this. The problem is that I want to *only* alter the +object+ instance, and NOT its class. Unfortunately, #alias_method and #alias_method_chain only operate on classes, not instances, which makes them useless for this task.

      template = <<-HERE
        def method_missing<%=chain ? '_with_automateit' : ''%>(method, *args, &block)
          ### puts "mm+a(%s, %s)" % [method, args.inspect]
          if @__automateit.respond_to?(method)
            @__automateit.send(method, *args, &block)
          else
            <%-if chain-%>
              method_missing_without_automateit(method, *args, &block)
            <%-else-%>
              super
            <%-end-%>
          end
        end
        <%-if chain-%>
          @__method_missing_without_automateit = self.method(:method_missing)

          def method_missing_without_automateit(*args)
            ### puts "mm-a %s" % args.inspect
            @__method_missing_without_automateit.call(*args)
          end

          def method_missing(*args)
            ### puts "mm %s" % args.inspect
            method_missing_with_automateit(*args)
          end
        <%-end-%>
      HERE

      text = ::HelpfulERB.new(template).result(binding)
      object.instance_eval(text)
    end
  end
end
