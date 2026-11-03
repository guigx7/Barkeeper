# Barkeeper — Especificação funcional

> Fonte da verdade do comportamento do Barkeeper. Construído a partir da observação
> de um app de referência e de análise com REA. O código do Barkeeper é próprio:
> não copiar código, pseudocódigo, textos nem assets do app de referência.
> Plano de implementação: [PLAN.md](PLAN.md).

- **Referência observada:** app comercial de gerenciamento da barra de menu, versão 6.6.2 (trial).
- **Escopo:** abas **General**, **Menu Bar Layout** e **About**.
- **Fora do escopo:** Menu Bar Style, Presets, Triggers, Hot Keys, Advanced, Widgets, License, About Pro.
- **Marcadores:** `[CONFIRMAR]` = comportamento a validar com REA ou teste no protótipo.

---

## 0. Conceitos

| Termo | Definição |
|---|---|
| **Item** | Ícone na barra de menu pertencente a qualquer app (incluindo itens do sistema, como relógio e Control Center). |
| **Shown** | Itens sempre visíveis na barra. |
| **Hidden** | Itens escondidos, revelados sob demanda (clique, scroll, hover, atalho). |
| **Always Hidden** | Itens que só aparecem por ação explícita (⌥+clique ou ⇧+clique no ícone do Barkeeper). |
| **Ícone do Barkeeper** | Item próprio do app; separa Shown de Hidden e serve de botão para revelar. |
| **Revelar / Re-esconder** | Mostrar temporariamente os itens Hidden (e/ou Always Hidden) e depois escondê-los de novo. |
| **Barkeeper Bar** | Painel flutuante abaixo da barra de menu que exibe itens escondidos (ver 1.5). |
| **Organizar** | Aplicar na barra real a ordem e as seções definidas em Menu Bar Layout. |

### Janela de configurações

- Janela com sidebar à esquerda (botão para recolher a sidebar no topo) e conteúdo à direita.
- Cada aba começa com um cabeçalho: ícone grande, título e subtítulo.
- Seções agrupadas em cartões arredondados, com título acima e nota de rodapé opcional abaixo.
- Sidebar do Barkeeper: **General**, **Menu Bar Layout**, **About**.

---

## 1. General

Cabeçalho: "General" — "Configure o básico do Barkeeper, ative a Barkeeper Bar e mais."

### 1.1 Início

| Opção | Tipo | Padrão | Comportamento |
|---|---|---|---|
| Start at login | toggle | off | Registra/remove o app como item de login do macOS. |

### 1.2 Layout Mode

> **v1: apenas On-Demand.** O seletor não aparece na v1; o modo Live fica para v2 e está documentado abaixo só como referência.

Seletor com dois botões grandes (ícone + rótulo): **On-Demand** e **Live**. Padrão: On-Demand.

- **On-Demand:** a barra só é reorganizada quando o usuário pede (ver 2.2). Não interfere com o mouse.
- **Live:** ao detectar mudança na barra (app novo abriu, item mudou de posição, monitor mudou), reorganiza automaticamente. Aviso exibido: "pode interromper o mouse brevemente".
- `[CONFIRMAR]` O que conta como "mudança detectada" e quais eventos disparam a reorganização no modo Live.

### 1.3 Show hidden bar items

Formas de revelar os itens Hidden:

| Opção | Tipo | Padrão | Comportamento |
|---|---|---|---|
| Click on empty menu bar space | toggle | on | Clicar numa área vazia da barra de menu revela os itens. |
| Swipe or scroll in menu bar | toggle | on | Rolar/deslizar com o cursor sobre a barra revela os itens. `[CONFIRMAR]` direção: só revela, ou um sentido revela e o outro esconde? |
| Hover over empty menu bar space | toggle | off | Passar o mouse sobre área vazia da barra revela os itens. |
| Hover delay before activating | slider | 0.2 s | Atraso do hover. `[CONFIRMAR]` faixa (aprox. 0–1 s) e passo. Desabilitado quando o hover estiver off? |

### 1.4 Show always hidden bar items

| Opção | Tipo | Padrão | Comportamento |
|---|---|---|---|
| Shift-click Barkeeper menu bar item to show all items | toggle | off | ⇧+clique no ícone do Barkeeper mostra **todos** os itens, inclusive Always Hidden, **desde que haja espaço** na barra. |

