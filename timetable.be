# This block is used for live updates

do
  import strict
  # erases all TimetableWeb global instances.
  # hopefully this allows GC to work
  for o:global()
    if classname(global.(o))=='TimetableWeb'
      print('disabing TimetableWeb instance',o)
      try
        global.(o).disable()
      except .. as err, msg
        print(o, ".disable() :", err, ",", msg)
      end
      global.(o)=nil
    end
  end
  global.timetableweb = nil
  #print('gc=',tasmota.gc())
end

do
  import strict
  # erases all Timetable global instances.
  # hopefully this allows GC to work
  for o:global()
    if classname(global.(o))=='Timetable'
      print('disabing Timetable instance',o)
      try
        global.(o).disable()
      except .. as err, msg
        print(o, ".disable() :", err, ",", msg)
      end
      global.(o)=nil
    end
  end
  global.timetable = nil
end

# encapsulates vars, strings, helper functions
# and the main class
#def ttable_combo()
do
  #
  import strict
  import string
  #import gpio
  import json
  #
  var title='TTABLE :'
  var IDXS=['1','2','3','4','5']
  
  def idxcheck(idx)
    if idx==nil || idx==0 || idx==1 idx='1' end
    idx=str(idx)
    if IDXS.find(idx)==nil
      return -1
    end
    return idx
  end

  def datetime()
    var t = tasmota.rtc()['local']
    return tasmota.strftime("%d %B %Y %H:%M:%S", t)
  end

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
    s = string.tr(s,'\"\'\n\t\r,.#$-','          ')
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
    #var pin # this is the relay number in tasmota config
    var idx # controls the topic used tt/topic/bell+idx etc
    var disabled # disables all functionality bell, timers etc
    #
    var timetable # example '08:00 09:15 10:00 14:00 15:30'
    #
    var duration # time in seconds the bell is ringing (number)
    var active_days # usually '*' or 'MON-FRI' or '1-5' must be understandabe by tasmota.set_cron()
    #
    static default_timetable = '08:10 08:55'
    static default_duration = 6.0
    static default_active_days = '1-5'
    
    def init(idx)
      print("init", idx)
      self.disabled = false
      #self.pin = pin
      self.idx = idx
      #
      #print('relay =', self.pin)
      #if idx != '' print('idx =', self.idx) end
      print('idx =', self.idx)
      # gpio.pin_mode(self.pin, gpio.OUTPUT)
      ##
      do
        var settings = self.fetch_disk_settings(true) # true = print verbose messages
        #
        self.duration = settings[0]
        self.timetable = settings[1]
        self.active_days = settings[2]
      end
      #
      self.install_cron_entries() # we can do this as timetable amd active_days are loaded
      self.set_pulsetime()
      #
      print('INIT OK')
      
    end

    def fetch_disk_settings(p) # p = true- print otherwise quiet
      # Gets the settings from the disk and returns a [duration,timetable,active_days] list
      #if self.disabled print('fetch_disk_settings: disabled') return end
      var saveflag = false
      var j # the settings as a map
      try
        var fn = '/.tt' .. self.idx .. '.json'
        if p print('Opening "' .. fn .. '" to get the settings') end
        var f = open(fn)
        var data = f.read()
        f.close()
        j = json.load(data)
        if classname(j) != 'map'
          if p print('Cannot parse JSON') end
          j=nil
        end
      except .. as err, msg
        if p print('Error loading settings, using defaults') end
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
        var f = open('/.tt' .. self.idx .. '.json', 'w')
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
      return 'tt' .. self.idx .. '-' .. c
    end

    def bell_on_with_check()
      # This function is called by cron, the difference is the check
      # that the ESP32 time is correct, or at least it is set to a reasonable
      # value. This check can save us from triggering the bell in a very unconvenient time.
      if tasmota.rtc_utc() < 1720000000
        print('The system time is wrong')
        return
      end
      self.bell_on()
    end

    def bell_on()
      if self.disabled print('bell_on: disabled') return end
      if self.duration < 0.1
        print('The bell is disabled')
        return
      end
      #if gpio.digital_read(self.pin) == 0 # return end 
      #  gpio.digital_write(self.pin, 1)
      #  tasmota.remove_timer(self)
      #  tasmota.set_timer( int(self.duration*1000) , /->self.bell_off() , self )
      #end
      #print('The bell is ON')
      tasmota.set_power(self.idx-1, true)
    end

    def bell_off()
      if self.disabled print('bell_off: disabled') return end
      #tasmota.remove_timer(self)
      #gpio.digital_write(self.pin, 0)
      #print('The bell is OFF')
      tasmota.set_power(self.idx-1, false)
    end

    def bell_onoff(x)
      if self.disabled print('bell_onoff: disabled') return end
      x = str(x)
      x = string.tr(x, ' \"\'\n\t\r', '')
      if x == '1'
        self.bell_on()
      elif x == '0'
        self.bell_off()
      else
        print('bell_onoff : Use parameter 0/1')
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
      if dur > 15 dur = 15 end # Maximum 15 seconds, no need for more
      dur = int(dur*10+0.5)*1.0/10 # we need 1 decimal place maximum
      return dur
    end

    def set_duration(dur) # accepts real, integer or string
      if self.disabled print('set_duration: disabled') return end
      dur = self.parse_duration(dur)
      if dur==nil || self.duration == dur # berry can correctly do comparisons with reals, I dont know how, but it works
        return
      end
      self.duration = dur
      self.set_pulsetime()
      self.save_settings()
      print('New duartion', dur, 'saved')
    end

    def set_pulsetime()
      if self.duration<1.0
        #pulsetime(10)
        tasmota.cmd("pulsetime"..self.idx.." 10")
        return
      end
      if self.duration<=11.1
        var p = int(self.duration *10+0.5)
        tasmota.cmd("pulsetime"..self.idx.." "..p)
        return
      end
      var duration=int(self.duration+0.5)
      if duration<12
        duration=12
      end
      tasmota.cmd("pulsetime"..self.idx.." "..(duration+100))      
    end

    def set_timetable(tt)
      if type(tt) != 'string' print('Cannot parse',tt, type(tt)) return end
      tt = parse_timetable(tt)
      if size(tt)==0
        print('Cannot parse', tt)
        return
      end
      if tt == self.timetable ## string NEW TODO .concat(' ')
        #print('The timetable is the same bit by bit')
        #self.update_timetable_mqtt()
        return
      end
      self.remove_cron_entries() # removes the old cron
      #
      self.timetable = tt
      self.save_settings() # saves the new timetable
      self.install_cron_entries() # creates the new cron
      #
    end

    def parse_active_days(active_days)
      if active_days == nil return self.active_days end
      active_days = string.tr(active_days,' \"\'\n\t\r', '')
      if active_days == '' return self.active_days end
      tasmota.remove_cron('test')
      try
        tasmota.add_cron("0 0 0 * * "+active_days, def() end , 'test') # empty closure for test
      except 'value_error'
        print('Invalid active days')
        return self.active_days
      end
      tasmota.remove_cron('test')
      return active_days
    end

    def set_active_days(active_days_raw)
      var active_days = self.parse_active_days(active_days_raw)
      if size(active_days) == 0 || self.active_days == active_days
        # print('Not replacing active days')
        return
      end
      self.remove_cron_entries()
      self.active_days = active_days
      self.save_settings()
      self.install_cron_entries()
      #self.update_active_days_mqtt()
      print('active days updated')
    end
    
    def disable() # Releases recourses to be garbage collected by BerryVM
      if global.('tt' .. self.idx) != self return end
      self.remove_cron_entries()
      self.bell_off()
      self.disabled = true
    end

    def deinit()
      if !self.disabled self.disable() end
      print(self, 'deinit()')
    end

  end # class timetable

  def tt_generator(idx)
    #idx = idxcheck(idx)
    #if idx==-1
    #  print('Wrong index, must be ', IDXS)
    #  return
    #end
    if global.('tt' .. idx) != nil
      print('global var', 'tt' .. idx, 'is used')
      return
    end
    #if type(pin)!='int' || pin<0 || pin>30
    #  print(title,'Wrong PIN, 0-30 accepted, be careful many pins are unusable', pin)
    #  return
    #end
    print('Creating timetable :', 'tt'..idx)
    global.('tt'..idx) = Timetable(idx)
  end # tt_generator

  import webserver

  def webpage_show(idx)
      if !webserver.check_privileged_access() return nil end
      var t = global.('tt'..idx)
      webserver.content_start("Timetable Settings"..idx) # title of the web page
      webserver.content_send_style() # standard Tasmota style
      if webserver.arg_size()==1
        print('arg0=',webserver.arg(0))
        if webserver.arg(0)=='1'
          t.bell_on()
        end
      elif webserver.arg_size()==3
          var timetable = webserver.arg(0)
          var duration = webserver.arg(1)
          var active_days = webserver.arg(2)
          t.set_active_days(active_days)
          t.set_duration(duration)
          t.set_timetable(timetable)
          webserver.content_send('<p style="text-align:center; background-color: green; color: white;">The settings are stored</p>')
      end
      if global.ds3231 != nil && global.ds3231.active()
        webserver.content_send('<p style="text-align:center">DS3231 is working</p>')
      else
        webserver.content_send('<p style="text-align:center; background-color: red; color: white;">DS3231 not found</p>')
      end
      webserver.content_send('<p style="text-align:center">Local Time (Refresh the page to update) : ')
      webserver.content_send(datetime())
      webserver.content_send('</p>')
      webserver.content_send('<br><button onclick="location.href=\'/tt' .. idx .. '?bell=1\'" style="background-color:red;">Ring the bell</button><br><br>')
      webserver.content_send('<form action="/tt' .. idx .. '" id="ttform">')
      webserver.content_send('<label for="tt">Timetable ' .. idx .. ' (24h format, can be ie 08:50 or 0850) :</label>')
      webserver.content_send('<input type="text" id="tt" name="tt" value="'+t.timetable+'"><br><br>')
      webserver.content_send('<label for="dur">Bell duration: (5 or 4.5 etc seconds)</label><input type="text" id="dur" name="dur" value="' .. t.duration .. '"><br><br>')
      webserver.content_send('<label for="ad">Active Days (1-5 means MON-FRI, * means all days)</label><input type="text" id="ad" name="ad" value="' .. t.active_days .. '"><br><br>')
      webserver.content_send('</form>')
      webserver.content_send('<button type="submit" form="ttform">Save settings ' .. idx .. '</button>')
      webserver.content_button(webserver.BUTTON_MAIN)
      webserver.content_stop()
  end

  class TimetableWeb
      var idx

      def init(idx)
          self.idx = idx
          if global.('tt'+self.idx)==nil
            print('Error : timetable tt' .. self.idx, 'not found')
            return
          end
          tasmota.add_driver(self)
          if tasmota.wifi('up')
            self.web_add_handler()
          end
      end

      def web_add_main_button()
          webserver.content_send('<button onclick="location.href=\'/tt' .. self.idx .. '\'">School Timer ' .. self.idx .. '</button><br><br>')
      end

      def web_add_handler()
        webserver.on('/tt' .. self.idx, /-> webpage_show(self.idx))
        print('Created web page for tt' .. self.idx)
      end

      def disable()
          webserver.on('/tt' .. self.idx, / -> nil)
          tasmota.remove_driver(self)
      end

      def deinit()
          print(self, 'deinit()')
      end
  end

  def web_generator(idx)
    idx = idxcheck(idx)
    if idx==-1 print('Wrong index, must be ', IDXS) return end
    if global.('tt' .. idx) == nil print('Timetable is missing, not creating web interface') return end
    if global.('ttweb' .. idx) != nil print('ttweb' .. idx,'already exists, not creating web') return end
    global.('ttweb' .. idx) = TimetableWeb(idx)
  end

  def start_timetable(idx)
    tt_generator(idx)
    web_generator(idx)
  end
  #for idx:IDXS
  #  if global.('TTPIN'+idx) != nil
  #    tt_generator(global.('TTPIN'+idx), idx)
  #    web_generator(idx)
  #  end
  #end
  global.start_timetable = start_timetable

end # ttable_combo()

#ttable_combo()
#ttable_combo = nil #  we cannot call ttable_combo() again
