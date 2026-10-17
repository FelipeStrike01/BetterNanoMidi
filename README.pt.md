# Better NanoMidi

<p align="center">
  <img src="assets/branding/better-nanomidi/readme-banner.png" alt="Forma de onda MIDI abstrata na paleta grafite e terracota do Better NanoMidi" width="100%">
</p>

<p align="center">
  <strong>Mais música, menos complicação.</strong><br>
  Sua biblioteca MIDI, playlists e reprodução em um só lugar.
</p>

<p align="center">
  <a href="https://github.com/FelipeStrike01/BetterNanoMidi/actions/workflows/build.yml"><img src="https://img.shields.io/github/actions/workflow/status/FelipeStrike01/BetterNanoMidi/build.yml?branch=main&label=build&style=flat-square&color=C47B5A" alt="Status da compilação"></a>
  <img src="https://img.shields.io/badge/Python-3.12-141210?style=flat-square&logo=python&logoColor=F1EAE2" alt="Python 3.12">
  <img src="https://img.shields.io/badge/interface-PySide6%20%2B%20Qt%20Quick-C47B5A?style=flat-square" alt="PySide6 e Qt Quick">
  <img src="https://img.shields.io/badge/licença-GPL--3.0-141210?style=flat-square" alt="Licença GPL 3.0">
</p>

<p align="center">
  <a href="#recursos">Recursos</a> ·
  <a href="#executar-do-código-fonte">Início rápido</a> ·
  <a href="#compilar">Compilar</a> ·
  <a href="#estrutura">Estrutura</a> ·
  <a href="#créditos-e-licença">Créditos</a> ·
  <a href="README.md">English</a>
</p>

Better NanoMidi é um fork independente do [nanoMIDIPlayer](https://github.com/NotHammer043/nanoMIDIPlayer). Ele mantém o motor original de reprodução MIDI e acrescenta uma interface em PySide6 e Qt Quick, uma biblioteca MIDI local, busca ampliada no catálogo e Presença Avançada opcional do Discord.

## Recursos

- Reproduza arquivos MIDI pelo teclado QWERTY ou por uma saída MIDI selecionada.
- Mapeie dispositivos MIDI de entrada para teclas QWERTY.
- Reproduza faixas de bateria com mapeamentos de teclado configuráveis.
- Navegue pelos MIDIs locais e pesquise no catálogo da comunidade, com fallback para o BitMidi.
- Organize playlists MIDI em ordem e avance automaticamente para a próxima faixa.
- Configure sustain, velocity, afinação, velocidade, extensão do teclado e atalhos.
- Use a interface em português ou inglês, com Presença Avançada opcional no Discord.
- Disponível para Windows, macOS e Linux; os recursos de entrada e MIDI dependem do sistema operacional e dos dispositivos instalados.

Para manter compatibilidade com instalações existentes, as configurações e os MIDIs baixados continuam em `Documents/nanoMIDIPlayer`.

## Executar do código-fonte

Use Python 3.12 e instale as dependências fixadas:

```powershell
python -m venv .venv
.venv\Scripts\activate
python -m pip install -r requirements.txt
python main.py
```

No macOS ou Linux, ative o ambiente com `source .venv/bin/activate` antes dos dois últimos comandos.

## Compilar

Execute o script da plataforma:

```powershell
scripts\build-win.bat
```

```bash
./scripts/build-mac.sh --arch arm
./scripts/build-mac.sh --arch intel
./scripts/build-lnx.sh
```

A compilação do Windows gera `dist/Better NanoMid.exe`. No macOS e no Linux, o nome é `BetterNanoMidi`. O GitHub Actions compila os quatro destinos em pushes, pull requests e execuções manuais; os arquivos ficam disponíveis nos artefatos da execução.

As atualizações automáticas ficam desativadas até o Better NanoMidi ter seu próprio repositório de releases. O aplicativo não baixa executáveis do projeto original.

## Estrutura

| Caminho | Conteúdo |
|---|---|
| `ui/qml/` | Interface Qt Quick e componentes reutilizáveis |
| `ui/controller.py` | Ponte entre Python e QML |
| `modules/` | Reprodução MIDI, entrada, configurações e serviços |
| `assets/` | Padrões do app, marca, fontes e conteúdo About |
| `api/` | Dados padrão e código-fonte opcional do atualizador |
| `scripts/` | Scripts de compilação por plataforma e compilação do shader |
| `build-portable/` | Spec do PyInstaller para Windows e hooks de coleta do Qt |

## Créditos e licença

Better NanoMidi usa como base o trabalho de **NotHammer043 (NotHammer)** e dos colaboradores do nanoMIDIPlayer original. Este é um fork independente, não uma versão oficial daquele projeto.

O projeto usa a licença **GNU GPL v3**. Consulte [`LICENSE`](LICENSE) e [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
