//------------------------------------------------------------------------------
// Interface: apb4_2_master_intf
// Description: APB4 Protocol Interface with modports for Master and Slave
//------------------------------------------------------------------------------

interface Bus2Master_intf #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input logic pclk,
    input logic presetn
);

    //--------------------------------------------------------------------------
    // APB4 Signals
    //--------------------------------------------------------------------------
    logic                      psel;      // Peripheral select
    logic                      penable;   // Enable
    logic                      pwrite;    // Write/Read direction
    logic [ADDR_WIDTH-1:0]     paddr;     // Address
    logic [DATA_WIDTH-1:0]     pwdata;    // Write data
    logic [DATA_WIDTH-1:0]     prdata;    // Read data
    logic                      pready;    // Ready signal from slave
    logic                      pslverr;   // Slave error

    //--------------------------------------------------------------------------
    // Clocking Blocks for Synchronous Driving
    //--------------------------------------------------------------------------
    clocking master_cb @(posedge pclk);
        default input #1 output #1;
        output psel, penable, pwrite, paddr, pwdata;
        input  prdata, pready, pslverr;
    endclocking

    clocking slave_cb @(posedge pclk);
        default input #1 output #1;
        input  psel, penable, pwrite, paddr, pwdata;
        output prdata, pready, pslverr;
    endclocking

    //--------------------------------------------------------------------------
    // Modport for Master (Initiator)
    //--------------------------------------------------------------------------
    modport master (
        clocking master_cb,           // Synchronous driving
        output psel, penable, pwrite, paddr, pwdata,  // Async outputs (optional)
        input  prdata, pready, pslverr,               // Async inputs (optional)
        input  pclk, presetn                          // Clock and reset
    );

    //--------------------------------------------------------------------------
    // Modport for Slave (Target)
    //--------------------------------------------------------------------------
    modport slave (
        clocking slave_cb,            // Synchronous driving
        input  psel, penable, pwrite, paddr, pwdata,  // Async inputs
        output prdata, pready, pslverr,               // Async outputs
        input  pclk, presetn                          // Clock and reset
    );

    //--------------------------------------------------------------------------
    // Modport for Passive Monitoring
    //--------------------------------------------------------------------------
    // modport monitor (
    //     input psel, penable, pwrite, paddr, pwdata, prdata, pready, pslverr,
    //     input pclk, presetn
    // );

    //--------------------------------------------------------------------------
    // Assertions for APB4 Protocol Checking
    //--------------------------------------------------------------------------
    // property apb4_setup_phase;
    //     @(posedge pclk) disable iff (!presetn)
    //     (psel && !penable) |=> (psel && penable);
    // endproperty
/*
    property apb4_valid_transaction;
        @(posedge pclk) disable iff (!presetn)
        (psel && penable) |-> (pready === 1'b1 within [1:16]);
    endproperty

    // Assertions
    apb4_setup_phase_check: assert property (apb4_setup_phase)
        else $error("APB4 Setup phase violation: PSEL asserted without PENABLE");

    apb4_valid_transaction_check: assert property (apb4_valid_transaction)
        else $error("APB4 Transaction timeout: PREADY not asserted within 16 cycles");

    //--------------------------------------------------------------------------
    // Coverage Groups
    //--------------------------------------------------------------------------
    covergroup apb4_transaction_cg @(posedge pclk);
        option.per_instance = 1;
        
        cp_psel: coverpoint psel;
        cp_penable: coverpoint penable;
        cp_pwrite: coverpoint pwrite;
        cp_paddr: coverpoint paddr {
            bins low_addr = {[0:16'h0FFF]};
            bins mid_addr = {[16'h1000:16'hFFEF]};
            bins high_addr = {[16'hFFF0:16'hFFFF]};
        }
        cp_pwdata: coverpoint pwdata {
            bins zeros = {0};
            bins ones = {{DATA_WIDTH{1'b1}}};
            bins alternating = {32'hAAAAAAAA, 32'h55555555};
            wildcard bins other = default;
        }
        cp_pready: coverpoint pready;
        cp_pslverr: coverpoint pslverr;
        
        cross_transaction: cross cp_psel, cp_penable, cp_pwrite, cp_pready, cp_pslverr;
        
    endgroup

    apb4_transaction_cg apb4_cg;

    //--------------------------------------------------------------------------
    // Initialization
    //--------------------------------------------------------------------------
    initial begin
        apb4_cg = new();
    end
*/
    // //--------------------------------------------------------------------------
    // // Reset Behavior
    // //--------------------------------------------------------------------------
    // always @(negedge presetn) begin
    //     if (!presetn) begin
    //         // Reset values
    //         psel    <= 1'b0;
    //         penable <= 1'b0;
    //         pwrite  <= 1'b0;
    //         paddr   <= '0;
    //         pwdata  <= '0;
    //         prdata  <= '0;
    //         pready  <= 1'b0;
    //         pslverr <= 1'b0;
    //     end
    // end

    //--------------------------------------------------------------------------
    // Utility Functions
    //--------------------------------------------------------------------------
    // function string get_state();
    //     if (!psel && !penable) return "IDLE";
    //     if (psel && !penable) return "SETUP";
    //     if (psel && penable) return "ACCESS";
    //     return "UNKNOWN";
    // endfunction

    // function void display_transaction();
    //     $display("[%0t] APB4 State: %s, PWRITE: %b, PADDR: 0x%h, PWDATA: 0x%h, PRDATA: 0x%h, PREADY: %b, PSLVERR: %b",
    //              $time, get_state(), pwrite, paddr, pwdata, prdata, pready, pslverr);
    // endfunction

endinterface

//------------------------------------------------------------------------------
// End of apb4_intf
//------------------------------------------------------------------------------