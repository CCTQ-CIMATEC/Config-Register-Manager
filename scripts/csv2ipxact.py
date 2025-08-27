#!/usr/bin/env python3
"""
CSV to IP-XACT 2022 Converter
Converts CSR register tables from CSV format to IP-XACT 2022 XML format
"""

import csv
import os
import xml.etree.ElementTree as ET
from xml.dom import minidom
import re
import argparse
from pathlib import Path

class IPXACT2022Generator:
    def __init__(self):
        self.namespaces = {
            'ipxact': 'http://www.accellera.org/XMLSchema/IPXACT/1685-2022',
            'xsi': 'http://www.w3.org/2001/XMLSchema-instance'
        }
        
    def create_root_element(self):
        """Create the root IP-XACT component element"""
        root = ET.Element('ipxact:component')
        root.set('xmlns:ipxact', self.namespaces['ipxact'])
        root.set('xmlns:xsi', self.namespaces['xsi'])
        root.set('xsi:schemaLocation', 
                f"{self.namespaces['ipxact']} "
                "http://www.accellera.org/XMLSchema/IPXACT/1685-2022/index.xsd")
        
        # Add vendor, library, name, version
        vlnv = ET.SubElement(root, 'ipxact:vendor')
        vlnv.text = "vendor.com"
        
        library = ET.SubElement(root, 'ipxact:library')
        library.text = "components"
        
        name = ET.SubElement(root, 'ipxact:name')
        name.text = "CSR_IP_Map"
        
        version = ET.SubElement(root, 'ipxact:version')
        version.text = "1.0"
        
        return root
    
    def parse_bit_range(self, bit_str):
        """Parse bit range string like '[7:0]' or '[4]' and return (msb, lsb)"""
        if not bit_str or bit_str.strip() == '':
            return None, None
            
        # Remove brackets and whitespace
        bit_str = bit_str.strip('[]').strip()
        
        if ':' in bit_str:
            # Range like "7:0"
            parts = bit_str.split(':')
            msb = int(parts[0].strip())
            lsb = int(parts[1].strip())
            return msb, lsb
        else:
            # Single bit like "4"
            bit = int(bit_str.strip())
            return bit, bit
    
    def parse_access_policy(self, access_str):
        """Convert access policy string to IP-XACT 2022 access type"""
        access_map = {
            'RW': 'read-write',
            'RO': 'read-only',
            'WO': 'write-only',
            'R': 'read-only',
            'W': 'write-only',
            'RW1C': 'read-writeOnce',
            'RW1S': 'read-writeOnce'
        }
        return access_map.get(access_str.upper(), 'read-write')
    
    def parse_reset_value(self, reset_str):
        """Parse reset value string and convert to integer"""
        if not reset_str or reset_str.strip() == '':
            return 0
            
        reset_str = reset_str.strip()
        
        # Handle Verilog-style hex values like 'h0, 'hFF
        if reset_str.startswith("'h"):
            return int(reset_str[2:], 16)
        elif reset_str.startswith("0x"):
            return int(reset_str, 16)
        elif reset_str.startswith("'b"):
            return int(reset_str[2:], 2)
        else:
            try:
                return int(reset_str, 0)  # Auto-detect base
            except ValueError:
                return 0
    
    def parse_enum_values(self, enum_str):
        """Parse enumerated values string like '0:100Hz; 1:500Hz'"""
        if not enum_str or enum_str.strip() == '':
            return []
            
        enums = []
        # Split by semicolon or comma
        parts = re.split(r'[;,]', enum_str)
        
        for part in parts:
            part = part.strip()
            if ':' in part:
                value, name = part.split(':', 1)
                enums.append({
                    'value': value.strip(),
                    'name': name.strip()
                })
        
        return enums
    
    def create_register_element(self, reg_name, reg_offset, fields_data, bus_size):
        """Create a register element with its fields"""
        register = ET.Element('ipxact:register')
        
        # Register name
        name = ET.SubElement(register, 'ipxact:name')
        name.text = reg_name
        
        # Register address offset
        address_offset = ET.SubElement(register, 'ipxact:addressOffset')
        address_offset.text = reg_offset
        
        # Register size (calculate from fields or default to 32)
        max_bit = 0
        for field_data in fields_data:
            msb, lsb = self.parse_bit_range(field_data.get('bits', ''))
            if msb is not None:
                max_bit = max(max_bit, msb)
        
        size = ET.SubElement(register, 'ipxact:size')
        size.text = bus_size  # Default to 32-bit minimum
        
        # Add fields
        for field_data in fields_data:
            field_elem = self.create_field_element(field_data)
            if field_elem is not None:
                register.append(field_elem)
        
        return register
    
    def create_field_element(self, field_data):
        """Create a field element from field data using IP-XACT 2022 format"""
        field_name = field_data.get('field', '').strip()
        if not field_name:
            return None
            
        field = ET.Element('ipxact:field')
        
        # Field name
        name = ET.SubElement(field, 'ipxact:name')
        name.text = field_name
        
        # Bit range - using bitOffset and bitWidth for IP-XACT 2022
        msb, lsb = self.parse_bit_range(field_data.get('bits', ''))
        if msb is not None and lsb is not None:
            # Calculate bitOffset (LSB) and bitWidth
            bit_offset = min(msb, lsb)
            bit_width = abs(msb - lsb) + 1
            
            bit_offset_elem = ET.SubElement(field, 'ipxact:bitOffset')
            bit_offset_elem.text = str(bit_offset)
            
            bit_width_elem = ET.SubElement(field, 'ipxact:bitWidth')
            bit_width_elem.text = str(bit_width)
        
        # Access policy
        access_policy = field_data.get('access_policy', 'RW')
        access = ET.SubElement(field, 'ipxact:access')
        access.text = self.parse_access_policy(access_policy)
        
        # Reset value
        reset_value = self.parse_reset_value(field_data.get('reset', '0'))
        if reset_value != 0:
            resets = ET.SubElement(field, 'ipxact:resets')
            reset_elem = ET.SubElement(resets, 'ipxact:reset')
            reset_type = ET.SubElement(reset_elem, 'ipxact:resetTypeRef')
            reset_type.text = "HARD"
            reset_val = ET.SubElement(reset_elem, 'ipxact:value')
            reset_val.text = f"0x{reset_value:X}"
        
        # Description
        description = field_data.get('description', '').strip()
        if description:
            desc = ET.SubElement(field, 'ipxact:description')
            desc.text = description
        
        # Enumerated values
        enum_values = self.parse_enum_values(field_data.get('enum_values', ''))
        if enum_values:
            enums = ET.SubElement(field, 'ipxact:enumeratedValues')
            for enum_data in enum_values:
                enum_val = ET.SubElement(enums, 'ipxact:enumeratedValue')
                enum_name = ET.SubElement(enum_val, 'ipxact:name')
                enum_name.text = enum_data['name']
                enum_value = ET.SubElement(enum_val, 'ipxact:value')
                enum_value.text = enum_data['value']
        
        # Volatile
        volatile = field_data.get('volatile', 'false').lower()
        if volatile in ['true', '1', 'yes']:
            vol = ET.SubElement(field, 'ipxact:volatile')
            vol.text = "true"
        
        return field
    
    def create_address_block(self, csv_name, registers, base_address, bus_size="32"):
        """Create an address block for a specific CSV table"""
        address_block = ET.Element('ipxact:addressBlock')
        
        # Address block name
        block_name = ET.SubElement(address_block, 'ipxact:name')
        block_name.text = csv_name.replace("RegisterMap_", "", 1)
        
        # Base address
        base_addr = ET.SubElement(address_block, 'ipxact:baseAddress')
        base_addr.text = base_address
        
        # Range
        max_offset = 0x1000
        for reg in registers:
            offset_str = reg.find('ipxact:addressOffset').text
            offset = int(offset_str, 0)
            size = int(reg.find('ipxact:size').text)
            max_offset = max(max_offset, offset + (size // 8))
        
        range_elem = ET.SubElement(address_block, 'ipxact:range')
        range_elem.text = f"0x{max_offset:X}"
        
        # Width
        width = ET.SubElement(address_block, 'ipxact:width')
        width.text = bus_size
        
        # Add registers to address block
        for register in registers:
            address_block.append(register)
        
        return address_block

def read_csv_data(csv_file):
    """Read CSV data and return structured data"""
    registers_data = {}
    
    with open(csv_file, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        
        # Handle case-insensitive headers
        fieldnames = [name.lower().strip() for name in reader.fieldnames]

        for row in reader:
            # Convert keys to lowercase for consistency
            row_data = {k.lower().strip(): v.strip() for k, v in row.items()}
            
            register = row_data.get('register', '').strip().lower()

            if not register:
                continue
                
            if register not in registers_data:
                registers_data[register] = {
                    'offset': row_data.get('offset', '0x0000'),
                    'fields': []
                }
            
            # Add field data
            field_data = {
                'field': row_data.get('field', '').lower(),
                'bits': row_data.get('bits', ''),
                'access_policy': row_data.get('access_policy', row_data.get('access policy', 'RW')),
                'volatile': row_data.get('volatile', 'false'),
                'reset': row_data.get('reset', '0'),
                'description': row_data.get('description', ''),
                'enum_values': row_data.get('enum values', row_data.get('enum_values', ''))
            }
            
            registers_data[register]['fields'].append(field_data)
    
    return registers_data

def convert_all_csv_to_ipxact(bus_size="32"):
    """Convert all CSV files to a single IP-XACT XML file"""
    

    #resolver isso!!!!!
    input_path = Path("build/csv")
    output_path = Path("build/ipxact")
    csv_files = list(input_path.glob('RegisterMap_*.csv'))

    #pura gambiarra
    base_addresses = {}
    with open ("build/csv/table_main.csv", mode="r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            row["IP"] = re.sub("IP ", "IP-", row["IP"])
            row["Base Address"] = re.sub(" ", "", row["Base Address"])
            base_addresses[row["IP"]] = row["Base Address"]
            
    if not csv_files:
        print(f"No IPs specific CSV files found in directory: {input_path}")
        return False
    
    print(f"Found {len(csv_files)} CSV files")
    
    # Create IP-XACT generator
    generator = IPXACT2022Generator()
    
    # Create root element
    root = generator.create_root_element()
    
    # Create memory maps container
    memory_maps = ET.SubElement(root, 'ipxact:memoryMaps')
    memory_map = ET.SubElement(memory_maps, 'ipxact:memoryMap')
    
    # Memory map name
    map_name = ET.SubElement(memory_map, 'ipxact:name')
    map_name.text = "CSR_MemoryMap"
    
    # Process each CSV file
    for csv_file in csv_files:
        print(f"Processing {csv_file.name}...")
        
        try:
            # Read CSV data
            registers_data = read_csv_data(csv_file)
            print(f"  Found {len(registers_data)} registers")
            
            if not registers_data:
                print(f"  No register data found in {csv_file.name}")
                continue
            
            # Create registers for this CSV
            registers = []
            for reg_name, reg_data in registers_data.items():
                register = generator.create_register_element(
                    reg_name, 
                    reg_data['offset'], 
                    reg_data['fields'],
                    bus_size
                )
                registers.append(register)
                print(f"    Created register: {reg_name} at {reg_data['offset']}")
            
            # Creation of address block
            csv_name = csv_file.stem  # remove extension
            ip_name = re.sub(r'RegisterMap_', '', csv_name)
            address_block = generator.create_address_block(csv_name, registers, base_addresses.get(ip_name), bus_size)
            memory_map.append(address_block)
            
            print(f"  Created address block: {csv_name}")
            
        except Exception as e:
            print(f"Error processing {csv_file.name}: {e}")
            continue
    
    # Write the combined XML file
    output_file = output_path / "ipMap.xml"
    try:
        # Pretty print the XML
        xml_str = ET.tostring(root, encoding='unicode')
        parsed = minidom.parseString(xml_str)
        pretty_xml = parsed.toprettyxml(indent="  ")
        
        # Remove extra empty lines
        lines = [line for line in pretty_xml.split('\n') if line.strip()]
        pretty_xml = '\n'.join(lines)
        
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(pretty_xml)
        
        print(f"\nSuccessfully created combined IP-XACT file: {output_file}")
        return True
        
    except Exception as e:
        print(f"Error writing XML file: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description='Convert CSV register tables to IP-XACT 2022 XML format')
    parser.add_argument('-s', '--bus-size', default='32', help='size of bus (default: 32)')

    args = parser.parse_args()

    convert_all_csv_to_ipxact(args.bus_size)

if __name__ == "__main__":
    main()