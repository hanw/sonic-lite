import ClientServer::*;

typedef 16 RoundSize;
typedef 16 MsgTypeSize;
typedef 16 DatapathSize;
typedef 32 InstanceSize;
typedef 32 ValueLenSize;
typedef 256 ValueSize;
typedef 1024 InstanceCount;

typedef enum {
   PAXOS_1A = 0,
   PAXOS_1B = 1,
   PAXOS_2A = 2,
   PAXOS_2B = 3
} MsgType deriving (Bits, Eq);

typedef struct {
   Bit#(addrSz) addr;
   Bit#(dataSz) data;
   Bool write;
} RegRequest#(numeric type addrSz, numeric type dataSz) deriving (Bits, Eq);

typedef struct {
   Bit#(dataSz) data;
} RegResponse#(numeric type dataSz) deriving (Bits, Eq);

typedef RegRequest#(TLog#(InstanceCount), RoundSize) RoundRegRequest;
typedef RegResponse#(RoundSize) RoundRegResponse;
typedef RegRequest#(1, DatapathSize) DatapathIdRegRequest;
typedef RegResponse#(DatapathSize) DatapathIdRegResponse;
typedef RegRequest#(1, InstanceSize) InstanceRegRequest;
typedef RegResponse#(InstanceSize) InstanceRegResponse;
typedef RegRequest#(TLog#(InstanceCount), RoundSize) VRoundRegRequest;
typedef RegResponse#(RoundSize) VRoundRegResponse;
typedef RegRequest#(TLog#(InstanceCount), ValueSize) ValueRegRequest;
typedef RegResponse#(ValueSize) ValueRegResponse;

typedef enum {
   ACCEPTOR,
   COORDINATOR,
   FORWARDER
} Role deriving (Bits, Eq);
instance FShow#(Role);
   function Fmt fshow(Role role);
      case(role)
         ACCEPTOR: return fshow("ACCEPTOR");
         COORDINATOR: return fshow("COORDINATOR");
         FORWARDER: return fshow("FORWARDER");
      endcase
   endfunction
endinstance

typedef RegRequest#(1, SizeOf#(Role)) RoleRegRequest;
typedef RegResponse#(SizeOf#(Role)) RoleRegResponse;

typedef struct {
   Role role;
} RoleT deriving (Bits, Eq);

//typedef struct {
//   Bit#(1) addr;
//   Role data;
//   Bool write;
//} RoleRegRequest deriving (Bits);
//
//typedef struct {
//   Role data;
//} RoleRegResponse deriving (Bits);
//
typedef Client#(RoundRegRequest, RoundRegResponse) RoundRegClient;
typedef Server#(RoundRegRequest, RoundRegResponse) RoundRegServer;
typedef Client#(RoleRegRequest, RoleRegResponse) RoleRegClient;
typedef Server#(RoleRegRequest, RoleRegResponse) RoleRegServer;
typedef Client#(DatapathIdRegRequest, DatapathIdRegResponse) DatapathIdRegClient;
typedef Server#(DatapathIdRegRequest, DatapathIdRegResponse) DatapathIdRegServer;
typedef Client#(InstanceRegRequest, InstanceRegResponse) InstanceRegClient;
typedef Server#(InstanceRegRequest, InstanceRegResponse) InstanceRegServer;
typedef Client#(VRoundRegRequest, VRoundRegResponse) VRoundRegClient;
typedef Server#(VRoundRegRequest, VRoundRegResponse) VRoundRegServer;
typedef Client#(ValueRegRequest, ValueRegResponse) ValueRegClient;
typedef Server#(ValueRegRequest, ValueRegResponse) ValueRegServer;

/* Tables */
typedef enum {
    FORWARD,
    BROADCAST
} DmacTblActionT deriving (Bits, Eq, FShow);

typedef enum {
    Nop,
    IncreaseInstance
} SequenceTblActionT deriving (Bits, Eq, FShow);

typedef enum {
    Unused,
    Handle1A,
    Handle2A,
    Drop
} AcceptorTblActionT deriving (Bits, Eq, FShow);

//typedef struct {
//   AcceptorTblAction act;
//} AcceptorTblActionT deriving (Bits, Eq, FShow);