### 1.5 Barkeeper Bar

Cartão com descrição + ilustração: "Mostre seus itens escondidos na Barkeeper Bar, abaixo da barra de menu."

Painel flutuante logo abaixo da barra de menu que exibe os itens escondidos. Resolve o caso de falta de espaço, principalmente em telas com notch.

| Opção | Tipo | Padrão | Comportamento |
|---|---|---|---|
| Use Barkeeper Bar to show hidden items | toggle | off | **On:** itens revelados aparecem no painel. **Off:** são expandidos na própria barra de menu. |
| Only on screens with a notch | toggle | off | Só vale com a opção anterior ligada: usa o painel apenas em monitores com notch. |
| Automatically rehide | toggle | on | Itens revelados voltam a se esconder automaticamente. `[CONFIRMAR]` gatilhos (clique fora, fechar o menu do item, tempo) e intervalo. |
| Items to show on option-clicking the Barkeeper icon | seletor `All Hidden` / `Always Hidden` | Always Hidden | ⌥+clique no ícone do Barkeeper revela: `All Hidden` = Hidden + Always Hidden; `Always Hidden` = apenas Always Hidden. |
| Show items to the right when there's no room | toggle | on | Ao clicar num item escondido que ficaria atrás do notch, ele é colocado **depois** dos itens sempre visíveis (à direita), para ficar clicável. |

Nota de rodapé da seção: "option-click" para mostrar itens escondidos.

#### Comportamento do painel (observado em runtime)

**Aparência e posição**
- Janela flutuante sem borda, no nível de menus pop-up (acima das janelas normais e da barra de menu), com cantos arredondados e fundo escuro translúcido em formato de "pílula".
- **Altura = altura da barra de menu** daquela tela (30 pt no monitor externo observado). Fica ~4 pt abaixo da barra.
- Horizontalmente, ancorado ao **item que abriu o painel** (ícone do Barkeeper ou ícone de um grupo), com a borda direita perto dele. A largura se ajusta à quantidade de ícones (≈ 38 pt por ícone + margens: 3 ícones ≈ 131 pt; 2 ícones ≈ 93 pt).
- Abre na tela onde está o item clicado.
- Ícones na mesma ordem da barra (ordem do Menu Bar Layout), desenhados a partir da captura de imagem de cada item.

**Clique num ícone do painel** (o menu que abre é o menu **real** do app dono):
1. O painel some.
2. Uma janela de cobertura, opaca e da altura da barra, aparece sobre parte da barra de menu, acima dos itens.
3. O item real é movido temporariamente para a área visível da barra, à esquerda do ícone do Barkeeper. O movimento usa o arrastar com ⌘ nativo, e o macOS mostra a própria animação de "clone" do item.
4. A cobertura é removida e o item recebe o clique: o menu do app abre **abaixo da posição real do item** na barra.
5. Quando o menu fecha (Esc ou clique fora), o item é movido de volta para a seção de origem (Hidden ou Always Hidden), de novo sob a cobertura.
- Tempo total observado entre o clique e o menu aberto: ~0,2 s.
- **Requisito Barkeeper:** reproduzir esse fluxo. Sem mover o item, o menu do app não abre no lugar certo, e muitos apps nem respondem a clique enquanto estão fora da tela.

**Esconder de novo**
- Com "Automatically rehide", o painel desaparece com fade (~0,3 s) ao clicar fora ou depois de usar um item.

`[CONFIRMAR]` (baixo risco, testar no protótipo): comportamento com hover e com scroll quando o painel está ligado; teclado (Esc fecha o painel?).

### 1.6 Barkeeper menu bar item

| Opção | Tipo | Padrão | Comportamento |
|---|---|---|---|
| Barkeeper has a menu bar item | toggle | on | Mostra/esconde o ícone do Barkeeper na barra. |
| Barkeeper menu bar icon | popup | "••• More" | Escolhe o símbolo do ícone. `[CONFIRMAR]` lista de opções; o Barkeeper terá o próprio conjunto de símbolos (SF Symbols). |
| Show divider (‹) between shown and hidden sections | toggle | off | Mostra um item separador "‹" entre Shown e Hidden. |

