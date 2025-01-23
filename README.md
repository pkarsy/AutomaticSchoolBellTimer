# timetable
Automatic school bell timer based on the popular ESP32x series and Tasmota.


# WARNING
Most electromechanical school bells use mains voltage (230/110V) Anthrough the project can be assembled without the need to be exposed to such a voltage. However when installing to the final location a connection has to be made to the bell. So,
WORKING WITH MAINS VOLTAGE IS VERY DANGEROUS. KEEP ALL PRECAUTIONS AND AT YOUR OWN RISK.
If you are unsure ask a licenced tecnician to do the mains connection.

PHOTO TODO

## Problems with existing solutions
Although there are many options for the automation of a school bell, very few of them are particularly good.
- Many timers use anchient and/or very cheap contruction, without network connectivity (= time drift) and a horrible hardware control panel.
- very limited number of timers usually smaller than a 14-20 a school needs,
- a horrible control panel.
- Usually no way to keep accurate time. This basically means that the bell never rings on the expected time. A few minutes error does not seem a problem at first glance, but the real problem is the argument in the classroom that the time has already passed etc.
- Also none of the timers I have checked is capable of switching to Daylight time.
- Computer based solutions suffer from complexity and unreliability (in the log run). Operating system updates, broken harware high electricity consumption, audio equipment maintainance are some of the drawbacks.
- Ready made WIFI plugs like TUYA sonoff etc have almost always the problem with limited number of timers
- they do not have the option to be dry contacts (See electrical connection) this alone can be a deal braker.
- Very/No limited protection from moisture and dust.


## Design Goals

- Very accurate, using NTP(Network Time Protocol).
- Time Zone and Daylight Savings Time
- Resistant to Network disconnections and power outages. The module keeps accurate time on such occations, and only rarely needs to connect to the Internet to fix the time drift(less than 1 sec per week without Internet) We use a dedicated DS3231 module(with a lithium coin cell) for this. In the unlikely event of no network availability (at all) there is a dedicated section below.
- Simple Web Control Panel. Easily controllable via PC or mobile. With the option of MQTT, it can also be controlled outside of the local network.
- Very low cost of the hardware.
- as few parts as possible, and no soldering at all, if the ESP has presoldered headers.
- Reliable hardware. It is expected to work for years and years mostly anattended. The minimal part count and the airtight enclosure is hepling on this.
- Reliable software. Minimal dependencies on external services. For example there is no dependency for an MQTT server, whom we dont now if it is working or even exists 10 years from now. If you want it of course is working and can be useful for remote control and debugging (see the dedicated section).
- Free software. Both tasmota and timetable are open source with very permissive licences.

# Why Tasmota and not use a bare metal solution (Arduino, micropython circuitpyton, lua or enen ESP-IDF)
Tasmota solves for us some very important aspects of the project.
- Network connectivity (this includes WIFI autoconnect, optionally MQTT client autoconnect )
- A customizable web server, which allows us to create a dedicated page for the timetable.
- Time Zone and Daylight Time Switching
- Easy control of peripherals.
- filesystem and settings.
- a scripting language the excellnt Berry Language. The automation of the bell and the webserver customizations are written in this language.
- An excellent web based installer. No software is needed for installation and is working the same on all operating systeI insist onms we happen to use.
- Controllable Panic Mode. Easy troubleshooting and changing the WIFI credentials using the same web installer.

# ESP board recommendations
There is a muriad of boards and board modifications based on ESP32, so you can easily get confused.

Some recommended boards that i have tested are :
- ESP32 DevKit
- ESP32-C3-32S NodeMCU
- ESP32-C3 Core. The "standard" version (has a LUATOS.COM logo). I personally use them because it is very easy to connect the DS3231 chip, but you have to solder the headers.

Generally all ESP32 and ESP32-C3 boards with a dedicated serial chip and at least 2-3 GND pins are recommended. Avoid ultra tiny versions (suffer from lack of IO and GND pins). Presoldered headers is a bonus.

Some boards which are less than ideal/unsuitable for this specific project

- ESP32 with Lipo Battery Charger(lolin32 lite I believe). It has only one GND pin.
. ESP32-S2 boards I have checked do not have a serial chip.
- ESP32-C3 Core, the "simple" version (no luatos.com logo), no Serial chip.
- **ESP8266 will NOT work.** It does not support the Berry scripting language.

**First we will install all necessary software to the ESP board we will test that the automatic timer is working, then we will continue with the hardware assembly**

