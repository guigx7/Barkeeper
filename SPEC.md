# g-bar — Especificação funcional (clean-room)

> Este documento descreve apenas **comportamento observável**. Não contém código,
> pseudocódigo, nomes internos nem assets do app de referência.
> A implementação deve ser feita **somente** a partir deste documento.

- **Referência observada:** app comercial de gerenciamento da barra de menu, versão 6.6.2 (trial).
- **Escopo:** abas **General**, **Menu Bar Layout** e **About**.
- **Fora do escopo:** Menu Bar Style, Presets, Triggers, Hot Keys, Advanced, Widgets, License, About Pro.
- **Marcadores:** `[CONFIRMAR]` = comportamento a validar na fase de análise (REA / teste manual).

---

## 0. Conceitos

| Termo | Definição |
|---|---|
| **Item** | Ícone na barra de menu pertencente a qualquer app (incluindo itens do sistema, como relógio e Control Center). |
| **Shown** | Itens sempre visíveis na barra. |
| **Hidden** | Itens escondidos, revelados sob demanda (clique, scroll, hover, atalho). |
| **Always Hidden** | Itens que só aparecem por ação explícita (⌥+clique ou ⇧+clique no ícone do g-bar). |
| **Ícone do g-bar** | Item próprio do app; separa Shown de Hidden e serve de botão para revelar. |
| **Revelar / Re-esconder** | Mostrar temporariamente os itens Hidden (e/ou Always Hidden) e depois escondê-los de novo. |
| **g-bar Bar** | Painel flutuante abaixo da barra de menu que exibe itens escondidos (ver 1.5). |
| **Organizar** | Aplicar na barra real a ordem e as seções definidas em Menu Bar Layout. |

### Janela de configurações

- Janela com sidebar à esquerda (botão para recolher a sidebar no topo) e conteúdo à direita.
- Cada aba começa com um cabeçalho: ícone grande, título e subtítulo.
- Seções agrupadas em cartões arredondados, com título acima e nota de rodapé opcional abaixo.
- Sidebar do g-bar: **General**, **Menu Bar Layout**, **About**.

---

## 1. General

Cabeçalho: "General" — "Configure o básico do g-bar, ative a g-bar Bar e mais."

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
| Shift-click g-bar menu bar item to show all items | toggle | off | ⇧+clique no ícone do g-bar mostra **todos** os itens, inclusive Always Hidden, **desde que haja espaço** na barra. |

### 1.5 g-bar Bar

Cartão com descrição + ilustração: "Mostre seus itens escondidos na g-bar Bar, abaixo da barra de menu."

Painel flutuante logo abaixo da barra de menu que exibe os itens escondidos. Resolve o caso de falta de espaço, principalmente em telas com notch.

| Opção | Tipo | Padrão | Comportamento |
|---|---|---|---|
| Use g-bar Bar to show hidden items | toggle | off | **On:** itens revelados aparecem no painel. **Off:** são expandidos na própria barra de menu. |
| Only on screens with a notch | toggle | off | Só vale com a opção anterior ligada: usa o painel apenas em monitores com notch. |
| Automatically rehide | toggle | on | Itens revelados voltam a se esconder automaticamente. `[CONFIRMAR]` gatilhos (clique fora, fechar o menu do item, tempo) e intervalo. |
| Items to show on option-clicking the g-bar icon | seletor `All Hidden` / `Always Hidden` | Always Hidden | ⌥+clique no ícone do g-bar revela: `All Hidden` = Hidden + Always Hidden; `Always Hidden` = apenas Always Hidden. |
| Show items to the right when there's no room | toggle | on | Ao clicar num item escondido que ficaria atrás do notch, ele é colocado **depois** dos itens sempre visíveis (à direita), para ficar clicável. |

Nota de rodapé da seção: "option-click" para mostrar itens escondidos.

Comportamento do painel — `[CONFIRMAR]`:
- [ ] Aparência: material/blur, cantos, sombra; altura igual à da barra de menu?
- [ ] Posição: alinhado à direita da tela, abaixo do ícone do g-bar?
- [ ] Clicar num ícone do painel abre o menu **real** do app dono? Como?
- [ ] Origem das imagens dos ícones e frequência de atualização.
- [ ] Multi-monitor: monitor ativo ou monitor do mouse?
- [ ] Ordem no painel = ordem definida em Menu Bar Layout?

### 1.6 g-bar menu bar item