Nota de rodapé: "Se o item do Barkeeper estiver escondido…" — `[CONFIRMAR]` texto completo. Provavelmente explica como reabrir as configurações (por exemplo, abrindo o app de novo pelo Finder/Spotlight) e como revelar os itens sem o ícone.

### 1.7 Menu bar item spacing

| Opção | Tipo | Padrão | Comportamento |
|---|---|---|---|
| Menu bar item spacing | popup | Default Spacing | Ajusta o espaçamento horizontal entre **todos** os itens da barra (configuração global do macOS). Mostra uma prévia ao lado. `[CONFIRMAR]` opções disponíveis, se exige relogin/reinício dos apps e como restaura o padrão. |

### 1.8 Screens

| Opção | Tipo | Padrão | Comportamento |
|---|---|---|---|
| Hide all menu bar items on inactive menu bars | toggle | off | Em monitores que não são o ativo, esconde todos os itens da barra. |
| Show all menu bar items when active screen is above a set size | toggle | off | Se a largura do monitor ativo for ≥ Size, mostra todos os itens (nada escondido). |
| Size | slider | 3000 pt | Limite de largura em pontos. Extremos ilustrados com ícone de notebook (esq.) e de monitor externo (dir.). `[CONFIRMAR]` faixa e se fica desabilitado com a opção anterior off. |

### 1.9 Menu do ícone do Barkeeper

- `[CONFIRMAR]` O que acontece com clique simples, clique direito e ⌃+clique no ícone (revelar? menu com "Settings…", "Quit"?).

---

## 2. Menu Bar Layout

Cabeçalho: "Menu Bar Items" — "Arraste itens entre as seções para reordenar sua barra de menu." Botão **refresh** no canto superior direito da janela (recarrega a lista de itens).

### 2.1 Seções

Cada seção é uma faixa escura que imita a barra de menu, com os ícones reais **alinhados à direita**, na mesma ordem da barra.

| Seção | Ícone do título | Conteúdo |
|---|---|---|
| Shown Items | óculos | Itens visíveis. Inclui o ícone do Barkeeper e itens do sistema (bateria, relógio, Control Center). |
| Hidden Items | óculos tracejados | Itens escondidos. |
| Always Hidden | olho cortado | Itens sempre escondidos. |
| Palette | paleta | Botões **Add a Spacer** e **Add a menu bar item group**. |

Interações:
- Arrastar um item dentro de uma seção muda a ordem; entre seções muda a seção.
- Arrastar da Palette cria um elemento novo na posição solta.
- `[CONFIRMAR]` Itens que não podem ser movidos (relógio? Control Center? o próprio ícone do Barkeeper?).
- `[CONFIRMAR]` Como remover um spacer/grupo (arrastar para fora? menu de contexto?).
- `[CONFIRMAR]` Tooltip ou nome do app ao passar o mouse sobre um item.
- `[CONFIRMAR]` Persistência: como um item é identificado entre execuções (app dono + identificador do item?) e o que acontece com itens de apps fechados.

**Barkeeper (implementado na etapa 6):**
- Soltar um item numa faixa move o item real **na hora** (o próprio arrastar é o pedido do usuário no modo On-Demand). O destino é calculado pelos vizinhos na faixa: à esquerda do vizinho da direita; se não houver, à direita do vizinho da esquerda; numa faixa vazia, junto ao divisor (Hidden/AH) ou à direita do ícone (Shown).
- Itens fixos (relógio, Control Center) e o ícone do Barkeeper aparecem esmaecidos e não arrastam. Nada pode ser solto à direita dos itens fixos do sistema.
- Tooltip com o nome do app/item. Spacer: clique direito → "Remove Spacer".
- O layout salvo (`savedLayout`: identidades por seção, da esquerda para a direita) é gravado a cada drop. Na primeira abertura, é copiado da barra atual. Itens de apps fechados permanecem no layout salvo e voltam ao lugar com "Organize Now".
- Sem Screen Recording, as faixas mostram o ícone do app dono no lugar da imagem do item.

### 2.2 Status do layout (On-Demand)

