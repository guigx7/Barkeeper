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
- Modo Live: fora da v1 (não implementado).

### 1.3 Show hidden bar items

Formas de revelar os itens Hidden:

| Opção | Tipo | Padrão | Comportamento |
|---|---|---|---|
| Click on empty menu bar space | toggle | on | Clicar numa área vazia da barra de menu revela os itens. |
| Hover over empty menu bar space | toggle | off | Passar o mouse sobre área vazia da barra revela os itens. |
| Hover delay before activating | slider | 0.2 s | Atraso do hover. **Barkeeper:** 0–1 s, passo 0,1 s, desabilitado com o hover off. |

### 1.3.1 Scroll in the Menu Bar (Barkeeper, decidido com o usuário)

Substitui a opção "Swipe or scroll in menu bar" da referência por uma seção dedicada. Rolar ou deslizar **em qualquer lugar** da barra de menu (não só em área vazia) executa uma ação configurável **por direção**.

| Opção | Tipo | Padrão |
|---|---|---|
| Scroll or swipe in the menu bar | toggle | on |
| Scroll Up | popup de ação | Hide Hidden Items |
| Scroll Down | popup de ação | Show Hidden Items |
| Scroll Left | popup de ação | Desktop on the Left |
| Scroll Right | popup de ação | Desktop on the Right |

- Ações: Do Nothing, Show / Hide Hidden Items, Show Hidden Items, Hide Hidden Items, Desktop on the Left, Desktop on the Right. Com a Barkeeper Bar ligada, mostrar/esconder abre/fecha o painel.
- Direções físicas (dedos ou roda), independentes da rolagem natural. Uma ação por gesto; a inércia (momentum) é ignorada. Roda de mouse: no máximo uma ação a cada 0,5 s.
- Trocar de mesa envia o atalho do próprio sistema "Mover para a esquerda/direita um espaço" (Mission Control, IDs 79/81 de `com.apple.symbolichotkeys`), lido das preferências do usuário; se o atalho estiver desligado, nada acontece.

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
| Automatically rehide | toggle | on | Itens revelados voltam a se esconder automaticamente. **Barkeeper:** sem temporizador. Re-esconde no primeiro clique fora da barra de menu; o painel fecha ao clicar fora ou depois de usar um item; um item aberto pelo painel volta a se esconder quando o menu dele fecha. Itens revelados por **hover** se escondem sempre que o cursor sai da barra (e do painel) por ~0,5 s, esperando antes qualquer menu/popover aberto fechar. |
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

**Barkeeper (implementado na etapa 7, macOS 26.6):**
- Clique no ícone com a Barkeeper Bar ligada: abre o painel com os itens Hidden. ⌥+clique: Always Hidden (ou Hidden + Always Hidden, conforme 1.5). ⇧+clique com a opção 1.4 ligada continua expandindo a barra real ("mostrar todos"). Clique no ícone com o painel aberto fecha o painel. "Only on screens with a notch" ligado em tela sem notch: o clique expande a barra real.
- O painel reaproveita o último scan e só relê frames e imagens (abre em ~50 ms); um scan completo roda em segundo plano para atualizar o cache.
- **Abrir sem mexer no mouse (pedido do usuário):** o clique num ícone do painel **não move o ponteiro**. O Barkeeper revela a seção do item (encolhe o divisor, sem eventos de mouse), espera o app dono atualizar a posição do item no Accessibility (macOS 26.6: ~100 ms após o divisor mudar; antes disso o AX reporta a posição antiga e o menu abriria fora da tela) e aciona o item com `AXPress`. O menu abre embaixo do item, na posição revelada, em ~0,25–0,3 s. Quando o menu fecha, a seção volta a se esconder.
- **Só o item clicado aparece (pedido do usuário):** antes de revelar, a barra de cada monitor é congelada com uma imagem (janela de cobertura acima dos status items). Depois de revelar, a cobertura é dividida em pedaços que deixam descobertos apenas o item clicado (e a cópia dele nas barras dos outros monitores, achada pela mesma posição na ordem) e os ícones do próprio Barkeeper em Shown. Os outros itens da seção ficam sob a imagem até o menu fechar.
- Observado no macOS 26.6: a cobertura **não pode sobrepor** a janela do item, em nenhum monitor, nem com uma região transparente. Se sobrepuser, o macOS fecha o popover/menu do item logo depois de abrir. A captura da tela também não inclui os status items do próprio app, por isso os ícones do Barkeeper ficam descobertos.
- Fallback (só quando o item continua fora da tela ou atrás do notch mesmo revelado, ou quando o `AXPress` falha): o fluxo com ⌘-drag (move o ponteiro brevemente), clique por AX e volta à seção de origem. A volta usa o vizinho original: à esquerda do vizinho da direita, senão à direita do da esquerda. Medido: ~0,6 s para abrir e ~0,9 s para devolver.
- O fechamento do menu é detectado pela janela nova que o clique abriu: dono = app do item ou o host da barra, nível acima das janelas normais, ou popover em nível de status com mais de 40 pt de altura. O app espera essa janela sumir (até 10 min). Se nenhuma janela aparece em 1,5 s (item sem menu ou que abre uma janela normal), o item volta logo.
- Overflow: se a posição à esquerda do ícone cairia atrás do notch ou fora da tela e "Show items to the right" estiver ligado, o item é colocado à esquerda do primeiro item fixo do sistema (Control Center), ou seja, depois dos itens visíveis.
- Re-esconder: o painel fecha com fade de 0,3 s ao clicar fora ou ao escolher um item. O painel não recebe teclado (não ativa o app), então Esc não o fecha (v1).
- "Only on screens with a notch" decide pela tela da barra **ativa no momento do clique**: no macOS 26 cada barra tem as próprias janelas de item, então o cache da varredura é descartado quando a barra ativa mudou de tela (antes, o primeiro clique depois de trocar de monitor usava a tela anterior).
- Hover, scroll e clique em área vazia com o painel ligado abrem o painel (mesmo efeito de um clique no ícone); clique em área vazia com o painel aberto só o fecha.

