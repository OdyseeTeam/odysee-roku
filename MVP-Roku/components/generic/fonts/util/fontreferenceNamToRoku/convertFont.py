#!/usr/bin/python3
import os.path
import sys
#this script converts from a fontforge namelist (encoding -> save namelist of font) to a roAssociativeArray of integers that can be used with Chr, or alternatively provides raw characters instead.
#should be useful with fonts that use non-standard characters.
varname = "vjschars" # Change Roku variable name here
filename = "./VideoJS.nam" # Change filename here
providesRawChars = True # Change to provide raw chars/don't (true/false)

def readfile(filename):
    try:
        file = open(filename, "r+")
        data = file.read()
        return(data)
    except:
        return("")

fontData = readfile(filename).split("\n")
lines = []
filtereditems = []
for fontitem in fontData:
 subData = fontitem.split(" ")
 if len(subData) > 1:
  filtereditems.append(fontitem)
filtereditemslength = len(filtereditems)

for i in range(len(filtereditems)):
  subData = filtereditems[i].split(" ")
  unicodeInt = int(subData[0].split("x")[1], 16)
  if providesRawChars:
   lines.append("\""+subData[1]+"\": Chr("+str(unicodeInt)+")")
  else:
   lines.append("\""+subData[1]+"\": "+str(unicodeInt))

print(varname+" = {"+", ".join(lines)+"}")
