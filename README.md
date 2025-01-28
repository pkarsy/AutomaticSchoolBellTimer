# timetable
Automatic school bell timer based on the popular ESP32x series and Tasmota.

PHOTO BOX - PHOTO materials

# WARNING
Most electromechanical school bells use mains voltage (230/110V). The project can be assembled and be ready, without the need to be exposed to such a voltage. However when installing to the final location a connection has to be made to the bell.
**WORKING WITH MAINS VOLTAGE IS VERY DANGEROUS. KEEP ALL PRECAUTIONS AND DO IT AT YOUR OWN RISK.** In some coutries It may even be illegal to to it yourself.
If you are unsure ask a licenced tecnician to do the mains connection.

## Problems with existing solutions
- Very limited number of timers usually smaller than a 14-20 a school needs.
- Hard to use control panel.
- Severe time drift. This basically means constant maintenance and/or that the bell never rings at the expected time. A few minutes/even seconds error does not seem to be a problem at first glance, but the real problem is the argument with the students that the time is passed that they are gonna loose the bus etc.
- None of the timers I have checked is capable of switching to Daylight time. Even WIFI plugs have problems.
- Computer based solutions suffer from complexity and unreliability. Operating system updates, broken harware, high electricity consumption, audio equipment maintainance, are some of the drawbacks. And computers even theese days, easily lose the time.
- Wall WIFI plugs like TUYA sonoff etc have almost always the problem with limited number of timers. Not to mention every one needs a different mobile application, and they can ONLY be controlled by their modile app.
- Especially WIFI plugs do not have the option to be used as **dry contacts** (See **electrical connection**) this alone can be a deal braker.
- Wifi based timers do not have internal battery backed RTC, and without network, lose the time.
- Limited/No protection from moisture and dust.

## Design Goals
- Very accurate, using NTP(Network Time Protocol).
- Time Zone and Daylight Savings Time
- Resistant to Network disconnections and power outages. The module keeps accurate time on such occasions, and only rarely needs to connect to the Internet to fix the time drift(less than 1 sec per week without Internet) We use a dedicated DS3231 module(backed by a lithium coin cell) for this.
- Simple Web Control Panel, via PC or mobile. With the option of MQTT, it can also be monitored and controlled outside of the local network.
- As few parts as possible, no PCB, and no soldering at all (if we choose an ESP32 board with presoldered headers).
- Reliable hardware. It is expected to work for years and years mostly anattended. The minimal part count and the airtight enclosure is hepling on this.
- Reliable software. Minimal dependencies on external services. It can tolerate power outages and MONTHS of WIFI anavailability before the time drift becomes noticeable. The CR2032 coin cell will probably work for 10 years or even more, given that most of the time it will not discharge. There is no dependency for MQTT server, whom we dont now if it is working or even exists 10 years from now. If you want it of course is working and can be useful for remote control and debugging (see the dedicated section). If it stops working it will not break the functionality however.
- Very low cost (See the BOM below)
- Free software. Both tasmota and timetable are open source with very permissive licences. This also means it is very easy to modify the software if you want to.

# STEP 1. Get an ESP board.
- ESP32 boards are prefered over ESP32-S2 or ESP32-C3. I have witnessed some instability whith C3 (When the ESP32-C3 cannot find an AccessPoint frequently crashes. It recovers immediatelly but lets stay on the safe side). I am sure the situation will change to the better over time, but for now(2025) the ESP32 is the right choice. The prices of the boards are very low anyway, and there is no cost reason to prefer one over another.
- Another very good point in favor of ESP32 boards is they always come with a dedicated serial chip (CP2102, CH9102, CH340). Many C3 and S2 boards use serial implemented by the ESP itself, and the Tasmota isntallation/recovery is unstable as the board vanishes and reappears on reboots.

The boards that i have tested are :
PHOTO
- ESP32 WROOM-32D devkit boards (The metallic cover), 30 and 36 pin versions. Very popular, presoldered headers, 5V power pin(You can power a relay whith this) and plenty of GPIO and GND pins. This is the safest option. There is TODO a screw terminal adapter wich makes the assembly even easier than it is already.
PHOTO
- ESP32 LOLIN32 Lite. Do not connect a LiPo battery. You can drive an SSR, but no 5V output for a relay. No presoldered headers. Only 1 GND pin, but for the very low power DS3231 we can use GPIO pins as VCC and GND.

We aware
- **ESP8266 will NOT work.** It does not support the Berry scripting language.

**First we will install all necessary software to the ESP board, test the functionality and only then, we will continue with the hardware assembly**

## STEP 2. Tasmota installation & configuration.
This is a very short and limited installation guide, the tasmota home page contains instructions to solve all shorts of problems.
Do not assemble anything yet, just connect the board with the USB cable to your computer. Tasmota supports a very convenient web based installer. You will need google chrome or chromium or similar browser. Currently firefox does not support serial connections. Linux users may have serial permission problems you have to add yourself to the "dialout" group. You may need to press the boot button when plugging the board to the computer.

