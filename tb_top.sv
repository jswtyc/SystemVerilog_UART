`timescale 1ns / 1ps

module tb_top(    );

/*****************************************************************************
*                                 variable                                  *
*****************************************************************************/
// top signal
bit				  clk     ;
bit               rst     ;
always #5 clk = ~clk;

//tx signal
logic             tx      ;
logic             tx_rdy  ;
bit    [7 : 0]    tx_data ;

//rx signal
wire               rx_vld     ;
wire    [7 : 0]    rx_data    ;
wire               rx_pc_pass ;

/*****************************************************************************
*                                  testing                                  *
*****************************************************************************/

bit [7:0] temp;
bit [7:0] q[$];
always_ff @ (posedge clk) begin
    temp = $urandom();
    if(tx_rdy) begin
        q.push_back(temp);
        tx_data <= temp;
    end
    if(rx_vld)
        assert(q.pop_front() == rx_data);
end

/*****************************************************************************
*                                 instance                                  *
*****************************************************************************/

uart_tx#(
	.PARITY_CHECK("NONE"    ),
	.CLK_FREQ    (100000000 ),
	.TX_FREQ     (1000000   )
)transmitter(
    .clk    ( clk       ),
    .rst    ( rst       ),
    
    .i_vld  ( 1'b1      ),
    .i_data ( tx_data   ),
    
    .o_rdy  ( tx_rdy    ),
    .tx     ( tx        )
);

uart_rx#(
	.PARITY_CHECK("NONE"    ),
	.CLK_FREQ    (100000000 ),
	.TX_FREQ     (1000000   )
)receiver(
    .clk     ( clk        ),
    .rst     ( rst        ),
    
    .rx      ( tx         ),
    .i_rdy   ( 1'b1       ),
    
    .o_vld   ( rx_vld     ),
    .pc_pass ( rx_pc_pass ),
    .o_data  ( rx_data    )
) ;
initial begin
    rst = 1;
    #20
    rst = 0;
end

endmodule

