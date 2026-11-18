# EVO — Seu bichinho, suas escolhas, sua evolução

EVO é um simulador de bichinho virtual em desenvolvimento. O HUD mostra as quatro necessidades, o nível, o XP e as moedas. Use o menu inferior para alimentar, dar banho, descansar, fazer carinho, jogar Memória Mágica ou misturar ingredientes. Em Alimentar, arraste um alimento até o Evolin ou selecione-o e toque em **Alimentar**. Use a seta para voltar ao quarto. Nos demais menus, toque novamente no botão da atividade para fechar. As ações e o descanso são salvos localmente.

- [Jogar no GitHub Pages](https://mariomarques01.github.io/Bichinho/)
- [Baixar o projeto editável da Godot](https://mariomarques01.github.io/Bichinho/EVO-Godot.zip)
- [Instalar o editor Godot para Android](https://godotengine.org/download/android/)

## Abrir e executar na Godot

Use a Godot **4.6.3 estável** com renderizador **Compatibility**. No Android, extraia o ZIP em uma pasta acessível ao editor, como `Documentos/EVO`. No gerenciador de projetos da Godot, selecione **Importar**, localize `project.godot` e toque em **Importar e editar**. Use o botão **Executar projeto**. No desktop, abra o mesmo arquivo pelo gerenciador de projetos e pressione **F5**.

O projeto roda localmente, sem plugins ou serviços externos. No navegador, é necessário WebGL 2.

## Estrutura

- `scenes/main` reúne a cena de entrada e o quarto.
- `scenes/pet` contém a cena reutilizável do Evolin. O modelo GLB texturizado fica em `assets/models` e as animações ficam em `scripts/pet`.
- `scenes/ui` e `scripts/ui` contêm a interface nativa.
- `scripts/core` contém a construção do quarto, a geometria compartilhada e a integração de entrada.
- `tests` contém o teste de integração. `docs` reúne o plano técnico.
- `resources`, `assets` e as pastas de atividades reservam espaço para as próximas etapas.

## Exportar APK

Em um ambiente com suporte à exportação Android, instale os templates de exportação da Godot 4.6.3. No desktop, configure o Android SDK e um JDK 17 nas configurações do editor. Em **Projeto → Exportar**, adicione o preset **Android**, defina um identificador de aplicativo e exporte um APK de depuração. Consulte os requisitos da plataforma na [documentação da Godot](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html).

## Atualizar o GitHub Pages

O site é servido pela raiz da branch `gh-pages`. Com os templates Web da Godot 4.6.3 instalados, crie uma pasta de publicação fora do projeto e execute a partir da raiz do repositório.

```sh
saida=/tmp/evo-publicacao
mkdir -p "$saida/jogo"
godot --headless --editor --path . --import
godot --headless --path . --export-release Web "$saida/jogo/index.html"
cp web/index.html "$saida/index.html"
git archive --format=zip --output="$saida/EVO-Godot.zip" HEAD
touch "$saida/.nojekyll"
```

Publique o conteúdo gerado na raiz da branch `gh-pages`. O ZIP usa os arquivos do commit atual. Salve as alterações do projeto em um commit antes de gerar a publicação.
