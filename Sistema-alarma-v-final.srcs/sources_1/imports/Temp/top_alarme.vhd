--------------------------------------------------------------------------------
-- top_alarme.vhd  -  Topo da central perimetrica em FPGA (Basys 3 / Artix-7) (R01)
-- Integra: MEF + gerenciador de zonas (1 sensor/zona) + temporizador 0..120s
--          + display A/d/U + keypad 4x4 + controle de acesso + contramedidas
--          + interface/watchdog ESP32. Registrador de mascara de bypass por zona
--          alimentado por keypad E pelo app (via ESP32).
--
-- ATUALIZADO: 1 sensor por zona (antes 2 com fusao). Mapeamento:
--   Z1 = reed switch                   (reed1)
--   Z2 = reed switch                   (reed2)
--   Z3 = sensor de obstaculo a laser   (obst3)
--   Z4 = proximidade a laser VL53L0X   (vl4_det)  -- linha digital 'detectado'
--   Z5 = proximidade ultrassonica      (HC-SR04: trig5/echo5)
--
-- Obs.: alguns modulos de obstaculo a laser sao ATIVO-BAIXO (saida '0' quando
--   detecta). Se for o caso do seu modulo, inverta na fiacao ou troque
--   's_obst3(1)' por 'not s_obst3(1)' na montagem do vetor 'sensores' abaixo.
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_alarme is
    port (
        clk         : in  std_logic;                       -- 100 MHz (W5)
        btn_reset   : in  std_logic;                       -- btnC
        btn_secreto : in  std_logic;                       -- botao secreto (escondido)
        sw          : in  std_logic_vector(6 downto 0);    -- segundos programados 0..120

        -- sensores das 5 zonas (1 por zona) -------------------------------------
        reed1       : in  std_logic;                       -- Z1 reed switch
        reed2       : in  std_logic;                       -- Z2 reed switch
        obst3       : in  std_logic;                       -- Z3 obstaculo a laser
        vl4_det     : in  std_logic;                       -- Z4 VL53L0X (detectado)
        echo5       : in  std_logic;                       -- Z5 HC-SR04 echo
        trig5       : out std_logic;                       -- Z5 HC-SR04 trigger

        -- keypad 4x4
        kp_linhas   : in  std_logic_vector(3 downto 0);
        kp_colunas  : out std_logic_vector(3 downto 0);

        -- ESP32
        esp_rx      : in  std_logic;                       -- ESP32 -> FPGA
        esp_tx      : out std_logic;                       -- FPGA -> ESP32
        esp_rst     : out std_logic;                       -- reset (watchdog)

        -- atuadores
        sirene_o    : out std_logic;
        estrobo_o   : out std_logic;                       -- LED 10W via 555/TIP31
        bomba_o     : out std_logic;                       -- bomba do gerador de fumaca

        -- saidas da placa
        seg         : out std_logic_vector(6 downto 0);
        an          : out std_logic_vector(3 downto 0);
        led         : out std_logic_vector(15 downto 0)
    );
end top_alarme;

architecture rtl of top_alarme is
    signal rst : std_logic;

    -- ticks
    signal t_1hz, t_1khz, t_100hz : std_logic;

    -- botao secreto
    signal sec_clean, sec_rise : std_logic;

    -- sincronizadores de sensores (1 por zona)
    signal s_reed1, s_reed2, s_obst3, s_vl4 : std_logic_vector(1 downto 0);
    signal hc5_det : std_logic;

    -- vetor de zonas (1 bit por zona)
    signal sensores : std_logic_vector(4 downto 0);

    -- keypad / acesso
    signal kp_val   : unsigned(3 downto 0);
    signal kp_valid : std_logic;
    signal cmd_toggle, cmd_desarma, kp_byp_v : std_logic;
    signal kp_byp_z : unsigned(2 downto 0);

    -- app via ESP32
    signal app_toggle, app_desarma, app_byp_v : std_logic;
    signal app_byp_z : unsigned(2 downto 0);

    -- mascara de bypass
    signal mascara : std_logic_vector(4 downto 0) := "11111";

    -- zonas / fsm / timer
    signal zonas_violadas : std_logic_vector(4 downto 0);
    signal alguma_viol    : std_logic;
    signal esp_rst_n : std_logic; 
    signal armado, sirene, contramedidas, esp_trig : std_logic;
    signal estado_cod     : std_logic_vector(2 downto 0);
    signal timer_carrega, timer_roda, zonas_limpar  : std_logic;
    signal seg_set, seg_atual : unsigned(6 downto 0);
    signal tempo_zerado : std_logic;

    signal arma_desarma_p, desarma_p : std_logic;
    signal zona_disp : unsigned(3 downto 0);
