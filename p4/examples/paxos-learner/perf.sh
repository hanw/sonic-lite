#!/bin/bash

# script to convert following bluesim log

#(1000) blah blah
#(1010) foo bar
#(1020) xxx
#(1030) yyy

# to

#10
#10
#10

awk '{print $1}' $1 | sed 's/(//g' | sed 's/)//g' | awk 'NR==1{old=$1;next} {print $1-old; old=$1}'
