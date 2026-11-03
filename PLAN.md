# Barkeeper — Plano de implementação (v1)

Fonte do comportamento: [SPEC.md](SPEC.md). REA disponível para tirar dúvidas sobre o app de referência.

## Regras de trabalho

- **Stack:** Swift 6 + SwiftUI (janela de configurações) + AppKit (status items, painéis, janelas de cobertura). macOS 14+. Sem sandbox. Projeto Xcode gerado com **XcodeGen** (`project.yml` versionado, `.xcodeproj` fora do git).
- **Commits:** curtos, em inglês, Conventional Commits (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`, `test:`), com push para `origin/main` ao fim de cada etapa.
- **REA:** usar para responder `[CONFIRMAR]` ou entender um comportamento. Registrar o resultado no `SPEC.md` (comportamento, não código) no mesmo commit da etapa. Nunca transcrever pseudocódigo.
- **Verificação:** cada etapa termina com `xcodebuild` sem erros e o app rodando; validação manual descrita na etapa.
- **Separação:** acesso a APIs privadas (CGS/SkyLight) isolado num único módulo (`Platform/`), declarado via `@_silgen_name`/`dlsym`, com fallback quando indisponível.

## Arquitetura alvo

```
Barkeeper/
  App/            AppDelegate, ciclo de vida, LSUIElement
  Platform/       WindowServer (lista de janelas, APIs privadas), Accessibility, EventSynth (⌘-drag, cliques), ScreenCapture, Displays
  MenuBar/        MenuBarItem (modelo + identidade), ItemScanner, ControlItems (ícone + divisores), Hider, Mover, Layout (seções/ordem, persistência)
  Panel/          BarkeeperBarPanel, CoverWindow, fluxo "clicar item escondido"
  Groups/         Group model, GroupStatusItem, editor
  Settings/       janela com sidebar; GeneralView, MenuBarLayoutView, AboutView
  Support/        Preferences (UserDefaults tipado), Logging (os.Logger + export), LoginItem (SMAppService)
```

## Etapas

| # | Etapa | Entrega | Validação |
|---|---|---|---|
| 0 | Scaffold | XcodeGen, app agente (`LSUIElement`), status item básico, `README.md`, `.gitignore` | Abre e mostra ícone na barra |
| 1 | Permissões | Onboarding de Accessibility + Screen Recording (checar/pedir/reabrir Ajustes) | Estados corretos com e sem permissão |
| 2 | Scanner de itens | Listar itens da barra por tela (macOS 14–15 por PID; macOS 26 por título/bundle ID, dono Control Center), identidade estável | Log com todos os itens e frames |
| 3 | Esconder/revelar | Ícone + divisor Hidden + divisor Always Hidden; colapso ~largura da maior tela; revelar por clique, ⌥+clique, ⇧+clique | Itens somem/voltam |
| 4 | Captura de ícones | Imagem de cada item (inclusive fora da tela) | Grid de imagens em janela debug |
| 5 | Mover itens | ⌘-drag sintético com cobertura, supressão de input, timeout e retry | Mover item entre seções de forma confiável |
| 6 | Menu Bar Layout | Aba com Shown/Hidden/Always Hidden, drag & drop, status "Organized", refresh, Spacer | Arrastar na aba reorganiza a barra real |
| 7 | Barkeeper Bar | Painel abaixo da barra + fluxo de clique (mover temporário → clicar → devolver), auto-rehide, notch-only, overflow à direita | Abrir menu de item escondido pelo painel |
| 8 | Grupos | Status item por grupo, painel do grupo, editor (ícone/título/emoji, hover, membros, delete) | Criar grupo, abrir membro pelo painel |
| 9 | General | Demais opções (login, gatilhos de revelar/hover delay, ícone/divisor, espaçamento, Screens) | Cada toggle com efeito |
| 10 | About | Ícone, versão, links, Debug Logs, Quit | Links e export de logs |
| 11 | Polimento | Multi-monitor, notch, mudança de telas, apps que recriam itens, resolver `[CONFIRMAR]` restantes | Checklist do SPEC sem pendências |

Riscos principais: estabilidade do ⌘-drag (etapa 5) e identificação no macOS 26 (etapa 2). Fazer essas etapas cedo e com logs detalhados.
