# timetable
Control a school bell

PHOTO

School bell based on ESP32x Tasmota

Most (at least) schools are using automatic bells which are on the most part quite unreliable.
The time is drifting, creating a confusion among the students and teacher whether the ring is delayed or working etc

Motivation
Although there are a lot of solutions for the school bell. None of them seems to be a good one. Many dedicated school bell timers use anchient technology (even all through hole boards)
A lot of generic timers (Even WIFI based) have very limited number of time triggers usually smaller than a 14-20 a school needs, and in that case more than one is needed.
and usually no way to keep accurate time. This basicslly means that the bell never rings on the expected time. 1-2 min error does not seem a problem at first glance, but the real problem is the argument in the classroom that the time has already passed etc. Also none of the timers a have checked is capable of switching to Daylight time of course. There is of course the solution of using a computer with a suitable application. But then the complexity and the unreliability is bigger. Not to forget operating system updates, broken harware high electricity consumption, audio equipment etc. Of cource we can use a RaspberryPi but overall is both unreliable and an overkill. The ESP32 based boards using a stable "operating system" is a natural choice provided you like to DIY things of course.

Why not esp8266 boards like sonoff
Whith stock firmware, there is the problem that the timers are not enough.
Of course we can load tasmota or esphome or espurna on them and then they are a very viable option but with a lot of limitations and inconveniences. If the WIFI is unreliable the module can stop working(or even work in the middle of the night) or the time starts to drift. Most of theese modules are not well protected from the ambient conditions. And finally the web interface is not well suited for the specific purpose.
However the goal here is to create a truly superior solution, see the next session. with internal RTC (to bypass network instability)
and SSR (to drive inductive loads) and finally a very simple and convenient web control panel. The enclosure offers the module the potential for a very long life.

Goals

- as few parts as possible (and no soldering if the ESP has presoldered headers). No display, control buttons etc. Only a  ON/OFF button (Do not ommit this however, see explanation below).
- Very low cost.
- Very accurate (Using NTP time). See Motivation above.
- Automatically shiching daylight time, twice a year.
- Even on unreliable WIFI with very long offline times will keep accurate time. In the unlikely event of no network availability there is a dedicated section below.
- Easily (and securelly by the way) controllable via PC or mobile wia a web browser. This is in fact mandatory as there is no hardware buttons.
- Reliable operation. The project is expected to work for years and years mostly anattended. The minimal part count and the enclosure is hepling this very much.
- Completely open source. Both tasmota and this project are open source with a very permissive licence.

 ALLOY Most school bells preffer to be electromechanical and SCR may be a better choice than Relays.

Selection of tools: Hardware, software
- We use any of ESP32x family running tasmota. The use of tasmota is very important as it solves easily  some very important aspects of the project. Network connectivity (this includes WIFI autoconnect, Web Page, MQTT client autoconnect ), Time and Daylight Time Switching, Easy control of peripherals, and a scripting language the excellnt berry language. Basically tasmota acts like an operating system and berry as the programming language.

Hardware PHOTO-TODO
- Box enclosure
- Esp32x board. Tested with ESP32 (luatos ) C3 S2 (2-5E)
- SSR (solid state relay). I found it to be much more reliable than a Relay and much more easily controllable from ESP32. TODO own section WARNING SSR cannot completely isolate the circuit and allows for a few mA to leak even when inactive.

- Tasmota installation
- Install Tasmota to your board https://tasmota....
- Use the console to easily apply the settings for your board
- Copy and paste the following to the serial console:
- After restart check the console messages to see if WIFI, MQTT, is connected and if LOCAL time is set.

- Timetable aplication:
Although tasmota has programmable timers, using them for the bell is not very convenient especially when we need network access. The solution is to use a dedicated application written in the Berry scripting language. This language comes with all Esp32 variants preinstalled and is very powerful, conrolling basically every aspect of the tasmota system in addition to what Tasmota already offers.