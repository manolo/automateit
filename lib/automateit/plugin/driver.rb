module AutomateIt
  class Plugin
    # == Plugin::Driver
    #
    # A driver provides the low-level functionality for features, e.g. the
    # PackageManager::APT driver is responsible for installing a software
    # package using the Debian <tt>apt-get</tt> command. Multiple drivers
    # providing common functionality are managed by a single Manager class,
    # e.g. drivers that install software packages are managed by the
    # PackageManager.
    #
    # A driver may only be available on certain platforms and provides its
    # manager with an idea of when it's suitable. For example, if a platform
    # doesn't have the <tt>apt-get</tt> command, the PackageManager::APT driver
    # must tell the PackageManager class that it's not suitable.
    class Driver < Base
      collect_registrations

      # Defines what this driver depends on the system for. 
      #
      # Options:
      # * :files -- Array of filenames that must exist.
      # * :directories -- Array of directories that must exist.
      # * :programs -- Array of programs, checked with +which+, that must exist.
      #
      # Example:
      #   class APT < Plugin::Driver
      #     depends_on :programs => %w(apt-get dpkg)
      #     # ...
      #  end
      def self.depends_on(opts)
        meta_eval do
          attr_accessor :_depends_on_opts, :_is_available, :_missing_dependencies
        end
        self._depends_on_opts = opts
      end

      # Is this driver available on this platform? Queries the dependencies set
      # by #depends_on to make sure that they're all present, otherwise raises
      # a NotImplementedError. If a driver author needs to do some other kind
      # of check, it's reasonable to override this method.
      #
      # For example, this method is used by the PackageManager driver for APT
      # to determine if the "apt-get" program is installed.
      #
      # What's the difference between #available? and #suitability? The
      # #available? method is used to determine if the driver *can* do the
      # work, while the #suitability method determines if the driver *should*
      # be automatically selected.
      def available?
        # Some drivers don't run +depends_on+, so assume they're available.
        return true unless self.class.respond_to?(:_depends_on_opts)
        opts = self.class._depends_on_opts

        # Driver said that it +depends_on :nothing+, so it's available.
        return true if opts == :nothing

        is_available = self.class._is_available
        if is_available.nil? and opts.nil?
          log.debug("don't know if driver #{self.class} is available, maybe it doesn't state what it +depends_on+")
          return false
        elsif is_available.nil?
          all_present = true
          missing = []
          for kind in [:files, :directories, :programs]
            next unless opts[kind]
            for item in opts[kind]
              present = \
                case kind
                when :files
                  File.exists?(item)
                when :directories
                  File.directory?(item)
                when :programs
                  # XXX Find less awkward way to check if a program exists. Can't use +shell_manager.which+ because that will use +dispatch+ and go into an infinite loop checking +available?+. The +which+ command isn't available on all platforms, so that failure must be handled as well.
                  begin
                    interpreter.shell_manager[:unix].which!(item)
                    true
                  rescue ArgumentError, NotImplementedError
                    false
                  end
                else
                  raise "unknown kind: #{kind}"
                end
              unless present
                all_present = false
                missing << item
              end
            end
          end
          self.class._missing_dependencies = missing
          self.class._is_available = all_present
          log.debug(PNOTE+"Driver #{self.class} #{all_present ? "is" : "isn't"} available")
        end
        return self.class._is_available
      end

      # Raise a NotImplementedError if this driver is called but is not
      # #available?.
      def _raise_unless_available
        unless available?
          raise NotImplementedError.new(
            %{missing dependencies: #{self.class._missing_dependencies.join(", ")}})
        end
      end

      # What is this driver's suitability for automatic detection? The Manager
      # queries its drivers when there isn't a driver specified with a
      # <tt>:with</tt> or #default so it can choose a suitable driver for the
      # +method+ and +args+. Any driver that returns an integer 1 or greater
      # claims to be suitable. The Manager will then select the driver with the
      # highest suitability level. Drivers that return an integer less than 1
      # are excluded from automatic detection.
      #
      # The <tt>available?</tt> method is used to determine if the driver can
      # do the work, while the <tt>suitability</tt> method determines if the
      # driver should be automatically selected.
      def suitability(method, *args, &block)
        log.debug("driver #{self.class} doesn't implement the +suitability+ method")
        return -1
      end
    end
  end
end