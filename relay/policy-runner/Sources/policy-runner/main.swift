// main.swift
// Krasip
// Reads one transcript per line from standard input and prints the text policy's final text for each.

import KrasipCore

let policy = TextPolicy()
while let line = readLine() {
    print(policy.finalize(line, glossary: Glossary([])).text)
}
