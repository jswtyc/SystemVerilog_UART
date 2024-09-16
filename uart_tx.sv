module uart_tx#(
	parameter PARITY_CHECK = "NONE"   ,
	parameter CLK_FREQ     = 50000000 ,
	parameter TX_FREQ      = 9600
)(
     input               clk    ,
     input               rst    ,

     input               i_vld  ,
     input    [7 : 0]    i_data ,

    output               o_rdy  ,
    output    reg        tx
);
/*****************************************************************************
*                             check parameter                               *
*****************************************************************************/

initial begin
	assert(PARITY_CHECK == "NONE" || PARITY_CHECK == "ODD" || PARITY_CHECK == "EVEN") else
	$fatal("Input error in parity check method");
end

/*****************************************************************************
*                                 variable                                  *
*****************************************************************************/
// data for output
reg    [9  : 0]    non_pc_data  = '1 ;
reg    [10 : 0]    odd_pc_data  = '1 ;
reg    [10 : 0]    even_pc_data = '1 ;
// counters
reg    [$clog2(CLK_FREQ/TX_FREQ)-1 : 0]    signal_bit_cnter = CLK_FREQ/TX_FREQ-1;
reg    [3  : 0]    non_pc_bits_cnter ;
reg    [3  : 0]    pc_bits_cnter     ;
//fsm
reg                tx_fsm            ; // fsm == 0 represent idle, fsm == 1 represent sending

assign o_rdy = ~tx_fsm;
always_ff @(posedge clk) begin
	if (rst)
		tx_fsm <= 0;
	else if (o_rdy&&i_vld) 
		tx_fsm <= 1;
	else if (tx_fsm == 1) 
		case(PARITY_CHECK)
			"NONE"  : tx_fsm <= non_pc_bits_cnter != 10 ;
			default : tx_fsm <= pc_bits_cnter     != 11 ;
		endcase
end

/*****************************************************************************
*                            buffer the i_data                              *
*****************************************************************************/

always_ff @(posedge clk) 
	if (rst) begin
		non_pc_data  <= '1;
		odd_pc_data  <= '1;
		even_pc_data <= '1;
	end else if (o_rdy&&i_vld) begin
		non_pc_data  <= {1'b1             ,i_data ,1'b0};
		odd_pc_data  <= {1'b1 ,!(^i_data) ,i_data ,1'b0};
		even_pc_data <= {1'b1 ,^i_data    ,i_data ,1'b0};
	end else if (signal_bit_cnter == 0) begin
		non_pc_data  <= {1'b1 , non_pc_data[9   : 1] };
		odd_pc_data  <= {1'b1 , odd_pc_data[10  : 1] };
		even_pc_data <= {1'b1 , even_pc_data[10 : 1] };
	end 


/*****************************************************************************
*                          counter start and stop                           *
*****************************************************************************/
always_ff @(posedge clk) begin
	if (rst)
		signal_bit_cnter <= CLK_FREQ/TX_FREQ - 1;
	else if (tx_fsm) 
		signal_bit_cnter <= signal_bit_cnter == 0 ? CLK_FREQ/TX_FREQ-1 : signal_bit_cnter - 1;
	
	if (rst) begin
		non_pc_bits_cnter <= 0;
		pc_bits_cnter <= 0;
	end	else if (tx_fsm) begin
		non_pc_bits_cnter <= signal_bit_cnter == 0 ? non_pc_bits_cnter + 1 : non_pc_bits_cnter;
		pc_bits_cnter <= signal_bit_cnter == 0 ? pc_bits_cnter + 1 : pc_bits_cnter;
	end	else if (!tx_fsm) begin
		non_pc_bits_cnter <= 0;
		pc_bits_cnter <= 0;
	end
end 

/*****************************************************************************
*                           shift data and output                           *
*****************************************************************************/
always_ff @(posedge clk) begin
	case (PARITY_CHECK)
		"NONE" : tx <= non_pc_data[0]  ;
		"ODD"  : tx <= odd_pc_data[0]  ;
		"EVEN" : tx <= even_pc_data[0] ;
	endcase
end

endmodule
