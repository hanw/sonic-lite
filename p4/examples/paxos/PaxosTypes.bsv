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


