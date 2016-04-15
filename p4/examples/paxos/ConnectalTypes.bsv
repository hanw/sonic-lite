import ClientServer::*;

typedef 16 RoundSize;
typedef 16 MsgTypeSize;
typedef 32 InstanceSize;
typedef 64 ValueSize;

typedef struct {
   Bit#(InstanceSize) addr;
   Bit#(RoundSize) data;
   Bool write;
} RoundRegRequest deriving (Bits);

typedef struct {
   Bit#(RoundSize) data;
} RoundRegResponse deriving (Bits);

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
   Bit#(8) role;
} RoleT deriving (Bits, Eq);

typedef struct {
   Bit#(1) addr;
   Bit#(8) data;
   Bool write;
} RoleRegRequest deriving (Bits);

typedef struct {
   Bit#(8) data;
} RoleRegResponse deriving (Bits);

typedef struct {
   Bit#(1) addr;
   Bit#(64) data;
   Bool write;
} DatapathIdRegRequest deriving (Bits);

typedef struct {
   Bit#(64) data;
} DatapathIdRegResponse deriving (Bits);

typedef struct {
   Bit#(1) addr;
   Bit#(16) data;
   Bool write;
} InstanceRegRequest deriving (Bits);

typedef struct {
   Bit#(16) data;
} InstanceRegResponse deriving (Bits);

typedef struct {
   Bit#(InstanceSize) addr;
   Bit#(RoundSize) data;
   Bool write;
} VRoundRegRequest deriving (Bits);

typedef struct {
   Bit#(RoundSize) data;
} VRoundRegResponse deriving (Bits);

typedef struct {
   Bit#(InstanceSize) addr;
   Bit#(ValueSize) data;
   Bool write;
} ValueRegRequest deriving (Bits);

typedef struct {
   Bit#(ValueSize) data;
} ValueRegResponse deriving (Bits);

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

