module apb4_slave #(
    parameter ADDR_WIDTH = 4,
    parameter DATA_WIDTH = 32
)(
    Bus2Reg_intf intf,
    Bus2Master_intf s_apb4
);

    //---------
    // FSM 
    //---------
    typedef enum logic [1:0] {
        IDLE   = 2'b00,
        SETUP  = 2'b01,
        ACCESS = 2'b10
    } apb_state_t;

    apb_state_t current_state, next_state;

    logic transaction_complete;

    // Registradores para capturar sinais no ACCESS
    logic [ADDR_WIDTH-1:0] addr_reg;
    logic [DATA_WIDTH-1:0] wdata_reg;
    logic                  write_reg;
    logic                  capture_signals;

    //--------------------------------------------------------------------------
    // Lógica de próximo estado
    //--------------------------------------------------------------------------
    always_comb begin
        case (current_state)
            IDLE: begin
                if (s_apb4.psel && !s_apb4.penable)
                    next_state = SETUP;
                else
                    next_state = IDLE;
            end
            SETUP: begin
                if (s_apb4.psel && s_apb4.penable)
                    next_state = ACCESS;
                else if (!s_apb4.psel)
                    next_state = IDLE;
                else
                    next_state = SETUP;
            end
            ACCESS: begin
                if (transaction_complete) begin
                    if (s_apb4.psel && !s_apb4.penable)
                        next_state = SETUP;
                    else
                        next_state = IDLE;
                end else
                    next_state = ACCESS;
            end
            default: next_state = IDLE;
        endcase
    end

    //--------------------------------------------------------------------------
    // State Register
    //--------------------------------------------------------------------------
    always_ff @(posedge intf.clk or posedge intf.rst) begin
        if (intf.rst) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    //--------------------------------------------------------------------------
    // Sinal para capturar no início do ACCESS
    //--------------------------------------------------------------------------
    assign capture_signals = (current_state == SETUP) && (next_state == ACCESS);

    //--------------------------------------------------------------------------
    // Captura de sinais na transição SETUP -> ACCESS
    //--------------------------------------------------------------------------
    always_ff @(posedge intf.clk or posedge intf.rst) begin
        if (intf.rst) begin
            addr_reg  <= '0;
            wdata_reg <= '0;
            write_reg <= 1'b0;
        end else if (capture_signals) begin
            // Captura os sinais quando entramos no estado ACCESS
            addr_reg  <= s_apb4.paddr;
            wdata_reg <= s_apb4.pwdata;
            write_reg <= s_apb4.pwrite;
        end
    end

    //--------------------------------------------------------------------------
    // Lógica Combinacional para Saídas
    //--------------------------------------------------------------------------
    always_comb begin
        // valores padrão para evitar latches
        intf.bus_req        = 1'b0;
        intf.bus_req_is_wr  = 1'b0;
        intf.bus_addr       = '0;
        intf.bus_wr_data    = '0;
        intf.bus_wr_biten   = '0;

        // usa valores registrados quando no estado ACCESS
        if (current_state == ACCESS) begin
            intf.bus_req       = 1'b1;
            intf.bus_req_is_wr = write_reg; 
            intf.bus_addr      = addr_reg;  
            intf.bus_wr_data   = wdata_reg;
            
            // CORREÇÃO: bus_wr_biten agora é [3:0] (4 bits para byte enable)
        
            if (write_reg) begin
                intf.bus_wr_biten = 4'b1111; 
            end else begin
                intf.bus_wr_biten = 4'b0000; 
            end
        end
    end

    //--------------------------------------------------------------------------
    // Transaction Completion
    //--------------------------------------------------------------------------
    assign transaction_complete = (intf.bus_ready);

    //--------------------------------------------------------------------------
    // APB Response Signals
    //--------------------------------------------------------------------------
    assign s_apb4.pready  = (current_state == ACCESS) ? transaction_complete : 1'b0;
    assign s_apb4.prdata  = (current_state == ACCESS) ? intf.bus_rd_data : '0;
    assign s_apb4.pslverr = (current_state == ACCESS) ? intf.bus_err : 1'b0;

    //--------------------------------------------------------------------------
    // Stall signals
    //--------------------------------------------------------------------------
    assign intf.bus_req_stall_wr = 1'b0;
    assign intf.bus_req_stall_rd = 1'b0;

endmodule