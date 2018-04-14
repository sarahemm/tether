class UDPSocket
  def recv_packet(timeout = nil)
    return nil if timeout and !IO.select([self], nil, nil, timeout)
    begin
      return self.recvfrom_nonblock(32)
    rescue Errno::EAGAIN
      return nil
    end
  end
end

def log(state, msg)
  puts "#{Time.now.strftime("%H:%M:%S")}: [#{state}] #{msg}"
end
