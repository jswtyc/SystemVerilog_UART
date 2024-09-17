`timescale 1ns / 1ps

module tb_random_tr(    );

/*****************************************************************************
*                                 variable                                  *
*****************************************************************************/
localparam DATA_WIDTH   = 7       ;
localparam PARITY_CHECK = "NONE"  ;
localparam BAUD_RATE    = 1000000 ;
// top signal
bit				  clk     ;
bit               rst     ;
always #5 clk = ~clk ;

//tx signal
logic                        tx      ;
logic                        tx_rdy  ;
logic                        tx_vld  ;
bit    [DATA_WIDTH-1 : 0]    tx_data ;

//rx signal
wire                          rx_vld     ;
wire    [DATA_WIDTH-1 : 0]    rx_data    ;
wire                          rx_pc_pass ;

/*****************************************************************************
*                                  testing                                  *
*****************************************************************************/
bit    [DATA_WIDTH   : 0]    temp ;
bit    [DATA_WIDTH-1 : 0]    q[$] ;
always_ff @ (posedge clk) begin
	temp = $urandom();
	if (rst)
		tx_vld <= '0;
	else if (tx_rdy) begin
		if (tx_vld)
			tx_vld <= 0;
		else begin
			tx_vld <= temp[DATA_WIDTH];
			if(temp[DATA_WIDTH]) begin
				q.push_back(temp[DATA_WIDTH-1:0]);
				tx_data <= temp[DATA_WIDTH-1:0];
			end
		end
	end        

	if(rx_vld)
		assert(q.pop_front() == rx_data)
	else $fatal("wrong");
end

/*****************************************************************************
*                                 instance                                  *
*****************************************************************************/

uart_tx#(
    .DATA_WIDTH   ( DATA_WIDTH   ) ,
    .PARITY_CHECK ( PARITY_CHECK ) ,
    .CLK_FREQ     ( 100000000    ) ,
    .BAUD_RATE    ( BAUD_RATE    )
)transmitter(
    .clk    ( clk       ),
    .rst    ( rst       ),
    
    .i_vld  ( tx_vld    ),
    .i_data ( tx_data   ),
    
    .o_rdy  ( tx_rdy    ),
    .tx     ( tx        )
);

uart_rx#(
    .DATA_WIDTH   ( DATA_WIDTH   ) ,
    .PARITY_CHECK ( PARITY_CHECK ) ,
    .CLK_FREQ     ( 100000000    ) ,
    .BAUD_RATE    ( BAUD_RATE    )
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