| Opção | Tipo | Padrão | Comportamento |
|---|---|---|---|
| g-bar has a menu bar item | toggle | on | Mostra/esconde o ícone do g-bar na barra. |
| g-bar menu bar icon | popup | "••• More" | Escolhe o símbolo do ícone. `[CONFIRMAR]` lista de opções; o g-bar terá o próprio conjunto de símbolos (SF Symbols). |
| Show divider (‹) between shown and hidden sections | toggle | off | Mostra um item separador "‹" entre Shown e Hidden. |

Nota de rodapé: "Se o item do g-bar estiver escondido…" — `[CONFIRMAR]` texto completo. Provavelmente explica como reabrir as configurações (por exemplo, abrindo o app de novo pelo Finder/Spotlight) e como revelar os itens sem o ícone.

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

### 1.9 Menu do ícone do g-bar

- `[CONFIRMAR]` O que acontece com clique simples, clique direito e ⌃+clique no ícone (revelar? menu com "Settings…", "Quit"?).

---

## 2. Menu Bar Layout

Cabeçalho: "Menu Bar Items" — "Arraste itens entre as seções para reordenar sua barra de menu." Botão **refresh** no canto superior direito da janela (recarrega a lista de itens).

### 2.1 Seções

Cada seção é uma faixa escura que imita a barra de menu, com os ícones reais **alinhados à direita**, na mesma ordem da barra.

| Seção | Ícone do título | Conteúdo |
|---|---|---|
| Shown Items | óculos | Itens visíveis. Inclui o ícone do g-bar e itens do sistema (bateria, relógio, Control Center). |
| Hidden Items | óculos tracejados | Itens escondidos. |
| Always Hidden | olho cortado | Itens sempre escondidos. |
| Palette | paleta | Botões **Add a Spacer** e **Add a menu bar item group**. |

Interações:
- Arrastar um item dentro de uma seção muda a ordem; entre seções muda a seção.
- Arrastar da Palette cria um elemento novo na posição solta.
- `[CONFIRMAR]` Itens que não podem ser movidos (relógio? Control Center? o próprio ícone do g-bar?).
- `[CONFIRMAR]` Como remover um spacer/grupo (arrastar para fora? menu de contexto?).
- `[CONFIRMAR]` Tooltip ou nome do app ao passar o mouse sobre um item.
- `[CONFIRMAR]` Persistência: como um item é identificado entre execuções (app dono + identificador do item?) e o que acontece com itens de apps fechados.

### 2.2 Status do layout (On-Demand)

Linha "On-Demand Layout" com um cartão de status:
- ✅ "Menu Items Organized" — a barra real corresponde ao layout salvo.
- `[CONFIRMAR]` Os outros estados: desorganizado, com botão para organizar agora? Organizando, com progresso? Erro de permissão?
- No modo Live o cartão muda ou some? `[CONFIRMAR]`

### 2.3 Palette

- **Spacer:** item vazio que adiciona espaço entre itens. `[CONFIRMAR]` largura e se é configurável.
- **Menu bar item group:** agrupa vários itens sob um único ícone. **Escopo v1 (prioridade alta).** `[CONFIRMAR]` comportamento completo: aparência do ícone do grupo, como os itens do grupo são exibidos ao clicar, como o grupo é nomeado e editado, e como os itens entram e saem do grupo.

### 2.4 Permissões

- `[CONFIRMAR]` Quais permissões são pedidas (Accessibility, Screen Recording) e em que momento, além do que aparece na aba sem elas.

---

## 3. About

Layout observado: ícone grande do app, nome, versão, bloco de licença/trial, links, Debug Logs e botão Quit.

Versão g-bar (sem licença/trial):

| Elemento | Comportamento |
|---|---|
| Ícone + nome "g-bar" + versão | Versão lida do bundle (fonte monoespaçada). |
| Acknowledgments | Abre a lista de créditos/licenças de terceiros. |
| Website | Abre o site do projeto no navegador. |
| Support | Abre a página de suporte/issues. |
| Feedback | Abre o canal de feedback. `[DECIDIR]` e-mail ou GitHub issues. |
| Debug Logs | Exporta/abre os logs do app para anexar em pedidos de suporte. Nota: "Se estiver com problemas, anexe estes logs ao pedido de suporte." |
| Quit g-bar | Botão que encerra o app. |

Removido (não se aplica): Buy Now, Enter License Key, contagem do trial e aviso de expiração da beta.
