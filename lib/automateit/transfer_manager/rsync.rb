# == TransferManager::Rsync
#
# A TransferManager driver providing rsync.
# It uses rsync in command line mode.
# 

class AutomateIt::TransferManager::Rsync < AutomateIt::TransferManager::BaseDriver

  depends_on :libraries => %w(net/ssh), :programs => %w(rsync)
  
  # See TransferManager#rsync
  def rsync(source, target, *opts)
    
    if opts[0]
      user = opts[0][:user]
      password = opts[0][:password]
      channel = opts[0][:channel]
      options = opts[0][:options]
      params  = opts[0][:params] || ""
      params += " --delete " if (opts[0][:delete])
      params += " -v " if (opts[0][:verbose])
      if opts[0][:exclude]
        opts[0][:exclude].each do |reg|
          params += " --exclude #{reg} "
        end
      end
    end
    channel ||= "-e 'ssh -o BatchMode=yes -o CheckHostIP=no -o StrictHostKeyChecking=no'"
    options ||= "-raz"
    params  ||= ""
    
    key_sent = false
    if channel.match(/.*ssh.*/)
      nuser, npassword, hostname =  parse_scp_uri(source)
      if (hostname.nil?)
        nuser, npassword, hostname =  parse_scp_uri(target)
      end
      user ||= nuser
      password ||= npassword
      log.debug PNOTE + "Authorizing user #{user} in host #{hostname}"
      key_sent = authorize_rsync hostname, user, password
      target = target.sub(/^[^@]+@/, "");
    end
    
    begin
      cmd = "rsync #{channel} #{options} #{params} #{source} #{user}@#{target}"
      interpreter.sys(cmd)
    rescue Exception => e
      raise e
    ensure  
      unauthorize_rsync(hostname, user) if (key_sent)
    end
  end
  
  
  :private
  
  def get_pub_key
    if File.exist? "#{ENV['HOME']}/.ssh/id_dsa.pub"
      return `cat #{ENV['HOME']}/.ssh/id_dsa.pub`.strip
    end
    if File.exist? "#{ENV['HOME']}/.ssh/id_rsa.pub"
      return `cat #{ENV['HOME']}/.ssh/id_rsa.pub`.strip
    end
    create_key
    return `cat #{ENV['HOME']}/.ssh/id_rsa.pub`.strip
  end
  
  def create_key
    return unless interpreter.which("ssh-keygen")
    log.info PNOTE + "creating local ssh key"
    interpreter.mkdir_p "#{ENV['HOME']}/.ssh"
    interpreter.sys "ssh-keygen -N '' -f #{ENV['HOME']}/.ssh/id_rsa >/dev/null"
  end

  
  def remote_exec( command, hostname, user, password=nil)
    log.debug PEXEC + "Remote execution: #{command}, #{hostname}, #{user}, #{password}"
    status = 1; stderr = ""; stdout ="";
    begin
      Net::SSH.start( hostname, user, :password => password ) do |ssh|
        ssh.open_channel do |chan|
          chan.on_request('exit-status') { |ch, data| status = data.read_long}
          chan.on_extended_data          { |ch, type, data| stderr += data; puts "- " + data}
          chan.on_data                   { |ch, data| stdout += data; puts "* " + data}
          chan.exec(command)
        end
      end
    rescue Net::SSH::AuthenticationFailed
      return false
    end
    return status == 0
  end
  
  def authorize_rsync(hostname, user, password)
    return false if remote_exec("true", hostname, user)
    pub = get_pub_key 
    reg = pub.gsub(/[^\w]/,".")
    log.info PNOTE + "Transfering public key to #{user}@#{hostname}"
    command = "mkdir -p $HOME/.ssh; touch $HOME/.ssh/authorized_keys; egrep '#{reg}' $HOME/.ssh/authorized_keys >/dev/null || echo '#{pub}' >> $HOME/.ssh/authorized_keys"
    remote_exec(command, hostname, user, password)
    raise ArgumentError.new("Unable to authorize host") if !remote_exec("true", hostname, user)
    log.debug PNOTE + "Authorization OK"
    return true
  end
  
  def unauthorize_rsync(hostname, user)
    log.info PNOTE + "Removing public key from #{user}@#{hostname}"
    pub = get_pub_key 
    reg = pub.gsub(/[^\w]/,".")
    command = "perl -pi -e 's##{reg}##' $HOME/.ssh/authorized_keys"
    remote_exec command, hostname, user
  end  

end
