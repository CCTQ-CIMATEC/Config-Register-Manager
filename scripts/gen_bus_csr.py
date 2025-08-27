"""
Gerador de RTL para módulo APB4 CSR Top
Autor: Script Python para geração automatizada
"""
 
import os
import shutil
import argparse
from pathlib import Path
 
class APB4RTLGenerator:
    def __init__(self, bus_type="apb4", data_width=32, addr_width=8):
        self.bus_type = bus_type.lower()
        self.data_width = data_width
        self.addr_width = addr_width
        self.build_dir = Path("build/rtl")
        self.src_dir = Path("src/rtl/apb")
        self.source_files = [
            "CSR_IP_Map_pkg.sv",
            "CSR_IP_Map.sv"
        ]
        
    def create_directories(self):
        """Cria o diretório build/rtl se não existir"""
        self.build_dir.mkdir(parents=True, exist_ok=True)
        print(f"✓ Diretório {self.build_dir} criado/verificado")
    
    def copy_source_files(self):
        """Copia os arquivos necessários do diretório src para build"""
        source_files = []
        if self.bus_type == "apb4":
            source_files = [
            "apb4_2_reg_intf.sv",
            "apb4_2_master_intf.sv",
            "apb4_template.sv"
        ]
        elif self.bus_type == "axi4lite":
            source_files = [
            "apb4_2_reg_intf.sv", #alterar depois
            "apb4_2_master_intf.sv",
            "apb4_template.sv"
        ]
        else:
            source_files = [
            "apb4_2_reg_intf.sv",
            "apb4_2_master_intf.sv",
            "apb4_template.sv"
        ]
        
        for file_name in source_files:
            src_file = self.src_dir / file_name
            dst_file = self.build_dir / file_name
            
            if src_file.exists():
                shutil.copy2(src_file, dst_file)
                print(f"✓ Arquivo {file_name} copiado para {self.build_dir}")
            else:
                print(f"⚠ Arquivo {src_file} não encontrado")
    
    def generate_bus2Reg_interface_params(self):
        """Gera os parâmetros específicos do barramento"""
        if self.bus_type == "apb4":
            return {
                "bus_interface_name": "apb42Reg_intf",
                "bus_connection": "apb42Reg_intf.BUS",
                "reg_map_connection": "apb42Reg_intf.REG_MAP"
                ""
            }
        elif self.bus_type == "axi4lite":
            return {
                "bus_interface_name": "axi4lite2Reg_intf",
                "bus_connection": "axi4lite2Reg_intf.BUS",
                "reg_map_connection": "axi4lite2Reg_intf.REG_MAP"
            }
        else:
            # Default para APB4
            return {
                "bus_interface_name": "apb42Reg_intf",
                "bus_connection": "apb42Reg_intf.BUS",
                "reg_map_connection": "apb42Reg_intf.REG_MAP"
            }
    
    def generate_bus2Master_interface_params(self):
        """Gera os parâmetros específicos do barramento"""
        if self.bus_type == "apb4":
            return {
                "bus_interface_name": "apb42Master_intf",
                "slave_connection": "apb42Master_intf.slave",
            }
        elif self.bus_type == "axi4lite":
            return {
                "bus_interface_name": "aaxi4lite2Reg_intf",
                "slave_connection": "aaxi4lite2Reg_intf.BUS",
            }
        else:
            # Default para APB4
            return {
                "bus_interface_name": "apb42Master_intf",
                "slave_connection": "apb42Master_intf.BUS",
            }
    
    def generate_rtl_content(self):
        """Gera o conteúdo do arquivo SystemVerilog"""
        bus2Reg_params = self.generate_bus2Reg_interface_params()
        bus2Master_params = self.generate_bus2Master_interface_params()
        
        # Calcula a largura do endereço necessária para o CSR
        csr_addr_width = max(3, (self.addr_width - 2))  # Mínimo 3 bits, remove 2 bits para word alignment
        
        rtl_content = f'''//------------------------------------------------------------------------------
// Module: {self.bus_type}_csr_top
// Description: Top-level module for {self.bus_type.upper()} CSR interface
// Generated automatically by Python script
//------------------------------------------------------------------------------
 
module {self.bus_type}_csr_top #(
    parameter DATA_WIDTH = {self.data_width},
    parameter ADDR_WIDTH = {self.addr_width},
    parameter CSR_ADDR_WIDTH = {csr_addr_width}
) (
    input wire clk,
    input wire rst,
    
    // {self.bus_type.upper()} Interface
    Bus2Master_intf {bus2Master_params['bus_interface_name']},
    
    // Hardware Interface
    input  CSR_IP_Map__in_t  hwif_in,
    output CSR_IP_Map__out_t hwif_out
);
 
    //--------------------------------------------------------------------------
    // Local Parameters
    //--------------------------------------------------------------------------
    localparam P_DATA_WIDTH = DATA_WIDTH;
    localparam P_DMEM_ADDR_WIDTH = ADDR_WIDTH;
    localparam P_CSR_ADDR_WIDTH = CSR_ADDR_WIDTH;
 
    //--------------------------------------------------------------------------
    // Bus Interface Instance
    //--------------------------------------------------------------------------
    Bus2Reg_intf #(
        .DATA_WIDTH(P_DATA_WIDTH),
        .ADDR_WIDTH(P_DMEM_ADDR_WIDTH)
    ) {bus2Reg_params['bus_interface_name']} (
        .clk(clk),
        .rst(rst)
    );
 
    //--------------------------------------------------------------------------
    // {self.bus_type.upper()} Slave Instance
    //--------------------------------------------------------------------------
    {self.bus_type}_slave #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_{self.bus_type}_slave (
        // {self.bus_type.upper()} Interface
        .s_{self.bus_type}({bus2Master_params['bus_interface_name']}),
        
        // Internal Bus Interface
        .intf({bus2Reg_params['bus_connection']})
    );
 
    //--------------------------------------------------------------------------
    // CSR_IP_Map Instance
    //--------------------------------------------------------------------------
    CSR_IP_Map u_csr_ip_map (
        // Bus Interface
        .intf({bus2Reg_params['reg_map_connection']}),
        
        // Hardware Interface
        .hwif_in(hwif_in),
        .hwif_out(hwif_out)
    );
 
    //--------------------------------------------------------------------------
    // Assertions and Coverage (optional)
    //--------------------------------------------------------------------------
`ifdef ASSERT_ON
    // Add assertions here for verification
    initial begin
        assert (DATA_WIDTH >= 8) else $error("DATA_WIDTH must be >= 8");
        assert (ADDR_WIDTH >= 3) else $error("ADDR_WIDTH must be >= 3");
        assert (CSR_ADDR_WIDTH >= 3) else $error("CSR_ADDR_WIDTH must be >= 3");
    end
`endif
 
endmodule
 
//------------------------------------------------------------------------------
// End of {self.bus_type}_csr_top
//------------------------------------------------------------------------------'''
        
        return rtl_content
    
    def write_rtl_file(self):
        """Escreve o arquivo RTL gerado"""
        rtl_content = self.generate_rtl_content()
        file_name = f"{self.bus_type}_csr_top.sv"
        output_file = self.build_dir / file_name
        
        self.source_files.append(file_name)
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(rtl_content)
        
        print(f"✓ Arquivo RTL gerado: {output_file}")
        return output_file
    
    def write_srclist_file(self):
        """Escreve o arquivo srclist gerado"""
        output_file = self.build_dir / f"{self.bus_type}_at.srclist"
 
        with open(output_file, 'w', encoding='utf-8') as f:
            for file_name in self.source_files:
                f.write("${CONFIG_REGISTER_MANAGER}/build/rtl/"+file_name + '\n')
        
        print(f"✓ Arquivo srclist gerado: {output_file}")
        return output_file
       
    def generate_all(self):
        """Executa todo o processo de geração"""
        print(f"🚀 Iniciando geração de RTL para {self.bus_type.upper()}")
        print(f"   DATA_WIDTH: {self.data_width}")
        print(f"   ADDR_WIDTH: {self.addr_width}")
        print("-" * 50)
        
        try:
            # 1. Criar diretórios
            self.create_directories()
            
            # 2. Copiar arquivos fonte
            self.copy_source_files()
            
            # 3. Gerar arquivo RTL
            rtl_file = self.write_rtl_file()
 
            #4. Gerar srclist
            self.write_srclist_file()
            
            print("-" * 50)
            print("✅ Geração concluída com sucesso!")
            print(f"📁 Arquivos gerados em: {self.build_dir}")
            print(f"📄 Arquivo principal: {rtl_file.name}")
            
        except Exception as e:
            print(f"❌ Erro durante a geração: {str(e)}")
            raise
 
