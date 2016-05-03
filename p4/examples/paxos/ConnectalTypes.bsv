import ClientServer::*;

typedef 16 RoundSize;
typedef 16 MsgTypeSize;
typedef 16 DatapathSize;
typedef 32 InstanceSize;
typedef 256 ValueSize;
typedef 65535 InstanceCount;

typedef enum {
   PAXOS_1A = 1,
   PAXOS_1B = 2,
   PAXOS_2A = 3,
   PAXOS_2B = 4
} MsgType deriving (Bits, Eq);

typedef struct {
   Bit#(addrSz) addr;
   Bit#(dataSz) data;
   Bool write;
} RegRequest#(numeric type addrSz, numeric type dataSz) deriving (Bits, Eq);

typedef struct {
   Bit#(dataSz) data;
} RegResponse#(numeric type dataSz) deriving (Bits, Eq);

typedef RegRequest#(16, RoundSize) RoundRegRequest;
typedef RegResponse#(RoundSize) RoundRegResponse;
typedef RegRequest#(1, DatapathSize) DatapathIdRegRequest;
typedef RegResponse#(DatapathSize) DatapathIdRegResponse;
typedef RegRequest#(1, InstanceSize) InstanceRegRequest;
typedef RegResponse#(InstanceSize) InstanceRegResponse;
typedef RegRequest#(16, RoundSize) VRoundRegRequest;
typedef RegResponse#(RoundSize) VRoundRegResponse;
typedef RegRequest#(16, ValueSize) ValueRegRequest;
typedef RegResponse#(ValueSize) ValueRegResponse;

typedef enum {
   ACCEPTOR = 1,
   COORDINATOR = 2
} Role deriving (Bits, Eq);
instance FShow#(Role);
   function Fmt fshow(Role role);
      case(role)
         ACCEPTOR: return fshow("ACCEPTOR");
         COORDINATOR: return fshow("COORDINATOR");
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
    Handle1A,
    Handle2A,
    Drop,
    Unused
} AcceptorTblActionT deriving (Bits, Eq, FShow);

//typedef struct {
//   AcceptorTblAction act;
//} AcceptorTblActionT deriving (Bits, Eq, FShow);
