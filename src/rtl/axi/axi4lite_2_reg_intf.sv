interface axi_lite #(
    parameter DATA_WIDTH = 31,
    parameter ADDR_WIDTH = 31
) (
    input logic ACLK,
    input logic ARESETN
);
    
    // Read Address Channel - AR
    logic [ADDR_WIDTH:0]    ARADDR;
    logic [3:0]             ARCACHE;
    logic [2:0]             ARPROT;
    logic                   ARVALID;
    logic                   ARREADY;

    //Read Data Channel - R
    logic [DATA_WIDTH:0]    RDATA;
    logic [1:0]             RRESP;
    logic                   RVALID;
    logic                   RREADY;

    //Write Address Channel - AW
    logic [ADDR_WIDTH:0]    AWADDR;
    logic [3:0]             AWCACHE;
    logic [2:0]             AWPROT;
    logic                   AWVALID;
    logic                   AWREADY;

    //Write Data Channel - W
    logic [DATA_WIDTH]      WDATA;
    logic [3:0]             WSTRB;
    logic                   WVALID;
    logic                   WREADY;

    //Write Response Channel - B
    logic [1:0]             BRESP;
    logic                   BVALID;
    logic                   BREADY;

    modport master_ports (
        input ACLK, ARESETN,
        input ARREADY, RDATA, RRESP, RVALID,
        input AWREADY, WREADY, BRESP, BVALID,
        output ARADDR, ARCACHE, ARPROT, ARVALID, RREADY,
        output AWADDR, AWCACHE, AWPROT, AWVALID,
        output WDATA, WSTRB, WVALID, BREADY
    );

    modport slave_ports (
        input ACLK, ARESETN,
        input ARADDR, ARCACHE, ARPROT, ARVALID, RREADY,
        input AWADDR, AWCACHE, AWPROT, AWVALID,
        input WDATA, WSTRB, WVALID, BREADY,
        output ARREADY, RDATA, RRESP, RVALID,
        output AWREADY, WREADY, BRESP, BVALID
    );


endinterface //axi4_lite