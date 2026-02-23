# Automatic School Bell Timer

![SchoolTimer](timer.png)

### WARNING
⚡🚨 **WORKING WITH MAINS VOLTAGE IS VERY DANGEROUS. TAKE ALL PRECAUTIONS AND DO IT AT YOUR OWN RISK.** Ask a licensed technician to do the mains connection. The AC connector (schematic) should be connected ONLY after fully assembling the parts and closing the project box. 🚨⚡

### Features

- Very accurate, using NTP (Network Time Protocol). The time never needs to be set manually.

- Time Zone and Automatic Daylight Saving Time support.

- Resistant to network failures and power outages. The module keeps accurate time and only needs the Internet to correct time drift (less than 1 second per week). We use a dedicated DS3231 module (backed by a lithium coin cell) for this.

- Easy configuration via PC or mobile.

- Very few parts (see the schematic). Easy assembly and low cost.

- No PCB and no soldering required (if you buy an ESP32 board with pre-soldered headers).

- Reliable hardware. It is expected to work for many years. The minimal part count and airtight enclosure help ensure this.

- With (optional) MQTT, it can also be monitored and controlled outside of the local network.

- (Rarely needed) Ability to use more than 1 timetable, even different bells.

- Free software. Both Tasmota and the Berry script are open source with very permissive licenses.

### Tips (Important, do not skip this)
- Prefer to buy some parts and wait a few days rather than using old/broken/unsuitable parts you happen to already own. This project is about reliability. Read the README before hunting for parts in online stores.

- The most important part is a good quality SSR with low leakage current (see below).

- If you are going to solder the headers yourself, only solder the pins that you need. This will make the assembly easier and less error-prone.

- Avoid Micro-USB boards. They are very unreliable in the long run (SMD, crack unexpectedly with minor mechanical stress). Micro-USB cables are gradually disappearing, and you may not find one in usable condition if you need a replacement.

- The LED with cable and resistor, even with Dupont connectors, can be found in online stores.

- Boards with chip antennas (in my observation) seem to have very bad WiFi signal. PCB antennas are OK.

- Some USB-C cables are charge-only, so you cannot communicate with the board. Make sure you use a data cable, especially for the final installation.

- A paper with recovery instructions, password, pinout, etc., folded and placed inside the timer box will save your day a few years later.


