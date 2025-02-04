# Groovy core for MiSTer

## General description
This core is a analog gpu for crt for subframe latency emulators

## Features
- Very low latency (3ms tested with GILT on GroovyMAME with frame delay 8)
- Full RGB888
- Switch all modes (progressive/interlaced) reprogramming pll according to modeline
- Connect with ethernet (can be work on wifi5/6 or Gb lan)
- Menu options: scandoubler, video position, frameskip (uses framebuffer if emulator don't send frame at time), ..

To install on your MiSTer you need replace MiSTer binary from /media/fat (core isn't official yet)
  
## Emulators available

### GroovyMAME
 for src details, see GroovyMAME fork by @Calamity https://github.com/antonioginer/GroovyMAME/tree/nogpu_0261
 ,to activate new MiSTer backend set on command line args:
  
    -video mister 
    -aspect 4:3 
    -switchres 
    -monitor arcade_15 
    -mister_window 
    -mister_ip "192.x.x.x" 
    -mister_compression lz4 
    -skip_gameinfo 
    -syncrefresh 
    -nothrottle
   
### Mednafen 
  for src details, see emu4crt fork https://github.com/psakhis/emu4crt
  ,on mednafen.cfg set:
  
    mister.host "192.x.x.x"
    mister.port 32100
    mister.lz4 1 (raw or lz4)
    mister.vsync 0 (automatic frame delay)
  
  
### Retroarch (Dreamcast non working atm)
  
  on retroarch.cfg set:
  
    mister_ip = "192.x.x.x"
    mister_lz4 = "true"
    video_mister_enable = "true"

    *Automatic frame delay for best results on latency options