def main():
    parser = argparse.ArgumentParser(
        description='Gerador de RTL para módulo CSR com interface de barramento'
    )
    
    parser.add_argument(
        '--bus',
        choices=['apb4', 'axi4lite'],
        default='apb4',
        help='Tipo de barramento (default: apb4)'
    )
    
    parser.add_argument(
        '--data-width',
        type=int,
        default=32,
        help='Largura dos dados em bits (default: 32)'
    )
    
    parser.add_argument(
        '--addr-width',
        type=int,
        default=8,
        help='Largura do endereço em bits (default: 8)'
    )
    
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Modo verboso'
    )
    
    args = parser.parse_args()
    
    # Validações
    if args.data_width < 8 or args.data_width > 1024:
        print("❌ Erro: DATA_WIDTH deve estar entre 8 e 1024 bits")
        return 1
    
    if args.addr_width < 3 or args.addr_width > 32:
        print("❌ Erro: ADDR_WIDTH deve estar entre 3 e 32 bits")
        return 1
    
    # Criar gerador e executar
    generator = APB4RTLGenerator(
        bus_type=args.bus,
        data_width=args.data_width,
        addr_width=args.addr_width
    )
    
    try:
        generator.generate_all()
        return 0
    except Exception as e:
        if args.verbose:
            import traceback
            traceback.print_exc()
        print(f"❌ Falha na geração: {str(e)}")
        return 1
 
if __name__ == "__main__":
    exit(main())
 