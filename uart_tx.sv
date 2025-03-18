module uart_tx#(
	parameter DATA_WIDTH   = 8        ,
	parameter PARITY_CHECK = "NONE"   ,
	parameter CLK_FREQ     = 50000000 ,
	parameter BAUD_RATE    = 9600
)(
     input                          clk    ,
     input                          rst    ,

     input                          i_vld  ,
     input    [DATA_WIDTH-1 : 0]    i_data ,

    output                          o_rdy  ,
    output    bit                   tx = 1
) ;
/*****************************************************************************
*                             check parameter                               *
*****************************************************************************/

initial begin
	assert(PARITY_CHECK == "NONE" || PARITY_CHECK == "ODD" || PARITY_CHECK == "EVEN") else
	$fatal(1,"Input error in parity check method");

	assert(CLK_FREQ/BAUD_RATE >= 2) else
	$fatal(1,"the CLK_FREQ must be 2 times larger than BAUD_RATE");

	assert(DATA_WIDTH >= 2)	else 
	$fatal(1,"The bit width of the data must be reasonable.");

	assert(DATA_WIDTH <= 8)	else
	$warning("The bit width of the data seems too long.");
end

/*****************************************************************************
*                                 variable                                  *
*****************************************************************************/
// data for output
reg    [DATA_WIDTH+1 : 0]    non_pc_data  = '1 ;
reg    [DATA_WIDTH+2 : 0]    odd_pc_data  = '1 ;
reg    [DATA_WIDTH+2 : 0]    even_pc_data = '1 ;

// counters
reg    [$clog2(CLK_FREQ/BAUD_RATE)-1 : 0]    signal_bit_cnter = CLK_FREQ/BAUD_RATE - 2 ;
reg    [$clog2(DATA_WIDTH+2)-1       : 0]    non_pc_data_cnter ;
reg    [$clog2(DATA_WIDTH+3)-1       : 0]    pc_data_cnter     ;

//fsm
reg    tx_fsm = '0 ; // fsm == 0 represent idle, fsm == 1 represent sending

reg    tx_pre = '1 ;
/*****************************************************************************
*                                  TX_FSM                                   *
*****************************************************************************/

assign o_rdy = ~tx_fsm;
always_ff @(posedge clk) begin
	if (rst)
		tx_fsm <= 0 ;
	else if (o_rdy&&i_vld) 
		tx_fsm <= 1 ;
	else if (tx_fsm == 1) 
		case(PARITY_CHECK)
			"NONE"  : tx_fsm <= !((non_pc_data_cnter == DATA_WIDTH+1) && (signal_bit_cnter == 0));
			default : tx_fsm <= !((pc_data_cnter     == DATA_WIDTH+2) && (signal_bit_cnter == 0));
		endcase
end

/*****************************************************************************
*                            buffer the i_data                              *
*****************************************************************************/

always_ff @(posedge clk) 
	if (rst) begin
		non_pc_data  <= '1 ;
		odd_pc_data  <= '1 ;
		even_pc_data <= '1 ;
	end else if (o_rdy&&i_vld) begin
		non_pc_data  <= { 1'b1             ,i_data ,1'b0 } ;
		odd_pc_data  <= { 1'b1 ,!(^i_data) ,i_data ,1'b0 } ;
		even_pc_data <= { 1'b1 ,^i_data    ,i_data ,1'b0 } ;
	end else if (signal_bit_cnter == 0) begin
		non_pc_data  <= { 1'b1 , non_pc_data[DATA_WIDTH+1  : 1] } ;
		odd_pc_data  <= { 1'b1 , odd_pc_data[DATA_WIDTH+2  : 1] } ;
		even_pc_data <= { 1'b1 , even_pc_data[DATA_WIDTH+2 : 1] } ;
	end 


/*****************************************************************************
*                          counter start and stop                           *
*****************************************************************************/
always_ff @(posedge clk) begin
	if (tx_fsm) 
		signal_bit_cnter <= signal_bit_cnter == 0 ? CLK_FREQ/BAUD_RATE - 1 : signal_bit_cnter - 1;
	else
		signal_bit_cnter <= CLK_FREQ/BAUD_RATE - 2;
	
	if (rst) begin
		non_pc_data_cnter <= 0;
		pc_data_cnter <= 0;
	end else if (tx_fsm) begin
		non_pc_data_cnter <= signal_bit_cnter == 0 ? non_pc_data_cnter + 1 : non_pc_data_cnter;
		pc_data_cnter <= signal_bit_cnter == 0 ? pc_data_cnter + 1 : pc_data_cnter;
	end else if (!tx_fsm) begin
		non_pc_data_cnter <= 0;
		pc_data_cnter <= 0;
	end
end 

/*****************************************************************************
*                           shift data and output                           *
*****************************************************************************/
always_ff @(posedge clk) begin
	if (rst)
		tx_pre <= '1 ;
	else
		case (PARITY_CHECK)
			"NONE" : tx_pre <= i_vld && o_rdy ? '0 : non_pc_data[0]  ;
			"ODD"  : tx_pre <= i_vld && o_rdy ? '0 : odd_pc_data[0]  ;
			"EVEN" : tx_pre <= i_vld && o_rdy ? '0 : even_pc_data[0] ;
		endcase
	tx <= rst ? '1 : tx_pre ;
end

endmodule
