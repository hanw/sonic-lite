import DefaultValue::*;

 typedef 32 IP_ADDR_LEN;
 typedef 48 MAC_ADDR_LEN;
 typedef 4 NUM_OF_SERVERS;
 typedef 3 NUM_OF_PORTS;

 typedef 8 DEFAULT_FIFO_LEN;

 typedef Bit#(IP_ADDR_LEN) IP;
 typedef Bit#(MAC_ADDR_LEN) MAC;
 typedef Bit#(4) ServerIndex; /* bits to represent num of servers */
 typedef Bit#(3) PortIndex; /* bits to represent num of ports */
 typedef Bit#(32) Address;

 typedef 16 RING_BUFFER_SIZE; /* make sure it is a power of 2 */

 typedef enum {CONFIG, RUN} State deriving(Bits, Eq);

 typedef struct {
      IP server_ip;
      MAC server_mac;
 } TableData deriving(Bits, Eq); /* Each entry in the table */

 instance DefaultValue#(TableData);
      defaultValue = TableData {
                         server_ip : 0,
                         server_mac : 0
                      };
 endinstance
