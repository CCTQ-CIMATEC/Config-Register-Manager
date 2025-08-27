module axi4lite_tb;

    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;
    parameter CSR_ADDR_WIDTH = 3;
    parameter CLK_PERIOD = 10; // 100 MHz
    parameter MEM_DEPTH = 1024; // Add this parameter for the slave module

    logic clk;
    logic rst_n;
    
    // Hardware Interface
    // CSR_IP_Map__in_t  hwif_in;
    // CSR_IP_Map__out_t hwif_out;
    
    // Test variables
    logic [DATA_WIDTH-1:0] expected_data;
    logic [ADDR_WIDTH-1:0] test_address;
    logic test_passed;

    // AXI4-Lite Interface instance
    Bus2Master_intf #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) s_axi4_lite (
        .ACLK(clk),
        .ARESETN(rst_n)
    );

    // DUT Instance
    axilite_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .SAXI(s_axi4_lite.slave_ports)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Reset Generation
    initial begin
        rst_n = 0;
        #(CLK_PERIOD * 2);
        rst_n = 1;
        #(CLK_PERIOD);
    end

    // AXI4-Lite Write Task using interface clocking block
    task axi4_lite_write;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        input [(DATA_WIDTH/8)-1:0] strb;
        begin
            // Address Write Channel
            @(s_axi4_lite.master_cb);
            s_axi4_lite.master_cb.AWADDR  <= addr;
            s_axi4_lite.master_cb.AWPROT  <= 3'b000;
            s_axi4_lite.master_cb.AWVALID <= 1'b1;
            
            // Write Data Channel
            s_axi4_lite.master_cb.WDATA   <= data;
            s_axi4_lite.master_cb.WSTRB   <= strb;
            s_axi4_lite.master_cb.WVALID  <= 1'b1;
            
            // Write Response Channel
            s_axi4_lite.master_cb.BREADY  <= 1'b1;
            
            // Wait for address and data handshakes
            while (!(s_axi4_lite.master_cb.AWREADY && s_axi4_lite.master_cb.WREADY)) begin
                @(s_axi4_lite.master_cb);
            end
            
            // Deassert AWVALID and WVALID after handshake
            @(s_axi4_lite.master_cb);
            s_axi4_lite.master_cb.AWVALID <= 1'b0;
            s_axi4_lite.master_cb.WVALID  <= 1'b0;
            
            // Wait for write response
            while (!s_axi4_lite.master_cb.BVALID) begin
                @(s_axi4_lite.master_cb);
            end
            
            // Check write response
            if (s_axi4_lite.master_cb.BRESP != 2'b00) begin
                $display("[%0t] AXI4-Lite WRITE WARNING: BRESP=0x%h (not OKAY)", $time, s_axi4_lite.master_cb.BRESP);
            end
            
            // End transaction
            @(s_axi4_lite.master_cb);
            s_axi4_lite.master_cb.BREADY <= 1'b0;
            
            $display("[%0t] AXI4-Lite WRITE: Addr=0x%h, Data=0x%h, STRB=0x%h, BRESP=0x%h", 
                     $time, addr, data, strb, s_axi4_lite.master_cb.BRESP);
        end
    endtask

    // AXI4-Lite Read Task using interface clocking block
    task axi4_lite_read;
        input [ADDR_WIDTH-1:0] addr;
        output [DATA_WIDTH-1:0] data;
        output [1:0] resp;
        begin
            // Address Read Channel
            @(s_axi4_lite.master_cb);
            s_axi4_lite.master_cb.ARADDR  <= addr;
            s_axi4_lite.master_cb.ARPROT  <= 3'b000;
            s_axi4_lite.master_cb.ARVALID <= 1'b1;
            s_axi4_lite.master_cb.RREADY  <= 1'b1;
            
            // Wait for address handshake
            while (!s_axi4_lite.master_cb.ARREADY) begin
                @(s_axi4_lite.master_cb);
            end
            
            // Deassert ARVALID after handshake
            @(s_axi4_lite.master_cb);
            s_axi4_lite.master_cb.ARVALID <= 1'b0;
            
            // Wait for read data
            while (!s_axi4_lite.master_cb.RVALID) begin
                @(s_axi4_lite.master_cb);
            end
            
            // Capture data and response
            data = s_axi4_lite.master_cb.RDATA;
            resp = s_axi4_lite.master_cb.RRESP;
            
            // End transaction
            @(s_axi4_lite.master_cb);
            s_axi4_lite.master_cb.RREADY <= 1'b0;
            
            $display("[%0t] AXI4-Lite READ: Addr=0x%h, Data=0x%h, RRESP=0x%h", $time, addr, data, resp);
        end
    endtask

    // AXI4-Lite Write Task using direct interface signals (alternative)
    task axi4_lite_write_direct;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        input [(DATA_WIDTH/8)-1:0] strb;
        begin
            // Start write transaction
            @(posedge clk);
            s_axi4_lite.AWADDR  <= addr;
            s_axi4_lite.AWPROT  <= 3'b000;
            s_axi4_lite.AWVALID <= 1'b1;
            s_axi4_lite.WDATA   <= data;
            s_axi4_lite.WSTRB   <= strb;
            s_axi4_lite.WVALID  <= 1'b1;
            s_axi4_lite.BREADY  <= 1'b1;
            
            // Wait for address and data handshakes
            wait(s_axi4_lite.AWREADY && s_axi4_lite.WREADY);
            @(posedge clk);
            
            s_axi4_lite.AWVALID <= 1'b0;
            s_axi4_lite.WVALID  <= 1'b0;
            
            // Wait for write response
            wait(s_axi4_lite.BVALID);
            
            if (s_axi4_lite.BRESP != 2'b00) begin
                $display("[%0t] AXI4-Lite WRITE WARNING: BRESP=0x%h (not OKAY)", $time, s_axi4_lite.BRESP);
            end
            
            @(posedge clk);
            s_axi4_lite.BREADY <= 1'b0;
            
            $display("[%0t] AXI4-Lite WRITE (Direct): Addr=0x%h, Data=0x%h, STRB=0x%h, BRESP=0x%h", 
                     $time, addr, data, strb, s_axi4_lite.BRESP);
        end
    endtask

    // AXI4-Lite Read Task using direct interface signals (alternative)
    task axi4_lite_read_direct;
        input [ADDR_WIDTH-1:0] addr;
        output [DATA_WIDTH-1:0] data;
        output [1:0] resp;
        begin
            // Start read transaction
            @(posedge clk);
            s_axi4_lite.ARADDR  <= addr;
            s_axi4_lite.ARPROT  <= 3'b000;
            s_axi4_lite.ARVALID <= 1'b1;
            s_axi4_lite.RREADY  <= 1'b1;
            
            // Wait for address handshake
            wait(s_axi4_lite.ARREADY);
            @(posedge clk);
            s_axi4_lite.ARVALID <= 1'b0;
            
            // Wait for read data
            wait(s_axi4_lite.RVALID);
            data = s_axi4_lite.RDATA;
            resp = s_axi4_lite.RRESP;
            
            @(posedge clk);
            s_axi4_lite.RREADY <= 1'b0;
            
            $display("[%0t] AXI4-Lite READ (Direct): Addr=0x%h, Data=0x%h, RRESP=0x%h", $time, addr, data, resp);
        end
    endtask

    // Test Sequence
    initial begin
        // Initialize signals
        // hwif_in     <= '0;
        test_passed <= 1;
        
        // Initialize AXI4-Lite interface through modport
        s_axi4_lite.master_cb.ARADDR  <= '0;
        s_axi4_lite.master_cb.ARPROT  <= '0;
        s_axi4_lite.master_cb.ARVALID <= 1'b0;
        s_axi4_lite.master_cb.RREADY  <= 1'b0;
        s_axi4_lite.master_cb.AWADDR  <= '0;
        s_axi4_lite.master_cb.AWPROT  <= '0;
        s_axi4_lite.master_cb.AWVALID <= 1'b0;
        s_axi4_lite.master_cb.WDATA   <= '0;
        s_axi4_lite.master_cb.WSTRB   <= '0;
        s_axi4_lite.master_cb.WVALID  <= 1'b0;
        s_axi4_lite.master_cb.BREADY  <= 1'b0;
        
        // Wait for reset to complete
        wait(rst_n == 1);
        #(CLK_PERIOD * 2);
        
        $display("==========================================");
        $display("Starting AXI4-Lite CSR Top Testbench");
        $display("Using AXI4-Lite Interface with modports");
        $display("==========================================");
        
        // Test 1: Write to a register using clocking block
        $display("\nTest 1: Writing to register address 0x00000000 (Clocking Block)");
        test_address = 32'h00000000;
        expected_data = 32'hDEADBEEF;
        
        // Perform AXI4-Lite write using clocking block (full word write)
        axi4_lite_write(test_address, expected_data, 4'hF);
        
        // Allow some time for the write to propagate
        #(CLK_PERIOD * 2);
        
        // Test 2: Read back the same register using clocking block
        $display("\nTest 2: Reading back from register address 0x00000000 (Clocking Block)");
        begin
            logic [DATA_WIDTH-1:0] read_data;
            logic [1:0] read_resp;
            axi4_lite_read(test_address, read_data, read_resp);
            
            if (read_data === expected_data && read_resp === 2'b00) begin
                $display("✅ READBACK PASSED: Expected=0x%h, Got=0x%h, RRESP=0x%h", expected_data, read_data, read_resp);
            end else begin
                $display("❌ READBACK FAILED: Expected=0x%h, Got=0x%h, RRESP=0x%h", expected_data, read_data, read_resp);
                test_passed = 0;
            end
        end
        
        // Test 3: Write to another register using direct signals
        $display("\nTest 3: Writing to register address 0x00000010 (Direct)");
        test_address = 32'h00000010;
        expected_data = 32'hCAFEBABE;
        
        axi4_lite_write_direct(test_address, expected_data, 4'hF);
        #(CLK_PERIOD * 2);
        
        // Test 4: Read back the second register using direct signals
        $display("\nTest 4: Reading back from register address 0x00000010 (Direct)");
        begin
            logic [DATA_WIDTH-1:0] read_data;
            logic [1:0] read_resp;
            axi4_lite_read_direct(test_address, read_data, read_resp);
            
            if (read_data === expected_data && read_resp === 2'b00) begin
                $display("✅ READBACK PASSED: Expected=0x%h, Got=0x%h, RRESP=0x%h", expected_data, read_data, read_resp);
            end else begin
                $display("❌ READBACK FAILED: Expected=0x%h, Got=0x%h, RRESP=0x%h", expected_data, read_data, read_resp);
                test_passed = 0;
            end
        end
        
        // Test 5: Test byte writes using WSTRB
        $display("\nTest 5: Testing byte writes with WSTRB");
        test_address = 32'h00000020;
        
        // Write only lower byte
        axi4_lite_write(test_address, 32'h12345678, 4'h1);
        #(CLK_PERIOD * 2);
        
        begin
            logic [DATA_WIDTH-1:0] read_data;
            logic [1:0] read_resp;
            axi4_lite_read(test_address, read_data, read_resp);
            
            if (read_data[7:0] === 8'h78 && read_resp === 2'b00) begin
                $display("✅ BYTE WRITE PASSED: Lower byte=0x%h", read_data[7:0]);
            end else begin
                $display("❌ BYTE WRITE FAILED: Expected lower byte=0x78, Got=0x%h", read_data[7:0]);
                test_passed = 0;
            end
        end
        
        // Test 6: Test out of bounds access
        $display("\nTest 6: Testing out of bounds access");
        test_address = 32'hFFFFFFFC; // Very high address
        
        begin
            logic [DATA_WIDTH-1:0] read_data;
            logic [1:0] read_resp;
            axi4_lite_read(test_address, read_data, read_resp);
            
            if (read_resp === 2'b10) begin // SLVERR expected
                $display("✅ OUT OF BOUNDS READ PASSED: Got SLVERR (0x%h)", read_resp);
            end else begin
                $display("❌ OUT OF BOUNDS READ FAILED: Expected SLVERR, Got=0x%h", read_resp);
                test_passed = 0;
            end
        end
        
        // Summary
        $display("\n==========================================");
        if (test_passed) begin
            $display("✅ ALL TESTS PASSED!");
        end else begin
            $display("❌ SOME TESTS FAILED!");
        end
        $display("==========================================");
        
        #(CLK_PERIOD * 5);
        $finish;
    end

    // Monitoring using interface monitor modport
    initial begin
        $timeformat(-9, 0, " ns", 6);
        forever begin
            @(posedge clk);
            
            // Monitor Read Address Channel
            if (s_axi4_lite.ARVALID && s_axi4_lite.ARREADY) begin
                $display("[%0t] AXI4-Lite AR: ARADDR=0x%h, ARPROT=0x%h", 
                         $time, s_axi4_lite.ARADDR, s_axi4_lite.ARPROT);
            end
            
            // Monitor Read Data Channel
            if (s_axi4_lite.RVALID && s_axi4_lite.RREADY) begin
                $display("[%0t] AXI4-Lite R: RDATA=0x%h, RRESP=0x%h", 
                         $time, s_axi4_lite.RDATA, s_axi4_lite.RRESP);
            end
            
            // Monitor Write Address Channel
            if (s_axi4_lite.AWVALID && s_axi4_lite.AWREADY) begin
                $display("[%0t] AXI4-Lite AW: AWADDR=0x%h, AWPROT=0x%h", 
                         $time, s_axi4_lite.AWADDR, s_axi4_lite.AWPROT);
            end
            
            // Monitor Write Data Channel
            if (s_axi4_lite.WVALID && s_axi4_lite.WREADY) begin
                $display("[%0t] AXI4-Lite W: WDATA=0x%h, WSTRB=0x%h", 
                         $time, s_axi4_lite.WDATA, s_axi4_lite.WSTRB);
            end
            
            // Monitor Write Response Channel
            if (s_axi4_lite.BVALID && s_axi4_lite.BREADY) begin
                $display("[%0t] AXI4-Lite B: BRESP=0x%h", 
                         $time, s_axi4_lite.BRESP);
            end
        end
    end

    // State Monitoring
    initial begin
        forever begin
            @(posedge clk);
            if (s_axi4_lite.ARVALID || s_axi4_lite.RVALID || 
                s_axi4_lite.AWVALID || s_axi4_lite.WVALID || s_axi4_lite.BVALID) begin
                $display("[%0t] AXI4-Lite State: Read=%s, Write=%s",
                         $time, s_axi4_lite.get_read_state(), s_axi4_lite.get_write_state());
            end
        end
    end

    // Assertion Monitoring
    initial begin
        // Wait for reset to complete
        wait(rst_n == 1);
        $display("AXI4-Lite Protocol Assertions enabled");
    end

    // Simulation Control
    initial begin
        #2000; // Timeout protection
        $display("❌ SIMULATION TIMEOUT");
        $finish;
    end

endmodule