### 1.6 Barkeeper menu bar item

| Opção | Tipo | Padrão | Comportamento |
|---|---|---|---|
| Barkeeper has a menu bar item | toggle | on | Mostra/esconde o ícone do Barkeeper na barra. **Barkeeper: não existe** — decidido com o usuário que o ícone nunca pode ser escondido. |
| Barkeeper menu bar icon | popup | "••• More" | Escolhe o símbolo do ícone. **Barkeeper:** grade com ~70 SF Symbols num popover. |
| Show divider (‹) between shown and hidden sections | toggle | off | Mostra um item separador "‹" entre Shown e Hidden. **Removido do Barkeeper (decisão do usuário).** Revelado, os divisores reais continuam aparecendo como "‹". |

Nota de rodapé: **Barkeeper:** "O ícone do Barkeeper sempre fica visível: não pode ser movido para uma seção escondida." (o caso "ícone escondido" não existe).

### 1.7 Menu bar item spacing / 1.8 Screens

**Removidos do Barkeeper (decisão do usuário).** A referência tem um popup de espaçamento global entre itens (`NSStatusItemSpacing`/`NSStatusItemSelectionPadding`, lido por cada app ao iniciar) e opções por tela (esconder tudo em barras inativas; mostrar tudo em telas acima de uma largura). O Barkeeper não oferece essas opções.

### 1.9 Menu do ícone do Barkeeper

- **Barkeeper:** clique simples alterna Hidden (ou abre a Barkeeper Bar); ⌥+clique e ⇧+clique conforme 1.4/1.5; clique direito ou ⌃+clique abre o menu: Settings… (⌘,), Permissions…, Quit Barkeeper (⌘Q). Com ⌥ pressionado ao abrir o menu aparecem também os itens de diagnóstico (Log Menu Bar Items, Show Item Images).

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
- **Barkeeper:** relógio e Control Center não podem ser movidos (o macOS não permite). O ícone do Barkeeper pode ser arrastado com ⌘ na barra, mas nunca fica escondido: o app devolve-o à ordem certa (ver 4.5).
- **Barkeeper:** spacer sai pelo menu de contexto na faixa ("Remove Spacer"); grupo, pelo botão Delete do editor de grupo.
- **Barkeeper:** tooltip com o nome do app dono ("Spacer" para espaçadores, "Group — click to edit" para grupos).
- **Barkeeper:** identidade = bundle ID do app dono + nome do item (autosave name no macOS 26; identificador AX ou `#índice` como último recurso). Itens de apps fechados somem do layout; membros de grupo continuam salvos e voltam a aparecer quando o app abre. Itens recriados por um app (janela nova) mantêm a identidade, e o cache da barra é descartado quando apps abrem ou fecham.
- **Itens novos (decidido com o usuário):** o macOS coloca todo item nunca visto na ponta esquerda, ou seja, dentro de Always Hidden. O Barkeeper guarda os itens já vistos (`knownItems`) e move cada item novo que nasce em Always Hidden para o início de Shown (à direita do ícone), com ⌘-drag, ~2 s e ~5 s depois de um app abrir. Na primeira execução só registra o que existe. Apps abrindo/fechando são detectados pela lista de apps em execução (KVO), porque a notificação de lançamento não vem para apps agentes (sem Dock), que são a maioria dos apps de barra.

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
- Modo Live fora da v1.

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
| Delete Menu bar Item Group | Botão à esquerda no rodapé: remove o grupo e os membros voltam para a barra, na seção Hidden. |
| Done | Botão principal à direita no rodapé: fecha a folha e aplica. |

