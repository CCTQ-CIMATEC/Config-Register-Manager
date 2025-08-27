import xml.etree.ElementTree as ET
import os
import sys
from datetime import datetime
from pathlib import Path

# Namespace IP-XACT
NS = {'ipxact': 'http://www.accellera.org/XMLSchema/IPXACT/1685-2022'}

def get_absolute_path(relative_path):
    """Converte caminhos relativos em absolutos baseado na localização do script."""
    script_dir = Path(__file__).parent
    return (script_dir / relative_path).resolve()

def parse_enumerated_values(field):
    """Extrai valores enumerados de um campo."""
    enum_values = {}
    for enum in field.findall('ipxact:enumeratedValues/ipxact:enumeratedValue', NS):
        name_elem = enum.find('ipxact:name', NS)
        value_elem = enum.find('ipxact:value', NS)
        if name_elem is not None and value_elem is not None:
            enum_values[value_elem.text] = name_elem.text
    return enum_values if enum_values else None

def parse_ipxact(input_xml):
    """Extrai dados do IP-XACT para geração de CSR."""
    try:
        input_path = get_absolute_path(input_xml)
        tree = ET.parse(input_path)
        root = tree.getroot()
        
        component = root
        name = component.find('ipxact:name', NS).text
        
        registers = {}
        enum_definitions = {}  # Nome do enum -> valores
        enum_cache = {}        # Assinatura -> enum_name

        for addr_block in component.findall('.//ipxact:addressBlock', NS):
            for reg in addr_block.findall('ipxact:register', NS):
                reg_name = reg.find('ipxact:name', NS).text
                offset = reg.find('ipxact:addressOffset', NS).text
                size = int(reg.find('ipxact:size', NS).text) if reg.find('ipxact:size', NS) is not None else 32
                
                fields = {}
                for field in reg.findall('ipxact:field', NS):
                    field_name = field.find('ipxact:name', NS).text
                    bit_offset = int(field.find('ipxact:bitOffset', NS).text)
                    bit_width = int(field.find('ipxact:bitWidth', NS).text)
                    access = field.find('ipxact:access', NS).text if field.find('ipxact:access', NS) is not None else 'read-write'
                    volatile = field.find('ipxact:volatile', NS) is not None and field.find('ipxact:volatile', NS).text.lower() == 'true'
                    
                    # Valor de reset
                    reset_value = "'h0"
                    resets = field.find('ipxact:resets', NS)
                    if resets is not None:
                        reset = resets.find('ipxact:reset', NS)
                        if reset is not None:
                            reset_value_elem = reset.find('ipxact:value', NS)
                            if reset_value_elem is not None:
                                reset_value = reset_value_elem.text
                    else:
                        reset_value_elem = field.find('.//ipxact:value', NS)
                        if reset_value_elem is not None:
                            reset_value = reset_value_elem.text
                    
                    description = field.find('ipxact:description', NS).text if field.find('ipxact:description', NS) is not None else ""
                    
                    # Processa valores enumerados
                    enum_values = parse_enumerated_values(field)
                    enum_name = None
                    if enum_values:
                        # Cria assinatura única do enum
                        signature = tuple(sorted(enum_values.items()))
                        if signature in enum_cache:
                            enum_name = enum_cache[signature]  # reutiliza enum existente
                        else:
                            enum_name = f"{reg_name}_{field_name}_e"
                            enum_definitions[enum_name] = enum_values
                            enum_cache[signature] = enum_name
                    
                    fields[field_name] = {
                        'bit_offset': bit_offset,
                        'bit_width': bit_width,
                        'access': access,
                        'volatile': volatile,
                        'reset_value': reset_value,
                        'description': description,
                        'enum': enum_name
                    }
                
                registers[reg_name] = {
                    'offset': offset,
                    'size': size,
                    'fields': fields
                }
        
        return {
            'name': name,
            'registers': registers,
            'enums': enum_definitions
        }
    
    except Exception as e:
        print(f"Erro inesperado: {type(e).__name__}: {str(e)}", file=sys.stderr)
        return None

def needs_hw_input(field_info):
    """Verifica se o campo precisa de entrada de hardware"""
    return (field_info['volatile'] or 
            field_info['access'] == 'read-only' or
            'master mode will be cleared' in field_info.get('description', '').lower())

