# Sistema de Alarme Perimetral em FPGA

Este repositório contém o código-fonte em VHDL para um Sistema de Alarme Perimetral projetado para rodar na placa de desenvolvimento **Basys 3 (Xilinx Artix-7)** utilizando o **Vivado IDE**.

## 🚀 Funcionalidades

O sistema possui gerenciamento completo de segurança, incluindo as seguintes funcionalidades:

* **5 Zonas de Sensores Independentes:**
    * **Z1 e Z2:** Sensores magnéticos (Reed Switch).
    * **Z3:** Sensor de obstáculo a laser.
    * **Z4:** Sensor de proximidade a laser (VL53L0X).
    * **Z5:** Sensor ultrassônico (HC-SR04).
* **Máquina de Estados Finita (FSM):** Controle robusto de estados da central de alarme: Desarmado, Retardo de Saída, Armado, Retardo de Entrada e Disparo.
* **Controle de Acesso:** Teclado matricial (Keypad 4x4) e botão secreto para armar/desarmar e realizar o *bypass* (ignorar) zonas específicas.
* **Temporizador Configurável:** Tempo de retardo de entrada e saída configurável entre 0 e 120 segundos utilizando os *switches* da placa.
* **Interface IoT com ESP32:** Comunicação UART bidirecional com um microcontrolador ESP32 para enviar alertas (trigger) e receber comandos via aplicativo (Armar, Desarmar, Bypass). Inclui sistema de segurança com *Watchdog*.
* **Contramedidas Automáticas:** Acionamento de Sirene, Estrobo (LED 10W de alta potência via 555/TIP31) e Bomba geradora de fumaça em caso de invasão.
* **Interface Visual (IHM):**
    * **Display de 7 Segmentos:** Mostra o estado atual da central ('d' para desarmado, 'A' piscando para saída, 'A' fixo para armado, 'U' para disparo), contagem regressiva e identificação da zona violada.
    * **LEDs de Status:** Exibem zonas ativas, zonas em bypass, status do sistema (armado/desarmado) e acionamento de contramedidas.

## 🛠️ Arquitetura do Sistema

O projeto é modularizado e inclui os seguintes componentes principais descritos em VHDL:
* `top_alarme.vhd`: Módulo topo (Top-Level) que interliga todos os subcomponentes.
* `fsm_central.vhd`: Máquina de estados (Moore) que gerencia a lógica de funcionamento e transições.
* `gerenciador_zonas.vhd`: Trata as entradas dos sensores com confirmação temporal (debounce) e registra as violações.
* `keypad_4x4.vhd` / `controle_acesso.vhd`: Varredura do teclado e validação das senhas do usuário.
* `interface_esp32.vhd`: Controlador UART e Watchdog para comunicação com o módulo Wi-Fi.
* `temporizador.vhd`: Divisor e contador para os retardos de entrada e saída.
* `controle_contramedidas.vhd`: Gerador de sinais para controle seguro dos atuadores.

## 🔌 Mapeamento de Hardware (Pinout)

As conexões de hardware na Basys 3 utilizam os conectores Pmod (detalhes no arquivo `basys3.xdc`):

| Porta / Pmod | Pino(s) | Função | Hardware Externo |
| :--- | :--- | :--- | :--- |
| **Pmod JA** | JA1 | Sensor Z1 | Reed Switch 1 |
| | JA2 | Sensor Z2 | Reed Switch 2 |
| | JA3 | Sensor Z3 | Sensor de obstáculo a laser |
| | JA4 | Sensor Z4 | Sensor VL53L0X (sinal digital) |
| **Pmod JB** | JB1 / JB2 | Sensor Z5 | HC-SR04 (Echo / Trigger) |
| | JB7 | Atuador | Sirene |
| | JB8 | Atuador | Estrobo (via CI 555 / Transistor TIP31) |
| | JB9 | Atuador | Bomba de fumaça (via Relé/MOSFET) |
| | JB10 | Controle | Reset / Enable do módulo ESP32 |
| **Pmod JC** | JC1-JC4 | Keypad Linhas | Teclado Matricial 4x4 (requer Pull-Up) |
| | JC7-JC10| Keypad Colunas | Teclado Matricial 4x4 |
| **JXADC** | JXADC1 / JXADC2 | UART | RX / TX (Comunicação FPGA ↔ ESP32) |

**Interface Integrada da Placa (On-board):**
* **Clock:** Entrada de 100 MHz (Pino W5).
* **Switches (SW0-SW6):** Configuração de tempo (0-120s).
* **Botões:** `btnC` (Reset do sistema), `btnU` (Botão Secreto).
* **Display de 7 Segmentos:** Identificação visual.
* **LEDs (LD0-LD15):** Diagnóstico rápido de portas e status do alarme.

## 💻 Como Rodar (Ambiente Vivado)

1. Crie um novo projeto no **Xilinx Vivado** selecionando a placa **Basys 3** (modelo de chip: `xc7a35tcpg236-1`).
2. Adicione todos os arquivos de código-fonte (`.vhd`) contidos no projeto ao diretório de *Design Sources*.
3. Adicione o arquivo de restrições (`basys3.xdc`) ao diretório de *Constraints*.
4. Na hierarquia do projeto, certifique-se de que o arquivo `top_alarme.vhd` esteja definido como o **Top Module**.
5. Execute as etapas de *Synthesis* e *Implementation*.
6. Clique em *Generate Bitstream* para gerar o arquivo `.bit`.
7. Conecte a sua placa Basys 3 via USB, abra o *Hardware Manager*, conecte-se ao *target* e grave o bitstream na FPGA.

## ⚠️ Observações de Hardware
* **Lógica dos Sensores:** Alguns módulos comerciais de sensores de obstáculo a laser operam em lógica ativa-baixa (enviam '0' ao detectar). Caso seja o seu cenário, altere a atribuição no arquivo `top_alarme.vhd` invertendo o sinal (utilizando a porta `not`).
* **Níveis de Tensão:** Certifique-se de adequar os níveis lógicos ao interligar os módulos periféricos de 5V (como relés ou o HC-SR04) às portas de I/O do Artix-7, que operam tipicamente a 3.3V, a fim de evitar danos à placa FPGA.
