`timescale 1ns / 1ps

module top_controller #(N_DATA_BITS = 8)(
    input   i_clk_100M,
            reset,
            mode,
            i_uart_rx,
            i_data_valid,
    
    output  o_uart_tx,
            uart_tx_ready,
            [7:0] cathodes,
            [3:0] anodes
            
);

    localparam  OVERSAMPLE = 13;
                
    localparam integer UART_CLOCK_DIVIDER = 64;
    localparam integer MAJORITY_START_IDX = 4;
    localparam integer MAJORITY_END_IDX = 8;
    localparam integer UART_CLOCK_DIVIDER_WIDTH = $clog2(UART_CLOCK_DIVIDER);
    
    //wire reset;
    reg [7:0] sum = 'd0;
    wire [7:0] result;
    wire write_enable;
    
    reg uart_clk_rx;
    reg uart_en_rx;
    reg [UART_CLOCK_DIVIDER_WIDTH:0] uart_divider_counter_rx;
    
    reg uart_clk_tx;
    reg uart_en_tx;
    reg [UART_CLOCK_DIVIDER_WIDTH:0] uart_divider_counter_tx;
    
    wire [N_DATA_BITS-1:0] uart_rx_data;
    wire [N_DATA_BITS-1:0] uart_tx_data;
    wire uart_rx_data_valid;
    
    reg [N_DATA_BITS-1:0] uart_rx_data_buf;
    reg uart_rx_data_valid_buf;
    
    // Variables for BRAM
    reg [4:0] addr = 'd0;
    reg [7:0] data [0:15];
    
    // Variables for the seven segment display
    reg uart_clk;
    reg display_clk;
    reg display_data_update;
    reg [N_DATA_BITS-1:0] display_data;
    reg [N_DATA_BITS-1:0] display_data_rx;
    reg [N_DATA_BITS-1:0] display_data_tx;
    
   /* vio_0 reset_source (
      .clk(i_clk_100M),
      .probe_out0(reset)  // output wire [0 : 0] probe_out0
    );*/
    
    /*ila_0 input_monitor (
        .clk(uart_clk), // input wire clk
    
    
        .probe0(uart_rx_data_valid), // input wire [0:0]  probe0  
        .probe1(uart_rx_data), // input wire [7:0]  probe1 
        .probe2(i_uart_rx) // input wire [7:0]  probe2
    );*/
    
    ila_0 input_monitor (
	.clk(uart_clk_rx), // input wire clk


	.probe0(uart_rx_data_valid), // input wire [0:0]  probe0  
	.probe1(uart_rx_data), // input wire [7:0]  probe1 
	.probe2(i_uart_rx), // input wire [0:0]  probe2 
	.probe3(i_data_valid), // input wire [0:0]  probe3 
	.probe4(display_data), // input wire [7:0]  probe4 
	.probe5(uart_tx_ready), // input wire [0:0]  probe5 
	.probe6(o_uart_tx), // input wire [0:0]  probe6 
	.probe7(uart_en_tx) // input wire [0:0]  probe7
);

    clk_wiz_0 clock_gen (
        // Clock out ports
        .clk_out1(uart_clk_rx),     // output clk_out1    = 95.849M = Baud rate * OVERSAMPLE * CLOCK_DIVIDER
        .clk_out2(uart_clk_tx),     // output clk_out2 = 43.6M
       // Clock in ports
        .clk_in1(i_clk_100M)
    );
    
    uart_rx #(
        .OVERSAMPLE(OVERSAMPLE),
        .N_DATA_BITS(N_DATA_BITS),
        .MAJORITY_START_IDX(MAJORITY_START_IDX),
        .MAJORITY_END_IDX(MAJORITY_END_IDX)
    ) rx_data (
        .i_clk(uart_clk_rx),
        .i_en(uart_en_rx),
        .i_reset(reset),
        .i_data(i_uart_rx),
        
        .o_data(uart_rx_data),
        .o_data_valid(uart_rx_data_valid)
    );
    
    /*always @(posedge uart_clk_rx) begin
        if(uart_rx_data_valid) begin
           if(addr < 'd16) begin
            sum <= sum + uart_rx_data;
            addr <= addr + 5'd1;
           end
        end
    end*/
    
    //assign result = sum;
    
    uart_tx #(
        .N_DATA_BITS(N_DATA_BITS)
    ) uart_transmistter (
        .i_uart_clk(uart_clk_tx),
        .i_uart_en(uart_en_tx),
        .i_uart_reset(reset),
        .i_uart_data_valid(i_data_valid),
        .i_uart_data(sum),
        .o_uart_ready(uart_tx_ready),
        .o_uart_tx(o_uart_tx));
    
   /*blk_mem_gen_0 memory (
      .clka(uart_clk_rx),    // input wire clka
      .ena(1),      // input wire ena
      .wea(write_enable),      // input wire [0 : 0] wea
      .addra(addr[3:0]),  // input wire [3 : 0] addra
      .dina(uart_rx_data),    // input wire [7 : 0] dina
      .douta(data)  // output wire [7 : 0] douta
  );*/

    
    seven_seg_drive #(
        .INPUT_WIDTH(N_DATA_BITS),
        .SEV_SEG_PRESCALAR(16)
    ) display (
        .i_clk(uart_clk_rx),
        .number(sum),
        .decimal_points(4'h0),
        .anodes(anodes),
        .cathodes(cathodes)
    );
    
    always @(posedge i_clk_100M) begin
        if(mode == 1'b0) begin
            uart_clk <= uart_clk_rx;
            //display_data <= display_data_rx;
        end
        else begin
           uart_clk <= uart_clk_tx;
           //display_data <= display_data_tx;
        end
    end
    
    always @(posedge uart_clk_rx) begin
        if(uart_divider_counter_rx < (UART_CLOCK_DIVIDER-1))
            uart_divider_counter_rx <= uart_divider_counter_rx + 1;
       else
            uart_divider_counter_rx <= 'd0;
    end
    
    always @(posedge uart_clk_rx)
        uart_en_rx <= (uart_divider_counter_rx == 'd10);
        

//assign write_enable = (addr == 5'd16) ? 0 : uart_rx_data_valid;    

   reg [7:0] buff [0:15];
    integer k = 0;
    reg flag = 0;
    always @(posedge uart_clk_rx) begin
        if(uart_rx_data_valid) begin
           buff[k] <= uart_rx_data;
           display_data <= buff[k];
           k=k+1;
        end
        //else flag = 0;
    end
    
    always @(negedge uart_rx_data_valid)
        sum <= sum + buff[k];
   
  /* always @(posedge uart_clk_rx) begin
    if(flag)
        sum = sum + display_data_rx;
    end*/
    
   always @(posedge uart_clk_tx) begin
        if(uart_divider_counter_tx < (UART_CLOCK_DIVIDER-1))
            uart_divider_counter_tx <= uart_divider_counter_tx + 1;
       else
            uart_divider_counter_tx <= 'd0;
    end
    
    always @(posedge uart_clk_tx) begin
        uart_en_tx <= (uart_divider_counter_tx == 'd10); 
    end
    
endmodule
