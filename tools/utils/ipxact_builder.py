import xml.etree.ElementTree as ET
import re

class IPXACT2022Generator:
    def __init__(self) -> None:
        self.namespaces = {
            'ipxact': 'http://www.accellera.org/XMLSchema/IPXACT/1685-2022',
            'xsi': 'http://www.w3.org/2001/XMLSchema-instance'
        }
        
    def create_root_element(self) -> ET.Element:
        """
        Create the root IP-XACT component element:
        
        This initializes the `<ipxact:component>` root element with the
        required XML namespaces and schema location. It also populates
        the vendor, library, name, and version child elements with
        default values.

        Returns:
            ET.Element: The root IP-XACT component element.
        """

        root = ET.Element('ipxact:component')
        root.set('xmlns:ipxact', self.namespaces['ipxact'])
        root.set('xmlns:xsi', self.namespaces['xsi'])
        root.set('xsi:schemaLocation', 
                f"{self.namespaces['ipxact']} "
                "http://www.accellera.org/XMLSchema/IPXACT/1685-2022/index.xsd")
        
        vlnv = ET.SubElement(root, 'ipxact:vendor')
        vlnv.text = "vendor.com"
        
        library = ET.SubElement(root, 'ipxact:library')
        library.text = "components"
        
        name = ET.SubElement(root, 'ipxact:name')
        name.text = "CSR_IP_Map"
        
        version = ET.SubElement(root, 'ipxact:version')
        version.text = "1.0"
        
        return root
    
    def parse_bit_range(self, bit_str : str) -> tuple[int, int] | tuple[None, None]:
        """
        Parse a bit range string and return the most and least significant bits.
        Handles strings in the form '[msb:lsb]' for ranges or '[bit]' for single bits.

        Args:
            bit_str (str): The bit range string, e.g., '[7:0]' or '[4]'.

        Returns:
            tuple[int, int] | tuple[None, None]: A tuple (msb, lsb). Returns (None, None)
            if the input is empty or None.
        """
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
    
    def parse_access_policy(self, access_str : str) -> str:
        """
        Convert access policy string to IP-XACT 2022 access type

        Args:
            access_str: Access policy string.

        Returns:
            IP-XACT 2022 access type string.
        """
        access_map = {
            'RW':   'read-write',
            'RO':   'read-only',
            'WO':   'write-only',
            'R':    'read-only',
            'W':    'write-only',
            'RW1C': 'read-writeOnce',
            'RW1S': 'read-writeOnce'
        }

        return access_map.get(access_str.upper(), 'read-write')
    
    def parse_reset_value(self, reset_str : str) -> int:
        """
        Parse reset value string(from an hex, C-style, verilog 
        representations) and convert to integer
        
        Args:
            reset_str: Reset value as a string.

        Returns:
            int: Parsed reset value as an integer (default: 0).
        """
        if not reset_str or reset_str.strip() == '':
            return 0
            
        reset_str = reset_str.strip()
        
        # handle possible style hex
        if reset_str.startswith("'h"):
            return int(reset_str[2:], 16)
        elif reset_str.startswith("'b"):
            return int(reset_str[2:], 2)
        else:
            try:
                return int(reset_str, 0)
            except ValueError:
                return 0
    
    def parse_enum_values(self, enum_str : str) -> list[dict[str, str]]:
        """
        Parse enumerated values string like '0:100Hz; 1:500Hz'

        IMPORTANT -> TO DOC THIS
        Each enumerated entry must use the form "value:name".
        Delimiters can be semicolons (;) or commas (,).
        IMPORTANT -> TO DOC THIS
        
        Args:
            enum_str: A string containing enumerated values.

        Returns:
            List[Dict[str, str]]: A list of dictionaries, each with:
                - "value": The enumeration value as a string.
                - "name":  The label/name as a string.
            Returns an empty list if `enum_str` is empty or invalid.        
        """
        if not enum_str or enum_str.strip() == '':
            return []
            
        enums = []

        # HERE CAUTION
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
    
    def create_register_element(self, 
                                reg_name: str, 
                                reg_offset: str, 
                                fields_data: list, 
                                bus_size = "32"
    ) -> ET.Element:
        """
        Create a register element with its fields

        This builds an <ipxact:register> element populated with:
        - <ipxact:name>: The register name.
        - <ipxact:addressOffset>: The register offset within the block.
        - <ipxact:size>: The register size (bus width).

        For each entry in `fields_data`, a <field> sub-element is created using
        `create_field_element` and appended to the register.

        Args:
            reg_name: Name of the register.
            reg_offset: Address offset as a string.
            fields_data: List of field metadata dictionaries. Each dict must
                contain at least a `"bits"` entry (bit range string).
            bus_size: Register size in bits (usually matches bus width, e.g. "32").

        Returns:
            ET.Element: The constructed <ipxact:register> XML element.
        """
        register = ET.Element('ipxact:register')
        
        name = ET.SubElement(register, 'ipxact:name')
        name.text = reg_name
        
        address_offset = ET.SubElement(register, 'ipxact:addressOffset')
        address_offset.text = reg_offset
        
        max_bit = 0
        for field_data in fields_data:
            msb, lsb = self.parse_bit_range(field_data.get('bits', ''))
            if msb is not None:
                max_bit = max(max_bit, msb)
        
        size = ET.SubElement(register, 'ipxact:size')
        size.text = bus_size
        
        for field_data in fields_data:
            field_elem = self.create_field_element(field_data)
            if field_elem is not None:
                register.append(field_elem)
        
        return register
    
    def create_field_element(self, field_data: dict[str, any]) -> ET.Element | None:
        """
        Create a field element from field data using IP-XACT 2022 format

        The function will generate the following child elements when appropriate:
        - `<ipxact:name>`       : required, taken from field_data['field']
        - `<ipxact:bitOffset>`  : LSB (calculated from bit range)
        - `<ipxact:bitWidth>`   : width in bits (calculated from bit range)
        - `<ipxact:access>`     : mapped via `self.parse_access_policy(...)`
        - `<ipxact:resets>`     : contains `<ipxact:reset>` with `<ipxact:value>` as hex if reset != 0
        - `<ipxact:description>`
        - `<ipxact:enumeratedValues>` / `<ipxact:enumeratedValue>` entries
        - `<ipxact:volatile>`   : present only when truthy

        Args:
            field_data: dict with keys commonly:
                - 'field'         (str)    : field name (required)
                - 'bits'          (str)    : bit range (e.g. "[7:0]", "3", "7:4")
                - 'access_policy' (str)    : e.g. "RW", "RO"
                - 'reset'         (str)    : reset value (any supported by parse_reset_value)
                - 'description'   (str)
                - 'enum_values'   (str)    : "0:Off; 1:On" style
                - 'volatile'      (str|bool|int)
        Returns:
            ET.Element or None: `<ipxact:field>` element or None if required data missing.
        """
        field_name = field_data.get('field', '').strip()
        if not field_name:
            return None
            
        field = ET.Element('ipxact:field')
        
        name = ET.SubElement(field, 'ipxact:name')
        name.text = field_name
        
        msb, lsb = self.parse_bit_range(field_data.get('bits', ''))
        if msb is not None and lsb is not None:
            # Calculate bitOffset (LSB) and bitWidth
            bit_offset = min(msb, lsb)
            bit_width = abs(msb - lsb) + 1
            
            bit_offset_elem = ET.SubElement(field, 'ipxact:bitOffset')
            bit_offset_elem.text = str(bit_offset)
            
            bit_width_elem = ET.SubElement(field, 'ipxact:bitWidth')
            bit_width_elem.text = str(bit_width)
        
        access_policy = field_data.get('access_policy', 'RW')
        access = ET.SubElement(field, 'ipxact:access')
        access.text = self.parse_access_policy(access_policy)
        
        reset_value = self.parse_reset_value(field_data.get('reset', '0'))
        if reset_value != 0:
            resets          = ET.SubElement(field, 'ipxact:resets')
            reset_elem      = ET.SubElement(resets, 'ipxact:reset')
            reset_type      = ET.SubElement(reset_elem, 'ipxact:resetTypeRef')
            reset_type.text = "HARD"
            reset_val       = ET.SubElement(reset_elem, 'ipxact:value')
            reset_val.text  = f"0x{reset_value:X}"
        
        description = field_data.get('description', '').strip()
        if description:
            desc = ET.SubElement(field, 'ipxact:description')
            desc.text = description
        
        enum_values = self.parse_enum_values(field_data.get('enum_values', ''))
        if enum_values:
            enums = ET.SubElement(field, 'ipxact:enumeratedValues')
            for enum_data in enum_values:
                enum_val = ET.SubElement(enums, 'ipxact:enumeratedValue')
                enum_name = ET.SubElement(enum_val, 'ipxact:name')
                enum_name.text = enum_data['name']
                enum_value = ET.SubElement(enum_val, 'ipxact:value')
                enum_value.text = enum_data['value']
        
        volatile = field_data.get('volatile', 'false').lower()
        if volatile in ['true', '1', 'yes']:
            vol = ET.SubElement(field, 'ipxact:volatile')
            vol.text = "true"
        
        return field
    
    def create_address_block(self, 
                             csv_name:      str, 
                             registers:     list[ET.Element], 
                             base_address:  str, 
                             bus_size :     str = "32") -> ET.Element:
        """
        Create an address block for a specific CSV table
        
        Args:
            csv_name: Block name (removes "RegisterMap_" prefix if present)
            registers: List of register elements with offset/size info
            base_address: Starting address (hex or decimal string)
            bus_size: Bus width in bits (default: "32")
        
        Returns:
            ET.Element: Complete `<ipxact:addressBlock>` element
        """
        address_block = ET.Element('ipxact:addressBlock')
        
        block_name = ET.SubElement(address_block, 'ipxact:name')
        block_name.text = csv_name.replace("RegisterMap_", "", 1)
        
        base_addr = ET.SubElement(address_block, 'ipxact:baseAddress')
        base_addr.text = base_address
        
        max_offset = 0x1000
        for reg in registers:
            offset_str = reg.find('ipxact:addressOffset').text
            offset = int(offset_str, 0)
            size = int(reg.find('ipxact:size').text)
            max_offset = max(max_offset, offset + (size // 8))
        
        range_elem = ET.SubElement(address_block, 'ipxact:range')
        range_elem.text = f"0x{max_offset:X}"
        
        width = ET.SubElement(address_block, 'ipxact:width')
        width.text = bus_size
        
        for register in registers:
            address_block.append(register)
        
        return address_block