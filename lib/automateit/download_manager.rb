# == DownloadManager
#
# The DownloadManager provides a way of downloading files.


module AutomateIt
  class DownloadManager < Plugin::Manager
    alias_methods :download, :download_if_modified

    # Downloads the +source+ document.
    #
    # Options:
    # * :to -- Saves source to this filename or directory. Defaults to current directory.
    def download(*arguments) dispatch(*arguments) end
      
    # Downloads the +source+ document but only in the case of its size has changed.
    # It uses the HEAD http command to get the remote size.
    # It puts the downloaded file in the system's temporary dir when the target is not provided
    # 
    # Examples:
    #   download_if_modified("http://domain.com/file.html", "/var/tmp/my_file.html")
    #   download_if_modified("http://domain.com/file.html") 
    def download_if_modified(*arguments) dispatch(*arguments) end

    # == DownloadManager::BaseDriver
    #
    # Base class for all DownloadManager drivers.
    class BaseDriver < Plugin::Driver
    end
  
  
    # == DownloadManager::OpenURI
    #
    # A DownloadManager driver using the OpenURI module for handling HTTP and FTP transfers.
    class OpenURI < BaseDriver
      depends_on :libraries => %w(open-uri net/http)

      def suitability(method, *args) # :nodoc:
        return available? ? 1 : 0
      end

      # See DownloadManager#download
      def download(*arguments)
        args, opts = args_and_opts(*arguments)
        source = args[0] or raise ArgumentError.new("No source specified")
        target = args[1] || opts[:to] || File.basename(source)
        target = File.join(target, File.basename(source)) if File.directory?(target)
        log.info(PNOTE+"Downloading: #{target} From: #{source}")
        if writing?
          open(target, "w+") do |writer|
            open(source) do |reader|
              writer.write(reader.read)
            end
          end
        end
        return writing?
      end
      
      # The transfer is done using a temporary file in order to preserve the original 
      # transfer time and size in the case of an incomplete transfer.
      #
      def download_if_modified(url, target=nil)
        target ||= Dir.tmpdir + "/" + File.basename(url.gsub("?.*$", ""))
        log.info PNOTE + "Download if modified: #{target} From: #{url}"
        if remote_has_different_size(url, target)
          tmp_file =  Dir.tmpdir + "/" + "ai_dnld_#{$$}.tmp"
          download url, tmp_file
          return if preview?
          interpreter.mv tmp_file, target
          return true
        end
        return false
      end
      
      def remote_has_different_size(url, target)
        if File.exists? target
           local_size = File.size target
           req=Net::HTTP.new URI.parse(url).host
           res=req.request_head URI.parse(url).path
           remote_size=res.content_length
           if (!remote_size || remote_size == 0)
             log.info PNOTE + "Remote server has not sent the file size in the head request."
           else   
             if (local_size == remote_size)
                log.info PNOTE + "Remote file size is identical to local size"
                return false
             end
           end
        end
        return true
      end
      private :remote_has_different_size
      
    end
  end
end
