## basys3.xdc - Constraints do Alarme Perimetrico (Basys 3 / Artix-7 xc7a35tcpg236-1)
## ATUALIZADO: 1 sensor por zona (5 sensores no total).
## Ajuste os pinos dos Pmods conforme a fiacao real da sua maquete.
## Sensores, keypad, ESP32 e atuadores ficam nos conectores Pmod (JA/JB/JC/JXADC).

## ---------------- Clock 100 MHz ----------------
set_property -dict { PACKAGE_PIN W5  IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk -period 10.00 -waveform {0 5} [get_ports clk]

## ---------------- Botoes ----------------
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports btn_reset]    ;# btnC
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports btn_secreto]  ;# btnU (escondido)

## ---------------- Switches: segundos programados 0..120 (sw[6:0]) ----------------
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports {sw[0]}]
set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } [get_ports {sw[1]}]
set_property -dict { PACKAGE_PIN W16 IOSTANDARD LVCMOS33 } [get_ports {sw[2]}]
set_property -dict { PACKAGE_PIN W17 IOSTANDARD LVCMOS33 } [get_ports {sw[3]}]
set_property -dict { PACKAGE_PIN W15 IOSTANDARD LVCMOS33 } [get_ports {sw[4]}]
set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports {sw[5]}]
set_property -dict { PACKAGE_PIN W14 IOSTANDARD LVCMOS33 } [get_ports {sw[6]}]

## ---------------- Display 7 segmentos ----------------
set_property -dict { PACKAGE_PIN W7  IOSTANDARD LVCMOS33 } [get_ports {seg[0]}] ;# a
set_property -dict { PACKAGE_PIN W6  IOSTANDARD LVCMOS33 } [get_ports {seg[1]}] ;# b
set_property -dict { PACKAGE_PIN U8  IOSTANDARD LVCMOS33 } [get_ports {seg[2]}] ;# c
set_property -dict { PACKAGE_PIN V8  IOSTANDARD LVCMOS33 } [get_ports {seg[3]}] ;# d
set_property -dict { PACKAGE_PIN U5  IOSTANDARD LVCMOS33 } [get_ports {seg[4]}] ;# e
set_property -dict { PACKAGE_PIN V5  IOSTANDARD LVCMOS33 } [get_ports {seg[5]}] ;# f
set_property -dict { PACKAGE_PIN U7  IOSTANDARD LVCMOS33 } [get_ports {seg[6]}] ;# g
set_property -dict { PACKAGE_PIN U2  IOSTANDARD LVCMOS33 } [get_ports {an[0]}]
set_property -dict { PACKAGE_PIN U4  IOSTANDARD LVCMOS33 } [get_ports {an[1]}]
set_property -dict { PACKAGE_PIN V4  IOSTANDARD LVCMOS33 } [get_ports {an[2]}]
set_property -dict { PACKAGE_PIN W4  IOSTANDARD LVCMOS33 } [get_ports {an[3]}]

## ---------------- LEDs de status ----------------
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN E19 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN V19 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } [get_ports {led[4]}]
set_property -dict { PACKAGE_PIN U15 IOSTANDARD LVCMOS33 } [get_ports {led[5]}]
set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports {led[6]}]
set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 } [get_ports {led[7]}]
set_property -dict { PACKAGE_PIN V13 IOSTANDARD LVCMOS33 } [get_ports {led[8]}]
set_property -dict { PACKAGE_PIN V3  IOSTANDARD LVCMOS33 } [get_ports {led[9]}]
set_property -dict { PACKAGE_PIN W3  IOSTANDARD LVCMOS33 } [get_ports {led[10]}]
set_property -dict { PACKAGE_PIN U3  IOSTANDARD LVCMOS33 } [get_ports {led[11]}]
set_property -dict { PACKAGE_PIN P3  IOSTANDARD LVCMOS33 } [get_ports {led[12]}]
set_property -dict { PACKAGE_PIN N3  IOSTANDARD LVCMOS33 } [get_ports {led[13]}]
set_property -dict { PACKAGE_PIN P1  IOSTANDARD LVCMOS33 } [get_ports {led[14]}]
set_property -dict { PACKAGE_PIN L1  IOSTANDARD LVCMOS33 } [get_ports {led[15]}]

## ================= Pmod JA : sensores das zonas 1 a 4 =================
set_property -dict { PACKAGE_PIN J1  IOSTANDARD LVCMOS33 } [get_ports reed1]   ;# JA1  Z1 reed switch
set_property -dict { PACKAGE_PIN L2  IOSTANDARD LVCMOS33 } [get_ports reed2]   ;# JA2  Z2 reed switch
set_property -dict { PACKAGE_PIN J2  IOSTANDARD LVCMOS33 } [get_ports obst3]   ;# JA3  Z3 obstaculo a laser
set_property -dict { PACKAGE_PIN G2  IOSTANDARD LVCMOS33 } [get_ports vl4_det] ;# JA4  Z4 VL53L0X (detectado)

## ================= Pmod JB : sensor da zona 5 (HC-SR04) + atuadores =================
set_property -dict { PACKAGE_PIN A14 IOSTANDARD LVCMOS33 } [get_ports echo5]    ;# JB1  Z5 HC-SR04 echo
set_property -dict { PACKAGE_PIN A16 IOSTANDARD LVCMOS33 } [get_ports trig5]    ;# JB2  Z5 HC-SR04 trigger
set_property -dict { PACKAGE_PIN A15 IOSTANDARD LVCMOS33 } [get_ports sirene_o] ;# JB7
set_property -dict { PACKAGE_PIN A17 IOSTANDARD LVCMOS33 } [get_ports estrobo_o];# JB8 -> 555/TIP31 (LED 10W)
set_property -dict { PACKAGE_PIN C15 IOSTANDARD LVCMOS33 } [get_ports bomba_o]  ;# JB9 -> rele/MOSFET bomba
set_property -dict { PACKAGE_PIN C16 IOSTANDARD LVCMOS33 } [get_ports esp_rst]  ;# JB10 -> EN/RST do ESP32

## ================= Pmod JC : keypad 4x4 =================
set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33 } [get_ports {kp_linhas[0]}]  ;# JC1
set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 } [get_ports {kp_linhas[1]}]  ;# JC2
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports {kp_linhas[2]}]  ;# JC3
set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports {kp_linhas[3]}]  ;# JC4
set_property -dict { PACKAGE_PIN L17 IOSTANDARD LVCMOS33 } [get_ports {kp_colunas[0]}] ;# JC7
set_property -dict { PACKAGE_PIN M19 IOSTANDARD LVCMOS33 } [get_ports {kp_colunas[1]}] ;# JC8
set_property -dict { PACKAGE_PIN P17 IOSTANDARD LVCMOS33 } [get_ports {kp_colunas[2]}] ;# JC9
set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports {kp_colunas[3]}] ;# JC10
## (habilite pull-up nas linhas do keypad)
set_property PULLUP true [get_ports {kp_linhas[*]}]

## ================= Pmod JXADC : UART ESP32 =================
set_property -dict { PACKAGE_PIN J3  IOSTANDARD LVCMOS33 } [get_ports esp_rx] ;# JXADC1  (ESP32 TX -> FPGA RX)
set_property -dict { PACKAGE_PIN L3  IOSTANDARD LVCMOS33 } [get_ports esp_tx] ;# JXADC2  (FPGA TX -> ESP32 RX)

## ---------------- Configuracao ----------------
set_property CFGBVS VCCO        [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
