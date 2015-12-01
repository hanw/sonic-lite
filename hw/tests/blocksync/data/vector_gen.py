#
# This script converts bitstream.dat which has 64 bit in a row
# to test_vector.hex which has 66 bit in a row, separate into
# two column, first column has one byte, second column has 
# eight bytes.
# Author: Han Wang
# Date: 11/14/2011
#

#!/bin/python
import string

from bitstring import *
from bitstream import *

conv_64_to_66 ('../../scripts/test_vector.dat', 'test_vector.dat')
