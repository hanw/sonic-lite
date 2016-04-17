import ClientServer::*;

typedef 16 RoundSize;
typedef 16 MsgTypeSize;
typedef 32 InstanceSize;
typedef 64 ValueSize;

typedef struct {
   Bit#(addrSz) addr;
   Bit#(dataSz) data;
   Bool write;
} RegRequest#(numeric type addrSz, numeric type dataSz) deriving (Bits, Eq);

typedef struct {
   Bit#(dataSz) data;
} RegResponse#(numeric type dataSz) deriving (Bits, Eq);

typedef RegRequest#(InstanceSize, RoundSize) RoundRegRequest;
typedef RegResponse#(RoundSize) RoundRegResponse;
typedef RegRequest#(1, 64) DatapathIdRegRequest;
typedef RegResponse#(64) DatapathIdRegResponse;
typedef RegRequest#(1, 16) InstanceRegRequest;
typedef RegResponse#(16) InstanceRegResponse;
typedef RegRequest#(InstanceSize, RoundSize) VRoundRegRequest;
typedef RegResponse#(RoundSize) VRoundRegResponse;
typedef RegRequest#(InstanceSize, ValueSize) ValueRegRequest;
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

typedef struct {
   Role role;
} RoleT deriving (Bits, Eq);

typedef struct {
   Bit#(1) addr;
   Role data;
   Bool write;
} RoleRegRequest deriving (Bits);

typedef struct {
   Role data;
} RoleRegResponse deriving (Bits);

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
    FORWARD = 1,
    BROADCAST = 2
} DmacTblActionT deriving (Bits, Eq, FShow);

typedef enum {
    IncreaseInstance = 1,
    Nop = 2
} SequenceTblActionT deriving (Bits, Eq, FShow);

typedef enum {
    Handle1A = 1,
    Handle2A = 2,
    Drop = 3,
    None = 4
} AcceptorTblActionT deriving (Bits, Eq, FShow);