begin
    rst    <= btn_reset;
    seg_set<= unsigned(sw);

    ---------------- divisores de clock ----------------
    D1 : entity work.clk_div generic map (DIV_FACTOR => 100_000_000) port map (clk,rst,t_1hz);
    D2 : entity work.clk_div generic map (DIV_FACTOR => 100_000)     port map (clk,rst,t_1khz);
    D3 : entity work.clk_div generic map (DIV_FACTOR => 1_000_000)   port map (clk,rst,t_100hz);

    ---------------- botao secreto ----------------
    DB : entity work.debounce generic map (STABLE_COUNT => 8)
         port map (clk=>clk, rst=>rst, sample_tick=>t_1khz,
                   noisy_in=>btn_secreto, clean_out=>sec_clean, rise=>sec_rise);

    ---------------- sincronizadores de sensores ----------------
    process(clk)
    begin
        if rising_edge(clk) then
            s_reed1 <= s_reed1(0) & reed1;
            s_reed2 <= s_reed2(0) & reed2;
            s_obst3 <= s_obst3(0) & obst3;
            s_vl4   <= s_vl4(0)   & vl4_det;
        end if;
    end process;

    ---------------- HC-SR04 da zona 5 ----------------
    HC5 : entity work.sensor_hcsr04 generic map (LIMIAR_CM => 25)
          port map (clk=>clk, rst=>rst, echo=>echo5, trig=>trig5, detectado=>hc5_det);

    ---------------- montagem do vetor de zonas (1 sensor cada) ----------------
    sensores(0) <= not s_reed1(1);   -- Z1 reed switch
    sensores(1) <= not s_reed2(1);   -- Z2 reed switch
    sensores(2) <= s_obst3(1);   -- Z3 obstaculo a laser (inverter aqui se ativo-baixo)
    sensores(3) <= s_vl4(1);     -- Z4 VL53L0X (detectado)
    sensores(4) <= hc5_det;      -- Z5 HC-SR04 ultrassonico

    ---------------- gerenciador de zonas (confirmacao temporal) ----------------
    GZ : entity work.gerenciador_zonas generic map (CONFIRMA_TICKS => 5)
         port map (clk=>clk, rst=>rst, tick_10ms=>t_100hz, armado=>armado,
                   limpar_latch=>zonas_limpar, sensores=>sensores,
                   mascara_ativa=>mascara, zonas_violadas=>zonas_violadas,
                   alguma_violacao=>alguma_viol);

    ---------------- keypad + controle de acesso ----------------
    KP : entity work.keypad_4x4
         port map (clk=>clk, rst=>rst, scan_tick=>t_1khz, linhas=>kp_linhas,
                   colunas=>kp_colunas, key_val=>kp_val, key_valid=>kp_valid);

    CA : entity work.controle_acesso
         port map (clk=>clk, rst=>rst, key_valid=>kp_valid, key_val=>kp_val,
                       cmd_toggle=>cmd_toggle, cmd_desarma=>cmd_desarma,
                       bypass_valid=>kp_byp_v, bypass_zona=>kp_byp_z,
                       fsm_armado=>armado, autenticado=>open);

    ---------------- registrador da mascara de bypass ----------------
    process(clk, rst)
    begin
        if rst = '1' then
            mascara <= "11111";
        elsif rising_edge(clk) then
            if kp_byp_v = '1' then
                mascara(to_integer(kp_byp_z)) <= not mascara(to_integer(kp_byp_z));
            elsif app_byp_v = '1' then
                mascara(to_integer(app_byp_z)) <= not mascara(to_integer(app_byp_z));
            end if;
        end if;
    end process;

    ---------------- combinacao de comandos ----------------
    arma_desarma_p <= sec_rise or cmd_toggle or app_toggle;
    desarma_p      <= cmd_desarma or app_desarma;

    ---------------- temporizador 0..120 s ----------------
    TM : entity work.temporizador
         port map (clk=>clk, rst=>rst, tick_1hz=>t_1hz, carrega=>timer_carrega,
                   roda=>timer_roda, segundos_set=>seg_set, segundos_atual=>seg_atual,
                   zerado=>tempo_zerado);

    ---------------- MEF central ----------------
    FSM : entity work.fsm_central
          port map (clk=>clk, rst=>rst, tick_1hz=>t_1hz,
                    arma_desarma=>arma_desarma_p, desarma_cmd=>desarma_p,
                    alguma_violacao=>alguma_viol, tempo_zerado=>tempo_zerado,
                    timer_carrega=>timer_carrega, timer_roda=>timer_roda,
                    zonas_limpar=>zonas_limpar, armado=>armado, sirene=>sirene,
                    contramedidas=>contramedidas, esp32_trigger=>esp_trig,
                    estado_cod=>estado_cod);

    ---------------- contramedidas ----------------
    CM : entity work.controle_contramedidas generic map (FREQ_ESTROBO => 15)
         port map (clk=>clk, rst=>rst, enable=>contramedidas,
                   estrobo=>estrobo_o, bomba=>bomba_o);

    ---------------- interface ESP32 + watchdog ----------------
    IE : entity work.interface_esp32 generic map (WD_MS => 8000)
         port map (clk=>clk, rst=>rst, tick_1hz=>t_1hz, trigger=>esp_trig,
                   estado_cod=>estado_cod, zonas_violadas=>zonas_violadas,
                   rx=>esp_rx, tx=>esp_tx, esp_reset=>esp_rst_n,
                   app_toggle=>app_toggle, app_desarma=>app_desarma,
                   app_bypass_v=>app_byp_v, app_bypass_z=>app_byp_z);
    esp_rst <= not esp_rst_n;

    ---------------- zona violada (prioridade) p/ display ----------------
    process(zonas_violadas)
    begin
        if    zonas_violadas(0)='1' then zona_disp <= to_unsigned(1,4);
        elsif zonas_violadas(1)='1' then zona_disp <= to_unsigned(2,4);
        elsif zonas_violadas(2)='1' then zona_disp <= to_unsigned(3,4);
        elsif zonas_violadas(3)='1' then zona_disp <= to_unsigned(4,4);
        elsif zonas_violadas(4)='1' then zona_disp <= to_unsigned(5,4);
        else  zona_disp <= to_unsigned(0,4);
        end if;
    end process;

    ---------------- display 7 seg ----------------
    DSP : entity work.display_7seg
          port map (clk=>clk, rst=>rst, mux_tick=>t_1khz, estado_cod=>estado_cod,
                    zona=>zona_disp, segundos=>seg_atual, seg=>seg, an=>an);

    ---------------- sirene e LEDs de status ----------------
    -- TESTE KEYPAD (temporario): mostra a ultima tecla e o pulso nos LEDs
--    led(3 downto 0) <= std_logic_vector(kp_val);   -- valor 0..15 da tecla
--    led(8)          <= kp_valid;                    -- pisca a cada tecla nova
    sirene_o <= sirene;
    led(4 downto 0)  <= zonas_violadas;     -- zonas violadas
    led(9 downto 5)  <= mascara;            -- zonas ativas/bypass
    led(10)          <= armado;
    led(11)          <= sirene;
    led(12)          <= contramedidas;
    led(13)          <= esp_trig;
    led(15 downto 14)<= (others => '0');
end rtl;