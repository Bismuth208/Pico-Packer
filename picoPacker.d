/+
 + Author: Antonov Alexander (Bismuth208)
 + Date: 12 november 2017
 + Last edit: 22 april 2018
 + Lang: D
 + Compiler: DMD v2.079.1
 +
 + This tool convert and compress indexed (or not) ".png" files
 + by simple RLE and tiny dictionary (like LZ family) to ".h" files.
 +
 + For more info look readme.md for picoPacker (rleEncoder in old times)!
 +/

import arsd.color;
import arsd.png;

immutable auto infoText = "\nPico Packer. v0.5. Build: " ~ __TIMESTAMP__;
immutable auto fmtSize = "// Old size %d * 2 = %d\n// New size = %d + 2\n// Compress ratio %f\n";
immutable auto fmt = "pic_t %s[] PROGMEM = {  // -l%d -d%d\n  0x%.2x,0x%.2x, // width and height";

immutable auto minMatchCount = 3;
immutable auto rleMark = 0x80; /// RLE marker. Show to unpaker where raw data and where compressed data.
immutable auto pictureEndMarker = 0xff; /// Show what no more bytes in picted left.

/// Base value of pair bytes in dictionary; (rleMark + 0x50) or (0xff - maxDictSize - 1).
/// 0x50 - is data range from 0x00 to 0x4F + 1.
immutable auto dictPosMarker = 0xd0;
immutable auto maxDataLength = 0xcf; /// Calculated as: dictPosMarker-1, but actual size is: dictPosMarker-2

/// Maximum dictionary size in pairs of ubyte. Calculated as: 0xfe - dictPosMarker-1
immutable auto maxDictSize = 0x2d;
ubyte dictSize = maxDictSize;

/** Which pack to use; V3 needs more RAM on unpack.
  Where are 4 versions:
    v0 - only raw data (converted png to rgb565).
    v1 - simple RLE, whith no dictionary used.
    v2 - more strict rules, proveide less compression, also sometimes work better...
    v3 - is much more relaxed, on unpack may reque a lot of RAM.
*/
enum compressVersion { V0, V1, V2, V3 }
auto compressVersionCurrent = cast(int)compressVersion.V3;

/** Palette used to make indexed pictures.
  Colors are represented in RGB565 color space,
  as it's used in most of TFT displays and in all my games.

  Size: 160 ( 80 * sizeof(uint16_t) )

  It's include 4 brightness level. Each one in it's own range:
    0x00-0x0F : very dark;
    0x10-0x1F : mid dark;
    0x20-0x2F : normal;
    0x30-0x3F : mid bright;
    0x40-0x4F : very bright.
*/
immutable auto palette_ext = [
  // 0x00-0x0F
  0x020C, 0x01F4, 0x0096, 0x4012, 0xA00B, 0xC005, 0xB820, 0x88A0,
  0x5960, 0x3220, 0x0240, 0x0226, 0x02CC, 0x8410, 0x0000, 0x0020,
  
  // 0x10-0x1F
  0x04D9, 0x03BF, 0x4ABF, 0x81BF, 0xC0B3, 0xE0E8, 0xF182, 0xD244,
  0xC300, 0x54C0, 0x0460, 0x04AB, 0x04D4, 0xC638, 0x2104, 0x0020,
  
  // 0x20-0x2F
  0x06FD, 0x059F, 0x44BD, 0x837F, 0xE23B, 0xF94D, 0xFB06, 0xF3E2,
  0xE5C3, 0x9EC1, 0x2668, 0x0E91, 0x06F9, 0xE71C, 0x31A6, 0x0020,
  
  // 0x30-0x3F
  0x07DF, 0x06FF, 0x751F, 0xAC1F, 0xEB1E, 0xFB33, 0xFCCE, 0xF589,
  0xFF04, 0xBF01, 0x2F86, 0x0F94, 0x07BB, 0xEF7D, 0x5AEB, 0x0020,
  
  // 0x40-0x4F
  0x9FFF, 0x875F, 0xA6BF, 0xDD5D, 0xFD5F, 0xFD56, 0xFE96, 0xFF34,
  0xFFB3, 0xD752, 0xA771, 0x8FB5, 0x9F9C, 0xFFFF, 0xDEFB, 0x0020
];

/// Converted version of palette_ext. It's need to transcode *.png files.
Color[] rgbaPalette;

/// Need to store some propities to fill *.h file correctly.
struct PicoPic {
  int width; ///
  int height; ///
  ubyte[] data; /// compressed by RLE and dictionary data.
}

