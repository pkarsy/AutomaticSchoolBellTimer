# timetable
Control a school bell

WARNING WORKING WITH MAINS CAN BE VERY DANGEROUS KEEP ALL PRECAUTIONS AND AT YOUR OWN RISK. If you are unsure ask a licenced tecnician for the mains connection.

PHOTO

School bell based on ESP32x Tasmota. 
We will use real bells, usually electromechanical and not speakers or similar audio equipment.

## Motivation
Although there are a lot of solutions for the automation of a school bell, very few of them are particularly good.
- Many dedicated school bell timers use anchient technology, without network connectivity (= time drift) and a horrible hardware control panel.
- A lot of generic timed switches have very limited number of timers usually smaller than a 14-20 a school needs
- Usually no way to keep accurate time. This basically means that the bell never rings on the expected time. A few minutes error does not seem a problem at first glance, but the real problem is the argument in the classroom that the time has already passed etc. Also none of the timers I have checked is capable of switching to Daylight time.
- There is of course the solution of using a computer with a suitable application. But then the complexity and the unreliability is bigger. Not to forget operating system updates, broken harware high electricity consumption, audio equipment etc.

The ESP32 based boards are very well suited for this task, provided you like to DIY things of course.

Why not esp8266 boards like sonoff
Whith stock firmware, there is the problem that the timers are not enough.
Of course we can load tasmota or esphome or espurna on them and then they are a viable option but again with a lot of limitations and inconveniences. If the WIFI is unreliable the module can stop working(or even work in the middle of the night) or the time starts to drift. Most of theese modules are not well protected from the ambient conditions. And finally the web interface is not well suited for the specific purpose.
The goal here is to create a truly superior solution with internal RTC (to address potentian WIFI disconnections)
and SSR (to drive inductive loads) and finally a very simple and convenient web control panel. The enclosure offers the module the potential for a very long life.

Design Goals

- as few parts as possible (and no soldering if the ESP has presoldered headers). No display, control buttons etc. Only a ON/OFF button (Do not ommit this however, see explanation below).
- Very low cost.
- Very accurate (Using NTP time).
- Automatically shiching daylight time, twice a year.
- Even on unreliable WIFI with very long offline times will keep accurate time. We use a dedicated DS3131 module(witg battery) for this. In the unlikely event of no network availability there is a dedicated section below.
- Easily (and securelly by the way) controllable via PC or mobile. This is mandatory as there are no control buttons.
- Reliable operation. The project is expected to work for years and years mostly anattended. The minimal part count and the enclosure is hepling this very much.
- Completely open source. Both tasmota and this project are open source with a very permissive licences.

 ALLOY Most school bells preffer to be electromechanical and SCR may be a better choice than Relays.

Selection of tools: Hardware, software
- We use any of ESP32x family running tasmota. The use of tasmota is very important as it solves easily some very important aspects of the project. Network connectivity (this includes WIFI autoconnect, Web Page, MQTT client autoconnect ), Time and Daylight Time Switching, Easy control of peripherals, and a scripting language the excellnt Berry Language. Basically tasmota acts like an operating system and berry as the programming language.

Hardware PHOTO-TODO
- A project enclosure, better air tight to prevent moisture, and dust. 
- Esp32x board. Tested with ESP32 (luatos ) C3 S2 (2-5E)
- SSR (solid state relay). I found it to be much more reliable than a Relay and much more easily controllable from ESP32. TODO own section WARNING SSR cannot completely isolate the circuit and allows for a few mA to leak even when inactive.
- A usb charger. No need to be a powerful but it helps to be of good quality, for example from an old phone. Also you will need a data cable USB-C or micro-USB depending on the ESP32 board.

## MQTT server
Realistically you will need a MQTT server to control your device. You can host an MQTT server of course on your server. However there are a lot of online MQTT servers and probably you prefer this for simplicity
examples are
hivemqtt.com
flespi.com
Basically you need to create a MQTT server and write down host/username/password

## Tasmota installation
- Install Tasmota to your board https://tasmota....
- Use the console to easily apply the settings for your board
- Copy and paste the following to the serial console:
- After restart check the console messages to see if WIFI, MQTT, is connected and if LOCAL time is set. Copy the IP address of the 

## DS3231 real time clock
Here is the link
You can probably skip this and most of the time the bell will work perfectly. However there are scanarios which the clock can trully save the day. Example a short power outage followed by network instability. Or a WIFI password change without updating the tasmota system. With the RTC the module will continue to work for a long time, until we fix the problem

## Timetable aplication
Although tasmota has programmable timers, using them for the bell is not very convenient for this specific application. The solution is to use a dedicated application written in the Berry scripting language. This language comes with all Esp32 variants preinstalled and is very powerful, conrolling basically every aspect of the Tasmota system in addition to what Tasmota already offers.
On your browser enter 