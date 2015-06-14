## API

### Currently Implemented
` dtp_read_version()` returns the version of firmware in `uint32_t`
   
` dtp_reset(uint8_t port_no)`
   * resets dtp state machine for port `port_no`.

` dtp_read_delay(uint8_t port_no) ` read the measured delay of `port_no`.
   * returns `uint8_t port_no` and `uint32_t delay`

` dtp_read_state(uint8_t port_no) ` read the current state of the dtp state machine for port `port_no`.
   * returns `uint8_t port_no` and `uint32_t state`

` dtp_read_error(uint8_t port_no) ` read the number of counter jump for port `port_no`.
   * returns `uint8_t port_no` and `uint32_t error`

` dtp_read_cnt(uint8_t cmd) ` returns the **raw counter (free running counter, _NOT DTP counter__)** of the port `port_no`.
   * returns `uint64_t cnt`.
   
~~issues a read request to NIC, the response to the request will be available through the callback function`read_timestamp_resp(uint64_t timestamp)`. The callback function is invoked by hardware.~~

` dtp_logger_write_cnt(uint8_t port_no, uint64_t message) ` issues a log write message to the logger.
   * sends two 56bit `message` and `current DTP counter` to `port_no`
   
   ~~this should generate two 56-bit data: one for `counter` and the other for `current DTP counter of the NIC`~~

### Needs modification
` dtp_logger_read_cnt(uint8_t port_no) ` issues a logger read request to retreive a log message. 
   * returns `uint8_t port_no`, `uint64_t DTP_global_counter`, `uint64_t message1`, `uint64_t message2`.
   
     * where `DTP_global_counter` is the timestamp using `DTP_global_counter` of the logger,
   
     * ` message1` is the first 56bit of the received message,
   
     * ` message2` is the second 56bit of the received message
   
~~The requested message is available through callback function `log_read_resp(uint8_t port_no, uint64_t local_timestamp, uint64_t message1, uint64_t message2)`. This is used by logger. `message1` is the `counter` from `log_write`, and `message2` is the ` DTP counter from the remote NIC` from `log_write` of the remote node. ~~
  
### Needs to be added
` dtp_read_local_cnt(uint8_t port_no)` returns the current **DTP _local_ counter** of port `port_no`.
   *returns `uint64_t local`
   
` dtp_read_global_cnt()` returns the current **DTP _global_ counter**, if it is running as a **switch**.
   *returns `uint64_t global`

` dtp_reset_all()` resets everything.

` dtp_set_beacon_interval(uint8_t port_no, uint32_t interval)` sets the beacon interval of port `port_no` to `interval`.

` dtp_read_beacon_interval(uint8_t port_no)` returns the current beacon interval of `port_no`.
   * returns `uint8_t port_no`, and `uint32_t interval`

### Currently not implemented
` dtp_ctrl_set_local(uint8_t port_no, uint64_t counter)` manually set the counter for port `port_no`.

` dtp_ctrl_disable(void)` disable dtp state machine. A dtp-capable device is by default disabled.

` dtp_ctrl_enable(void)` enable dtp_state_machine.
