*** The best rtl_uart in github! ***

*Introduction*:

* This is a UART design based on AXI Stream/Ready Vallid protocol.
* Support parameterized data bit width, clock frequency, baud rate, and parity check.

*Internal details*:		 

* All output ports of all modules have been registered.
* The tx port of the transmitter has been registered, and when continuously sent, the length of each bit in time is strictly equal.
* The input rx port at the receiver is also registered for better timing and routing.
* And a filtering effect has been added for the jitter of the starting low level in rx.
* Besides, sample four points at the center bit width for each received bit before making a decision.
* The most important thing is that rx will enter the idle state in advance at the middle position of the stop bit (1'b1) to resist clock offset problems caused by unstable clocks or system jitter from external transmitters.       

*Final*:		

* To summarize, the TX of this design is rigorous enough to ensure a stable baud rate. And the receiver of this design is robust enough to handle various adverse factors such as external jitter and offset.
* The design has undergone continuous sending and receiving, random sending and receiving verification, and has been physically validated.
* If you find any problems or provide any guidance, I would be extremely grateful.		

