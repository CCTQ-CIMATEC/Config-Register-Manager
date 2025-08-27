import re
import os
from pathlib import Path

def extract_table_with_label(latex_content: str, target_label: str) -> str | None:
    """
    Extract the content of a LaTeX table by its label.

    Args:
        latex_content (str): Full LaTeX document content as a string.
        target_label  (str): The label identifier of the target table 
                            (e.g., 'tab:results').

    Returns:
        str | None: The inner tabular environment of the matched table as a string, 
                    or None if no table with the given label is found.
    """    
    
    pattern = (
        r'\\begin{table}.*?'          
        r'\\label{' + re.escape(target_label) + r'}.*?'  
        r'\\begin{tabular}\{[^}]*\}' 
        r'(.*?)'                     
        r'\\end{tabular}.*?'         
        r'\\end{table}'              
    )

    match = re.search(pattern, latex_content, re.DOTALL)

    if match:
        return match.group(1)
    return None

def extract_references_from_table(table_content: str) -> list[str]:
    """
    Extract reference identifiers from LaTeX table content.

    Args:
        table_content (str): The LaTeX content of a table (typically the tabular body).

    Returns:
        list[str]: A de-duplicated list of references found within the table. 
    """
    
    references = []
    
    ref_matches = re.findall(r'\\ref{([^}]+)}', table_content)
    references.extend(ref_matches)
    
    text_refs = re.findall(r'tabela[_\s]*([A-Za-z0-9_-]+)', table_content, re.IGNORECASE)
    references.extend([f"table:{ref}" for ref in text_refs])
    
    other_refs = re.findall(r'table[_\s]*([A-Za-z0-9_-]+)', table_content, re.IGNORECASE)
    references.extend([f"table:{ref}" for ref in other_refs])
    
    return list(set(references))

def clean_table_content(table_content : str) -> list[str]:
    """
    Clean and normalize LaTeX table content into a CSV row format.

    Args:
        table_content (str): Raw LaTeX tabular environment content.

    Returns:
        list[str]: A list of cleaned table rows as strings, ready for CSV export.
                   Each string corresponds to a single row (split on '\\\\').
    """
    table_content = table_content.strip()
    
    # Remove LaTeX macros
    table_content = re.sub(r'\\(?:hline|toprule|midrule|bottomrule|cline\{[^}]*\})', '', table_content)
    
    # Handle multirow and multicolumn commands
    table_content = re.sub(r'\\multirow\{[^}]*\}\{[^}]*\}\{([^}]*)\}', r'\1', table_content)
    table_content = re.sub(r'\\multicolumn\{[^}]*\}\{[^}]*\}\{([^}]*)\}', r'\1', table_content)
    table_content = re.sub(r'\\(?:textbf|textit|emph)\{([^}]*)\}', r'\1', table_content)
    table_content = re.sub(r'\\fontsize\{[^}]*\}\{[^}]*\}\\selectfont', '', table_content)
    
    # Split into rows by \\
    rows = re.split(r'\\\\', table_content)

    return rows

def get_main_table_label(latex_content: str, main_table_label: str) -> str:
    """
    Extract the label of the main table from LaTeX content.

    Args:
        latex_content (str): Full LaTeX document content as a string.
        main_table_label (str): The label identifier of the main table to extract.

    Returns:
        str: The label of the main table, or an empty string if not found.
    """
    
    main_table_content = extract_table_with_label(latex_content, main_table_label)
    
    if not main_table_content:
        print(f"Error: Could not find table with label '{main_table_label}'")
        return False
    
    print(f"Found main table: {main_table_label}")
    
    return main_table_content