- Remover um membro: arrastar de Group items de volta para a palette, ou clique direito → "Remove from Group". Clique direito na palette → "Add to Group".
- Reabrir a edição: clicar no grupo dentro do Menu Bar Layout (ou clique direito → "Edit Group…").
- Identidade do grupo: UUID estável, persistido (`menuBarGroups`); o status item usa o `autosaveName` `BarkeeperGroup-<UUID>`.

**Barkeeper (implementado na etapa 8):**
- Ícone, título e hover são aplicados ao vivo enquanto se edita; os membros só são aplicados em **Done**. Membros novos vão para Always Hidden (à esquerda do divisor AH); membros removidos voltam para Hidden.
- **Delete:** remove o grupo e o status item; os membros voltam para **Hidden** (decidido).
- Membros de grupos não aparecem nas faixas do Layout nem nos painéis Hidden/Always Hidden; um item pertence a no máximo um grupo (a palette não mostra membros de outros grupos).
- O macOS cria status items novos na ponta esquerda (dentro de Always Hidden). Por isso, um grupo ou spacer recém-criado é movido logo em seguida para a direita do ícone do Barkeeper (início de Shown).
- Clique no grupo com o painel do próprio grupo aberto: fecha. "Show on hover": abre após 0,2 s com o ponteiro parado sobre o ícone.
- Ícones disponíveis: grade de ~48 SF Symbols; ⊗ remove o ícone (fica só o título; sem ícone nem título, mostra "Group").

### 2.4 Permissões

- **Barkeeper (decidido):** Accessibility é obrigatória; Screen Recording é opcional (sem ela, os ícones aparecem sem imagem).
- Na abertura, se faltar alguma permissão, abre a janela "Barkeeper Permissions": uma linha por permissão com estado (Granted / botão **Grant…**). **Grant…** dispara o pedido do sistema e abre o painel correspondente em Ajustes do Sistema. O estado é reavaliado a cada 1 s enquanto a janela está aberta.
- **Continue** só fica habilitado com as obrigatórias concedidas. A janela pode ser reaberta pelo menu do ícone ("Permissions…") ou abrindo o app de novo (Finder/Spotlight).
- **Barkeeper:** sem Accessibility, a aba mostra só um cartão "Accessibility permission required" com o botão Grant….

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
- Além disso, existe uma janela de cobertura transparente permanente, do tamanho da barra, em cada tela. Função provável: capturar cliques/hover em áreas vazias. **Barkeeper não usa:** os gatilhos vêm de um event tap só de escuta (4.6), e qualquer janela sobre os itens fecharia os popovers deles.

**Barkeeper, primeira execução (decidido):** o ícone e o divisor Hidden nascem na ponta direita (ao lado do Control Center/relógio) e o divisor Always Hidden nasce à esquerda de todos os itens. Os itens existentes começam em Hidden e Always Hidden começa vazio. As posições iniciais vêm de `NSStatusItem Preferred Position` (valor menor = mais à direita), gravado só se ainda não existir. Clique no ícone alterna Hidden; ⌥+clique revela tudo na barra real (Always Hidden fica à esquerda de Hidden, então não dá para revelá-lo sozinho sem o painel); ⇧+clique revela tudo se a opção 1.4 estiver ligada; clique direito ou ⌃+clique abre o menu do app. Auto-rehide (1.5) re-esconde no primeiro clique fora da barra de menu. Ao encerrar, o macOS remove os divisores e tudo volta a aparecer.

