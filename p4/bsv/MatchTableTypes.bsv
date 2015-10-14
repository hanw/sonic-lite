import DefaultValue::*;

typedef 32 KEY_LEN;
typedef 32 VALUE_LEN;
typedef 1021 TABLE_LEN;
typedef 20 ADDR_LEN; //log(TABLE_LEN * (KEY_LEN+VALUE_LEN))

/* if you change this value, also make sure to change 
 * priority_encoder() and flip_bit_at_pos() functions
 * in MatchTable.bsv file.
*/
typedef 8 TABLE_ASSOCIATIVITY; // a match table consists of 8 hash tables

typedef Bit#(KEY_LEN) Key;
typedef Bit#(VALUE_LEN) Value;
typedef Bit#(10) AddrIndex; //XXX log(TABLE_LEN)
typedef Bit#(ADDR_LEN) Address;

typedef enum {GET, PUT, UPDATE, REMOVE, NONE} Operation deriving(Bits, Eq);
typedef enum {VALID, INVALID} Tag deriving(Bits, Eq);

typedef struct {
    Key key;
    Value value;
    Tag valid;
} Data deriving(Bits, Eq);

typedef struct {
    Key key;
    Value value;
    Operation op;
    AddrIndex addrIdx;
} RequestType deriving(Bits, Eq);

instance DefaultValue#(RequestType);
    defaultValue = RequestType {
                                key : 0,
                                value : 0,
                                op : NONE,
                                addrIdx : 0
                               };
endinstance

typedef struct {
    Key key;
    Value value;
    AddrIndex addrIdx;
    Operation op;
    Tag tag; //INVALID if operation failedt
} ResponseType deriving(Bits, Eq);

instance DefaultValue#(ResponseType);
    defaultValue = ResponseType {
                                key : 0,
                                value : 0,
                                addrIdx : 0,
                                op : NONE,
                                tag : INVALID
                               };
endinstance