/// Search for maximum repeats of ubyte pairs in ubute[] to create dictionary
/// Also supports two types of serching, V2 and V3.
auto findMatch(ref ubyte[] buf) {
  import std.algorithm : count;

  auto offset = 0;
  auto offsetMax = 0;
  auto matchCount = 0UL;
  auto allMatchFound = false;
  auto matchCountMax = buf.count(buf[0..2]);

  while(!allMatchFound) {
    if(compressVersionCurrent == compressVersion.V3) {
      ++offset;
    } else {      
      do {
        ++offset;
      } while(((buf[offset] >= dictPosMarker) || (buf[offset+1] >= dictPosMarker)) && (offset < buf.length-2));
    }

    if(offset < buf.length-2) {
      matchCount = buf[offset..$].count(buf[offset..offset+2]);

      if(matchCount > matchCountMax) {
        matchCountMax = matchCount;
        offsetMax = offset;
      }
    } else {
      allMatchFound = true;
    }
  }
  
  return (matchCountMax >= minMatchCount) ? buf[offsetMax..offsetMax+2] : buf[0..0];
}

/// Compress ubute[] by replacing same pairs of ubyte, also make dictionary
/// FIXME: need to setup inception level of dictionary replace
auto encodeMatches(ref ubyte[] buf) {
  import std.array : replace;

  auto dictionaryArr = new ubyte[1];
  auto markerBuf = new ubyte[1];
  auto tmpDict = new ubyte[2];
  auto dictPos = 0;
  
  do {
    tmpDict = buf.findMatch;
    
    if(tmpDict.length) { // found something?
      markerBuf[0] = cast(ubyte)(dictPosMarker + dictPos); // replaceVal
      buf = buf.replace(tmpDict, markerBuf);
      dictionaryArr ~= tmpDict;
      ++dictPos;
    }
  } while((tmpDict.length) && (dictPos < dictSize));
  
  // size of dictionary offset
  dictionaryArr[0] = cast(ubyte)(dictionaryArr.length+1);
  return dictionaryArr;
}

/// Make simple RLE compression whith indexed ubyte[]
auto compressRLE(ref ubyte[] buf) {
  import std.outbuffer, std.algorithm : group;

  auto encodedRLE = new OutBuffer;
  auto dataBuf = new ubyte[2];
  auto tmpByte = cast(ubyte)0;
  auto fastGrop = buf.group;  // actually this one make all RLE job...
  auto rleCount = 0;
  
  auto repeatWrite = (int i, int size, ubyte data) {
    dataBuf[0] = cast(ubyte)(data | rleMark);
    dataBuf[1] = cast(ubyte)size;
    while(i--){ encodedRLE.write(dataBuf);}}; // repeatByte and how much to repeat

  foreach(rleData; fastGrop) {
    rleCount = rleData[1]; // get data  from tuple:
    tmpByte = rleData[0];  //   [ tuple(val, times), ... ][]

    if(rleCount > 2) {
      if(rleCount > maxDataLength) {
        repeatWrite((rleCount / maxDataLength), maxDataLength-1, tmpByte); 
        rleCount -= maxDataLength * (rleCount / maxDataLength);
      }
      if(rleCount) { // left something?
        repeatWrite(1, rleCount-2, tmpByte);
      }
    } else {
      do {
        encodedRLE.write(tmpByte); // from 1 to 2 bytes to write
      } while (--rleCount);
    }
  }

  return encodedRLE.toBytes;
}

/// Converts Color pixel to RGB565 int
int colorTo565(ref Color pixel) {
  return ((cast(ubyte)pixel.r & 0xF8) << 8)
       | ((cast(ubyte)pixel.g & 0xFC) << 3)
       | (cast(ubyte)pixel.b >> 3);
}

/// Converts *.png files to indexed ubyte[] array
/// FIXME: add some warn if it's found nothing in palette_ext!
auto transcodePNG(ref string fileName) {
  import std.algorithm : countUntil;

  auto img = readPng(fileName);
  auto indexColor = 0;
  auto isIndexed = 0;
  Color pixel;

  PicoPic pic;
  pic.width = img.width;
  pic.height = img.height;
  pic.data = new ubyte[img.width * img.height];

  // it's veeery slow, in future i'll make something whith it...
  for(int y=0; y < pic.height; y++) {
    for(int x=0; x < pic.width; x++) {
      pixel = img.getPixel(cast(int)x, cast(int)y);
      indexColor = pixel.colorTo565;
      isIndexed = cast(int)palette_ext.countUntil(indexColor);
      pic.data.ptr[y*pic.width+x] = isIndexed ? cast(ubyte)isIndexed : findNearestColor(rgbaPalette, pixel);
    }
  }
  return pic;
}

