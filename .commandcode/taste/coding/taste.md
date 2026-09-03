# Coding preferences

- Uses XML doc comments (`/// <summary>`) on C# types and public members. Confidence: 0.7
- Prefers immutable C# data types (`sealed record` / `readonly record struct` with `init` accessors). Confidence: 0.7
- Organizes C# code into domain-focused namespaces with one type per file. Confidence: 0.6
- Prefers idiomatic PascalCase for C# public API and method names, correcting lowerCamelCase pseudocode from spec docs. Confidence: 0.7
- Uses static readonly `IReadOnlyDictionary` lookup tables for fixed mappings (e.g. control-to-key/button bindings) instead of long switch/if chains. Confidence: 0.6
- C# projects target .NET 10 (net10.0) with implicit usings enabled; .csproj scaffolding should include `<ImplicitUsings>enable</ImplicitUsings>`. Confidence: 0.6
