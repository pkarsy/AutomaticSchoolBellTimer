
# This module can be loaded with
# load('timetable')

# This block is used for live updates
do
  import strict
  # erases all Timetable global instances.
  # hopefully this allows GC to work
  for o:global()
    if classname(global.(o))=='Timetable'
      print('disabing',o,'and set to nil')
      try
        global.(o).disable()
      except .. as err, msg
        print(o, ".disable() :", err, ",", msg)
      end
      global.(o)=nil
    end
  end
  global.timetable = nil
  print('gc=',tasmota.gc())
end

# encapsulates vars, strings, helper functions
# and the main class
def ttable_combo()
  
  import strict
  import string
  import gpio
  import mqtt
  import json
  
  var title='TTABLE :'
  var ttdir = '/timetable' # contains the config json

  # Parses the timetable ie '1000 13:55 8: 00'
  def parse_timetable(s)
    var tt = []
    # Adds an element to tt, ensures that the
    # timetable is sorted, without duplicates,
    # the above example becomes '08:00 10:00 13:55'
    def add(e)
      if type(e)!='string'
        print(e,'is not a string')
        return
      end
      var i=0
      while(i<size(tt))
        if e<=tt[i] break end
        i+=1
      end
      if i==size(tt) tt.push(e) return end
      if e==tt[i] return end
      tt.insert(i,e)
    end
    #
    if type(s)!='string' print('parse_timetable : wrong arg ' .. s .. 'type=' .. type(s)) return '' end
    s = string.tr(s,'\"\'\n\t\r,.#$-',' ')
    if true
      var s1
      # replaces multiple spaces with a single space
      while s != s1
        s1=s
        s=string.replace(s, '  ', ' ')
      end
    end
    s=string.replace(s,': ',':') # allows ie 10: 00 to be converted to 10:00
    s=string.replace(s,' :',':') # the same
    s= string.tr(s,':','') # 10:00 -> 1000
    s=string.split(s,' ') # '1000 1200' -> ['1000','1200']
    for c:s
      #if size(c)==3 c='0'+c end
      if size(c)!=4
        print('Bad time format : ' .. c)
        continue
      end # TODO msg
      if string.tr(c,'0123456789','')!=''
        print('Only digits allowed : '..c)
        continue
      end # todo msg
      if int(c[0..1])>23 || int(c[2..3])>59
        print('Bad time format : ' .. c)
        continue
      end
      c=c[0..1]+':'+c[2..3] # '1000' -> '10:00' again
      add(c) # add the entry in accending order and discards duplicates
    end
    return tt.concat(' ')
  end # func parse_timetable

  class Timetable
    #
    var pin # this is the physical GPIO pin
    var idx # controls the topic used tt/topic/bell+idx etc
    var disabled # disables all functionality bell, timers etc
    var stat_topic # tt/topic/messages+idx
    #
    var timetable_topic # timetable control topic tt/topic/timetable+idx
    var timetable # example '08:00 09:15 10:00 14:00 15:30'
    var timetable_lastpub # The last incoming mqtt message (even id came from us)
    var timetable_out_mqtt # the last messsage WE published
    #
    var duration # time in seconds the bell is ringing (number)
    var duration_topic # the topic tt/topic/duration+idx of the duration (string)
    var duration_lastpub # the last published message, even our own (string)
    var duration_out_mqtt # this is what we send (string)
    #
    var bell_topic # tt/topic/bell+idx
    var bell_lastpub
    var bell_out_mqtt
    #
    var active_days_topic
    var active_days # usually '*' or 'MON-FRI' or '1-5' must be understandabe by tasmota.set_cron()
    var active_days_lastpub
    var active_days_out_mqtt
    static var topic = 'tt/'+tasmota.cmd('Topic', true)['Topic']+'/'
    static default_timetable = '08:10 08:55'
    static default_duration = 6.0
    static default_active_days = '1-5'
    
    def init(pin, idx)
      self.disabled = false
      self.pin = pin
      self.idx = idx
      #
      #self.active_days = '1-5' # safe defaults instead of nil
      #self.duration = 6.0
      #self.timetable = '08:10 08:55'
      #
      print('pin =', self.pin)
      if idx != '' print('idx =', self.idx) end
      gpio.pin_mode(self.pin, gpio.OUTPUT)
      ##
      do
        var settings = self.fetch_disk_settings(true) # true = print verbose messages
        #
        self.duration = settings[0]
        self.duration_out_mqtt = str(self.duration) # only for startup no need to send msg
        self.timetable = settings[1]
        self.timetable_out_mqtt = self.timetable
        self.active_days = settings[2]
        self.active_days_out_mqtt = self.active_days
      end
      #
      self.install_cron_entries() # we can do this as timetable amd active_days are loaded
      #
      #var topic = 'tt/'+Timetable.topic+'/'
      #
      self.timetable_topic = Timetable.topic + 'timetable' + idx
      print('Subscribing to', self.timetable_topic, 'for timetable control')
      mqtt.subscribe(self.timetable_topic,
        def (_topic, _idx , tt)
          #print('Sub =', _topic , 'Msg =', tt)
          self.timetable_lastpub = tt
          self.set_timetable(tt)
        end
      )
      #
      self.duration_topic = Timetable.topic + 'duration' + idx
      print('Subscribing to', self.duration_topic, 'for setting bell duration')
      mqtt.subscribe(self.duration_topic,
        def (_topic, _idx , dur)
          #print('Sub =', _topic , 'Msg =', dur)
          self.duration_lastpub = dur
          self.set_duration(dur)
        end
      )
      #
      self.bell_topic = Timetable.topic + 'bell' + idx
      mqtt.publish(self.bell_topic, '0', true)
      self.bell_out_mqtt = '0'
      print('Subscribing to', self.bell_topic, 'for manual bell on/off')
      mqtt.subscribe(self.bell_topic,
        def (_topic, _idx , onoff)
          #print('Sub =', _topic , 'Msg =', onoff)
          self.bell_lastpub = onoff
          self.bell_onoff(onoff)
        end
      )
      #
      self.active_days_topic = Timetable.topic + 'active_days' + idx
      print('Subscribing to', self.active_days_topic, 'for setting the active days')
      mqtt.subscribe(self.active_days_topic,
        def (_topic, _idx, active_days)
          #print('Sub =', _topic , 'Msg =', active_days)
          self.active_days_lastpub = active_days
          self.set_active_days(active_days)
        end
      )
      #
      self.stat_topic = Timetable.topic + 'messages' + idx
      print('Using', self.stat_topic, 'for publishing messages')
      global.('tt'+idx)=self
      print('Global variable name', '"tt'+idx+'"', 'is the timetable instance')
      #
      print('INIT OK')
      
    end

    def fetch_disk_settings(p) # p = true- print otherwise quiet
      # Gets the settings from the disk and returns a [duration,timetable,active_days] list
      #if self.disabled print('fetch_disk_settings: disabled') return end
      var saveflag = false
      var j # the settings as a map
      try
        var fn = ttdir + '/tt' + self.idx + '.json'
        if p print('Opening "' .. fn .. '" to get the settings') end
        var f = open(fn)
        var data = f.read()
        f.close()
        j = json.load(data)
        if classname(j) != 'map'
          if p print('Cannot parse JSON') end
          j=nil
          #j = {}
          #saveflag = true
        end
      except .. as err, msg
        if p print('Error loading settings, using defaults') end
        #saveflag = true
        #j = {}
      end
      #
      if j==nil || j=={}
        self.save_settings_unc(Timetable.default_duration, Timetable.default_timetable, Timetable.default_active_days )
        return [Timetable.default_duration, Timetable.default_timetable, Timetable.default_active_days]
      end
      #
      var duration # = Timetable.default_duration
      do
        var duration_file = j.find('duration')
        if type(duration_file)=='int' || type(duration_file)=='real'
          # ok
          if p print('Got duration from settings', duration_file) end
          duration = self.parse_duration(duration_file) # TODO
          if duration != duration_file
            if p print('fetch_disk_settings: duration file=', duration_file, 'new=', duration) end
            saveflag = true
          end
        else
          # bogus val
          if p print('bogus/missing duration :', duration, type(duration)) end
          saveflag = true
          duration = Timetable.default_duration
        end
      end
      #
      var timetable
      do
        var timetable_file = j.find('timetable')
        if type(timetable_file) != 'string'
          if p print('bogus/missing timetable : ' .. timetable_file) end
          timetable = Timetable.default_timetable
          saveflag = true
        else
          if p print('Got timetable from settings :', timetable_file) end
          timetable = parse_timetable(timetable_file)
          if size(timetable)==0
            if p print('bogus/missing timetable') end
            saveflag = true
            timetable = Timetable.default_timetable
            if p print('Revert to default timetable', timetable) end
          end
          if timetable != timetable_file
            # Can happen only if timetable is edited directly on disk
            if p print('fetch_disk_settings: timetable file=', timetable_file, 'new=', timetable) end
            saveflag=true
          end
        end
      end
      #
      # TODO active days_file
      var active_days
      do
        var active_days_file = j.find('active_days')
        if type(active_days_file)!='string' && type(active_days_file)!='int'
          if p print('bogus/missing active_days :', active_days_file) end
          active_days= Timetable.default_active_days
          saveflag = true
          if p print('Using default active_days =', active_days) end
        else
          active_days = str(active_days_file)
          if p print('Got active_days from settings :', active_days) end
        end
      end

      if saveflag self.save_settings_unc(duration, timetable, active_days) end
      return [duration, timetable, active_days]

    end

    def add_cron_entry(e)
      var hh = int(e[0..1])
      var mm = int(e[3..4])
      var cronjob = '0 ' .. mm .. ' ' .. hh .. ' * * ' .. self.active_days
      print("Add cron entry", cronjob, self.cron_id(e))
      tasmota.add_cron(cronjob ,/->self.bell_on_with_check(), self.cron_id(e))
    end

    def save_settings_unc(dur, tt, ad)
      var j = {'duration':dur, 'timetable':tt, 'active_days':ad}
      try
        var f = open(ttdir + '/tt' + self.idx + '.json', 'w')
        f.write(json.dump(j))
        f.close()
        print("Saved settings to flash")
      except .. as err, msg
        print('save_settings(): Cannot write to flash', err, msg)
      end
    end

    def save_settings()
      if self.disabled print('save_settings: disabled') return end
      do
        var s = self.fetch_disk_settings()
        if s[0]==self.duration && s[1]==self.timetable && s[2]==self.active_days
          print('No need to save the settings')
          return
        end
      end
      self.save_settings_unc(self.duration, self.timetable, self.active_days)
    end

    def remove_cron_entries()
      for c:string.split(self.timetable, ' ')
        print('removing', self.cron_id(c))
        tasmota.remove_cron(self.cron_id(c))
        tasmota.yield()
      end
    end

    def install_cron_entries() # accepts string '1020 1140' or list ['10:20','11:40']
      for e:string.split(self.timetable, ' ')
        self.add_cron_entry(e)
      end
    end

    def cron_id(c)
      # Used to create a unique name for every cronjob
      return 'tt'+self.idx + '-' + c
    end

    def pub(m)
      if m==nil return end
      mqtt.publish(self.stat_topic, m)
    end

    def bell_on_with_check()
      # This function is called by cron, the difference is the check
      # that the ESP32 time is correct, or at least it is set to a reasonable
      # value. This check can save us from triggering the bell in a very unconvenient time.
      # for better reliablility it is recommendent to use a DS3231 clock
      if tasmota.rtc_utc() < 1720000000
        print('The system time is wrong')
        # No point in publishing as probably there is no internet connection
        # self.pub('The system time is wrong')
        print('The system time is wrong')
        return
      end
      self.bell_on()
    end

    def update_bell_mqtt(msg)
      var v = str(gpio.digital_read(self.pin)) # 0 or 1
      # if we did not send this message || last published message was different
      if self.bell_out_mqtt != v || self.bell_lastpub != v
        self.bell_out_mqtt = v
        mqtt.publish(self.bell_topic, v, true)
        self.pub(msg)
      end
    end

    def bell_on()
      #print('DEBUG bell_on()')
      if self.disabled print('bell_on: disabled') return end
      if self.duration < 0.1
        self.update_bell_mqtt('The bell is disabled')
        #self.pub('The bell is disabled')
        return
      end
      if gpio.digital_read(self.pin) == 0 # return end 
        gpio.digital_write(self.pin, 1)
        #if self.bell_out_mqtt!='1' # This on is triggered by us
        tasmota.remove_timer(self)
        tasmota.set_timer( int(self.duration*1000) , /->self.bell_off() , self )
      end
      self.update_bell_mqtt('The bell is ON')
      #self.pub()
    end

    def bell_off()
      if self.disabled print('bell_off: disabled') return end
      tasmota.remove_timer(self)
      #if gpio.digital_read(self.pin) == 0 return end
      gpio.digital_write(self.pin, 0)
      #self.pub()
      self.update_bell_mqtt('The bell is OFF')
    end

    def bell_onoff(x)
      #print('DEBUG arg =', x, 'self.bell_lastpub =', self.bell_lastpub, 'self.bell_out_mqtt =', self.bell_out_mqtt)
      if self.disabled print('bell_onoff: disabled') return end
      x = str(x)
      #if type(x)!='string' print('not a string') return end
      x = string.tr(x, ' \"\'\n\t\r', '')
      if x == '1'
        self.bell_on()
      elif x == '0'
        self.bell_off()
      else
        mqtt.publish(self.bell_topic, str(gpio.digital_read(self.pin)) )
        print('Use parameter 0/1')
      end
    end

    def update_duration_mqtt()
      # var v=string.format("%.1f", self.duration)
      # berry can correctly convert real to string for example 1.3 -> '1.3' not '1.29999'
      var d = str(self.duration)
      # if we did not send this message || last published message was different
      if self.duration_out_mqtt != d || self.duration_lastpub != d
        self.duration_out_mqtt = d
        mqtt.publish(self.duration_topic, d, true)
      end
    end

    def parse_duration(dur)
      if type(dur)=='int' || type(dur)=='real' dur = str(dur) end
      if type(dur) != 'string' print('set_duration: arg is', type(dur) ) return end
      dur = string.tr(dur, ',', '.')
      do
        # we check dur is a valid decimal number
        import re
        if re.search('^\\s*[0-9]*\\.?[0-9]*\\s*$', dur) == nil
          print('Wrong number format', dur)
          return
        end
      end
      dur = real(dur)
      if dur < 0 dur = 0 end
      if dur > 12 dur = 12 end # Maximum 12 seconds no need for more
      dur = int(dur*10+0.5)*1.0/10 # we need 1 decimal place maximum
      return dur
    end

    def set_duration(dur) # accepts real, integer or string
      if self.disabled print('set_duration: disabled') return end
      #if self.duration_out_mqtt == dur && self.duration_lastpub == dur return end # is common
      dur = self.parse_duration(dur)
      if dur==nil || self.duration == dur # berry can correctly do comparisons with reals, I dont know how, but it works
        self.update_duration_mqtt()
        return
      end
      self.duration = dur
      self.update_duration_mqtt()
      self.save_settings()
      #
      self.pub('Duration = ' .. dur .. ' sec')
    end

    def update_timetable_mqtt()
      var tt = self.timetable
      # if we did not send this message || last published message was different
      if self.timetable_out_mqtt != tt || self.timetable_lastpub != tt
        self.timetable_out_mqtt = tt
        mqtt.publish(self.timetable_topic, tt, true)
      end
    end

    def set_timetable(tt)
      if type(tt) != 'string' print('Cannot parse',tt, type(tt)) return end
      tt = parse_timetable(tt)
      if size(tt)==0
        print('Cannot parse', tt)
        self.update_timetable_mqtt()
        return
      end
      if tt == self.timetable ## string NEW TODO .concat(' ')
        #print('The timetable is the same bit by bit')
        self.update_timetable_mqtt()
        return
      end
      self.remove_cron_entries() # removes the old cron
      #
      self.timetable = tt
      self.save_settings() # saves the new timetable
      self.install_cron_entries() # creates the new cron
      #
      self.update_timetable_mqtt() # sends the tt to the tt topic (if needed)
    end

    def update_active_days_mqtt()
      var ad = self.active_days
      # if we did not send this message || last published message was different
      if self.active_days_out_mqtt != ad || self.active_days_lastpub != ad
        self.active_days_out_mqtt = ad
        mqtt.publish(self.active_days_topic, ad, true)
      end
    end

    def parse_active_days(active_days)
      if active_days == nil return self.active_days end
      active_days = string.tr(active_days,' \"\'\n\t\r', '')
      if active_days == '' return self.active_days end
      tasmota.remove_cron('test')
      try
        tasmota.add_cron("0 0 0 * * "+active_days, def() end , 'test') # empty closure for test
      except 'value_error'
        self.update_active_days_mqtt()
        print('Invalid active days')
        return self.active_days
      end
      tasmota.remove_cron('test')
      return active_days
    end

    def set_active_days(active_days_raw)
      #print('DEBUG1 active_days_raw='..active_days_raw)
      var active_days = self.parse_active_days(active_days_raw)
      #print('DEBUG2 active_days='..active_days)
      if size(active_days) == 0 || self.active_days == active_days
        # print('Not replacing active days')
        self.update_active_days_mqtt()
        return
      end
      #print('DEBUG3 active_days='..active_days)
      self.remove_cron_entries()
      self.active_days = active_days
      self.save_settings()
      self.install_cron_entries()
      self.update_active_days_mqtt()
      #self.pub('active days updated')
    end
    
    def disable() # Releases recourses to be garbage collected by BerryVM
      if global.('tt'+self.idx) != self return end
      self.remove_cron_entries()
      self.bell_off()
      #
      mqtt.unsubscribe(self.timetable_topic)
      mqtt.unsubscribe(self.duration_topic)
      mqtt.unsubscribe(self.bell_topic)
      mqtt.unsubscribe(self.active_days_topic)
      #self.pub('DISABLED')
      self.disabled = true
    end

    def deinit()
      if !self.disabled self.disable() end
      print('tt'+self.idx + '.deinit()')
    end

  end # class timetable

  def instance_generator(pin, idx)
    do
      import path
      if path.exists(ttdir) && !path.isdir(ttdir)
        print('Fatal error : ', ttdir, 'is not a directory, remove it first')
        return
      end
      if !path.isdir(ttdir)
        path.mkdir(ttdir)
      end
    end
    if idx==nil
      idx=''
    elif type(idx)!='int'
      print('Need an index')
      return
    end
    idx=str(idx)
    if global.('tt'+idx) != nil
      print('global var', 'tt'+idx, 'is used')
      return
    end
    if type(pin)!='int' || pin<0 || pin>30
      print(title,'Wrong PIN, 0-30 accepted, be careful many pins are unusable', pin)
      return
    end
    print('Creating timetable :', 'tt'+idx)
    # Created the 'tt' or 'tt2' etc instance
    global.('tt'+idx) = Timetable(pin , idx)
    #return global.('tt'+idx)
  end # instance_generator
  global.timetable = instance_generator
end # ttable_combo()

# creates the "timetable" global function
ttable_combo()
# Ensures we cannot call ttable_combo() again
ttable_combo = nil
# Now we have no access to ttable_combo() and we can only call
# [global.]timetable(GPIO_PIN [, idx])

# 08:10 08:55 09:00 09:45 09:55 10:40 10:50 11:35 11:45 12:30 12:40 13:25 13:30 14:10

# GPIO-1 is connected with the Relay. Classic bells are inductive loads and MAY be
# an option to use an ~220V SSR (these are TRIAC based as far as I know)
# the second argument is the name of the timetable and if nil,
# it gets the "topic" from the tasmota module

# This declaration should be in autoexec.be, but for development allows fast reload
if global.('BELL_PIN')!=nil
  global.timetable(BELL_PIN)
end