def format_reset_value(reset_value, bit_width):
    """Formata o valor de reset com a largura correta"""
    if reset_value.startswith("'h"):
        return f"{bit_width}'h{reset_value[2:]}"
    elif reset_value.startswith("0x"):
        return f"{bit_width}'h{reset_value[2:]}"
    elif reset_value.startswith("'b"):
        return f"{bit_width}'b{reset_value[2:]}"
    elif reset_value.startswith("'d"):
        return f"{bit_width}'d{reset_value[2:]}"
    return f"{bit_width}'h0"

def generate_package(ipxact_data, output_dir):
    """Gera o arquivo package SystemVerilog."""
    try:
        output_path = get_absolute_path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        output_file = output_path / f"{ipxact_data['name']}_pkg.sv"
        
        component_name = ipxact_data['name']
        registers = ipxact_data['registers']
        enums = ipxact_data.get('enums', {})
        
        with open(output_file, 'w', encoding='utf-8') as f:
            # Cabeçalho
            f.write(f"// Package {component_name}_pkg - Gerado automaticamente em {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write("// Estruturas typedef para interface CSR\n\n")
            f.write(f"package {component_name}_pkg;\n\n")
            
            # Gera definições de enum primeiro
            if enums:
                f.write("    // Enum definitions\n")
                for enum_name, enum_values in enums.items():
                    # Calcula o número de bits necessário para representar o enum
                    enum_size = max(len(bin(len(enum_values))) - 3, 1)
                    f.write(f"    typedef enum logic [{enum_size}:0] {{\n")
                    for value, name in enum_values.items():
                        # Remove caracteres inválidos para nomes SystemVerilog
                        clean_name = name.replace('\\', '').replace(' ', '_')
                        f.write(f"        {clean_name} = {value},\n")
                    first_key = list(enum_values.keys())[0]
                    f.write(f"        {enum_name.upper()}_DEFAULT = {first_key},\n")
                    f.write(f"    }} {enum_name};\n\n")
            
            # Gera typedef structs para entrada (hardware -> registrador)
            f.write("    // Input structures (Hardware -> Register)\n")
            
            # Structs para campos individuais que precisam de entrada HW
            for reg_name, reg_info in registers.items():
                for field_name, field_info in reg_info['fields'].items():
                    if needs_hw_input(field_info):
                        f.write(f"    typedef struct {{\n")
                        
                        if field_info['enum']:
                            f.write(f"        {field_info['enum']} next;\n")
                        elif field_info['bit_width'] > 1:
                            f.write(f"        logic [{field_info['bit_width']-1}:0] next;\n")
                        else:
                            f.write(f"        logic next;\n")
                            
                        f.write(f"        logic we;\n")
                        f.write(f"    }} {component_name}__{reg_name}__{field_name}__in_t;\n\n")
            
            # Structs para registradores com entrada HW
            for reg_name, reg_info in registers.items():
                hw_input_fields = [f for f, info in reg_info['fields'].items() if needs_hw_input(info)]
                if hw_input_fields:
                    f.write(f"    typedef struct {{\n")
                    for field_name in hw_input_fields:
                        f.write(f"        {component_name}__{reg_name}__{field_name}__in_t {field_name};\n")
                    f.write(f"    }} {component_name}__{reg_name}__in_t;\n\n")
            
            # Struct principal de entrada
            hw_input_regs = [r for r, info in registers.items() 
                            if any(needs_hw_input(f_info) for f_info in info['fields'].values())]
            if hw_input_regs:
                f.write(f"    typedef struct {{\n")
                for reg_name in hw_input_regs:
                    f.write(f"        {component_name}__{reg_name}__in_t {reg_name};\n")
                f.write(f"    }} {component_name}__in_t;\n\n")
            
            # Gera typedef structs para saída (registrador -> hardware)
            f.write("    // Output structures (Register -> Hardware)\n")
            
            # Structs para campos individuais
            for reg_name, reg_info in registers.items():
                for field_name, field_info in reg_info['fields'].items():
                    if field_info['access'] != 'write-only':
                        f.write(f"    typedef struct {{\n")
                        if field_info['enum']:
                            f.write(f"        {field_info['enum']} value;\n")
                        elif field_info['bit_width'] > 1:
                            f.write(f"        logic [{field_info['bit_width']-1}:0] value;\n")
                        else:
                            f.write(f"        logic value;\n")
                        f.write(f"    }} {component_name}__{reg_name}__{field_name}__out_t;\n\n")
            
            # Structs para registradores
            for reg_name, reg_info in registers.items():
                output_fields = [f for f, info in reg_info['fields'].items() if info['access'] != 'write-only']
                if output_fields:
                    f.write(f"    typedef struct {{\n")
                    for field_name in output_fields:
                        f.write(f"        {component_name}__{reg_name}__{field_name}__out_t {field_name};\n")
                    f.write(f"    }} {component_name}__{reg_name}__out_t;\n\n")
            
            # Struct principal de saída
            f.write(f"    typedef struct {{\n")
            for reg_name in registers.keys():
                f.write(f"        {component_name}__{reg_name}__out_t {reg_name};\n")
            f.write(f"    }} {component_name}__out_t;\n\n")
            
            f.write("endpackage\n")
        
        print(f"Package gerado: {output_file}")
        return True
    
    except Exception as e:
        print(f"Falha ao gerar package: {str(e)}", file=sys.stderr)
        return False

def generate_logic(ipxact_data, output_dir):
    """Gera o arquivo de lógica SystemVerilog."""
    try:
        output_path = get_absolute_path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        output_file = output_path / f"{ipxact_data['name']}_logic.sv"
        
        component_name = ipxact_data['name']
        registers = ipxact_data['registers']
        enums = ipxact_data.get('enums', {})
        
        with open(output_file, 'w', encoding='utf-8') as f:
            # Cabeçalho
            f.write(f"// Lógica {component_name} - Gerado automaticamente em {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write("// Lógica dos registradores CSR\n\n")
            
            # Estruturas de combinacional e storage
            f.write("    //--------------------------------------------------------------------------\n")
            f.write("    // Field logic\n")
            f.write("    //--------------------------------------------------------------------------\n")
            
            # field_combo_t
            f.write("    typedef struct {\n")
            for reg_name, reg_info in registers.items():
                f.write(f"        struct {{\n")
                for field_name, field_info in reg_info['fields'].items():
                    if field_info['access'] != 'read-only' or field_info['volatile']:
                        f.write(f"            struct {{\n")
                        if field_info['enum']:
                            f.write(f"                {field_info['enum']} next;\n")
                        elif field_info['bit_width'] > 1:
                            f.write(f"                logic [{field_info['bit_width']-1}:0] next;\n")
                        else:
                            f.write(f"                logic next;\n")
                        f.write(f"                logic load_next;\n")
                        f.write(f"            }} {field_name};\n")
                f.write(f"        }} {reg_name};\n")
            f.write("    } field_combo_t;\n")
            f.write("    field_combo_t field_combo;\n\n")
            
            # field_storage_t
            f.write("    typedef struct {\n")
            for reg_name, reg_info in registers.items():
                f.write(f"        struct {{\n")
                for field_name, field_info in reg_info['fields'].items():
                    if field_info['access'] != 'read-only' or field_info['volatile']:
                        f.write(f"            struct {{\n")
                        if field_info['enum']:
                            f.write(f"                {field_info['enum']} value;\n")
                        elif field_info['bit_width'] > 1:
                            f.write(f"                logic [{field_info['bit_width']-1}:0] value;\n")
                        else:
                            f.write(f"                logic value;\n")
                        f.write(f"            }} {field_name};\n")
                f.write(f"        }} {reg_name};\n")
            f.write("    } field_storage_t;\n")
            f.write("    field_storage_t field_storage;\n\n")
            
            # Lógica para cada campo
            for reg_name, reg_info in registers.items():
                for field_name, field_info in reg_info['fields'].items():
                    if field_info['access'] == 'read-only' and not field_info['volatile']:
                        continue
                        
                    f.write(f"    // Field: {component_name}.{reg_name}.{field_name}\n")
                    
                    # Lógica combinacional
                    bit_range = f"[{field_info['bit_width']-1}:0]" if field_info['bit_width'] > 1 and not field_info['enum'] else ""
                    bit_select = f"[{field_info['bit_offset']+field_info['bit_width']-1}:{field_info['bit_offset']}]" if field_info['bit_width'] > 1 else f"[{field_info['bit_offset']}]"
                    
                    f.write("    always_comb begin\n")
                    if field_info['enum']:
                        f.write(f"        {field_info['enum']} next_c;\n")
                    else:
                        f.write(f"        logic {bit_range} next_c;\n")
                    f.write(f"        logic load_next_c;\n")
                    f.write(f"        next_c = field_storage.{reg_name}.{field_name}.value;\n")
                    f.write(f"        load_next_c = '0;\n")
                    
                    # Software write
                    if field_info['access'] in ['read-write', 'write-only']:
                        f.write(f"        if(decoded_reg_strb.{reg_name} && decoded_req_is_wr) begin // SW write\n")
                        if field_info['enum']:
                            f.write(f"            next_c = {field_info['enum']}'(decoded_wr_data{bit_select});\n")
                        elif field_info['bit_width'] > 1:
                            f.write(f"            next_c = (field_storage.{reg_name}.{field_name}.value & ~decoded_wr_biten{bit_select}) | (decoded_wr_data{bit_select} & decoded_wr_biten{bit_select});\n")
                        else:
                            f.write(f"            next_c = decoded_wr_data{bit_select};\n")
                        f.write(f"            load_next_c = '1;\n")
                        f.write("        end")
                        
                    # Hardware write
                    if needs_hw_input(field_info):
                        if field_info['access'] in ['read-write', 'write-only']:
                            f.write(" else ")
                        else:
                            f.write("        ")
                        f.write(f"if(hwif_in.{reg_name}.{field_name}.we) begin // HW Write - we\n")
                        f.write(f"            next_c = hwif_in.{reg_name}.{field_name}.next;\n")
                        f.write(f"            load_next_c = '1;\n")
                        f.write("        end\n")
                    elif field_info['access'] in ['read-write', 'write-only']:
                        f.write("\n")
                        
                    f.write(f"        field_combo.{reg_name}.{field_name}.next = next_c;\n")
                    f.write(f"        field_combo.{reg_name}.{field_name}.load_next = load_next_c;\n")
                    f.write("    end\n")
                    
                    # Lógica sequencial
                    f.write("    always_ff @(posedge clk) begin\n")
                    if field_info['access'] != 'write-only':
                        f.write("        if(rst) begin\n")
                        if field_info['enum']:
                            f.write(f"            field_storage.{reg_name}.{field_name}.value <= {field_info['enum']}'({format_reset_value(field_info['reset_value'], field_info['bit_width'])});\n")
                        else:
                            f.write(f"            field_storage.{reg_name}.{field_name}.value <= {format_reset_value(field_info['reset_value'], field_info['bit_width'])};\n")
                        f.write("        end else begin\n")
                        f.write(f"            if(field_combo.{reg_name}.{field_name}.load_next) begin\n")
                        f.write(f"                field_storage.{reg_name}.{field_name}.value <= field_combo.{reg_name}.{field_name}.next;\n")
                        f.write("            end\n")
                        f.write("        end\n")
                    else:
                        f.write(f"        if(field_combo.{reg_name}.{field_name}.load_next) begin\n")
                        f.write(f"            field_storage.{reg_name}.{field_name}.value <= field_combo.{reg_name}.{field_name}.next;\n")
                        f.write("        end\n")
                    f.write("    end\n")
                    
                    # Assignment de saída
                    if field_info['access'] != 'write-only':
                        f.write(f"    assign hwif_out.{reg_name}.{field_name}.value = field_storage.{reg_name}.{field_name}.value;\n")
                    
                    f.write("\n")
        
        print(f"Lógica gerada: {output_file}")
        return True
    
    except Exception as e:
        print(f"Falha ao gerar lógica: {str(e)}", file=sys.stderr)
        return False

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Uso: python3 ipxact_csr_gen.py <input.xml> <output_dir>")
        sys.exit(1)
        
    INPUT_XML = sys.argv[1]
    OUTPUT_DIR = sys.argv[2]
    
    print(f"⚡ Convertendo: {INPUT_XML}")
    ip_data = parse_ipxact(INPUT_XML)

    if ip_data:
        pkg_success = generate_package(ip_data, OUTPUT_DIR)
        logic_success = generate_logic(ip_data, OUTPUT_DIR)
        
        if pkg_success and logic_success:
            print(f"✅ Conversão concluída! Verifique {OUTPUT_DIR}")
            sys.exit(0)
    
    print("❌ Falha na conversão")
    sys.exit(1)