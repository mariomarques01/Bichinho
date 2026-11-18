# Estado do desenvolvimento

## Etapa 1

Projeto Godot 4.6.3 com GDScript, Compatibility, referência de 1080 × 1920, orientação retrato e limite configurado de 30 FPS. O quarto inclui piso de tábuas, tapete, cama, janela, estante, plantas e luminária. O Evolin usa o novo GLB texturizado com 19.456 triângulos e 37 ossos. O material suaviza os reflexos e o mapa de normais, e um osso controla o balanço da cauda. As texturas são importadas internamente como Basis Universal. O modelo tem movimentos de respiração, balanço, pulo e reação corporal ao carinho. O Evolin pisca e fecha os olhos ao receber carinho. O efeito usa um shader de pálpebras aplicado à malha importada durante a reação.

A interface acompanha as reações do Evolin, mostra corações e oferece botões para carinho, pulo e ciclo dia/noite. O toque primário é convertido em eventos de mouse pela Godot. A posição é projetada pela câmera e testada contra a área de colisão do personagem. Há um intervalo mínimo entre carinhos para limitar a emissão dos efeitos.

## Primeiro incremento de jogabilidade

O HUD mostra fome, higiene, energia, felicidade, XP, nível e moedas. Os seis menus permitem alimentar com cinco itens, tomar banho por arraste, descansar por 30, 60 ou 180 minutos, ganhar felicidade com carinho, jogar Memória Mágica com três pares e descobrir três receitas. As ações gravam um perfil local. O descanso recupera energia com base no tempo decorrido, inclusive com o jogo fechado.

## Arquivos

| Área | Arquivos |
| --- | --- |
| Projeto | `project.godot`, `export_presets.cfg` |
| Cenas | `main.tscn`, `room.tscn`, `evolin.tscn`, `hud.tscn` |
| Scripts | `main.gd`, `room.gd`, `geometry.gd`, `evolin.gd`, `hud.gd` |
| Web | `web/index.html`, `web/shell.html` |
| Teste | `tests/smoke_test.gd` |
| Documentação | `README.md`, `docs/PLANO_TECNICO.md` |

## Testes executados

- Importação por `godot --headless --editor --path . --import`.
- Inicialização da cena principal por `godot --headless --path . --quit-after 50`.
- Teste de integração por `godot --headless --path . --script res://tests/smoke_test.gd`. Vinte e uma verificações aprovadas, cobrindo piscada, reação facial ao carinho, acerto e erro de toque, arraste, ciclo de vida dos corações, intervalo mínimo, iluminação e pulo.
- Renderização Compatibility em Linux via Mesa llvmpipe. O driver virtual reporta uma advertência de VSync.

- Exportação Web sem threads com os templates oficiais da Godot 4.6.3. O GitHub Pages serviu o HTML, JavaScript, WebAssembly e PCK com HTTP 200.
- Renderização da página pública no Chromium em retrato com emulação de toque. O botão de iluminação alternou o ambiente e um toque no Evolin disparou a reação e mudou a mensagem da interface.
- Download do ZIP publicado, extração em pasta limpa, importação e repetição das verificações headless.

## Publicação

O código e o projeto editável ficam na branch `main`. O GitHub Pages serve a branch `gh-pages` e disponibiliza o ZIP editável pelo link no README.

## Pendências e limitações

Evolução, personalidade completa, Pula EVO, Pintura Maluca, cenários próprios para as atividades, missões, economia completa, áudio e backup de salvamento ficam para as próximas etapas. O enquadramento e a área segura precisam ser confirmados no editor Godot para Android. Exportação APK, desempenho em aparelho e iOS seguem sem validação.
