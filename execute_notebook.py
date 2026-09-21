"""Execute and save all notebook outputs. Run after build_notebook.py."""
from pathlib import Path
import nbformat
from nbclient import NotebookClient

root=Path(__file__).resolve().parent
path=root/'DPS_QKD_model.ipynb'
book=nbformat.read(path,as_version=4)
client=NotebookClient(book,timeout=240,kernel_name='python3',resources={'metadata':{'path':str(root)}})
client.execute()
nbformat.write(book,path)
executed=sum(c.cell_type=='code' and c.get('execution_count') is not None for c in book.cells)
errors=[o for c in book.cells for o in c.get('outputs',[]) if o.output_type=='error']
assert not errors
print(f'Executed and saved {executed} code cells; no cell errors.')
