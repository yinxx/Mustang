/*
###############################################################################
# Copyright (c) 2017, PulseRain Technology LLC 
#
# This program is distributed under a dual license: an open source license, 
# and a commercial license. 
# 
# The open source license under which this program is distributed is the 
# GNU Public License version 3 (GPLv3).
#
# And for those who want to use this program in ways that are incompatible
# with the GPLv3, PulseRain Technology LLC offers commercial license instead.
# Please contact PulseRain Technology LLC (www.pulserain.com) for more detail.
#
###############################################################################
 */


//=============================================================================
// Remarks:
//     Top Level Module for PulseRain M10 board
//=============================================================================


`include "debug_coprocessor.svh"
`include "common.svh"


`default_nettype none

module Mustang_fast (
        
    //=======================================================================
    // clock / reset
    //=======================================================================
        input wire                                  osc_in,         // expecting 12MHz oscillator in
        input wire                                  push_button,    // push button for reset
        
    //=======================================================================
    // external interrupt
    //=======================================================================
        
       // input wire  unsigned [1 : 0]                INTx,
    
    //=======================================================================
    // IO port
    //=======================================================================
        
            
        inout wire unsigned [7 : 0]                 P0,
        inout wire unsigned [7 : 0]                 P1,
     //   inout wire unsigned [7 : 0] P2,
     //   inout wire unsigned [7 : 0] P3,
        
    //=======================================================================
    // UART
    //=======================================================================
        input wire                                  UART_RXD,
        output logic                                UART_TXD,
        
        input wire                                  UART_AUX_RXD,
        output wire                                 UART_AUX_TXD,
        
        
    //=======================================================================
    // debug LED
    //=======================================================================
        output wire                                 debug_led,
        
    //=======================================================================
    // M23XX1024
    //=======================================================================
        input   wire                                mem_so,
        output  wire                                mem_si,
        output  wire                                mem_hold_n,
        output  wire                                mem_cs_n, 
        output  wire                                mem_sck,
          
    //=======================================================================
    // Si3000
    //=======================================================================
            
        inout   wire                                Si3000_SDO,
        output  wire                                Si3000_SDI,
        inout   wire                                Si3000_SCLK,
        output  wire                                Si3000_MCLK,
        input   wire                                Si3000_FSYNC_N,
        output  wire                                Si3000_RESET_N,
          
    //=======================================================================
    // SD Card
    //=======================================================================
        
        output wire                                 SD_SPI_CS,
        output wire                                 SD_SPI_CLK,
        input  wire                                 SD_SPI_DO,
        output wire                                 SD_SPI_DI,
        output wire                                 SD_DAT2,
        output wire                                 SD_DAT1,

    //=======================================================================
    // I2C
    //=======================================================================
        inout  wire                                 I2C_SDA,
        inout  wire                                 I2C_SCL,
        
    //=======================================================================
    // PWM
    //=======================================================================
        output logic unsigned [NUM_OF_PWM - 1 : 0]  PWM_OUT,
    //=======================================================================
    // GPIO on JTAG connector
    //=======================================================================
  
        output wire                                 JTAG_PIN6,
        output wire                                 JTAG_PIN7,
        output wire                                 JTAG_PIN8
  
);

	  

    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // Signals
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        wire                                                              clk, clk_24MHz, clk_2MHz;
        logic                                                             classic_12MHz_pulse;
        wire                                                              pll_locked;
    
        wire                                                              pram_read_enable_in;
        wire unsigned [DEBUG_DATA_WIDTH * DEBUG_FRAME_DATA_LEN - 1 : 0]   pram_read_data_in;
    
        wire                                                              pram_read_enable_out;
        wire unsigned [DEBUG_PRAM_ADDR_WIDTH - 1 : 0]                     pram_read_addr_out;
        wire                                                              pram_write_enable_out;
        wire unsigned [DEBUG_PRAM_ADDR_WIDTH - 3 : 0]                     pram_write_addr_out;
        wire unsigned [DEBUG_DATA_WIDTH * DEBUG_FRAME_DATA_LEN - 1 : 0]   pram_write_data_out;
        
        wire                                                              debug_stall_flag;
        wire unsigned [PC_BITWIDTH - 1 : 0]                               PC;
    
        wire                                                              cpu_reset;
        wire                                                              pause;
        wire                                                              break_on;
        wire unsigned [PC_BITWIDTH - 1 : 0]                               break_addr_A;
        wire unsigned [PC_BITWIDTH - 1 : 0]                               break_addr_B;
    
        wire                                                              run_pulse;
    
        wire                                                              debug_read_data_enable;
        wire unsigned [DEBUG_DATA_WIDTH - 1 : 0]                          debug_read_data;
    
        wire                                                              debug_data_read;
        wire unsigned [DEBUG_PRAM_ADDR_WIDTH - 1 : 0]                     debug_data_read_addr;
        wire                                                              debug_data_read_restore;
        wire unsigned [15 : 0]                                            debug_read_data_out;         
        wire                                                              debug_rd_indirect1_direct0;
        wire                                                              debug_counter_pulse;
            
        wire                                                              timer_pulse;    
              
        wire                                                              debug_data_write;
        wire  unsigned [DEBUG_PRAM_ADDR_WIDTH - 1 : 0]                    debug_data_write_addr;
        wire                                                              debug_wr_indirect1_direct0;
        wire  unsigned [DEBUG_DATA_WIDTH - 1 : 0]                         debug_data_write_data;
        
        wire                                                              debug_uart_tx_sel_ocd1_cpu0;
        wire                                                              uart_tx_cpu;
        wire                                                              uart_tx_ocd;
        
        wire                                                                loader_pram_we;
        wire  unsigned [$clog2(ON_CHIP_CODE_RAM_SIZE_IN_BYTES / 4) - 1 : 0] loader_pram_addr;
        wire  unsigned [31 : 0]                                             loader_pram_data;
        wire                                                                loader_done;
        
        wire                                                              reset_button;
        
        wire                                                              debug_led_i;
    
        logic                                                             cpu_pram_write_enable_out;
        logic unsigned [DEBUG_PRAM_ADDR_WIDTH - 3 : 0]                    cpu_pram_write_addr_out;
        logic unsigned [DEBUG_DATA_WIDTH * DEBUG_FRAME_DATA_LEN - 1 : 0]  cpu_pram_write_data_out;
        
        wire unsigned [7 : 0]                                             P2;
        wire unsigned [7 : 0]                                             P3;
      
        wire                                                              sda_in;
        wire                                                              scl_in;
        wire                                                              sda_out;
        wire                                                              scl_out;
        
        wire unsigned [NUM_OF_PWM - 1 : 0]                                pwm_out;
		  
		  wire  unsigned [1 : 0]                									  INTx;
        
    
	 //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // external interrupt
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
		  assign INTx[0] = P0[2];
		  assign INTx[1] = P0[3];
		  
	 
	 
	 //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // I2C
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        assign sda_in = I2C_SDA;
        assign scl_in = I2C_SCL;
        
        // assign I2C_SDA = sda_oe ? sda_out : 1'bZ;
        // assign I2C_SCL = scl_oe ? scl_out : 1'bZ;

        assign I2C_SDA = sda_out ? 1'bZ : 1'b0;
        assign I2C_SCL = scl_out ? 1'bZ : 1'b0;
        
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // PWM
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    
        always_ff @(posedge clk, negedge pll_locked) begin : pwm_out_proc
            if (!pll_locked) begin
                PWM_OUT <= 0;
            end else begin    
                PWM_OUT <= pwm_out;
            end
        end : pwm_out_proc
            
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // voice codec Si3000, mode 0
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        assign Si3000_SCLK = (Si3000_RESET_N) ? 1'bZ : 1'b0;
        assign Si3000_SDO = (Si3000_FSYNC_N) ? 1'b0 : 1'bZ;
        assign SD_DAT1 = 1'b1;
        assign SD_DAT2 = 1'b1;
     
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // PLL and clock control block
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
            
        PLL PLL_i (
            .areset (reset_button),
            .inclk0 (osc_in),
            .c0 (clk),
            .c1 (clk_24MHz),
            .c2 (clk_2MHz),
            .locked (pll_locked));
		            
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // button debouncer
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        switch_debouncer   #(.TIMER_VALUE(100000)) switch_debouncer_i (
            .clk (osc_in),
            .reset_n (1'b1),  
            .data_in (~push_button),
            .data_out (reset_button)
        );
    
     
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // UART
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
        always_ff @(posedge  clk, negedge pll_locked) begin
            if (!pll_locked) begin
                UART_TXD <= 0;
            end else if (!debug_uart_tx_sel_ocd1_cpu0) begin
                UART_TXD <= uart_tx_cpu;
            end else begin
                UART_TXD <= uart_tx_ocd;
            end
        
        end 
    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // code loader at power on
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
        code_mem_power_on_loader code_mem_power_on_loader_i (
              .clk (clk),
                .reset_n (pll_locked),
                .pram_we(loader_pram_we),
                .pram_addr (loader_pram_addr),
                .pram_data (loader_pram_data),
                .done (loader_done)
        );
    
    
    
        always_ff @(posedge clk, negedge pll_locked) begin : cpu_pram_write_proc
            if (!pll_locked) begin
                cpu_pram_write_enable_out <= 0;
                cpu_pram_write_addr_out   <= 0;
                cpu_pram_write_data_out   <= 0;
            end else if (loader_done) begin
                cpu_pram_write_enable_out <= pram_write_enable_out;
                cpu_pram_write_addr_out   <= pram_write_addr_out;
                cpu_pram_write_data_out   <= pram_write_data_out;
            end else begin
                cpu_pram_write_enable_out <= loader_pram_we;
                cpu_pram_write_addr_out   <= {(DEBUG_PRAM_ADDR_WIDTH - 2 - $clog2(ON_CHIP_CODE_RAM_SIZE_IN_BYTES / 4))'(0), loader_pram_addr};
                cpu_pram_write_data_out   <= loader_pram_data;
            end
        
        end : cpu_pram_write_proc

    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    //  onchip debugger
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
        debug_coprocessor_wrapper #(.BAUD_PERIOD (MIN_UART_BAID_PERIOD)) 
            debug_coprocessor_wrapper_i (
                .clk (clk),
                .reset_n (pll_locked),
                
                .RXD (UART_RXD),
                .TXD (uart_tx_ocd),
                
                .debug_counter_pulse  (1'b0),
                .timer_pulse (1'b0),
            
                .debug_stall_flag (debug_stall_flag),
                .PC (PC),
                
                .pram_read_enable_in (pram_read_enable_in),
                .pram_read_data_in (pram_read_data_in),
        
                .pram_read_enable_out (pram_read_enable_out),
                .pram_write_enable_out (pram_write_enable_out),
                .pram_write_addr_out (pram_write_addr_out),
                .pram_read_addr_out (pram_read_addr_out),
                    
                .pram_write_data_out (pram_write_data_out),
                
                .cpu_reset (cpu_reset),
                .pause (pause),
                .break_on (break_on),
                .break_addr_A (break_addr_A),
                .break_addr_B (break_addr_B),
                .run_pulse (run_pulse),
                
                .debug_read_data_enable_in (debug_read_data_enable),
                .debug_read_data_in (debug_read_data),
                
                .debug_data_read (debug_data_read),
                .debug_data_read_addr (debug_data_read_addr),
                .debug_rd_indirect1_direct0 (debug_rd_indirect1_direct0),
                .debug_data_read_restore (debug_data_read_restore),
                
                .debug_data_write (debug_data_write),
                .debug_data_write_addr (debug_data_write_addr),
                .debug_wr_indirect1_direct0 (debug_wr_indirect1_direct0),
                .debug_data_write_data (debug_data_write_data),
                .debug_uart_tx_sel_ocd1_cpu0 (debug_uart_tx_sel_ocd1_cpu0)
                
            );
            
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    //  FP51 MCU
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
            
         PulseRain_FP51_MCU #(.FOR_SIM (0), .FAST0_SMALL1 (0)) fast_8051 (
                .clk (clk),
                .reset_n (pll_locked & (~cpu_reset) & loader_done),
                
                .INTx (INTx),
                .inst_mem_we (cpu_pram_write_enable_out),
                .inst_mem_wr_addr (cpu_pram_write_addr_out),
                .inst_mem_data_in (cpu_pram_write_data_out),
                
                .inst_mem_re (pram_read_enable_out),
                .inst_mem_re_addr (pram_read_addr_out),
                
                .inst_mem_re_enable_out (pram_read_enable_in),
                .inst_mem_data_out (pram_read_data_in),
                            
                .UART_RXD (UART_RXD),
                .UART_TXD (uart_tx_cpu),
                
                .UART_AUX_RXD (UART_AUX_RXD),
                .UART_AUX_TXD (UART_AUX_TXD),
                
                .P0 (P0),
                .P1 (P1),
                .P2 (P2),
                .P3 (P3),
                 
                 
                .pause (pause),
                .break_on (break_on),
                .break_addr_A (break_addr_A),
                .break_addr_B (break_addr_B),
                .run_pulse (run_pulse),
        
                .debug_stall (debug_stall_flag),
                .debug_PC (PC),
            
                .debug_data_read (debug_data_read),
                .debug_data_read_addr (debug_data_read_addr),
                .debug_rd_indirect1_direct0 (debug_rd_indirect1_direct0),
                .debug_data_read_restore (debug_data_read_restore),
            
            
                .debug_data_write (debug_data_write),
                .debug_data_write_addr (debug_data_write_addr),
                .debug_wr_indirect1_direct0 (debug_wr_indirect1_direct0),
                .debug_data_write_data (debug_data_write_data),    
            
            
                .debug_read_data_enable_out (debug_read_data_enable),
                .debug_read_data_out (debug_read_data),
                .timer_pulse_out (timer_pulse),
                 
                .debug_led (debug_led_i),
                .debug_counter_pulse (debug_counter_pulse),
                 
                .mem_so     (mem_so),
                .mem_si     (mem_si),
                .mem_hold_n (mem_hold_n),
                .mem_cs_n   (mem_cs_n),
                .mem_sck    (mem_sck),
                     
                .Si3000_SDO (Si3000_SDO),
                .Si3000_SDI (Si3000_SDI),
                .Si3000_SCLK (Si3000_SCLK),
                .Si3000_MCLK (Si3000_MCLK),
                .Si3000_FSYNC_N (Si3000_FSYNC_N),
                .Si3000_RESET_N (Si3000_RESET_N),
                     
                .sd_cs_n     (SD_SPI_CS),
                .sd_spi_clk  (SD_SPI_CLK),
                .sd_data_out (SD_SPI_DO),
                .sd_data_in  (SD_SPI_DI),  
                 
                .adc_pll_clock_clk (clk_2MHz),
                .adc_pll_locked_export (pll_locked),
 
                .sda_in (sda_in),
                .scl_in (scl_in),
                .sda_out (sda_out),
                .scl_out (scl_out),
                .pwm_out (pwm_out)

        );    
     
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    //  debug led
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        assign debug_led = (debug_led_i) | (~push_button);
    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    //  dual config
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
    
        dual_config dual_config_i (
            .avmm_rcv_address (3'd0),   // avalon.address
            .avmm_rcv_read (1'b0),      //       .read
            .avmm_rcv_writedata (32'd0), //       .writedata
            .avmm_rcv_write (1'b0),     //       .write
            .avmm_rcv_readdata(),  //       .readdata
            .clk (clk_24MHz),                //    clk.clk
            .nreset (1'b1)              // nreset.reset_n
        );
    

	 
	 //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    //  JTAG IO
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
         assign JTAG_PIN6 = 1'b1;		
         assign JTAG_PIN7 = 0;
         assign JTAG_PIN8 = timer_pulse;
  
 
endmodule : Mustang_fast


`default_nettype wire