Linha "On-Demand Layout" com um cartão de status:
- ✅ "Menu Items Organized" — a barra real corresponde ao layout salvo.
- **Barkeeper (decidido):** além de "Organized", há "Menu Bar Differs From Layout" (laranja, com botão **Organize Now**), "Organizing…" (spinner, avisa que o mouse pode pausar), "Couldn't Organize" (vermelho, com o motivo e **Organize Now**) e, sem Accessibility, um cartão com **Grant…** no lugar das faixas.
- No modo Live o cartão muda ou some? `[CONFIRMAR]`

### 2.3 Palette

- **Spacer:** item vazio que adiciona espaço entre itens. **Barkeeper:** 20 pt, fixo, persistido entre execuções; nasce na ponta esquerda dos itens visíveis.
- **Menu bar item group:** agrupa vários itens sob um único ícone. **Escopo v1 (prioridade alta).** Ver 2.5.

### 2.5 Menu bar item group

#### Na barra de menu
- Cada grupo é um **status item próprio do Barkeeper**, com o ícone e/ou título escolhidos. A largura do item acompanha o título.
- Os itens membros saem da barra visível: ficam escondidos junto com os Always Hidden, fora da tela.
- **Clique no ícone do grupo:** abre um painel **idêntico ao da Barkeeper Bar** (1.5), ancorado ao ícone do grupo e mostrando só os membros do grupo.
- Clique num membro dentro do painel: mesmo fluxo da Barkeeper Bar (o item real é movido temporariamente, o menu abre e o item volta).
- Opção "Show on hover": o painel abre ao passar o mouse sobre o ícone do grupo.
- O grupo pode ser posicionado em qualquer seção (Shown, Hidden, Always Hidden) como um item comum, arrastando no Menu Bar Layout.

#### Criação e edição
"Add a menu bar item group" cria o grupo e abre uma folha (sheet) modal **"Menu bar item group"**:

| Elemento | Comportamento |
|---|---|
| Seção "Group menu bar item" | |
| Icon and title | Botão de ícone (seletor de símbolo/imagem), botão ⊗ para limpar o ícone, campo de texto do título e botão **Emoji** (abre o seletor de emojis do sistema). O ícone na barra é atualizado ao digitar. |
| Show on hover over menu bar item | Toggle, padrão off. |
| Group items | Área (vazia no início) com os membros do grupo, na ordem. |
| Menu bar item palette, drag from here to the Group items | Área com **todos** os itens atuais da barra (Shown + Hidden + Always Hidden), com suas imagens. Arraste para Group items para adicionar. |
| Delete Menu bar Item Group | Botão à esquerda no rodapé: remove o grupo e os membros voltam para a barra. `[CONFIRMAR]` para qual seção. |
| Done | Botão principal à direita no rodapé: fecha a folha e aplica. |

- Remover um membro: arrastar de Group items de volta para a palette. `[CONFIRMAR]`
- Reabrir a edição: clicar no grupo dentro do Menu Bar Layout. `[CONFIRMAR]`
- Identidade do grupo: UUID estável, persistido.

### 2.4 Permissões

- **Barkeeper (decidido):** Accessibility é obrigatória; Screen Recording é opcional (sem ela, os ícones aparecem sem imagem).
- Na abertura, se faltar alguma permissão, abre a janela "Barkeeper Permissions": uma linha por permissão com estado (Granted / botão **Grant…**). **Grant…** dispara o pedido do sistema e abre o painel correspondente em Ajustes do Sistema. O estado é reavaliado a cada 1 s enquanto a janela está aberta.
- **Continue** só fica habilitado com as obrigatórias concedidas. A janela pode ser reaberta pelo menu do ícone ("Permissions…") ou abrindo o app de novo (Finder/Spotlight).
- `[CONFIRMAR]` O que a aba Menu Bar Layout mostra sem as permissões.

---

## 3. About

Layout observado: ícone grande do app, nome, versão, bloco de licença/trial, links, Debug Logs e botão Quit.

Versão Barkeeper (sem licença/trial):

