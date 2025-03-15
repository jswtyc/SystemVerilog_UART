module uart_rx_slow#(
	parameter DATA_WIDTH   = 8        ,
	parameter PARITY_CHECK = "NONE"   ,
	parameter CLK_FREQ     = 50000000 ,
	parameter BAUD_RATE    = 9600
)(
     input                                 clk     ,
     input                                 rst     ,

     input                                 rx      ,
     input                                 i_rdy   ,

    output    reg                          o_vld   ,
    output    reg                          pc_pass , // pc_pass == 1 represent parity check pass.This signal is valid simultaneously with o_vld.
    output    reg    [DATA_WIDTH-1 : 0]    o_data
) ;

/*****************************************************************************
*                             check parameter                               *
*****************************************************************************/

initial begin
	assert(PARITY_CHECK == "NONE" || PARITY_CHECK == "ODD" || PARITY_CHECK == "EVEN") else
	$fatal(1,"Input error in parity check method");

	assert(CLK_FREQ/BAUD_RATE >= 16) else
	$fatal(1,"the CLK_FREQ must be 16 times larger than BAUD_RATE");

	assert(DATA_WIDTH >= 2)	else 
	$fatal(1,"The bit width of the data must be reasonable.");

	assert(DATA_WIDTH <= 8)	else
	$warning("The bit width of the data seems too long.");
end

(* ASYNC_REG="TRUE" *) reg [2-1:0] sreg = '1;
always_ff @ (posedge clk) sreg <= {sreg[0], rx};

/*****************************************************************************
*                                 variable                                  *
*****************************************************************************/
// for sampling
reg     [3 : 0]    rx_buffer = '1     ;
wire               sample             ;
reg                pc_sample_time     ; // pc_sample_time == 1 represent all data bits and pc bit are sampled
reg                non_pc_sample_time ; // non_pc_sample_time == 1 represent all data bits are sampled

// counter
reg    [$clog2(CLK_FREQ/BAUD_RATE)-1 : 0]    signal_bit_cnter = CLK_FREQ/BAUD_RATE - 1 ;
reg    [$clog2(DATA_WIDTH+2)-1       : 0]    non_pc_data_cnter ;
reg    [$clog2(DATA_WIDTH+3)-1       : 0]    pc_data_cnter     ;

// fsm
reg                        rx_fsm  ; // fsm == 0 represent idle, fsm == 1 represent receiving

// for output 
reg    [DATA_WIDTH : 0]    rx_data ;

/*****************************************************************************
*                   Control sampling and decision-making                    *
*****************************************************************************/

always_ff @(posedge clk) 
	rx_buffer <= rst ? '1 : {rx_buffer[2:0], sreg[1]} ;

assign sample = (rx_buffer[0] + rx_buffer[1] + rx_buffer[2] + rx_buffer[3]) > 2;

always_ff @(posedge clk) begin
	if (rst) begin
		pc_sample_time <= '0;
		non_pc_sample_time <= '0;
	end else begin
		// Enter the time to receive the stop code, select the appropriate time 
		// to output or calculate the checksum and output.
		pc_sample_time <= (pc_data_cnter == DATA_WIDTH+2 && signal_bit_cnter == (CLK_FREQ/BAUD_RATE-1)>>1); 
		non_pc_sample_time <= (non_pc_data_cnter == DATA_WIDTH+1 && signal_bit_cnter  == (CLK_FREQ/BAUD_RATE-1)>>1);
	end
end


/*****************************************************************************
*                             FSM and counters                              *
*****************************************************************************/

always_ff @(posedge clk) begin
	if (rst) 
		rx_fsm <= 0 ;
	else if ( rx_fsm == 0 ) 
		rx_fsm <= signal_bit_cnter == (CLK_FREQ/BAUD_RATE-1)>>1;
	else if ( rx_fsm == 1 )
		case (PARITY_CHECK)
			"NONE"  : rx_fsm <= !non_pc_sample_time ;
			default : rx_fsm <= !pc_sample_time ;
		endcase
end 

always_ff @(posedge clk) begin
	if (rst)
		signal_bit_cnter <= CLK_FREQ/BAUD_RATE - 1 ;
	else if (!rx_fsm) 
		signal_bit_cnter <= rx_buffer[0] ? CLK_FREQ/BAUD_RATE - 1 : signal_bit_cnter - 1;
	else if (rx_fsm) 
		signal_bit_cnter <= signal_bit_cnter == 0 ? CLK_FREQ/BAUD_RATE - 1 : signal_bit_cnter - 1 ;
	
	if (rst) begin
		non_pc_data_cnter <= '0;
		pc_data_cnter <= '0;
	end else if (rx_fsm) begin
		non_pc_data_cnter <= signal_bit_cnter == 0 ? non_pc_data_cnter + 1 : non_pc_data_cnter;
		pc_data_cnter <= signal_bit_cnter == 0 ? pc_data_cnter + 1 : pc_data_cnter;
	end else if (!rx_fsm) begin
		non_pc_data_cnter <= '0;
		pc_data_cnter <= '0;
	end
end

/*****************************************************************************
*                        buffer the data and output                         *
*****************************************************************************/

always_ff @(posedge clk)
	case (PARITY_CHECK)
		"NONE": 
			if (rx_fsm && (|non_pc_data_cnter) && non_pc_data_cnter != DATA_WIDTH+1)
				rx_data <= signal_bit_cnter == (CLK_FREQ/BAUD_RATE-1)>>1 ? {sample,rx_data[DATA_WIDTH-1:1]} : rx_data;
		default:
			if (rx_fsm && (|pc_data_cnter) && pc_data_cnter != DATA_WIDTH+2)
				rx_data <= signal_bit_cnter == (CLK_FREQ/BAUD_RATE-1)>>1 ? {sample,rx_data[DATA_WIDTH:1]} : rx_data;
	endcase

always_ff @(posedge clk) begin
	case (PARITY_CHECK)
		"NONE": begin 
			o_data <= non_pc_sample_time ? rx_data[DATA_WIDTH-1 : 0] : o_data ;
			pc_pass <= 1;
			if (rst)
				o_vld <= 0;
			else if (non_pc_sample_time) 
				o_vld <= 1;
			else if (i_rdy&&o_vld)
				o_vld <= 0;
		end
		"EVEN": begin
			o_data <= pc_sample_time ? rx_data[DATA_WIDTH-1 : 0] : o_data ;
			pc_pass <= pc_sample_time ? ~(^rx_data) : pc_pass;
			if (rst) 
				o_vld <= 0;
			else if (pc_sample_time) 
				o_vld <= 1;
			else if (i_rdy&&o_vld) 
				o_vld <= 0;
		end
		"ODD": begin
			o_data <= pc_sample_time ? rx_data[DATA_WIDTH-1 : 0] : o_data ;
			pc_pass <= pc_sample_time ? (^rx_data) : pc_pass;
			if (rst) 
				o_vld <= 0;
			else if (pc_sample_time) 
				o_vld <= 1;
			else if (i_rdy&&o_vld) 
				o_vld <= 0;
		end
	endcase

end

endmodule
