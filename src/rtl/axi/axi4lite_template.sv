module axilite_slave #(
    parameter logic DATA_WIDTH = 32,
    parameter logic ADDR_WIDTH = 32,
    parameter logic MEM_DEPTH = 32;
)(
    input logic clk,
    input logic rst_n,
    axi4_lite.slave_ports SAXI;
);
    // Memory array
    logic [DATA_WIDTH-1:0] memory [0:MEM_DEPTH-1];
    
    // Internal registers for address phases
    logic [ADDR_WIDTH-1:0] read_addr;
    logic [ADDR_WIDTH-1:0] write_addr;
    
    // State machines for read and write channels
    typedef enum logic [1:0] {
        READ_IDLE,
        READ_DATA
    } read_state_t;
    
    typedef enum logic [2:0] {
        WRITE_IDLE,
        WRITE_DATA,
        WRITE_RESP
    } write_state_t;
    
    read_state_t read_state, read_state_next;
    write_state_t write_state, write_state_next;
    
    // Calculate word address from byte address
    function automatic logic [ADDR_WIDTH-3:0] get_word_addr(logic [ADDR_WIDTH-1:0] byte_addr);
        return byte_addr[ADDR_WIDTH-1:2];  // Divide by 4 for word addressing
    endfunction
    
    // Sequential logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_state <= READ_IDLE;
            write_state <= WRITE_IDLE;
            read_addr <= '0;
            write_addr <= '0;
            
            // Initialize memory to zero
            for (int i = 0; i < MEM_DEPTH; i++) begin
                memory[i] <= '0;
            end
        end else begin
            read_state <= read_state_next;
            write_state <= write_state_next;
            
            // Capture read address
            if (SAXI.ARVALID && SAXI.ARREADY) begin
                read_addr <= SAXI.ARADDR;
            end
            
            // Capture write address
            if (SAXI.AWVALID && SAXI.AWREADY) begin
                write_addr <= SAXI.AWADDR;
            end
            
            // Write data to memory
            if (SAXI.WVALID && SAXI.WREADY) begin
                logic [ADDR_WIDTH-3:0] word_addr = get_word_addr(write_addr);
                if (word_addr < MEM_DEPTH) begin
                    for (int i = 0; i < 4; i++) begin
                        if (SAXI.WSTRB[i]) begin
                            memory[word_addr][i*8 +: 8] <= SAXI.WDATA[i*8 +: 8];
                        end
                    end
                end
            end
        end
    end
    
    // Read channel state machine
    always_comb begin
        read_state_next = read_state;
        
        case (read_state)
            READ_IDLE: begin
                if (SAXI.ARVALID && SAXI.ARREADY) begin
                    read_state_next = READ_DATA;
                end
            end
            
            READ_DATA: begin
                if (SAXI.RVALID && SAXI.RREADY) begin
                    read_state_next = READ_IDLE;
                end
            end
        endcase
    end
    
    // Write channel state machine
    always_comb begin
        write_state_next = write_state;
        
        case (write_state)
            WRITE_IDLE: begin
                if (SAXI.AWVALID && SAXI.AWREADY && SAXI.WVALID && SAXI.WREADY) begin
                    write_state_next = WRITE_RESP;
                end
            end
            
            WRITE_RESP: begin
                if (SAXI.BVALID && SAXI.BREADY) begin
                    write_state_next = WRITE_IDLE;
                end
            end
        endcase
    end
    
    // AXI4-Lite signal assignments
    
    // Read Address Channel
    assign SAXI.ARREADY = (read_state == READ_IDLE);
    
    // Read Data Channel
    always_comb begin
        logic [ADDR_WIDTH-3:0] word_addr = get_word_addr(read_addr);
        if (word_addr < MEM_DEPTH) begin
            SAXI.RDATA = memory[word_addr];
            SAXI.RRESP = 2'b00; // OKAY response
        end else begin
            SAXI.RDATA = '0;
            SAXI.RRESP = 2'b10; // SLVERR - slave error for out of bounds access
        end
    end
    assign SAXI.RVALID = (read_state == READ_DATA);
    
    // Write Address Channel
    assign SAXI.AWREADY = (write_state == WRITE_IDLE);
    
    // Write Data Channel
    assign SAXI.WREADY = (write_state == WRITE_IDLE);
    
    // Write Response Channel
    always_comb begin
        logic [ADDR_WIDTH-3:0] word_addr = get_word_addr(write_addr);
        if (word_addr < MEM_DEPTH) begin
            SAXI.BRESP = 2'b00; // OKAY response
        end else begin
            SAXI.BRESP = 2'b10; // SLVERR - slave error for out of bounds access
        end
    end
    assign SAXI.BVALID = (write_state == WRITE_RESP);

endmodule