### Step 1. Connect the electronic parts as shown in the schematic above (without the box).
The instructions and pinout are for the DEVkit 30-pin/38-pin boards (ESP32 based). For other boards see the dedicated section below, especially which pins you can use. A [terminal adapter](https://duckduckgo.com/?q=esp32+screw+terminal+adapter&t=lm&iar=images&iax=images&ia=images) can make the assembly even easier. You will need the board, a DS3231 module, a solid state relay, 1 optional LED, and a quality USB **DATA** cable.
For software installation/testing you can temporarily replace the relay with an LED. If you connect the SSR directly, **do not connect any mains load to it.** The built-in LED shows when it is activated.

### Step 2. Tasmota installation.
This is a short guide; for more info go to the Tasmota installation page.

Connect the ESP board to your computer with the USB cable. Tasmota supports a very convenient web-based installer; there is no need to install anything on your computer. Linux users may get a serial permission error; you will need to add yourself to the "dialout" group.

- Go to https://tasmota.github.io/install/ (or simply search for ["tasmota installer"](https://duckduckgo.com/?t=h_&q=tasmota+installer)). Tasmota (English) is the safest option.

- Press the connect button → choose the serial port → check "Erase Device" → Next → Install (**an ESP boot button press might be needed**)

- After the installation is complete, press Next → Configure WIFI. If you cannot communicate with the board, reset and reconnect. For other configuration methods see the Tasmota installation page.

- Use the current Access Point, even if it will be different at the final location. When we move to the final location we can change the Access Point.

- When connected, click Visit Device.
  Write down the IP address. It will be something like 192.168.1.xx for home routers. This is the web page of the Tasmota system. It is accessible from the LAN.
  
- **From now on we are working from the browser using the IP address. We will need a serial connection (USB cable) again only if we want to change WiFi.**

- Set the TimeZone/Daylight Saving settings.
  Go to [Tasmota Timezone Table](https://tasmota.github.io/docs/Timezone-Table/). Copy the necessary line and paste + execute it in Tools → Console (NOT the Berry console).

  Execute the console "time" command.
 
  You will see the time change to your local time.

- Again in console (and don't forget the "backlog"), various important settings:
  ```berry
  Backlog SetOption53 1; SetOption65 1; SetOption36 0; SetOption55 1; SetOption56 1; SetOption0 0; WifiConfig 5; PowerOnState 0;
  ```
  Replace "school" with the school's name, but only use Latin alphanumeric characters.
  ```berry
  backlog DeviceName school; FriendlyName school; Topic school; Hostname school; mqttlog 2; mqttclient school-%06X;
  ```
  The module will restart automatically and in the boot messages (web console), you will see something like:
  
  mDN: Initialized "school.local"
  
  From now on you can type "school.local" in the browser address bar instead of the IP. This is not very reliable unfortunately, so keep the IP as well.

### Step 3. Pin configuration
Web Browser → IP address (or school.local) → Configuration → Module

Adjust the pin configuration for your ESP board. As you can see we have used D25 and D26 to power the DS3231 (needs only about 4mA). This allows for easy cabling. Use real VCC and GND if you prefer.

**DevKit (schematic)**
```
#### DS3231 module
GPIO 25 → OutputHi (acts as VCC)
GPIO 26 → OutputLow (acts as GND)
GPIO 32 → I2C SCL
GPIO 33 → I2C SDA (Be careful NOT SPI SDA)

#### Indicating LED (Optional)
GPIO 13(D13) → LedLink_i
# GND is next to D13 if we use DevKit
## SSR/Relay
GPIO 4 → Relay(1)
```

**Alternative build with Luatos ESP32-C3 board (schematic)**
```
GPIO 4 → I2C SCL
GPIO 5 → I2C SDA (Be careful NOT SPI SDA)
GPIO 9 → LedLink_i
GPIO 2 → Relay(1)
```

Save the settings and the module will reboot. If you have installed the LED you will see it blinking until the boot process is complete. When the module connects to WiFi, the LED will stay active indicating everything is OK.

### Step 4. Loading the DS3231 real-time clock driver.
The driver lives on this [GitHub page](https://github.com/pkarsy/TasmotaBerryTime/tree/main/ds3231); for convenience, however, I include the installation instructions here:

Web Browser → IP address (or school.local) → Tools → Berry scripting console

Paste and execute the following code:
```berry
do
  var fn = 'ds3231.be'
  var cl = webclient()
  var url = 'https://raw.githubusercontent.com/pkarsy/TasmotaBerryTime/refs/heads/main/ds3231/' + fn
  cl.begin(url)
  if cl.GET() != 200 print('Error getting', fn) return end
  var s = cl.get_string()
  cl.close()
  var f = open('/'+fn, 'w')
  f.write(s)
  f.close()
  print('Installed', fn)
end
```

Now you have the driver "ds3231.be" in the Tasmota filesystem. Without leaving the console:
```berry
load('ds3231')
```
and hopefully you will see the driver finding the module. If the driver cannot find the DS3231 chip, either the cabling is incorrect or the pins are not configured correctly in the Tasmota configuration page (see the previous step). **No need to set the DS3231 time; the driver will do it for you.**

### Step 5. Berry script installation ("timetable.be")
This script implements the timer engine and the web configuration page.

Again in the Berry console, paste and execute the following code:

```berry
do
  var fn = 'timetable.be'
  var cl = webclient()
  var url = 'https://raw.githubusercontent.com/pkarsy/AutomaticSchoolBellTimer/refs/heads/main/' + fn
  cl.begin(url)
  if cl.GET() != 200 print('Error getting', fn) return end
  var s = cl.get_string()
  cl.close()
  var f = open('/'+fn, 'w')
  f.write(s)
  f.close()
  print('Installed', fn)
end
```

Now you have the "timetable.be" script installed.

Without leaving the Berry Console, write:

```berry
load('timetable')
```
You will see the timetable starting, using some defaults.


## Step 6. Load the scripts automatically on boot

Tools → Manage filesystem 
Edit "autoexec.be" **(the white icon with the pencil)** if the file exists, otherwise create it yourself.

Append the lines:
```berry
load('ds3231') # for the DS3231

load('timetable') # for the timetable
```
And save.

Restart (Main Menu → Restart) the module and go with the browser to the same IP address (or school.local) as previously. You will see a "School Timer" button on top. **This is the configuration page of the School Timer.** For the active days the correct setting is almost certainly 1-5 or MON-FRI. For tests you can set it to * (means ALL days, even weekends) but set it correctly before actual use. Set an alarm for the next few minutes and check that it is working.

### Step 7. Collecting the rest of the hardware.
As you can see (schematic) you will need a few more parts to complete the project:
- A few jumper cables (2.54mm spacing). Use only unused cables, you have been warned.
- Alternatively a Devkit screw terminal breakout and simple copper wires.
- A USB charger. No need to be powerful, but it helps to be of good quality, for example from an old phone.
- A connector for the bell connection.
- ON/OFF switch. This enables/disables the timer.
- A project enclosure, preferably airtight, to protect from moisture and dust. Do not try to use a very small box; it is better to have some room to organize the parts well with the SSR and AC cables at some distance. Be prepared to make some holes for the cables, LED, switch, and find some way (for example hot glue, epoxy, tape) to secure everything. There are excellent online tutorials on how to do this.

### Step 8. Protect the web interface from unauthorized access
Set a Tasmota Web Admin Password to access the page. school.local (or IP) → Configuration → Other → Web Admin Password (Username is "admin"). The page is not encrypted, so it is not very secure, but it is on LAN only, so I guess it is OK. Be sure to keep the password written in a safe place.

### Step 9. Install the electrical connector
AGAIN BE CAREFUL, THIS IS ELECTRICAL WORK.
SWITCH OFF THE POWER TO THE ELECTRICAL BELLS. Usually there is a dedicated switch in the electrical panel.
Almost certainly the school already has a wall button for the bell. In that case the most straightforward way is to install the connector's 2 cables at the 2 poles of the switch. With this configuration the bell rings whenever the SSR/Relay is activated. There is no need to uninstall the old timer (if it exists), just disable it.

### Step 10. Reconfigure WIFI to use the new Access Point.
If you configured the WiFi before at home, you have to reconfigure it to use the new Access Point.
**Plug the USB cable into your computer** (Chromium-based browser) and use the same Tasmota installer.
"Configure Wifi" does not always work.

The most reliable way is to use the "Logs & Console":
```sh
backlog ssid1 MyNewAP; password1 MyNewPassword
```
For the tinkerers: Alternatively you can use a serial terminal like gtkterm; however, in this case, instead of ENTER you may need Ctrl-J.

Wait for the module to reset and see if the connection works. You will see the new IP (school.local should also work).

Unplug the cable from the laptop and use the USB charger. Connect to the Timer using the Tasmota web interface (IP or school.local). You can review the settings of the timer; from now on it is ready for work.

### Last Step. Document the recovery process
Document on paper and/or in an app how to recover from a missing/changed Access Point. Keep in a folder on your PC:
- A photo of the timer (ESP32 and cabling)
- The pin configuration (as simple text)
- The WiFi configuration (SSID, password, maybe IP if it is static)


### Congratulations!


## Optional topics, some of which may be of interest to you.

### How to power OFF the ESP32
Unplug the USB charger. The ON/OFF button, as we have seen, only disconnects the relay output.

### More than 1 timetable/bells
Generally works. It will be documented when it is ready.
```
global.start_timetable(2)
```
The second timetable can be (for example) an additional class on Friday afternoon.

### No Manual "RING" button?
This is the job of a wall button, independent of our timer. All schools I know have one.

### MQTT server, optional but useful for debugging and remote control
There are many online MQTT servers, free and paid, and you may prefer them instead of hosting your own. Examples are (free, and there are more):
- hivemqtt.com
- flespi.com

You must use TLS connection; all online servers support secure connections. **If you are not using TLS, better not use MQTT at all.**

You will also need an MQTT client such as:

- MQTT-Explorer
- MQTTX
- (lots of terminal clients)
- (Android clients)
- (Android Termux clients)

In Tasmota console, we enable MQTT:
```sh
setoption3 1
```
After restart paste the following commands, modified of course for your MQTT server:
```sh
backlog topic school; setoption132 1; SetOption103 1; MqttHost mqtt.hostname.io; MqttPort 8883; MqttUser myusername; MqttPassword mypassword;
```

The module will restart again and this time you should see the module connecting and sending status messages to the MQTT server.

| publish topic | payload       | action | response topic |
| ------------- | ------------- | ----- | ------- |
| cmnd/school/br | tt1.bell_on() | rings the bell | stat/school/RESULT |
| cmnd/school/br | tt1.timetable | shows the timetable | stat/school/RESULT |
| cmnd/school/br | tt1.set_timetable("1000 1045")| sets the timetable | stat/school/RESULT |
| cmnd/school/br | tt1.duration | shows the duration | stat/school/RESULT |
| cmnd/school/br | tt1.set_duration(5) | sets the duration | stat/school/RESULT |
| cmnd/school/br | tt1.active_days | shows the active days | stat/school/RESULT |
| cmnd/school/br | tt1.set_active_days("1-5") | set the active days | stat/school/RESULT |

There are many MQTT GUI apps on mobile (and Web) allowing you to automate these commands with buttons if you need this, but I think it is overkill given how rarely you need to change the settings.

### Control the timer with console commands.
You can control the timetable with console (serial console or web console) commands.
```sh
br tt1.bell_on()
br tt1.set_timetable("1000 1045")
br tt1.set_duration(5)
br tt1.set_active_days("1-5")
```

### Do I need to update the Tasmota system?
Probably not. If it is working, don't fix it. The same applies to the Berry script.

### Why not use the built-in Tasmota timers?
They are not very convenient for this specific application. Also there are cases (schools with day+afternoon timetable) where the available timers are not enough. The "timetable.be" script offers an unlimited number of timers and a relatively easy-to-use web interface.

### 5GHz WiFi: Not working, but not a big deal.
At the moment all ESP chips only work with WiFi 2.4 GHz. This is OK, as most Access Points support 2.4 GHz and 5GHz at the same time; just be sure to enable it. When 5GHz chips become available, it will be trivial to include them.

### Why Tasmota and not an embedded programming language (Arduino, MicroPython, CircuitPython, Lua, ESP-IDF, Toit)?
Tasmota acts as an operating system and solves for us some very important aspects of the project:

- Network connectivity (this includes WiFi, TLS, optional MQTT client, and of course credentials storage).

- Keeping the system time accurate using the NTP protocol.

- A customizable web server, which allows us to easily create a configuration page.

- Time Zone and Daylight Saving Time.

- Easy control of peripherals.

- Filesystem and settings storage.

- A scripting language, the excellent Berry Language.

- Easy device connection (DS3231 specifically).

- An excellent web-based installer. No software/programming environment is needed for installation (only a browser) and it works the same on all operating systems.

- Easy recovery using the same Tasmota web installer (or any serial terminal if you prefer).

### How Tasmota gets the time from the Internet.
This crucial operation is performed by the Tasmota system itself and not by the "timetable.be" script.
It uses the ubiquitous and ultra-reliable NTP protocol. The default servers just work, so no need to configure anything.

### Notes on using various boards

- ESP32 boards (like DevKit) are OK. Be careful with [the pins you can use.](https://duckduckgo.com/?q=esp32+what+pins+to+use). One problem is that most of the boards in online stores still use Micro-USB. Ensure the board has USB-C.

- ESP32-C3. It is also OK and the WiFi performance is the best. Some boards do not have serial hardware but again they are very reliable. I have tested Luatos ESP32-C3 and WeAct ESP32-C3. They are both OK.

- ESP32-S2. Some boards come without PSRAM and are practically unusable as S2 comes with very limited built-in RAM. I find the web interface very laggy, and the USB frequently disappears. Also setting the board to programming mode can be difficult. I generally cannot see the point of using ESP32-S2 for this specific project.

There are many board-specific limitations:

- No 5V pin, so you cannot use a 5V electromechanical relay. Solid state relays (SSR) work fine.

- Limited GND pins, but as we said you can simulate VCC and GND with GPIO pins.

- Some boards have only a Micro-USB version. Avoid it.

- Generally avoid tiny boards; they almost always are missing something useful. But most importantly some/all use chip antennas. Some sources claim they can be OK, but I disagree; the 2 different chip antenna boards I have tested perform very poorly (2 meters range, unusable for the bell timer). If you are insisting on using a chip antenna, test it and check the signal (Tasmota Main → Information) and move around to see how it performs. All PCB antenna boards I have tested are fine.

- ESP8266 boards do NOT work. They cannot run the Berry interpreter.

### Relay types

- Be very careful with the SSR or Relay; it must match the voltage and the bell type.

- I have tested the project with a "GEYA GSR1" and also with "GEYA VSR8". Keep in mind that some SSRs have leakage in the mA range and this can cause safety concerns.

- A MOV and a TVS diode (parallel with the SSR) can absorb a lot of overvoltage due to transients. It is a must for this project (reliability).

- A [5V Relay breakout](https://duckduckgo.com/?q=5V+Relay+breakout+single&t=lm&iar=images&iax=images&ia=images) probably works but I have not tested it. I believe there is no reason to use electromechanical relays (for AC bells) given how good and affordable SSRs have become.

### Why this project was created
I have tested many timer solutions in the past. The limitations were severe, and I document them here in no particular order.

- Very limited number of timers, usually fewer than the 14-20 a school needs.

- Hard to use, almost unusable hardware control panel. Each one has a different interface.

- Severe time drift. This means constant maintenance and/or that the bell never rings at the expected time. A few minutes or even seconds error does not seem to be a problem at first glance, but the real problem is the argument with the students that the time has passed, that they are going to miss the bus, etc.

- Not capable of switching to Daylight Saving Time. Even WiFi plugs have problems with this.

- Computer-based solutions are overkill and suffer from complexity and unreliability. Operating system updates, broken hardware, high electricity consumption, audio equipment maintenance are some of the drawbacks.

- Wall WiFi plugs like TUYA, Sonoff, etc. almost always have the problem of a limited number of timers. Each one needs a different mobile application, and they can ONLY be controlled by their respective mobile app.

- Especially WiFi plugs cannot be used as [dry (no voltage) contacts](https://en.wikipedia.org/wiki/Dry_contact) (see **electrical connection**). Usually this alone is a deal breaker.

- WiFi-based timers do not have internal battery-backed RTC, and without a network, even temporarily, will lose the time.

- Limited/no protection from moisture and dust.

### Another solution to protect the web page (additionally/instead of password).
Use a WiFi Access Point which is dedicated for the bell. This can be an old unused access point. This way any changes to the primary network do not disturb the bell. To be able to access the Tasmota Web Page you have to connect to the same AP, so you have to keep the AP/password somewhere. Or it can be a second ("IoT") access point available via the configuration of many commercial Access Points.
