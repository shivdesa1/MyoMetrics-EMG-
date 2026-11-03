#!/usr/bin/env python3
"""Reorganise the MyoMetrics QMS to match the Project Week 1 lab script.

Run at the Git repository root with `python3 restructure_qms.py`.
Non-destructive: creates directories and moves known documents only if the destination
is not already present. Existing GitHub change-evidence links are preserved.
"""
from pathlib import Path
from shutil import move

root = Path.cwd()
if not (root / '.git').exists() or not (root / 'qms').is_dir() or not (root / 'files').is_dir():
    raise SystemExit('ERROR: run this from the MyoMetrics Git repository root (containing .git/, files/, and qms/).')

qms = root / 'qms'
folders = [
    'Quality_documents/Quality_manual',
    'Quality_documents/Procedure',
    'Quality_documents/Forms',
    'Quality_control',
    'Engineering',
    'Operations',
    'Purchasing',
    'Sales_customer_service',
    'Human_resources',
    'Documents_gallery',
]
for rel in folders:
    directory = qms / rel
    directory.mkdir(parents=True, exist_ok=True)
    # Git does not track empty directories. A .gitkeep is not a controlled document.
    (directory / '.gitkeep').touch(exist_ok=True)

# (current location, new location) — names and versions are preserved.
moves = [
    ('qms/QMS_Naming_Procedure_v0.1.docx', 'qms/Quality_documents/Procedure/QMS_Naming_Procedure_v0.1.docx'),
    ('qms/QMS_DD_Traceability_v0.1.xlsx', 'qms/Engineering/QMS_DD_Traceability_v0.1.xlsx'),
    ('files/PM_Advanced_Project_Management_v0.2.docx', 'qms/Operations/PM_Advanced_Project_Management_v0.2.docx'),
    ('files/PM_Gantt_Chart_v0.2.pdf', 'qms/Operations/PM_Gantt_Chart_v0.2.pdf'),
    ('files/PM_Gantt_Colour_Key_v0.2.png', 'qms/Operations/PM_Gantt_Colour_Key_v0.2.png'),
    ('files/PM_Team_Charter_Signed_v1.0.pdf', 'qms/Human_resources/PM_Team_Charter_Signed_v1.0.pdf'),
    ('files/PM_Team_Skills_Matrix_v0.2.xlsx', 'qms/Human_resources/PM_Team_Skills_Matrix_v0.2.xlsx'),
]

print('Created/verified 10 required QMS subfolders.')
for source_rel, dest_rel in moves:
    source, dest = root / source_rel, root / dest_rel
    if source.is_file() and not dest.exists():
        move(str(source), str(dest))
        print(f'MOVED   {source_rel} -> {dest_rel}')
    elif dest.is_file() and not source.exists():
        print(f'OK      {dest_rel} (already organised)')
    elif source.exists() and dest.exists():
        print(f'CONFLICT {source_rel} and {dest_rel} both exist; neither changed')
    else:
        print(f'MISSING {source_rel} (check actual filename/version)')

print('\nPreserved: qms/evidence/ screenshots, files/ unsigned draft, and all other project folders.')
print('NEXT: check git status, update README/links, then commit and push.')
