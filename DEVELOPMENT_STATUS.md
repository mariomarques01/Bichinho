# Estado do desenvolvimento

## Etapa 1

Projeto Godot 4.6.3 com GDScript, Compatibility, referência de 1080 × 1920, orientação retrato e limite configurado de 30 FPS. O quarto inclui piso de tábuas, tapete, cama, janela, estante, plantas e luminária. O Evolin é uma cena própria com corpo, cabeça, olhos, manchas, orelhas, patas, antenas luminosas e cauda. Piscar, respirar, balançar, pular e reagir ao carinho já funcionam.

A interface acompanha as reações do Evolin, mostra corações e oferece botões para carinho, pulo e ciclo dia/noite. O toque primário é convertido em eventos de mouse pela Godot. A posição é projetada pela câmera e testada contra a área de colisão do personagem. Há um intervalo mínimo entre carinhos para limitar a emissão dos efeitos.

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
- Teste de integração por `godot --headless --path . --script res://tests/smoke_test.gd`. Nove verificações aprovadas, cobrindo acerto e erro de toque, arraste, ciclo de vida dos corações, intervalo mínimo, iluminação e pulo.
- Renderização Compatibility em Linux via Mesa llvmpipe. O driver virtual reporta uma advertência de VSync.

## Pendências e limitações

O próximo incremento é implementar necessidades, alimentação, banho, descanso persistente e carinho com efeito no progresso. Evolução, personalidade completa, minigames, laboratório, inventário, missões, economia, áudio e salvamento também ficam para as próximas etapas. O enquadramento e a área segura precisam ser confirmados no editor Godot para Android. Exportação APK, desempenho em aparelho e iOS seguem sem validação.
