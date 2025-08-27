interface Bus2Master_intf #(
    parameter logic ADDR_WIDTH = 32,
    parameter logic DATA_WIDTH = 32
) (
    input logic ACLK,
    input logic ARESETN
);  
    // Read Address Channel - AR
    logic [ADDR_WIDTH-1:0]  ARADDR;
    logic [2:0]             ARPROT;
    logic                   ARVALID;
    logic                   ARREADY;

    // Read Data Channel - R
    logic [DATA_WIDTH-1:0]  RDATA;
    logic [1:0]             RRESP;
    logic                   RVALID;
    logic                   RREADY;

    // Write Address Channel - AW
    logic [ADDR_WIDTH-1:0]  AWADDR;
    logic [2:0]             AWPROT;
    logic                   AWVALID;
    logic                   AWREADY;

    // Write Data Channel - W
    logic [DATA_WIDTH-1:0]  WDATA;
    logic [(DATA_WIDTH/8)-1:0] WSTRB;
    logic                   WVALID;
    logic                   WREADY;

    // Write Response Channel - B
    logic [1:0]             BRESP;
    logic                   BVALID;
    logic                   BREADY;

    clocking master_cb @(posedge ACLK);
        default input #1 output #1;
        output ARADDR, ARPROT, ARVALID, RREADY;
        output AWADDR, AWPROT, AWVALID;
        output WDATA, WSTRB, WVALID, BREADY;
        input  ARREADY, RDATA, RRESP, RVALID;
        input  AWREADY, WREADY, BRESP, BVALID;
    endclocking

    clocking slave_cb @(posedge ACLK);
        default input #1 output #1;
        input  ARADDR, ARPROT, ARVALID, RREADY;
        input  AWADDR, AWPROT, AWVALID;
        input  WDATA, WSTRB, WVALID, BREADY;
        output ARREADY, RDATA, RRESP, RVALID;
        output AWREADY, WREADY, BRESP, BVALID;
    endclocking

    // Modport for Master
    modport master (
        clocking master_cb,
        output ARADDR, ARPROT, ARVALID, RREADY,
        output AWADDR, AWPROT, AWVALID,
        output WDATA, WSTRB, WVALID, BREADY,
        input  ARREADY, RDATA, RRESP, RVALID,
        input  AWREADY, WREADY, BRESP, BVALID,
        input  ACLK, ARESETN
    );

    // Modport for Slave
    modport slave_ports (
        clocking slave_cb,
        input  ARADDR, ARPROT, ARVALID, RREADY,
        input  AWADDR, AWPROT, AWVALID,
        input  WDATA, WSTRB, WVALID, BREADY,
        output ARREADY, RDATA, RRESP, RVALID,
        output AWREADY, WREADY, BRESP, BVALID,
        input  ACLK, ARESETN
    );

    // Modport for Passive Monitoring
    modport monitor (
        input ARADDR, ARPROT, ARVALID, ARREADY, RDATA, RRESP, RVALID, RREADY,
        input AWADDR, AWPROT, AWVALID, AWREADY,
        input WDATA, WSTRB, WVALID, WREADY,
        input BRESP, BVALID, BREADY,
        input ACLK, ARESETN
    );

    /* Assertions for AXI4-Lite Protocol Checking
    property axi4_lite_ar_handshake;
        @(posedge ACLK) disable iff (!ARESETN)
        (ARVALID && !ARREADY) |=> ARVALID;
    endproperty

    property axi4_lite_r_handshake;
        @(posedge ACLK) disable iff (!ARESETN)
        (RVALID && !RREADY) |=> RVALID;
    endproperty

    property axi4_lite_aw_handshake;
        @(posedge ACLK) disable iff (!ARESETN)
        (AWVALID && !AWREADY) |=> AWVALID;
    endproperty

    property axi4_lite_w_handshake;
        @(posedge ACLK) disable iff (!ARESETN)
        (WVALID && !WREADY) |=> WVALID;
    endproperty

    property axi4_lite_b_handshake;
        @(posedge ACLK) disable iff (!ARESETN)
        (BVALID && !BREADY) |=> BVALID;
    endproperty
    */
    // Assertions (commented out for now - uncomment if needed)
    /*
    axi4_lite_ar_handshake_check: assert property (axi4_lite_ar_handshake)
        else $error("AXI4-Lite AR channel handshake violation");

    axi4_lite_r_handshake_check: assert property (axi4_lite_r_handshake)
        else $error("AXI4-Lite R channel handshake violation");

    axi4_lite_aw_handshake_check: assert property (axi4_lite_aw_handshake)
        else $error("AXI4-Lite AW channel handshake violation");

    axi4_lite_w_handshake_check: assert property (axi4_lite_w_handshake)
        else $error("AXI4-Lite W channel handshake violation");

    axi4_lite_b_handshake_check: assert property (axi4_lite_b_handshake)
        else $error("AXI4-Lite B channel handshake violation");
    */

    //--------------------------------------------------------------------------
    // Coverage Groups (commented out - uncomment if needed)
    //--------------------------------------------------------------------------
    /*
    covergroup axi4_lite_transaction_cg @(posedge ACLK);
        option.per_instance = 1;
        
        cp_arvalid: coverpoint ARVALID;
        cp_awvalid: coverpoint AWVALID;
        cp_wvalid: coverpoint WVALID;
        cp_rready: coverpoint RREADY;
        cp_bready: coverpoint BREADY;
        cp_araddr: coverpoint ARADDR {
            bins low_addr = {[0:32'h0000_0FFF]};
            bins mid_addr = {[32'h0000_1000:32'hFFFF_FFEF]};
            bins high_addr = {[32'hFFFF_FFF0:32'hFFFF_FFFF]};
        }
        cp_awaddr: coverpoint AWADDR {
            bins low_addr = {[0:32'h0000_0FFF]};
            bins mid_addr = {[32'h0000_1000:32'hFFFF_FFEF]};
            bins high_addr = {[32'hFFFF_FFF0:32'hFFFF_FFFF]};
        }
        cp_wdata: coverpoint WDATA {
            bins zeros = {0};
            bins ones = {{DATA_WIDTH{1'b1}}};
            bins alternating = {32'hAAAAAAAA, 32'h55555555};
            wildcard bins other = default;
        }
        cp_rresp: coverpoint RRESP;
        cp_bresp: coverpoint BRESP;
        
        cross_read_transaction: cross cp_arvalid, cp_rready, cp_rresp;
        cross_write_transaction: cross cp_awvalid, cp_wvalid, cp_bready, cp_bresp;
        
    endgroup

    axi4_lite_transaction_cg axi4_lite_cg;
    */

    // Reset Behavior
    always @(negedge ARESETN) begin
        if (!ARESETN) begin
            ARADDR  <= '0;
            ARPROT  <= '0;
            ARVALID <= 1'b0;
            RREADY  <= 1'b0;
            AWADDR  <= '0;
            AWPROT  <= '0;
            AWVALID <= 1'b0;
            WDATA   <= '0;
            WSTRB   <= '0;
            WVALID  <= 1'b0;
            BREADY  <= 1'b0;
            ARREADY <= 1'b0;
            RDATA   <= '0;
            RRESP   <= 2'b00;
            RVALID  <= 1'b0;
            AWREADY <= 1'b0;
            WREADY  <= 1'b0;
            BRESP   <= 2'b00;
            BVALID  <= 1'b0;
        end
    end

    // Utility Functions
    function string get_read_state();
        if (ARVALID && !ARREADY) return "AR_WAIT";
        if (ARVALID && ARREADY) return "AR_HANDSHAKE";
        if (RVALID && !RREADY) return "R_WAIT";
        if (RVALID && RREADY) return "R_HANDSHAKE";
        return "IDLE";
    endfunction

    function string get_write_state();
        if (AWVALID && !AWREADY) return "AW_WAIT";
        if (WVALID && !WREADY) return "W_WAIT";
        if (AWVALID && AWREADY && WVALID && WREADY) return "AW_W_HANDSHAKE";
        if (BVALID && !BREADY) return "B_WAIT";
        if (BVALID && BREADY) return "B_HANDSHAKE";
        return "IDLE";
    endfunction

    function void display_read_transaction();
        $display("[%0t] AXI4-Lite READ - State: %s, ARADDR: 0x%h, RDATA: 0x%h, RRESP: %b",
                 $time, get_read_state(), ARADDR, RDATA, RRESP);
    endfunction

    function void display_write_transaction();
        $display("[%0t] AXI4-Lite WRITE - State: %s, AWADDR: 0x%h, WDATA: 0x%h, WSTRB: %b, BRESP: %b",
                 $time, get_write_state(), AWADDR, WDATA, WSTRB, BRESP);
    endfunction

    // Initialization (uncomment if coverage is enabled)

    /*
    initial begin
        axi4_lite_cg = new();
    end
    */

endinterface