## Tasmota installation.
This is a very short and limited installation guide, the tasmota home page contains a very complete manual to solve all shorts of problems. We also assume you are using a recommended board with dedicated serial chip.
Do not assemble anything yet, just connect the board with the USB cable to your computer. Tasmota supports a very convenient web based installer. You will need google chrome or chromium or similar browser. Firefox does not support serial connections. Linux users may have serial permission problems you have to add yourself to the "dialout" group. You may need to press the boot button when plugging the board to the computer.
I insist on
- Go to https://tasmota.github.io/install/
The first option tasmota(english) is the safest option. Localized versions have limited hardware support(only ESP32 variants).
- Choose the serial port enable "Erase Device" -> Next -> Install.
- After the installation is complete Next -> Configure WIFI
- If this is OK click Visit Device. Write down the IP address so you can reconfigure the device. There is no need for the serial connection anymore.
However you can always return to the installation page (and connect the usb cable) and Change the WIFI settings (If for example you change the location and the AP of the device)
- Change the TimeZone/Dayligtht settings. Go to
https://tasmota.github.io/docs/Timezone-Table/
Copy the necessary line and execute it in Tools->Console.
- You can add a muriad of additional options, mqtt server, MDNS if they are useful to you, but for the project the above are enough. There is a dedicated section for some useful Tasmota tweakings.

## Berry script application ("timetable.be")
WebBrowser -> IP address -> tools -> berry scripting console
paste and run the following code

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

tools -> manage filesystem -> edit autoexec.be (the white icon with the pencil)
append the 2 lines.
TTPIN = 12
load('timetable.be')
We use GPIO12 but choose any free pin to connect to the Relay/SSR. You can connect a LED to the pin(and GND) , or maybe the SSR, or you can temporarily/or permanently choose the buildin LED so you can see results before connecting anything to the board

restart the module

Go with the browser to the same IP address as previously. You will see a timetable button, for testing you can choose a time one or 2 minutes later.


## Connecting the DS3231 real time clock to the board. Optional but recommended
Here is the link
You can probably skip this and most of the time the bell will work perfectly. However there are scanarios which the clock can trully save your day. Example is a short power outage followed by network instability. Or a WIFI password change without updating the tasmota system. With the RTC, the module will continue to work for a long time, until we fix the problem

## Hardware PHOTO-TODO
- A project enclosure, better to be air tight to prevent moisture, and dust. 
- Esp32x board.
- SSR (solid state relay) Or a Relay breakout module. I personally use SSR. TODO own section WARNING SSR cannot completely isolate the circuit and allows for a few mA to leak even when inactive.
- A usb charger. No need to be powerful, but it helps to be of good quality, for example from an old phone. Also you will need a data cable, USB-C or micro-USB depending on the ESP32 board.

At this point the timer should be ready to work, congratulations !
The rest of the page is optional

## MQTT server, optional but useful for debugging or remote control
You can self host an MQTT server of course. However there are a lot of online MQTT servers free/paid and probably you prefer this for simplicity.
examples are
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

## Setup your mobile phone as second WIFI in setup. Optional
This is useful in the case the primary AP is gone. This allows to connect the Tasmota to the network and make the necessary changes via MQTT. The web intrface is working but can be challenging to find the IP. Generally the configuration via the serial cable is much easier and less error prone, see the section of WIFI troubleshooting


## Why not using the buildin tasmota timers
Although tasmota has programmable timers, using them for the bell is not very convenient for this specific application. Also there are schools where the available timers are not enough. The solution is to use a dedicated application written in the excellent Berry scripting language. This language comes preinstalled with all Esp32 variants.

## WIFI6 (5Ghz wifi). Currrently not working
At the moment all Tasmota ESP chips only support WIFI 2.4 GHz. This is acceptable as most Access Points support 2.4 GHz and 5GHz at the same time. The 5GHz cpnnection is not prefferable anyway as it has weaker obstacle penetration than 2.4 GHz. When the Tasmota system supports 5GHz for example ESP32-C6 I guess it will be trivial to
use the new chip, and if I can, I will try to update this page.

## Why not esp8266 boards like sonoff DELETE put previous section
Of course we can load tasmota or esphome or espurna on them and then they are a viable option but again with a lot of limitations and inconveniences. If the WIFI is unreliable the module can stop working (or even work in the middle of the night) or the time starts to drift. Most of theese modules are not well protected from the ambient conditions. And finally the web interface is not well suited for the specific purpose.

## Why using a board with dedicated serial chip
## WHY serial
- ESP32 and to lesser extend ESP32-C3(Not all boards have serial chip) based board. ESP32 boards also have localized tasmota versions.

- Dedicated serial chip.  It is located near the USB connector and usually the description mentions it(TODO CHIPS). All ESP32 boards have a dedicated serial chip. The manufacturers try to omit it to reduce the cost(on ESP32-C3 and ESP32-S2 ), but the difference to the customer is a few cents. On boards without a dedicated serial chip, the web installer has trouble detecting the board on reset, and configuring wifi. This can change in the future but stay safe.
As we explained earlier, the web installer is not only used at the installation phase, **but MOST IMPORTANTLY many years later when for some reason the WIFI is lost or changed**

Better use the previous recommendations but if you are curious, the following boards are tested.

 ALLOY Most school bells prefer to be electromechanical and SCR may be a better choice than Relays.