| Elemento | Comportamento |
|---|---|
| Ícone + nome "Barkeeper" + versão | Versão lida do bundle (fonte monoespaçada). |
| Acknowledgments | Abre a lista de créditos/licenças de terceiros. |
| Website | Abre o site do projeto no navegador. |
| Support | Abre a página de suporte/issues. |
| Feedback | Abre a página de nova issue do repositório no GitHub (https://github.com/guigx7/g-bar/issues/new). |
| Debug Logs | Exporta/abre os logs do app para anexar em pedidos de suporte. Nota: "Se estiver com problemas, anexe estes logs ao pedido de suporte." |
| Quit Barkeeper | Botão que encerra o app. |

Removido (não se aplica): Buy Now, Enter License Key, contagem do trial e aviso de expiração da beta.

---

## 4. Interoperabilidade com o macOS (requisitos de plataforma)

Fatos de plataforma observados (quais serviços do sistema a referência usa), sem detalhes de implementação.

### 4.1 Distribuição

- App de agente (`LSUIElement = true`): sem ícone no Dock, vive só na barra de menu.
- **Sem App Sandbox**, distribuído fora da App Store (assinado + notarizado). Necessário para Accessibility, eventos sintéticos e APIs de janela do WindowServer.
- macOS mínimo da referência: 14.0. **Barkeeper: macOS 14+.**
- Atualização automática via framework open-source Sparkle. **Barkeeper: Sparkle fica para a v2**; na v1, Website/About apontam para as GitHub Releases.
- Start at login: API pública `SMAppService` (ServiceManagement).

### 4.2 Permissões

| Permissão | API de verificação/pedido | Uso |
|---|---|---|
| Accessibility | `AXIsProcessTrusted(WithOptions)` | Ler a árvore de acessibilidade dos itens, acionar itens, mover itens via eventos sintéticos. |
| Screen Recording | `CGRequestScreenCaptureAccess` | Capturar a imagem dos ícones (Menu Bar Layout e Barkeeper Bar). |

### 4.3 Descoberta dos itens da barra

- Cada item da barra é uma **janela** do WindowServer pertencente ao processo do app dono. A referência enumera essas janelas pelas APIs de lista de janelas do WindowServer, incluindo uma lista específica de janelas da barra de menu por processo (API privada CGS).
- Metadados (dono, PID, frame, título) via `CGWindowListCopyWindowInfo` / `CGWindowListCreateDescriptionFromArray`.
- Complemento via Accessibility: atributo `AXExtrasMenuBar` de cada app (`AXUIElementCreateApplication`) expõe os itens com `AXFrame`/`AXPosition` e ações `AXPress`/`AXShowMenu`.
- Itens do sistema pertencem a processos como Control Center e SystemUIServer e precisam de tratamento de nomes próprio.
- **macOS 26 (Tahoe), observado:** todas as janelas de itens da barra, inclusive as de apps de terceiros, aparecem com o processo dono = **Control Center** (layer 25). O identificador do app real vem no **título da janela**: no monitor principal é o bundle ID (ex.: `com.apple.Passwords.MenuBarExtra`); em monitores secundários é o `autosaveName` do item (ex.: `Item-0`, `Clock`, `Battery`). Alguns itens não têm título. Por isso a referência inclui um serviço XPC específico para Tahoe. **Requisito Barkeeper:** a identificação de itens precisa de dois caminhos (macOS 14–15 por PID do dono; macOS 26 por título/bundle ID), e cada monitor tem a própria cópia da barra com janelas próprias.
- **Identificação no Barkeeper (observado no macOS 26.6, dois monitores):**
  - Cada item tem uma janela por monitor. Na barra **ativa**, o título da janela é o `autosaveName` do item (`Item-0`, `Clock`). Nas outras barras, é o bundle ID do app (vazio nos itens do sistema).
  - O `AXExtrasMenuBar` de cada app só informa frames da barra **ativa**. Os itens do Control Center trazem `AXIdentifier` estável (`com.apple.menuextra.clock`, `…battery`, `…sound`, `…focusmode`, `…controlcenter`).
  - Identidade estável = **bundle ID do app dono** (via AX, casando frame da janela com frame do item AX) + **nome do item** (`AXIdentifier`, senão título não bundle ID da janela, senão `#índice` dentro do app).
  - Nas barras não ativas, a identidade é herdada da barra ativa pela posição, já que os itens aparecem na mesma ordem e com a mesma largura.
  - A lista privada de janelas da barra (CGS) só inclui as janelas que estão de fato na barra. Uma janela de status item "ordered out" (ex.: escondida por outro gerenciador) fica fora da lista e não aparece no Barkeeper.
- As consultas de Accessibility rodam num **serviço XPC separado** que devolve "snapshots" da barra (lista de itens por app, com posição). Motivo provável: chamadas AX podem travar quando um app não responde; isolar no XPC protege o app principal. **Requisito Barkeeper:** as consultas AX de terceiros devem ter timeout (`AXUIElementSetMessagingTimeout`) e não podem bloquear a UI.

### 4.4 Imagem dos ícones

- Captura da janela de cada item: `CGWindowListCreateImage(FromArray)` e ScreenCaptureKit (`SCShareableContent` / stream). Requer Screen Recording.
- A referência importa `CGWindowListCreateImage(FromArray)` e `SCStream` (não usa `SCScreenshotManager`).
- **Observado no macOS 26.6:** `CGWindowListCreateImageFromArray` (deprecado, mas funcional) captura janelas de itens **fora da tela** (~10 ms por item). O `SCScreenshotManager` com filtro de janela única falha nessas janelas, assim como a captura direta do WindowServer (`SLSHWCaptureWindowList`), que só devolve janelas visíveis. Atenção: o array passado precisa conter os IDs crus (`CFArrayCreate` sem callbacks). Um `[UnsafeRawPointer?] as CFArray` faz a API devolver `nil`.
- **Barkeeper:** captura via CG `FromArray` (resolvida em runtime) → captura do WindowServer → ScreenCaptureKit, nessa ordem de fallback.

### 4.5 Ordem e visibilidade dos itens

- O macOS guarda a posição de cada `NSStatusItem` nas preferências do app dono, nas chaves `NSStatusItem Preferred Position <autosaveName>`, e a visibilidade em `NSStatusItem Visible <autosaveName>`. A referência lê/usa essas chaves.
- Movimento físico de itens: eventos sintéticos de mouse com ⌘ pressionado (o arrastar com ⌘ nativo do macOS), via `CGEventCreateMouseEvent` + `CGEventPost`/`CGEventPostToPid`. Durante o movimento o cursor é escondido (`CGDisplayHideCursor`) e a entrada local do usuário é suprimida por um intervalo curto. Isso explica o aviso "pode interromper o mouse brevemente".
#### Mecanismo de esconder (observado em runtime)

A barra de menu é preenchida da direita para a esquerda. O app cria **seus próprios status items**, que funcionam como divisores:

```
[ Always Hidden … ][ divisor AH ][ Hidden … ][ divisor H ][ ícone do app ][ Shown … ][ relógio ]
   ← fora da tela      ~5000 pt                  ~5000 pt
```

- **Divisor Hidden:** item próprio, logo à esquerda do ícone do app. Para esconder, sua largura passa a ~5000 pt e empurra para fora da tela (x negativo) tudo o que está à esquerda dele. Para revelar, volta à largura mínima.
- **Divisor Always Hidden:** segundo item próprio, mais à esquerda, com o mesmo truque (também ~5000 pt). Revelar só Hidden encolhe apenas o divisor H; revelar tudo encolhe os dois.
- Ao clicar num item que não cabe (atrás do notch), um **terceiro item espaçador** é posicionado à direita dos itens encobertos, empurrando-os para a esquerda até ficarem visíveis. Esse é o comportamento de "Show items to the right when there's no room" (1.5). Ele é removido quando não é mais necessário ou quando a barra secundária está aberta.
- Os divisores são `NSStatusItem` comuns, com `autosaveName` próprio, e por isso o macOS persiste a posição deles nas preferências do app (`NSStatusItem Preferred Position <nome>`).
- Os itens escondidos continuam existindo como janelas (fora da tela); por isso dá para capturar a imagem deles e listá-los no Menu Bar Layout.

#### Mover itens (observado em runtime)

- Os itens são movidos um a um com o arrastar com ⌘ sintético. O macOS exibe sua animação nativa de "clone" do item durante o movimento.
- Itens fora da tela passam temporariamente pela **borda esquerda da barra visível** durante a reorganização. Uma **janela de cobertura** (acima dos status items, altura da barra, opaca) esconde essa área enquanto o movimento acontece, para o usuário não ver a bagunça. Ela é removida logo depois, em ~0,1–1 s por operação.
- Além disso, existe uma janela de cobertura transparente permanente, do tamanho da barra, em cada tela. `[CONFIRMAR]` função: provavelmente capturar cliques/hover em áreas vazias da barra.

**Barkeeper, primeira execução (decidido):** o ícone e o divisor Hidden nascem na ponta direita (ao lado do Control Center/relógio) e o divisor Always Hidden nasce à esquerda de todos os itens. Os itens existentes começam em Hidden e Always Hidden começa vazio. As posições iniciais vêm de `NSStatusItem Preferred Position` (valor menor = mais à direita), gravado só se ainda não existir. Clique no ícone alterna Hidden; ⌥+clique revela tudo na barra real (Always Hidden fica à esquerda de Hidden, então não dá para revelá-lo sozinho sem o painel); ⇧+clique revela tudo se a opção 1.4 estiver ligada; clique direito ou ⌃+clique abre o menu do app. Auto-rehide (1.5) re-esconde no primeiro clique fora da barra de menu. Ao encerrar, o macOS remove os divisores e tudo volta a aparecer.

**Barkeeper, regras de ordem (decididas com o usuário):**
- Com itens revelados, os divisores ficam **sempre visíveis** como "‹", marcando a fronteira entre as seções, para o usuário ver o limite e arrastar itens com ⌘ por cima dele. Escondidos, ficam colapsados. A opção 1.6 "Show divider" passa a valer só para o estado escondido (v1: ainda não implementada).
- O ícone do Barkeeper **nunca pode ser escondido**. Antes de colapsar um divisor, o app confere a ordem: ícone à direita do divisor Hidden e divisor Always Hidden à esquerda dele. Se o usuário arrastou o ícone (ou o divisor AH) para o lado errado, o Barkeeper revela tudo, devolve **só** o que está fora de ordem com ⌘-drag sintético e então esconde.
- macOS 26: o `windowNumber` local de um `NSStatusItem` é um placeholder (≥ 2^32), porque a janela real pertence ao Control Center. A janela do próprio item é achada pelo título (= `autosaveName` na barra ativa).

**Mover (observado no Barkeeper, macOS 26.6):** cobertura com a imagem congelada da barra → revela todas as seções com divisores pequenos e visíveis (servem de alvo) → esconde o cursor → `mouseDown` com ⌘ no centro do item, 8 passos de `mouseDragged`, `mouseUp` na borda do alvo (borda esquerda = soltar à esquerda, direita = à direita) → confere pela posição da janela (adjacente ao alvo) em até 600 ms, até 3 tentativas → restaura cursor, estado e remove a cobertura. Movimento medido: 0,6–1,1 s por sessão, sucesso na 1ª tentativa. Eventos postados no HID tap com supressão de mouse local por 0,25 s.

**Requisito Barkeeper:** 3 status items próprios (ícone, divisor Hidden, divisor Always Hidden) + 1 espaçador temporário para overflow do notch + 1 status item por grupo. Larguras de colapso ≥ largura da maior tela conectada.

### 4.6 Interação com a barra

- Gatilhos de clique/scroll/hover na barra: event tap global (`CGEventTapCreate`).
- Abrir o menu de um item: Accessibility `AXPress` / `AXShowMenu` ou clique sintético na posição do item. `[CONFIRMAR]` qual é usado e quando.
- Tags de janela do WindowServer (`CGSSetWindowTags`/`CGSClearWindowTags`) aparecem nas importações. `[CONFIRMAR]` propósito.

### 4.7 Telas e Spaces

- Notch / tela embutida: `CGDisplayIsBuiltin` + área segura da tela. Mudanças de monitor: `CGDisplayRegisterReconfigurationCallback`.
- Tela com a barra ativa: API privada que informa o display da barra de menu ativa.
- Spaces e tela cheia são detectados (APIs CGS de Spaces).

### 4.8 Espaçamento

- O espaçamento entre itens usa as preferências globais `NSStatusItemSpacing` e `NSStatusItemSelectionPadding` (domínio global, current host). `[CONFIRMAR]` valores de cada opção e se a referência reinicia apps para aplicar.