**Barkeeper, regras de ordem (decididas com o usuário):**
- Com itens revelados, os divisores ficam **sempre visíveis** como "‹", marcando a fronteira entre as seções, para o usuário ver o limite e arrastar itens com ⌘ por cima dele. Escondidos, ficam colapsados. A opção 1.6 "Show divider" foi removida.
- O ícone do Barkeeper **nunca pode ser escondido**. Antes de colapsar um divisor, o app confere a ordem: ícone à direita do divisor Hidden e divisor Always Hidden à esquerda dele. Se o usuário arrastou o ícone (ou o divisor AH) para o lado errado, o Barkeeper revela tudo, devolve **só** o que está fora de ordem com ⌘-drag sintético e então esconde.
- macOS 26: o `windowNumber` local de um `NSStatusItem` é um placeholder (≥ 2^32), porque a janela real pertence ao Control Center. A janela do próprio item é achada pelo título (= `autosaveName` na barra ativa).

**Mover (observado no Barkeeper, macOS 26.6):** cobertura com a imagem congelada da barra → revela todas as seções com divisores pequenos e visíveis (servem de alvo) → esconde o cursor → `mouseDown` com ⌘ no centro do item, 8 passos de `mouseDragged`, `mouseUp` na borda do alvo (borda esquerda = soltar à esquerda, direita = à direita) → confere pela posição da janela (adjacente ao alvo) em até 600 ms, até 3 tentativas → restaura cursor, estado e remove a cobertura. Movimento medido: 0,6–1,1 s por sessão, sucesso na 1ª tentativa. Eventos postados no HID tap com supressão de mouse local por 0,25 s.

**Requisito Barkeeper:** 3 status items próprios (ícone, divisor Hidden, divisor Always Hidden) + 1 espaçador temporário para overflow do notch + 1 status item por grupo. Larguras de colapso ≥ largura da maior tela conectada.

### 4.6 Interação com a barra

- Gatilhos de clique/scroll/hover na barra: event tap global (`CGEventTapCreate`).
- **Barkeeper:** event tap só de escuta (`listenOnly`, sessão) para `leftMouseDown`, `scrollWheel` e `mouseMoved`; nunca altera eventos. "Área vazia" = dentro da altura da barra de uma tela, fora de qualquer status item, fora dos menus do app dono da barra (frames via AX `AXMenuBar`) e fora do notch. Clique em área vazia alterna (revela/esconde). Hover só revela, depois do atraso, se o cursor ainda estiver em área vazia; não esconde ao sair (quem esconde é o auto-rehide).
- Abrir o menu de um item: Accessibility `AXPress` / `AXShowMenu` ou clique sintético na posição do item. **Barkeeper:** `AXPress` (depois `AXShowMenu`) no item revelado no lugar; ⌘-drag temporário só quando o item não cabe na tela mesmo revelado.
- Tags de janela do WindowServer (`CGSSetWindowTags`/`CGSClearWindowTags`) aparecem nas importações. Propósito não investigado; o Barkeeper não precisa delas.

### 4.7 Telas e Spaces

- **Barkeeper:** em mudança de telas (conectar, desconectar, resolução), descarta o cache da barra, fecha o painel e reaplica o estado dos divisores (a largura de colapso vem da maior tela conectada); o Menu Bar Layout recarrega se estiver aberto. A tela da barra ativa é a que contém a janela do ícone do Barkeeper com o autosave name como título.
- **Barkeeper:** cada tela tem sua própria cópia das janelas dos itens. Telas lado a lado com o topo alinhado se sobrepõem em x depois que os itens ocultos saem da tela; a barra de cada uma é a cadeia de janelas encostadas que termina na borda direita daquela tela. Os divisores só são reaplicados depois que terminar qualquer movimentação de itens em andamento.
- **Barkeeper:** com itens sendo movidos ou com o menu de um item aberto pelo painel, clique, scroll e hover na barra e o rehide por clique fora não mexem nos divisores (trocar de desktop continua funcionando).
- **Barkeeper:** soltar um item no Menu Bar Layout só grava o layout se o movimento der certo, e mantém no layout salvo os itens de apps que não estão abertos.
- **Barkeeper:** hover no ícone de um grupo só abre o painel do grupo; nunca fecha.

- Notch / tela embutida: `CGDisplayIsBuiltin` + área segura da tela. Mudanças de monitor: `CGDisplayRegisterReconfigurationCallback`.
- Tela com a barra ativa: API privada que informa o display da barra de menu ativa.
- Spaces e tela cheia são detectados (APIs CGS de Spaces).

### 4.8 Espaçamento

- O espaçamento entre itens usa as preferências globais `NSStatusItemSpacing` e `NSStatusItemSelectionPadding` (domínio global, current host). Opção removida do Barkeeper (1.7).
