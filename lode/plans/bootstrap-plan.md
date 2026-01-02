# Plan: MCP Server for HEH8080 + spazm8080 Bootstrapping

## Goal
Add an MCP server to the heh8080 emulator enabling Claude to directly interact with CP/M (lolos), enabling iterative development of spazm8080 - a self-hosted 8080/Z80 assembler.

## Architecture

```
┌─────────────────┐     ┌──────────────────────────────────────┐
│   Claude Code   │────▶│  Heh8080.Desktop + MCP Server        │
│   (MCP Client)  │     │  ┌────────────────────────────────┐  │
└─────────────────┘     │  │  McpTools                      │  │
                        │  │  - send_input(text)            │  │
                        │  │  - read_screen()               │  │
                        │  │  - wait_for_text(pattern)      │  │
                        │  │  - read_file(drive, name)      │  │
                        │  │  - write_file(drive, name, data)│ │
                        │  │  - peek_memory(addr, len)      │  │
                        │  │  - poke_memory(addr, bytes)    │  │
                        │  └───────────┬────────────────────┘  │
                        │              │                       │
                        │  ┌───────────▼────────────────────┐  │
                        │  │  Adm3aTerminal  │  Emulator    │  │
                        │  │  (80x24 buffer) │  (CPU/Memory)│  │
                        │  └───────────┬────────────────────┘  │
                        │              │                       │
                        │  ┌───────────▼────────────────────┐  │
                        │  │  CP/M (lolos) running          │  │
                        │  │  - ED editor                   │  │
                        │  │  - Assemblers (ASM, etc.)      │  │
                        │  │  - spazm8080 (our target)      │  │
                        │  └────────────────────────────────┘  │
                        └──────────────────────────────────────┘
```

## Implementation Order
1. **Phase 1**: Set up spazm8080 lode and design (this repo) ✓ COMPLETE
2. **Phase 2**: Add MCP Server to heh8080 (heh8080 repo)
3. **Phase 3**: Develop spazm8080 using MCP

---

## Phase 1: Create spazm8080 Lode and Design ✓ COMPLETE

### 1.1 Initialize lode/
```
lode/
  summary.md          # Project overview ✓
  terminology.md      # 8080/Z80/CP/M terms ✓
  practices.md        # Assembly coding patterns ✓
  lode-map.md         # Index ✓
  assembler/
    architecture.md   # spazm8080 design ✓
```

### 1.2 Design the assembler architecture ✓
Documented in [architecture.md](../assembler/architecture.md):
- Two-pass assembly algorithm
- Symbol table structure (16-byte fixed entries)
- Expression parser (operator precedence)
- Module interfaces (lexer, parser, symtab, expr, emit, output)
- Output format generation (Intel HEX)

### 1.3 Source structure (planned)
```
src/
  spazm.asm           # Main assembler source
  lexer.asm           # Tokenizer
  parser.asm          # Instruction parser
  symtab.asm          # Symbol table
  expr.asm            # Expression evaluator
  emit.asm            # Code emitter
  output.asm          # HEX file output
```

---

## Phase 2: Add MCP Server to heh8080

### 2.1 Add NuGet packages to Heh8080.Desktop
```xml
<PackageReference Include="ModelContextProtocol" Version="*-*" />
```

### 2.2 Create `Heh8080.Mcp` project
New project for MCP tools, references:
- Heh8080.Terminal (for screen access)
- Heh8080.Devices (for disk access)
- Heh8080.Core (for memory access)

**Files to create:**
- `src/Heh8080.Mcp/Heh8080.Mcp.csproj`
- `src/Heh8080.Mcp/CpmTools.cs` - MCP tool implementations

### 2.3 Define MCP Tools

```csharp
[McpServerToolType]
public class CpmTools
{
    [McpServerTool] public void SendInput(string text);
    [McpServerTool] public string ReadScreen();
    [McpServerTool] public Task<bool> WaitForText(string pattern, int timeoutMs);
    [McpServerTool] public string ReadFile(int drive, string filename);
    [McpServerTool] public void WriteFile(int drive, string filename, string content);
    [McpServerTool] public byte[] PeekMemory(int address, int length);
    [McpServerTool] public void PokeMemory(int address, byte[] data);
    [McpServerTool] public string Status();
}
```

### 2.4 Integrate with Desktop startup
Add `--mcp` flag to start MCP server on stdio transport.

---

## Phase 3: Develop spazm8080 using MCP

With MCP server running, Claude can:
1. Write assembly source files to disk via `write_file`
2. Invoke ED or existing assemblers via `send_input`
3. Monitor output via `read_screen` and `wait_for_text`
4. Debug via `peek_memory`
5. Test assembled programs

## Key Files to Modify (heh8080 repo)

| File | Change |
|------|--------|
| `heh8080.sln` | Add Heh8080.Mcp project |
| `src/Heh8080.Desktop/Heh8080.Desktop.csproj` | Add MCP package, reference Heh8080.Mcp |
| `src/Heh8080.Desktop/Program.cs` | Add MCP server startup option |
| NEW `src/Heh8080.Mcp/Heh8080.Mcp.csproj` | New project |
| NEW `src/Heh8080.Mcp/CpmTools.cs` | MCP tool implementations |

## Questions Resolved
- **Language**: 8080 assembly (self-hosted)
- **Bootstrap**: Use heh8080 MCP to develop/test
- **Output**: Match zmac formats (HEX, CMD, CIM)
- **Lode**: Yes, create it

## Sources
- [Official MCP C# SDK](https://github.com/modelcontextprotocol/csharp-sdk)
- [.NET Blog: Build MCP Server in C#](https://devblogs.microsoft.com/dotnet/build-a-model-context-protocol-mcp-server-in-csharp/)
