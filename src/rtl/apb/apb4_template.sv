module apb4_slave #(
    parameter ADDR_WIDTH = 3,
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
    logic write_enable;  
    // lógica de próximo estado
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
    // Lógica Combinacional para Saídas
    //--------------------------------------------------------------------------
    always_comb begin
        // valores padrão para evitar latches
        intf.bus_req        = 1'b0;
        intf.bus_req_is_wr  = 1'b0;
        intf.bus_addr       = '0;
        intf.bus_wr_data    = '0;
        intf.bus_wr_biten   = '0;

        // logica baseada no estado atual
        if (current_state == ACCESS) begin
            intf.bus_req       = 1'b1;
            intf.bus_req_is_wr = write_enable; 
            intf.bus_addr      = s_apb4.paddr;  
            intf.bus_wr_data   = s_apb4.pwdata;
            // intf.o_bus_wr_biten pode precisar ser ajustado conforme necessário.
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