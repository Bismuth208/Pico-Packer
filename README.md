# Pico Packer

This tool convert and compress indexed (or not) ".png" files
by simple RLE and tiny dictionary (like LZ family) to ".h" files.
It was created as compression tool for indexed pictures in my games.

#### Build:
- YOU NEED to instal dmd compiler for D lang, grab it at https://dlang.org;
- compile it according howto at https://dlang.org;
- if you are runnig OS whith BASH, then just run "./build_release.sh";
- or compile like this: "dmd picoPacker.d arsd/{color,png}.d"

#### Be sure what you: 
- add "gimp_picoPacker_80c.gpl" palette to GIMP (paths are OS specific look howto in net);
- make image indexed whith "gimp_picoPacker_80c.gpl" palette;
- export image as ".png".
  - *p.s It's all unnecessary, tool can try to convert by itself, but result may be unpredictable.*

#### Usage: 
- place program in folder whith ".png" files;
- run terminal\command promt;
- exec picoPacker (execution is OS speciffic look in Internet howto, in nix systems type: "./picoPacker");
- wait untill program print "All done!".
  - *p.s Program also scan and process subfolders if they exists.*
  - *p.p.s Works ONLY whith data value < 0x50 as unsed 0x2f values *ARE USED* by this compressor!*
  - *p.p.p.s If program seems to stuck, then something is going wrong...*
  - *p.p.p.p.s This tool support different types of compressing, type "./picoPacker -h" for more info.*

Time of converting depends on size of data files
and power of your CPU, SSD and\or HDD (aka magic).
Also multicore CPU have advantage (converts faster), formula is
((Number of files) devided by (Number of cores)) multiplexed by magic index.


#### RLE format: 
- (0x80 | data), marker and data (0x80 - marker specify RLE start);
- repeatTimes, how much to repeat previous data.

#### Dictionary rules: 
- may be empty, in this case size of *offset* will be 0x02;
- consists of byte pairs (duplets - two bytes as one index);
- size of dictionary may be from 0 to 46 duplets;
- minimal size of repeats to be replaced by dict index is 3 (minMatchCount);
- duplets have index values from 0xd0 to 0xfc.

#### Examples: 
Packed data | Unpacked data
------------|--------------
0x81, 0x01 | 0x01, 0x01, 0x01
0x01, 0x01, 0x00 | no RLE, only raw data
0x8f,0x02,0x0e,0x0e | 0x0f,0x0f,0x0f,0x0f,0x0e,0x0e
0x81,0x02,0xd0,0x22 | 0x01,0x01,0x01,0x01,(get duplet at index 0),0x22
- *p.s duplets may represent everything: RLE pair, raw data or another duplet (if V3 enabled).*


Structure of every generated header (picture):
```C
pic_t somePicName[] PROGMEM = { 
  width-1, height-1,  // one byte each 
  offset,             // one byte offset to picture data and dictionary size 
  dictionary,         // from zero to 92 bytes (values from 0xd0 to 0xfc) 
  picture data,       // a lot of bytes... or at least one byte ;) 
  end marker          // 0xff mean picture data end 
};
```
- *p.s -1 at begin of every pic is conversations to correspond to tft display addr size.* 
- *p.p.s width, height you need to write manually as raw data not contain this params.*
- *p.p.p.s pic_t type is "typedef const uint8_t".*

***
- Author: Antonov Alexander (Bismuth208) 
- Date: 12 november 2017 
- Last edit: 22 april 2018
- Lang: D 
- Compiler: DMD v2.079.1 

Also, this program use arsd modules (png.d and color.d).
[Original author and libs are here:](https://github.com/adamdruppe/arsd "Adam D. Ruppe git")

> ### :exclamation: ATTENTION! :exclamation:
>  * Sometimes it's generate garbage! :beetle:
>  * If it's happen then just remove dictionary encode and use only RLE part,
>  * or just play whith input arguments.
