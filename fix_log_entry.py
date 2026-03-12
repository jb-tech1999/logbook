#!/usr/bin/env python3
import sys

# Read the file
with open('/Users/jandrebadenhorst/Projects/logbook/logbook/Views/LogEntryFormView.swift', 'r') as f:
    lines = f.readlines()

# Find and fix the saveLog function
output = []
in_save_function = False
found_defer = False
found_catch = False

for i, line in enumerate(lines):
    # Skip the defer line
    if 'defer { isSaving = false }' in line:
        found_defer = True
        continue
    
    # Add logging and isSaving = false in catch block
    if found_catch and 'errorMessage = "Unable to save log' in line:
        output.append('            logEntryFormLogger.error("Failed to save log entry: \\(error.localizedDescription)")\n')
        output.append('            errorMessage = "Unable to save log: \\(error.localizedDescription)"\n')
        output.append('            isSaving = false\n')
        continue
    
    if '} catch {' in line:
        found_catch = True
    
    output.append(line)

# Write the fixed file
with open('/Users/jandrebadenhorst/Projects/logbook/logbook/Views/LogEntryFormView.swift', 'w') as f:
    f.writelines(output)

print("Fixed LogEntryFormView.swift")
