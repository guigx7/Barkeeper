# Barkeeper

Gerenciador da barra de menu do macOS (14+): esconde itens, organiza a ordem e agrupa ícones.

- Comportamento: [SPEC.md](SPEC.md)
- Plano: [PLAN.md](PLAN.md)

## Build

Requer Xcode 16+ e [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen generate
xcodebuild -project Barkeeper.xcodeproj -scheme Barkeeper -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/Barkeeper.app
```

O `.xcodeproj` é gerado e não fica no git; edite o `project.yml`.