- Go to https://tasmota.github.io/install/
The first option tasmota(english) is the safest option. Localized versions have limited hardware support(only ESP32 variants).
- Choose the serial port enable "Erase Device" → Next → Install.
- After the installation is complete Next → Configure WIFI.

  Use the current WIFI for now. When we move the box to the final location we can easily change the AccessPoint.
- When connected, click Visit Device.
  Write down the IP address. This is the web page of the tasmota system. From now on we are working via network. There is no need for the serial connection anymore.

- Set the TimeZone/Dayligtht settings.
  In another tab go to
  https://tasmota.github.io/docs/Timezone-Table/
  
  Copy the necessary line and execute it in Tools → Console.(NOT berry console)

- Again in console (and dont forget the "backlog")
  ```berry
  backlog hostname school; SetOption55 1; restart 1;
  ```
  On boot messages, you will see something like
  ```
  mDN: Initialized 'school.local'
  ```
  From now on you can type "school.local" in the browser address instead of the IP.

## STEP 3. Berry script installation ("timetable.be")
We have to connect the SSR/RELAY. Any free PIN is OK, in this document we will use the 12 TODO_WITH SSR

TODO Photo

WebBrowser → IP address(or school.local) → tools → Berry scripting console

paste the following code
TODO use timetable.be

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

Now you have the "timetable.be" script.

Without leaving the Berry Console type

```berry
TTPIN = 12
load('timetable.be')
```

You will see the timetable starting successfully. To be started on boot, it needs to be in "autoexec.be"

tools → manage filesystem → edit autoexec.be (the white icon with the pencil). Or create it if does not exist.

Append the 2 lines.
```berry
TTPIN = 12
load('timetable.be')
```

restart the module

Go with the browser to the same IP address(or school.local) as previously. You will see a timetable button, for testing you can choose a time very close to the current time. When testing choose * (=ALL) for active days. On school most probably the setting will be 1-5 (Monday-Friday).

## STEP 4. Connecting the DS3231 real time clock to the board. Highly recommended.
Without a real time clock it is easy for the module to loose the time. Example is a power outage, followed by Internet disconnection. (The power outage affects the network equipment). Or a WIFI password change (Without updating our project). With the RTC, the module will continue to work for a long time, until we fix the problem. Full instrctions on:

https://github.com/pkarsy/TasmotaBerryTime/tree/main/ds3231

## STEP 6 Collecting the rest of the hardware.
PHOTO-TODO
- A project enclosure, better to be air tight, to prevent moisture and dust. 
- Esp32x board + DS3231 + USB cable (from the previous steps). DO NOT USE A 2 CHARGING ONLY CABLE. You will not have any means to recover the system from WIFI changes.
- A few jumper cables (Warning Unused)
- Alternativelly a screw terminal breakout and simple copper wires. PHOTO
- SSR (solid state relay) Or a Relay breakout module. I personally use an SSR. TODO own section WARNING SSR cannot completely break the circuit and allows for a few mA to leak even when inactive.
- A usb charger. No need to be powerful, but it helps to be of good quality, for example from an old phone.
- A connector for the bell connection.
- ON/OFF button
- Optionally an indicator LED. You can bye them ready with cables and resistor, or solder one yourself.

## STEP 7 Assembling the circuit
the ESP32 is already connected with the DS3231
now locate the GPIO and the GND pins and connect the SSR with the board
For a relay breakout you will need the 5V output also. TODO PHOTO
For the usb cable you will neet to open a hole and then use some Hot glue or UV-glue or
even better a screw form aliexepress etc. some gummy to fix it
TODO photo

## STEP 3.5 protect the web interface from anauthorized access

Here are 2 solutions. Use both of them if you prefer.
- Set a password to access the page. school.local(or IP) → Configuration → Other → Web Admin Password (Login with "admin"/"password"). The page is not encrypted so not very secure, but it is on LAN only so I guess is OK.

- Automatically disable the webserver 5min after powerup. When you need to access the web interface, unplug the power and connect again. Not very secure, but has the huge advantage of not having another password to remember (after 10 years), and this project is about reliability and maintainability. You can add a note on the back of the box (see section recovery from AP changes)
Paste this long line to the Tasmota Console:

```
backlog savedata 0; Rule1 ON Wifi#Connected DO webserver 2 ENDON ON Wifi#Connected DO RuleTimer1 300 ENDON ON Rules#Timer=1 DO webserver 0 ENDON; rule1 1; restart 1;
```

Warning "savedata 0" means the changes are not saved automatically from now on, and need a manual restart to be saved. This does not harm our project and in fact prevents flash wear.