/// Main core, actually do all stuff
void fillHeader(ref string fileName) {
  import std.file, std.outbuffer;//, std.string;

  auto arrayEnd = new OutBuffer;
  auto dictionaryArr = new ubyte[1];
  auto array = fileName.transcodePNG;
  auto bufSize = array.data.length;
  auto pictureSize = 0UL;
  auto headerName = fileName[0..$-4]; // fileName.chomp(".png");
  
  auto writeEndArr = (ref ubyte[] refArr, int sep) { // this lambda make new line each sep bytes
    foreach(i, ref pArr; refArr) arrayEnd.writef("%s0x%.2x,", (!(i % sep) ? "\n  " : ""), pArr);
  };

  dictionaryArr[0] = 0x02; // empty dictionary

  if(compressVersionCurrent > compressVersion.V0) {
    array.data = array.data.compressRLE;
    if(compressVersionCurrent > compressVersion.V1) { // v2,v3
      dictionaryArr = array.data.encodeMatches;
    }
  }

  array.data ~= cast(ubyte)pictureEndMarker;
  pictureSize = dictionaryArr.length + array.data.length;
  
  arrayEnd.writef(fmtSize, bufSize, bufSize*2, pictureSize, cast(float)(bufSize)/cast(float)pictureSize);
  arrayEnd.writef(fmt, headerName, cast(int)compressVersionCurrent, cast(int)dictionaryArr.length/2, array.width-1, array.height-1);
 
  writeEndArr(dictionaryArr, 16);
  writeEndArr(array.data, 16); // comressed and encoded array
  arrayEnd.write("\n};");

  (headerName ~ ".h").write(arrayEnd.toBytes); // write result to file
}

void processFile(string fileName) {
  import std.stdio;

  "\t%s...\n".writef(fileName);
  fileName.fillHeader;
}

/// Create Color[] palette from RGB565 int palette
void createPalette() {
  import std.stdio;

  Color pixel;
  rgbaPalette = new Color[palette_ext.length];

  "Creating palette... ".write;
  foreach(i, ref id; palette_ext) {
    pixel.r = (id >> 8) & 0xF8;
    pixel.g = (id >> 4) & 0x7E;
    pixel.b = (id & 0x1F);

    rgbaPalette[i] = pixel;
  }
  "Done!".writeln;
}

/// return false if help was requested
auto pareArguments(ref string[] args, ref string fileName) {
  import std.getopt;

  auto ok = true;
  auto newDictSize = cast(ubyte)maxDictSize;
  auto rslt = getopt(args, "level|l", "Select compression level: 0-3", &compressVersionCurrent,
                           "dict|d", "Select dictionary size. min: 0, max: 46", &newDictSize,
                           "file|f", "Select single *.png file to convert.", &fileName);

  if(rslt.helpWanted) {
    defaultGetoptPrinter(infoText, rslt.options);
    ok = false;
  } else {
    if(newDictSize != dictSize) {
      dictSize = newDictSize;
      if(dictSize == 0) {
        compressVersionCurrent = compressVersion.V1; // only RLE
      } else {
        if(dictSize > maxDictSize) {
          dictSize = maxDictSize;
        }
      }      
    }

    if(compressVersionCurrent > compressVersion.V3) {
      compressVersionCurrent = compressVersion.V3;
    } else {
      if(compressVersionCurrent == compressVersion.V1) {
        dictSize = 0;
      }
    }    
  }

  return ok;
}

void main(string[] args) {
  import std.file, std.stdio, std.parallelism;
  import std.conv, std.algorithm : canFind;

  auto selectedFileName = "";

  if(pareArguments(args, selectedFileName)) {
    createPalette();

    "Start encode...".writeln;
    if(selectedFileName.length) {
      assert(canFind(selectedFileName, ".png"), "Wrong *.png file name!");
      selectedFileName.processFile;
    } else {
      // search all *.png in execution folder and lower folders
      auto dataFiles = dirEntries("", "*.{png}", SpanMode.breadth, false);

      // each file parsed in thread,
      // number of threads depend on your CPU and it's number of real cores
      foreach(i; dataFiles.parallel(to!int(totalCPUs))) {
        i.name.processFile;
      }    
    }
    "All Done!".writeln;
  }
}
