#!/bin/bash

#Configura caminhos relativos ao diretório do script
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_ROOT="$SCRIPT_DIR/.."

INPUT_XML="$PROJECT_ROOT/build/ipxact/ipMap.xml"
OUTPUT_DIR="$PROJECT_ROOT/build/rtl"

#Cria diretório de saída se não existir
mkdir -p "$OUTPUT_DIR"

#Executa o conversor Python
echo "🔍 Procurando IP-XACT em: $INPUT_XML"
python3 "$PROJECT_ROOT/scripts/ipxact2rtl.py" "$INPUT_XML" "$OUTPUT_DIR"
