import Vector::*;
import Pipe::*;
import MemTypes::*;
import ConnectalConfig::*;

`include "ConnectalProjectConfig.bsv"
typedef `NumChannels NumChannels;

interface DmaTopPins;
   // derived from pcie clock
   interface Clock clock;
   interface Reset reset;
   // data out to application logic
   interface Vector#(NumChannels,PipeOut#(MemDataF#(DataBusWidth))) toFpga;
   // data in from application logic
   interface Vector#(NumChannels,PipeIn#(MemDataF#(DataBusWidth)))  fromFpga;
endinterface
