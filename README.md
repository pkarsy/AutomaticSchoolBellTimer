# timetable
Control a school bell

WARNING WORKING WITH MAINS VOLTAGE IS VERY DANGEROUS. KEEP ALL PRECAUTIONS AND AT YOUR OWN RISK.
If you are unsure ask a licenced tecnician for the mains connection.

PHOTO

Automatic school bell timer based on ESP32x Tasmota.

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

- as few parts as possible (and no soldering if the ESP has presoldered headers). No display, control buttons etc. Only a ON/OFF button (Do not ommit this however, see explanation below).
- Simple and intuitive Web Control Panel
- Very low cost of the hardware.
- Very accurate, using NTP(Network Time Protocol).
- Automatically shiching daylight time, twice a year.
- Resistand to Network disconnections and power outages. We use a dedicated DS3131 module(with battery) for this. In the unlikely event of no network availability at all there is a dedicated section below.
- Easily controllable via PC or mobile. With MQTT can be controlled outside of the local network if this is desirable.
- Reliable hardware. The timer is expected to work for years and years mostly anattended. The minimal part count and the airtight enclosure is hepling on this.
- Reliable software. Minimal dependencies on external services. For example there is no need for an MQTT server, whom we dont now if it is working or even exists 10 years from now. If you need it of course is working and can be useful for remote control and debugging (see the dedicated section).
- Completely open source. Both tasmota and timetable are open source with a very permissive licences.

 ALLOY Most school bells prefer to be electromechanical and SCR may be a better choice than Relays.

Selection of tools: Hardware, software
- We use any of ESP32x family running tasmota. The use of tasmota is very important as it solves easily some very important aspects of the project. Network connectivity (this includes WIFI autoconnect, Web Page, MQTT client autoconnect ), Time and Daylight Time Switching, Easy control of peripherals, and a scripting language the excellnt Berry Language. Basically tasmota acts like an operating system and berry as the programming language.

## Hardware PHOTO-TODO
- A project enclosure, better to be air tight to prevent moisture, and dust. 
- Esp32x board.
- SSR (solid state relay) Or a Relay breakout module. I personally use SSR. TODO own section WARNING SSR cannot completely isolate the circuit and allows for a few mA to leak even when inactive.
- A usb charger. No need to be powerful, but it helps to be of good quality, for example from an old phone. Also you will need a data cable, USB-C or micro-USB depending on the ESP32 board.

## Hardware recommendations

There is a muriad of boards and board modifications based on ESP32, so you can easily get confused. I recommend to choose a board with the following characteristics.

- ESP32 or ESP32-C3 based board

- Dedicated serial chip. It is located near the USB connector and usually the specification mentions it. All ESP32 boards have dedicated serial chip. The manufacturers try to omit it to reduce the cost, but the difference to the customer is a few cents. On boards without a serial chip, the web installer has trouble detecting the board on reset, and configuring wifi. This can change in the future but stay safe.
The web installer is used at the installation phase, **but MOST IMPORTANTLY many years later when for some reason the WIFI is lost or changed**

- At least 2 GND pins. Even more if you want to have an Indicator LED. Otherwise wiring is needed. (Dont forget, we target simplicity and reliability)

- Presoldered headers is a bonus.

Better use the previous recommendations but if you are curious, the following boards are tested.

- ESP32 DevKit works very well.
- ESP32 wemos lolin32. Do not use a lipo battery, otherwise works well.
- ESP32 with Lipo Battery Charger(lolin32 lite I believe). Not very well suited for this project. Do not plug a battery. It has only one GND pin.
- ESP32-C3-32S NodeMCU works very well
- ESP32-C3 Core. The "standard" version with LUATOS.COM logo works very well
- ESP32-C3 Core  The "simple" version (no Serial chip, no luatos.com logo). Difficulties at installation and wifi configuration.
- ESP32-S2 Wemos. Very limited testing. No serial chip, difficulties at installation and wifi configuration.

**ESP 8266 will NOT work. It does not support the Berry scripting language.**

## Tasmota installation.
This is a very short and limited installation guide, the tasmota home page contains a very complete manual to solve all shorts of problems.
Do not assemble anything yet, just connect the board with the USB cable to your computer. Tasmota supports a very convenient web based installer. You will need google chrome or chromium or similar browser. Firefox does not support serial connections. Linux users may have serial permission problems you have to add yourself to the "dialout" group. You may need to press the boot button when plugging the board to the computer.

- Install Tasmota to your board https://tasmota.github.io/install/
The first option tasmota(english) is the safest option. Localized versions have limited hardware support.
- Choose the serial port click EraseDevice -> Next -> Install.
- After the installation is complete Next -> Configure WIFI
- If this is OK click Visit Device. Write down the IP address so you can reconfigure the device. There is no need for the serial connection anymore.
However you can always return to the installation page (and connect the usb cable) and Change the WIFI settings (If for example you change the location and the AP of the device)
- Change the TimeZone/Dayligtht settings. Go to
https://tasmota.github.io/docs/Timezone-Table/
Copy the necessary line and execute it in Tools->Console.
- You can add a muriad of additional options, mqtt server, MDNS if they are useful to you, but for the project the above are enough. There is a dedicated section for some useful Tasmota tweakings.

## Berry script application
Go to tools -> berry scripting console
paste and run the following code

tools->manage filesystem -> edit autoexec.be (the white icon with the pancil)
append the lines.
TTPIN = 12
load('timetable')
We use GPIO12 but choose any free pin to connect to the Relay/SSR. You can use a header pin wich also drives a buildin LED. This way you can test the module even before assembling the project
restart the module

## Setup your mobile phone as second WIFI in setup. Optional
This is useful in the case the primary AP is gone. This allows to connect the Tasmota to the network and make the necessary changes via MQTT. The web intrface is working but can be challenging to find the IP. Generally the configuration via the serial cable is much easier and less error prone, see the section of WIFI troubleshooting

## DS3231 real time clock. Optional but recommended
Here is the link
You can probably skip this and most of the time the bell will work perfectly. However there are scanarios which the clock can trully save your day. Example is a short power outage followed by network instability. Or a WIFI password change without updating the tasmota system. With the RTC, the module will continue to work for a long time, until we fix the problem

## Timetable aplication
Although tasmota has programmable timers, using them for the bell is not very convenient for this specific application. The solution is to use a dedicated application written in the excellent Berry scripting language. This language comes preinstalled with all Esp32 variants
On your browser enter

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

## WIFI6 (5Ghz wifi). Currrently not working
At the moment all Tasmota ESP chips only support WIFI 2.4 GHz. This is acceptable as most Access Points support 2.4 GHz and 5GHz at the same time. The 5GHz cpnnection is not prefferable anyway as it has weaker obstacle penetration than 2.4 GHz. When the Tasmota system supports 5GHz for example ESP32-C6 I guess it will be trivial to
use the new chip, and if I can, I will try to update this page.

## Why not esp8266 boards like sonoff DELETE put previous section
Of course we can load tasmota or esphome or espurna on them and then they are a viable option but again with a lot of limitations and inconveniences. If the WIFI is unreliable the module can stop working (or even work in the middle of the night) or the time starts to drift. Most of theese modules are not well protected from the ambient conditions. And finally the web interface is not well suited for the specific purpose.