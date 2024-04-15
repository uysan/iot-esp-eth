# ESP32 Ethernet, Wi-Fi & Serial Gateway

_Open Source Hardware Developed With Open Source Software_ [*](#development-software)

## Overview

Default firmware on **iot-esp-eth** board is a modified version of [esp-at](https://github.com/espressif/esp-at) project. This project is linked to this repository as a submodule. After initializing the submodule, you can apply the necessary patch and compile the code for **iot-esp-eth**.

Clone the project into your local directory:
```
git clone https://github.com/uysan/iot-esp-eth.git
```

Initialize esp-at submodule and apply the patch:
```
cd iot-esp-eth/
git submodule update --init --depth 1
git apply firmware/esp-at.patch
```

Install esp-idf environment and tools:
```
cd firmware/esp-at/
./build.py install
```

Build script asks for some configuration:
```
Platform name:
1. PLATFORM_ESP32
2. PLATFORM_ESP32C3
3. PLATFORM_ESP32C2
4. PLATFORM_ESP32C6
choose(range[1,4]): 1  <-- Enter 1 here

Module name:
1. WROOM-32
2. WROVER-32
3. PICO-D4
4. SOLO-1
5. MINI-1 (description: ESP32-U4WDH chip inside)
6. ESP32-SDIO
7. ESP32-D2WD (description: 2MB flash, No OTA)
8. IOT-ESP-ETH (description: 16MB flash, Ethernet)
choose(range[1,8]): 8  <-- Enter 8 here

Enable silence mode to remove some logs and reduce the firmware size?
0. No
1. Yes
choose(range[0,1]): 1  <-- Enter 1 here
```

Build the code:
```
./build.py build
```

Then connect iot-esp-eth board to your computer with a USB cable and upload the firmware:
```
./build.py -p /dev/ttyUSB0 flash
```

You may use your preferred serial terminal software to enter AT commands. For picocom:
```
picocom /dev/ttyUSB0 -b 115200 --omap crcrlf
```

## Development Software

This project was developed with open source tools including but not limited to KiCAD, OpenEMS, Octave, FreeCAD, Paraview, Inkscape and Scribus on a PC running Ubuntu Desktop edition.
