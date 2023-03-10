## Physical Layer

The Physical Layer of the Serial Link has multiple channels where each channel has a configurable number of Lanes and its own source-synchronous clock. The physical protocol is essentially based on oversampling which is achieved by sending the data with a generated divided clock. The data is sent with Double-Data-Rate (DDR).

### Protocol
The physical protocol of the Serial Link is shown below

![Physical Protocol of the Serial Link](fig/phy-protocol.svg  "Physical Protocol of the Serial Link")

The data is sent synchronous to a generated divided clock, which is generated by a simple and SW configurable clock divider. Further, a clock is forwarded together with the data to sample the data on the receiving side. This forwarded source-synchronous clock typically has a phase shift of 90 degrees, such that sampling occurs when the eye opening is at a maximum. The exact phase shift is configurable i.e. the negative and positive edge of the forwarded clock can be configured independently by SW.

### TX Channel
The implementation of a TX channel is pretty simple. It contains a clock a configurable clock divider for generating the divided data and the forwarded clock. Since the Serial Link is Double-Data-Rate (DDR), the TX channel just multiplexes the output based on the data clock. To signal when actual data is being sent the TX channel clock-gates the forwarded clock i.e. in idle operating mode the forwarded clock is tied to `'1`.

### RX Channel
On the RX side a CDC FIFO takes care of synchronizing the data to the system clock. DDR is handled by sampling the first part of data on negedge-triggered FF and sampling the second part directly with the CDC Fifo which is positive-edge triggered.