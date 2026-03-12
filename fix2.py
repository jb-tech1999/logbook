with open('logbook/Views/LogEntryFormView.swift', 'r') as f:
    content = f.read()

# Remove defer line
content = content.replace('        defer { isSaving = false }\n', '')

# Fix duplicate logger lines
content = content.replace(
    '            logEntryFormLogger.error("Failed to save log entry: \\(error.localizedDescription)")\n            logEntryFormLogger.error("Failed to save log entry: \\(error.localizedDescription)")\n',
    '            logEntryFormLogger.error("Failed to save log entry: \\(error.localizedDescription)")\n'
)

# Fix duplicate isSaving lines
content = content.replace(
    '            isSaving = false\n            isSaving = false\n',
    '            isSaving = false\n'
)

with open('logbook/Views/LogEntryFormView.swift', 'w') as f:
    f.write(content)
    
print("Fixed!")
