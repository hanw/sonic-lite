## API

` read_timestamp_req(uint8_t cmd) ` issues a read request to NIC, the response to the request will be available through the callback function `read_timestamp_resp(uint64_t timestamp)`. The callback function is invoked by hardware.

` log_write(uint8_t port_no, uint64_t counter) ` issues a log write message to the logger.
   this should generate two 56-bit data: one for `counter` and the other for `current DTP counter of the NIC`

` log_read(uint8_t port_no) ` issues a logger read request to retreive a log message. The requested message is available through callback function `log_read_resp(uint8_t port_no, uint64_t local_timestamp, uint64_t message1, uint64_t message2)`. This is used by logger. `message1` is the `counter` from `log_write`, and `message2` is the ` DTP counter from the remote NIC` from `log_write` of the remote node. 
  
` dtp_delay_read(uint8_t port_no) ` read the measured delay of `port_no`

` dtp_state_read(uint8_t port_no) ` read the current state of the dtp state machine for port `port_no`.

` dtp_stats_jump_read(uint8_t port_no) ` read the number of counter jump for port `port_no`.

` dtp_ctrl_reset(uint8_t port_no) ` resets dtp state machine for port `port_no`.

` dtp_ctrl_set_local(uint8_t port_no, uint64_t counter)` manually set the counter for port `port_no`.

` dtp_ctrl_disable(void)` disable dtp state machine. A dtp-capable device is by default disabled.

` dtp_ctrl_enable(void)` enable dtp_state_machine.