## STEP 8 Intall the electrical connector (near the manual bell switch)
Most probably the school already has a circuit for the bell, and a wall button for manual ringing. In that case the most straitforward way is to install the connector 2 cables at the 2 poles of the switch. With this **dry contact** configuration the Bell rings whenever the SSR/Relay is activated. There is no need to uninstall the old timer (if installed), just disable it.

## STEP 9. Plug the timer in the newly installed connector
This is trivial but find a wall electrical socket for the usb charger **DEDICATED** for this purpose. You do not want someone unpluging the the timer, to use a Radio or watever

## STEP 10. Reconfigure WIFI
**Plug the USB cable to you laptop** (chromium based browse) and type "tasmota installation"
→ Configure WIFI(set the new  credentials) → select the new Access Point + pass → Visit Device. Unlug the cable from the laptop and use the USB charger.


## STEP 11. Document the previous to a paper and/or to an online note app(keep etc.) how to recover from a missing/changed Access Point. This way even someone else can do it instead of you.
The same method can be used if the module is connected to the WIFI but you cant find the IP address and the "school.local" is not working.
You will probably want to put this ins some accessible place, or to the back of the box.
Connect the USB cable, open your (chrome based) browser type "tasmota installer" and click on the installer page. Click connect and then setup WIFI.


Congratulations !

Optional stuff some of them may be of interest to you.

## Disable Device Recovery (Recommended)
Go to Tools → Console
```
backlog SetOption65 1; restart 1;
```
Device Recovery may be useful when we playing with tasmota, but not on a working device.

## MQTT server, optional but useful for debugging or remote control
You can self host an MQTT server of course. However there are a lot of online MQTT servers free/paid and probably you prefer this for simplicity. examples are
hivemqtt.com
flespi.com
You must use the TLS connection, all online servers support secure connections.
You also need an mqtt-client such as
MQTT-Explorer
MQTTX
mqtt-shell(terminal)
> publish cmnd/mybell/br bell_on() # rings the bell manually
> publish cmnd/mybell/br tt.timetable # shows the timetable
> publish cmnd/mybell/br tt.set_timetable('1000 1045 etc')
> publish cmnd/mybell/br tt.set_duration(5)
> publish cmnd/mybell/br tt.set_active_days('1-5')
There are a lot of mqtt GUI apps on mobile allowing to automate theese commands with buttons if you need this, but I think is overkill, given how rarelly you need to change the settings

## Why not using the buildin tasmota timers
Although tasmota has programmable timers, using them for the bell is not very convenient. Also there are cases(double schools day+afternoon) where the available timers are not enough. The solution is to use a dedicated application written in the excellent Berry scripting language. This language comes preinstalled with all Esp32 variants.

## WIFI6 (5Ghz wifi). Currrently not working
At the moment all Tasmota ESP chips only support WIFI 2.4 GHz. This is acceptable as most Access Points support 2.4 GHz and 5GHz at the same time. When the Tasmota system supports 5GHz for example ESP32-C6 I guess it will be trivial to use the new chip, and if I can, I will try to update this page.

## Why not esp8266 boards like sonoff DELETE put previous section
Of course we can load tasmota or esphome or espurna on them and then they are a viable option but again with a lot of limitations and inconveniences. If the WIFI is unreliable the module can stop working (or even work in the middle of the night) or the time starts to drift. Most of theese modules are not well protected from the ambient conditions. And finally the web interface is not well suited for the specific purpose.

## DELETE TODO Why using a board with dedicated serial chip
- ESP32 and to lesser extend ESP32-C3(Not all boards have serial chip) based board. ESP32 boards also have localized tasmota versions.

- Dedicated serial chip.  It is located near the USB connector and usually the description mentions it(TODO CHIPS). All ESP32 boards have a dedicated serial chip. The manufacturers try to omit it to reduce the cost(on ESP32-C3 and ESP32-S2 ), but the difference to the customer is a few cents. On boards without a dedicated serial chip, the web installer has trouble detecting the board on reset, and configuring wifi. This can change in the future but stay safe.
As we explained earlier, the web installer is not only used at the installation phase, **but MOST IMPORTANTLY many years later when for some reason the WIFI is lost or changed**

ALLOY Most school bells prefer to be electromechanical and SCR may be a better choice than Relays.

# Using Tasmota instead of an embeded programming language (Arduino, micropython circuitpyton, lua or enen ESP-IDF)
Tasmota solves for us some very important aspects of the project.
- Network connectivity (this includes WIFI autoconnect, optionally MQTT client autoconnect )
- A customizable web server, which allows us to create a dedicated page for the timetable.
- Time Zone and Daylight Time Switching
- Easy control of peripherals.
- filesystem and settings.
- a scripting language the excellnt Berry Language. The automation of the bell and the webserver customizations are written in this language.
- Pin setup(DS3231)
- An excellent web based installer. No software is needed for installation and is working the same on all operating systems.
- MOST IMPORTANTLY !! Easy recovery and changing the WIFI credentials using the tasmota web installer.
