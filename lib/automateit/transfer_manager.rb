# == TransferManager
#
# The TransferManager provides a way of transfer files between hosts

module AutomateIt
  class TransferManager < Plugin::Manager
    alias_methods :scp_r, :rsync
    
    # Transfers files between computers using ssh
    #
    # Options:
    # * :source, source file/folder
    # * :target, destination folder
    # * :user, :password are optional, by default it uses current user and ssh relationships
    #
    # user and password can be passed using the source or target string.
    # cross transfers aren't supported, so either the source or the target has to be in this host.
    #
    def scp_r(*arguments) dispatch(*arguments) end

    # Transfers files between computers using rsync
    #
    # Options:
    # * :source, source file/folder
    # * :target, destination folder
    # * :opts, is an array whose first element is a hash with arguments:
    #          :channel  default is -e ssh [...]
    #          :options  option passed to rsync, default is -raz
    #          :delete   adds the flag --delete to rsync, default is false 
    #          :params   a string with extra parameters to pass to rsync
    #          :exclude  an array of rsync expressions to exclude
    #          :user     remote user
    #          :password remote password 
    #
    # user and password can also be passed using the source or target string or as arguments.
    #
    # If password is empty it uses the actual user in the local machine and it asumes that the 
    # relationhips between the computers have been configured previously.
    #
    # Before executing the real transfer it checks that the transfer is authorized and in the
    # case of user and password are supplied, it tries to make a connexion using ssh and 
    # authorizes the local public ssh key in the remote host while the transfer process. 
    #
    # Cross transfers aren't supported, so the source or the target has to be in this host.
    #
    def rsync(*arguments) dispatch(*arguments) end  

    # == TransferManager::BaseDriver
    #
    # Base class for all TransferManager drivers.
    class BaseDriver < Plugin::Driver
      
      def suitability(method, *args) # :nodoc:
        return available? ? 1 : 0
      end
  
      def parse_scp_uri(uri)
        if (uri =~ /^([^:]+):([^@]+)@([^:]+):(.+)$/ )
          user = $1; password = $2; hostname = $3; path = $4;
        elsif (uri =~ /^([^:@]+)@([^:]+):(.+)$/ )
          user = $1; hostname = $2; path = $3;
        elsif (uri =~ /([^:@]+):([^:@]+)$/ )
          hostname = $1; path = $2;
        end
        return [user, password, hostname, path]
      end
      protected :parse_scp_uri
      
    end
      
  end  
end

require 'automateit/transfer_manager/scp'
require 'automateit/transfer_manager/rsync'
