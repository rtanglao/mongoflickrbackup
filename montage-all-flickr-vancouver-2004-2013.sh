#!/bin/bash
gm montage -verbose -adjoin -tile 25x14 +frame +shadow +label +adjoin -geometry '75x75+0+0<' @all_jpgs.txt %06d-hd-all-vancouver2004-2013.jpg
