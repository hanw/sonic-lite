typedef 16 RoundSize;
typedef 16 MsgTypeSize;
typedef 32 InstanceSize;
typedef 256 ValueSize;

typedef struct {
   Bit#(InstanceSize) addr;
   Bit#(RoundSize) data;
   Bool write;
} RoundRegRequest deriving (Bits);

typedef struct {
   Bit#(RoundSize) data;
} RoundRegResponse deriving (Bits);


