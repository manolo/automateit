# == TransferManager::Scp
#
# A TransferManager driver providing secure copy.
# It uses ruby net-ssh and net-scp implementation.
# 
class AutomateIt::TransferManager::Scp < AutomateIt::TransferManager::BaseDriver
  
  depends_on :libraries => %w(net/scp)
  
  # See TransferManager#scp_r
  def scp_r(source, target, *opts)
    
    raise ArgumentError.new("cross transfer is not allowed")  if (source =~ /:/ && target =~ /:/ || source !~ /:/ && target !~ /:/ )
    
    if (source =~ /:/ )
      user, password, hostname, source = parse_scp_uri(source)
      action = :download!
    else
      user, password, hostname, target = parse_scp_uri(target)
      action = :upload!
    end
    
    user ||= opts && opts[0] ? opts[0][:user] : nil
    password ||= opts && opts[0] ? opts[0][:password] : nil
    
    if (action == :download!)
      local = target + "/" + File.basename(source)
      return if  File.directory?(local) || File.exist?(local)
    else
      remote = target + "/" + File.basename(source)
      return if interpreter.rexist?(remote, hostname, :user=>user, :password=>password)
    end
    
    raise ArgumentError.new("hostname is nil")  if hostname.nil?
    
    log.info PEXEC + "scp_r action: #{action.to_s}, source: #{source}, target: #{target}, host: #{hostname}, user: #{user}"
    
    Net::SSH.start( hostname, user, :password => password ) do |ssh|
      # preview validates the connection, but doesn't transfer anything
      return if preview?
      
      last = ""
      ssh.scp.send(action, source, target, {:recursive => true , :verbose => true, :preserve => true}) do |ch, name, sent, total|
        printf("* %s   \r", "#{name}: #{sent}/#{total}")
        puts "" if (last != name)
        last = name
      end
      puts ""
    end
  end
  
end
