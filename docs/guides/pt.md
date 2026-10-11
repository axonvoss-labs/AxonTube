# AxonTube

[English](en.md) · [简体中文](zh-Hans.md) · [繁體中文](zh-Hant.md) · [日本語](ja.md) · [한국어](ko.md) · [Español](es.md) · [Français](fr.md) · [Deutsch](de.md) · [Italiano](it.md) · **Português** · [Русский](ru.md) · [العربية](ar.md) · [हिन्दी](hi.md) · [Türkçe](tr.md) · [Tiếng Việt](vi.md) · [ไทย](th.md) · [Bahasa Indonesia](id.md) · [Nederlands](nl.md) · [Polski](pl.md) · [Українська](uk.md) · [Svenska](sv.md) · [Dansk](da.md) · [Suomi](fi.md) · [עברית](he.md)

[README · English](../../README.md) · [README · 简体中文](../../README.zh-CN.md)

**Aprenda os idiomas do mundo mais rápido com IA.**

Versão 0.5.3 · Prévia para macOS · Apple silicon

[macOS DMG · ZIP · SHA-256](https://github.com/axonvoss-labs/AxonTube/releases/tag/v0.5.3) · [Install / 安装](../INSTALL.md)

Transforme o YouTube na sua própria sala de aula de idiomas. Use as legendas e traduções automáticas do YouTube para aprender com os vídeos que você adora: leia dois idiomas lado a lado, repita cada frase e guarde o material que importa.

**24 idiomas de interface · Legendas multilíngues**

24 é o número de idiomas disponíveis para a interface. Os idiomas das legendas dependem das faixas disponíveis no vídeo escolhido; isso não é uma promessa de fluência em 24 idiomas.

## Capturas de tela

As capturas foram feitas no aplicativo real 0.5.3. O idioma de cada captura é indicado separadamente do idioma deste documento.

### Boas-vindas e fluxo principal

![Boas-vindas e fluxo principal](../assets/interface-en.png)

As quatro ações da barra de ferramentas, os dois seletores de legendas visíveis, o slogan localizado e o estado desativado claramente indicado antes de abrir um vídeo. — Captura do aplicativo em inglês

### Prática focada em cada frase

![Prática focada em cada frase](../assets/interface-study.png)

demo.mp4 — Busca de frases, salto com um clique, frase anterior / seguinte, reprodução novamente, repetição em loop, velocidade de reprodução e acompanhamento da frase atual. — Captura do aplicativo em inglês

### Primeira e segunda legenda

![Primeira e segunda legenda](../assets/interface-caption-languages.png)

Captura real da interface em inglês com os menus independentes de legendas, definidos por padrão como inglês e chinês tradicional. — Captura do aplicativo em inglês

### Abrir um link do YouTube

![Abrir um link do YouTube](../assets/interface-youtube-dialog.png)

Captura real da caixa de diálogo de link na interface em inglês. Abrir um link inicia a reprodução e solicita as duas faixas de legendas selecionadas. — Captura do aplicativo em inglês

## Primeiros passos

### 1. Abra o YouTube

Cole o link de um vídeo. As legendas disponíveis são solicitadas automaticamente, com inglês na primeira faixa e chinês tradicional na segunda. A primeira obtenção pode levar cerca de 1 a 2 minutos; a disponibilidade não é garantida.

### 2. Escolha e pratique

Use os dois menus suspensos de legendas visíveis. Clique em uma frase para ir até ela, reproduzi-la novamente ou ativar a repetição em loop.

### 3. Salve ou exporte

Salvar vídeo permite escolher uma pasta para a mídia acessível e as legendas disponíveis. Exportar legendas bilíngues cria arquivos Word, TXT ou SRT a partir das legendas carregadas.

### 4. Ajuste ao seu jeito

Mude o idioma da interface, a velocidade de reprodução, o tamanho das legendas e o deslocamento de tempo de cada faixa. O aplicativo lembra os idiomas escolhidos para a interface e as legendas.

## Recursos disponíveis

### Duas faixas de legendas independentes

Inglês / chinês tradicional por padrão; escolha entre os originais e as traduções automáticas disponíveis no vídeo atual. Se a segunda faixa falhar, as legendas obtidas com sucesso para a primeira continuam utilizáveis.

### Prática focada em cada frase

Busca de frases, salto com um clique, frase anterior / seguinte, reprodução novamente, repetição em loop, velocidade de reprodução e acompanhamento da frase atual.

### Vídeo com legendas sincronizadas

É possível salvar enquanto as legendas carregam. Cada operação cria uma nova pasta para o vídeo acessível e, quando há legendas disponíveis, adiciona faixas SRT temporizadas e arquivos de leitura bilíngue. Também é possível salvar apenas o vídeo; o trabalho incompleto permanece em uma pasta .partial.

### Exportação para Word, TXT e SRT

Exporte as legendas disponíveis com os deslocamentos de tempo aplicados. Word e TXT associam os textos pela sobreposição de tempo. Se apenas uma faixa estiver carregada, seu conteúdo também poderá ser exportado.

### 24 interfaces localizadas

Menus, mensagens de status e o slogan de aprendizado mudam de idioma juntos. Árabe e hebraico oferecem layouts da direita para a esquerda; mudar a interface não altera o conteúdo das legendas.

### Reprodução local e controles claros

Abra arquivos locais de mídia e legendas pelo menu Arquivo. Ações indisponíveis aparecem esmaecidas com o motivo; os modos selecionados têm destaque e marcas de seleção; durante o salvamento, o aplicativo indica que está ocupado.

## Por que é útil

### De assistir a praticar em poucos passos

Quatro ações na barra de ferramentas tornam o fluxo principal direto: YouTube → Salvar vídeo → Legendas → Idioma. Não é necessário um botão extra para obter legendas.

### Material de aprendizado para guardar

Legendas temporizadas e arquivos Word / TXT de fácil leitura ajudam tanto na prática de escuta quanto na revisão posterior. As exportações usam novos destinos e preservam os arquivos originais.

### Uso local, sem chave de API de IA

Mídias locais e legendas salvas funcionam offline. O YouTube fornece as legendas do site e as traduções automáticas; o aplicativo não tem telemetria, não envia mídias locais e não exige uma chave de API de IA paga.

## Problemas em aberto e limites

### P0 · Disponibilidade de vídeos e legendas do YouTube

**Verificação do serviço real**

A última verificação online foi bloqueada pela exigência de login / verificação contra bots do YouTube. O sucesso dos downloads online nas condições atuais não foi confirmado. Antes da publicação, é necessário validar na rede prevista e com uma seleção representativa de vídeos.

### P1 · Vídeos com restrições de incorporação ou de conta

**Restrição da plataforma**

Alguns autores ou vídeos não permitem reprodução incorporada. O Google SSO dentro do aplicativo não está implementado; o atalho para o navegador usa uma sessão separada de login e reprodução. Essas restrições não podem ser apresentadas como resolvidas.

### P1 · Assinatura e testes em mais Macs

**Distribuição e compatibilidade**

O pacote tem assinatura ad hoc, sem notarização com Developer ID. Foi testado em Apple Silicon com macOS 26.5.2; macOS 27 e Macs Intel não foram testados. macOS 14 é o alvo de implantação, não uma prova de que todas as versões foram testadas.

### P2 · Qualidade do download e fidelidade das legendas

**Limites de formato e qualidade**

O salvamento usa um fluxo completo de áudio e vídeo e não combina fluxos separados de alta resolução. A importação ASS/SSA traz apenas o texto. Legendas automáticas, traduções e associação bilíngue baseada no tempo podem conter erros. A reprodução local depende do suporte a codecs. A conversão opcional com FFmpeg pode omitir faixas de áudio adicionais, HDR e legendas incorporadas.

### P2 · Histórico de aprendizado e ferramentas de estudo

**Não implementado**

Restauração do histórico de reprodução, coleções de vocabulário, revisão espaçada, OCR e extração de legendas em imagem não estão implementados. Preferências de idioma salvas não são progresso de aprendizado salvo.

### P2 · Revisão linguística por falantes nativos

**Revisão editorial**

Todos os 24 idiomas da interface e os slogans localizados passaram nas verificações de troca de idioma. Isso comprova cobertura e comportamento, mas não uma revisão profissional de cada tradução por falantes nativos.

## O que foi verificado

Para 0.5.3: passaram 105 verificações do núcleo, 138 asserções do modelo, 29 verificações de legendas, 60 de salvamento de vídeo e 317 asserções da interface nativa. Todos os 24 idiomas foram selecionados no menu real; foram revisados seis idiomas de interface e os layouts compactos em alemão.

Foram verificados a reprodução local, as exportações, as transições de estado e as caixas de diálogo nativas de salvamento. Dados de teste offline e testes de salvamento com um auxiliar simulado não provam que o YouTube permita atualmente downloads online de legendas ou vídeos. Nenhuma credencial de usuário foi importada.

[Registro detalhado de verificação](../VERIFICATION.md) · [README · EN](../../README.md) · [README · 简体中文](../../README.zh-CN.md)

[HTML (offline)](../product-guide.html#pt)

O aplicativo usa a licença MIT; os componentes de terceiros mantêm seus avisos. AxonTube não é afiliado ao YouTube, ao Google ou à Apple.

Data do documento: 2026-10-11
