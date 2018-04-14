class UDPSocket
  def recv_packet(timeout = nil)
    return nil if timeout and !IO.select([self], nil, nil, timeout)
    begin
      raw_pkt = self.recvfrom_nonblock(32)
      pkt = decode_packet(raw_pkt[0])
      return TetherFrame.new(pkt, raw_pkt[1][1])
    rescue Errno::EAGAIN
      return nil
    end
  end
  
  def send_packet(packet)
    self.send packet.raw, 0, "127.0.0.1", RADIOMESH_PORT
  end
  
  def timeslot_start(state)
    # anything already in the buffer right at the start of the slot came in
    # while we were asleep and would be lost in real life
    while(self.recv_packet) do
      log state, "Packet received outside of timeslot, would be lost."
    end
  end
end

def state_transition(old_state, new_state)
  log :transition, "State transitioning from #{old_state} to #{new_state}."
  return new_state
end

def log(state, msg)
  STDOUT.puts "#{Time.now.strftime("%H:%M:%S")}: [#{state}] #{msg}"
end

def port_to_sender(port)
  case port
    when RX_PORT
      return :rx
    when TX_PORT
      return :tx
    when BASESTATION_PORT
      return :base_station
    else
      return :unknown
  end
end

def decode_packet(packet)
  packet_type = packet.unpack("a")[0]
  case packet_type
    when 'A'
      return TetherAck.new
    when 'B'
      beacon_type, next_beacon_in, battery_level = packet.unpack("a1CC")
      return TetherBeacon.new(next_beacon_in, battery_level)
    when 'R'
      beacon_type, next_beacon_in, base_id, hours, minutes, seconds = packet.unpack("a1CCCCC")
      return TetherBaseReport.new(next_beacon_in, base_id, hours, minutes, seconds)
    else
      STDOUT.puts "Unknown packet passed to decode_packet"
  end
  return nil
end

class TetherFrame
  attr_reader :packet, :sender
  
  def initialize(packet, sender)
    return nil if packet == nil
    
    if(sender.class == Symbol) then
      @sender = sender
    else
      @sender = port_to_sender(sender)
    end
    if(packet.class == String) then
      @packet = decode_packet(packet)
    else
      @packet = packet
    end
  end
end

class TetherPacket
end

class TetherBeacon < TetherPacket
  attr_reader :next_beacon_in, :battery_level
  
  def initialize(next_beacon_in, battery_level)
    @next_beacon_in = next_beacon_in
    @battery_level = battery_level
  end
  
  def raw
    return ['B', @next_beacon_in, @battery_level].pack("a1CC");
  end
end

class TetherBaseReport < TetherPacket
  attr_reader :next_beacon_in, :base_id, :hours, :minutes, :seconds
  
  def initialize(next_beacon_in, base_id, hours_or_time, minutes = nil, seconds = nil)
    @next_beacon_in = next_beacon_in
    @base_id = base_id
    if(hours_or_time.class == Time) then
      now = Time.now
      @hours = now.hour
      @minutes = now.min
      @seconds = now.sec
    else
      @hours = hours_or_time
      @minutes = minutes
      @seconds = seconds
    end
  end
  
  def raw
    return ['R', @next_beacon_in, @base_id, @hours, @minutes, @seconds].pack("a1CCCCC");
  end
end

class TetherAck < TetherPacket
  def raw
    return 'A'
  end
end
