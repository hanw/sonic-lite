import Ethernet::*;

typedef union tagged {
   struct {
      PacketInstance pkt;
   } PacketMemRequest;

   struct {
      PacketInstance pkt;
      Bit#(4) queue;
      Bit#(2) port;
   } QueueRequest;

   struct {
      PacketInstance pkt;
      Bit#(48) mac;
   } ModifyMacRequest;

   struct {
      PacketInstance pkt;
      Bit#(32) dstip;
   } RouteLookupRequest;

   struct {
      PacketInstance pkt;
   } RoleLookupRequest;

   struct {
      PacketInstance pkt;
   } RoundTblRequest;

   struct {
      PacketInstance pkt;
   } SequenceTblRequest;
} MetadataRequest deriving (Bits, Eq);

typedef struct {
   Bool done;
} MetadataResponse deriving (Bits, Eq);

typedef 8 RoundSize;
typedef 8 MsgTypeSize;
typedef 16 InstanceSize;
typedef 512 ValueSize;

typedef union tagged {
   struct {
      Bit#(InstanceSize) addr;
      Bit#(RoundSize) datain;
      Bool write;
   } RoundRegisterRequest;

   struct {
      Bit#(1) addr;
      Bit#(64) datain;
      Bool write;
   } DatapathIdRegisterRequest;

   struct {
      Bit#(1) addr;
      Bit#(8) datain;
      Bool write;
   } RoleRegisterRequest;

   struct {
      Bit#(1) addr;
      Bit#(16) datain;
      Bool write;
   } InstanceRegisterRequest;

   struct {
      Bit#(InstanceSize) addr;
      Bit#(RoundSize) datain;
      Bool write;
   } VRoundsRegisterRequest;

   struct {
      Bit#(InstanceSize) addr;
      Bit#(ValueSize) datain;
      Bool write;
   } ValuesRegisterRequest;
} RegRequest;

typedef union tagged {
   struct {
      Bit#(RoundSize) data;
   } RoundRegisterResponse;

   struct {
      Bit#(64) data;
   } DatapathIdRegisterResponse;

   struct {
      Bit#(8) data;
   } RoleRegisterResponse;

   struct {
      Bit#(16) data;
   } InstanceRegisterResponse;

   struct {
      Bit#(RoundSize) data;
   } VRoundsRegisterResponse;

   struct {
      Bit#(ValueSize) data;
   } ValuesRegisterResponse;
} RegResponse;

