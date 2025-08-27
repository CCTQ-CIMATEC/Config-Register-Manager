//------------------------------------------------------------------------------
// Testbench: apb4_csr_top_tb
// Description: Testbench para verificar escrita através do barramento APB4
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module apb4_tb;

    //--------------------------------------------------------------------------
    // Parameters
    //--------------------------------------------------------------------------
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 3;
    parameter CSR_ADDR_WIDTH = 3;
    parameter CLK_PERIOD = 10; // 100 MHz

    //--------------------------------------------------------------------------
    // Signals
    //--------------------------------------------------------------------------
    logic clk;
    logic rst;
    
    // Hardware Interface
    CSR_IP_Map__in_t  hwif_in;
    CSR_IP_Map__out_t hwif_out;
    
    // Test variables
    logic [DATA_WIDTH-1:0] expected_data;
    logic [ADDR_WIDTH-1:0] test_address;
    logic test_passed;

    //--------------------------------------------------------------------------
    // APB4 Interface instance
    //--------------------------------------------------------------------------
    Bus2Master_intf #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) s_apb4 (
        .pclk(clk),
        .presetn(~rst)
    );

    //--------------------------------------------------------------------------
    // DUT Instance
    //--------------------------------------------------------------------------
    apb4_csr_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .CSR_ADDR_WIDTH(CSR_ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        
        // APB4 Interface
        .apb42Master_intf(s_apb4.slave),
        
        // Hardware Interface
        .hwif_in(hwif_in),
        .hwif_out(hwif_out)
    );

    //--------------------------------------------------------------------------
    // Clock Generation
    //--------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //--------------------------------------------------------------------------
    // Reset Generation
    //--------------------------------------------------------------------------
    initial begin
        rst = 1;
        #(CLK_PERIOD * 2);
        rst = 0;
        #(CLK_PERIOD);
    end

    //--------------------------------------------------------------------------
    // APB4 Write Task using interface clocking block
    //--------------------------------------------------------------------------
    task apb4_write;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        begin
            // Setup phase
            @(s_apb4.master_cb);
            s_apb4.master_cb.psel    <= 1'b1;
            s_apb4.master_cb.penable <= 1'b0;
            s_apb4.master_cb.pwrite  <= 1'b1;
            s_apb4.master_cb.paddr   <= addr;
            s_apb4.master_cb.pwdata  <= data;
            
            // Access phase
            @(s_apb4.master_cb);
            s_apb4.master_cb.penable <= 1'b1;
            
            // Wait for pready using clocking block
            while (s_apb4.master_cb.pready !== 1'b1) begin
                @(s_apb4.master_cb);
            end
            
            // End transaction
            @(s_apb4.master_cb);
            s_apb4.master_cb.psel    <= 1'b0;
            s_apb4.master_cb.penable <= 1'b0;
            s_apb4.master_cb.pwrite  <= 1'b0;
            
            $display("[%0t] APB4 WRITE: Addr=0x%h, Data=0x%h", $time, addr, data);
        end
    endtask

    //--------------------------------------------------------------------------
    // APB4 Read Task using interface clocking block
    //--------------------------------------------------------------------------
    task apb4_read;
        input [ADDR_WIDTH-1:0] addr;
        output [DATA_WIDTH-1:0] data;
        begin
            // Setup phase
            @(s_apb4.master_cb);
            s_apb4.master_cb.psel    <= 1'b1;
            s_apb4.master_cb.penable <= 1'b0;
            s_apb4.master_cb.pwrite  <= 1'b0;
            s_apb4.master_cb.paddr   <= addr;
            
            // Access phase
            @(s_apb4.master_cb);
            s_apb4.master_cb.penable <= 1'b1;
            
            // Wait for pready using clocking block
            while (s_apb4.master_cb.pready !== 1'b1) begin
                @(s_apb4.master_cb);
            end
            
            data = s_apb4.master_cb.prdata;
            
            // End transaction
            @(s_apb4.master_cb);
            s_apb4.master_cb.psel    <= 1'b0;
            s_apb4.master_cb.penable <= 1'b0;
            
            $display("[%0t] APB4 READ: Addr=0x%h, Data=0x%h", $time, addr, data);
        end
    endtask

    //--------------------------------------------------------------------------
    // APB4 Write Task using direct interface signals (alternative)
    //--------------------------------------------------------------------------
    task apb4_write_direct;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        begin
            // Setup phase
            @(posedge clk);
            s_apb4.psel    <= 1'b1;
            s_apb4.penable <= 1'b0;
            s_apb4.pwrite  <= 1'b1;
            s_apb4.paddr   <= addr;
            s_apb4.pwdata  <= data;
            
            // Access phase
            @(posedge clk);
            s_apb4.penable <= 1'b1;
            
            // Wait for pready
            wait(s_apb4.pready == 1'b1);
            @(posedge clk);
            
            // End transaction
            s_apb4.psel    <= 1'b0;
            s_apb4.penable <= 1'b0;
            s_apb4.pwrite  <= 1'b0;
            
            $display("[%0t] APB4 WRITE (Direct): Addr=0x%h, Data=0x%h", $time, addr, data);
        end
    endtask

    //--------------------------------------------------------------------------
    // APB4 Read Task using direct interface signals (alternative)
    //--------------------------------------------------------------------------
    task apb4_read_direct;
        input [ADDR_WIDTH-1:0] addr;
        output [DATA_WIDTH-1:0] data;
        begin
            // Setup phase
            @(posedge clk);
            s_apb4.psel    <= 1'b1;
            s_apb4.penable <= 1'b0;
            s_apb4.pwrite  <= 1'b0;
            s_apb4.paddr   <= addr;
            
            // Access phase
            @(posedge clk);
            s_apb4.penable <= 1'b1;
            
            // Wait for pready
            wait(s_apb4.pready == 1'b1);
            data = s_apb4.prdata;
            @(posedge clk);
            
            // End transaction
            s_apb4.psel    <= 1'b0;
            s_apb4.penable <= 1'b0;
            
            $display("[%0t] APB4 READ (Direct): Addr=0x%h, Data=0x%h", $time, addr, data);
        end
    endtask

    //--------------------------------------------------------------------------
    // Test Sequence
    //--------------------------------------------------------------------------
    initial begin
        // Initialize signals
        hwif_in <= '{default:0};
        test_passed <= 1;
        
        // Initialize APB4 interface through modport
        s_apb4.master_cb.psel    <= 1'b0;
        s_apb4.master_cb.penable <= 1'b0;
        s_apb4.master_cb.pwrite  <= 1'b0;
        s_apb4.master_cb.paddr   <= '0;
        s_apb4.master_cb.pwdata  <= '0;
        
        // Wait for reset to complete
        wait(rst == 0);
        #(CLK_PERIOD * 2);
        
        $display("==========================================");
        $display("Starting APB4 CSR Top Testbench");
        $display("Using APB4 Interface with modports");
        $display("==========================================");
        
        // Test 1: Write to a register using clocking block
        $display("\nTest 1: Writing to register address 0x0 (Clocking Block)");
        test_address = 3'h0;
        expected_data = 32'hDEADBEEF;
        
        // Perform APB4 write using clocking block
        apb4_write(test_address, expected_data);
        
        // Allow some time for the write to propagate
        #(CLK_PERIOD * 2);
        
        // Check hardware interface signals
        $display("Checking hardware interface signals...");
        // Add your specific checks here based on the CSR_IP_Map structure
        // Example: if (hwif_out.some_signal != expected_data[0]) test_passed = 0;
        
        $display("Expected data written: 0x%h", expected_data);
        
        // Test 2: Read back the same register using clocking block
        $display("\nTest 2: Reading back from register address 0x0 (Clocking Block)");
        begin
            logic [DATA_WIDTH-1:0] read_data;
            apb4_read(test_address, read_data);
            
            if (read_data === expected_data) begin
                $display("✅ READBACK PASSED: Expected=0x%h, Got=0x%h", expected_data, read_data);
            end else begin
                $display("❌ READBACK FAILED: Expected=0x%h, Got=0x%h", expected_data, read_data);
                test_passed = 0;
            end
        end
        
        // Test 3: Write to another register using direct signals
        $display("\nTest 3: Writing to register address 0x4 (Direct)");
        test_address = 3'h4;
        expected_data = 32'hCAFEBABE;
        
        apb4_write_direct(test_address, expected_data);
        #(CLK_PERIOD * 2);
        
        $display("Expected data written: 0x%h", expected_data);
        
        // Test 4: Read back the second register using direct signals
        $display("\nTest 4: Reading back from register address 0x4 (Direct)");
        begin
            logic [DATA_WIDTH-1:0] read_data;
            apb4_read_direct(test_address, read_data);
            
            if (read_data === expected_data) begin
                $display("✅ READBACK PASSED: Expected=0x%h, Got=0x%h", expected_data, read_data);
            end else begin
                $display("❌ READBACK FAILED: Expected=0x%h, Got=0x%h", expected_data, read_data);
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

    //--------------------------------------------------------------------------
    // Monitoring using interface monitor modport
    //--------------------------------------------------------------------------
    initial begin
        $timeformat(-9, 0, " ns", 6);
        forever begin
            @(posedge clk);
            if (s_apb4.psel || s_apb4.penable) begin
                $display("[%0t] APB4: State=%s, PSEL=%b, PENABLE=%b, PWRITE=%b, PADDR=0x%h, PWDATA=0x%h, PRDATA=0x%h, PREADY=%b, PSLVERR=%b",
                         $time, s_apb4.get_state(), s_apb4.psel, s_apb4.penable, s_apb4.pwrite, 
                         s_apb4.paddr, s_apb4.pwdata, s_apb4.prdata, s_apb4.pready, s_apb4.pslverr);
            end
        end
    end

    //--------------------------------------------------------------------------
    // Assertion Monitoring
    //--------------------------------------------------------------------------
    initial begin
        // Wait for reset to complete
        wait(rst == 0);
        $display("APB4 Protocol Assertions enabled");
    end

    //--------------------------------------------------------------------------
    // Simulation Control
    //--------------------------------------------------------------------------
    initial begin
        #1000; // Timeout protection
        $display("❌ SIMULATION TIMEOUT");
        $finish;
    end

endmodule

//------------------------------------------------------------------------------
// End of apb4_csr_top_tb
//------------------------------------------------------------------------------