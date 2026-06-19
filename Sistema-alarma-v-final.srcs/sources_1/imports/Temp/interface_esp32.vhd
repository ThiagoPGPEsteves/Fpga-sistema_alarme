--------------------------------------------------------------------------------
-- interface_esp32.vhd  -  Ponte UART FPGA <-> ESP32 + watchdog (R10, R11)
-- Contem: uart_tx, uart_rx e a logica de framing/watchdog (interface_esp32).
--
-- Frame enviado ao ESP32 (4 bytes), disparado em borda de 'trigger' e a cada
-- heartbeat (~1 s):  0xAA | status(=estado_cod) | zonas(4:0) | checksum(xor)
--   -> o ESP32 sabe EXATAMENTE quais zonas foram violadas (requisito do enunciado).
-- ACK esperado do ESP32 = 0x55 (confirma envio de e-mail/SMS).
-- WATCHDOG: em DISPARANDO, se nao chegar ACK dentro de WD_MS, pulsa esp_reset
--           (assume travamento do ESP32 - slide 6).
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--========================= UART TX =========================--
entity uart_tx is
    generic ( DIV : integer := 10417 );      -- 100MHz / 9600
    port (
        clk   : in  std_logic;
        rst   : in  std_logic;
        send  : in  std_logic;
        data  : in  std_logic_vector(7 downto 0);
        busy  : out std_logic;
        tx    : out std_logic
    );
end uart_tx;

architecture rtl of uart_tx is
    type st_t is (IDLE, START, DADOS, STOP);
    signal st   : st_t := IDLE;
    signal cont : integer range 0 to DIV := 0;
    signal bit_i: integer range 0 to 7 := 0;
    signal sh   : std_logic_vector(7 downto 0) := (others=>'0');
begin
    process(clk, rst)
    begin
        if rst = '1' then
            st <= IDLE; tx <= '1'; busy <= '0'; cont <= 0; bit_i <= 0;
        elsif rising_edge(clk) then
            case st is
                when IDLE =>
                    tx <= '1'; busy <= '0';
                    if send = '1' then
                        sh <= data; busy <= '1'; cont <= 0; st <= START;
                    end if;
                when START =>
                    tx <= '0'; busy <= '1';
                    if cont = DIV-1 then cont <= 0; bit_i <= 0; st <= DADOS;
                    else cont <= cont+1; end if;
                when DADOS =>
                    tx <= sh(bit_i);
                    if cont = DIV-1 then
                        cont <= 0;
                        if bit_i = 7 then st <= STOP; else bit_i <= bit_i+1; end if;
                    else cont <= cont+1; end if;
                when STOP =>
                    tx <= '1';
                    if cont = DIV-1 then cont <= 0; st <= IDLE; busy <= '0';
                    else cont <= cont+1; end if;
            end case;
        end if;
    end process;
end rtl;

--========================= UART RX =========================--
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_rx is
    generic ( DIV : integer := 10417 );
    port (
        clk   : in  std_logic;
        rst   : in  std_logic;
        rx    : in  std_logic;
        data  : out std_logic_vector(7 downto 0);
        valid : out std_logic
    );
end uart_rx;

architecture rtl of uart_rx is
    type st_t is (IDLE, START, DADOS, STOP);
    signal st   : st_t := IDLE;
    signal cont : integer range 0 to DIV := 0;
    signal bit_i: integer range 0 to 7 := 0;
    signal sh   : std_logic_vector(7 downto 0) := (others=>'0');
begin
    process(clk, rst)
    begin
        if rst = '1' then
            st <= IDLE; valid <= '0'; cont <= 0; bit_i <= 0;
        elsif rising_edge(clk) then
            valid <= '0';
            case st is
                when IDLE =>
                    if rx = '0' then cont <= 0; st <= START; end if;
                when START =>
                    if cont = (DIV/2)-1 then cont <= 0; st <= DADOS; bit_i <= 0;
                    else cont <= cont+1; end if;
                when DADOS =>
                    if cont = DIV-1 then
                        cont <= 0; sh(bit_i) <= rx;
                        if bit_i = 7 then st <= STOP; else bit_i <= bit_i+1; end if;
                    else cont <= cont+1; end if;
                when STOP =>
                    if cont = DIV-1 then
                        cont <= 0; st <= IDLE;
                        data <= sh; valid <= '1';
                    else cont <= cont+1; end if;
            end case;
        end if;
    end process;
end rtl;

--==================== INTERFACE + WATCHDOG ====================--
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity interface_esp32 is
    generic (
        CLK_HZ : integer := 100_000_000;
        WD_MS  : integer := 8000             -- timeout do watchdog (ms)
    );
    port (
        clk            : in  std_logic;
        rst            : in  std_logic;
        tick_1hz       : in  std_logic;
        trigger        : in  std_logic;                  -- DISPARANDO
        estado_cod     : in  std_logic_vector(2 downto 0);
        zonas_violadas : in  std_logic_vector(4 downto 0);
        rx             : in  std_logic;                  -- do ESP32
        tx             : out std_logic;                  -- ao ESP32
        esp_reset      : out std_logic;                  -- 1 = reseta ESP32
        -- comandos vindos do APP (decodificados do stream do ESP32)
        app_toggle     : out std_logic;                  -- 0x41 'A' = armar
        app_desarma    : out std_logic;                  -- 0x44 'D' = desarmar
        app_bypass_v   : out std_logic;                  -- 0x61..0x65 = bypass zona
        app_bypass_z   : out unsigned(2 downto 0)        -- 0..4
    );
end interface_esp32;

architecture rtl of interface_esp32 is
    component uart_tx is
        generic ( DIV : integer );
        port ( clk,rst,send : in std_logic; data : in std_logic_vector(7 downto 0);
               busy : out std_logic; tx : out std_logic );
    end component;
    component uart_rx is
        generic ( DIV : integer );
        port ( clk,rst,rx : in std_logic; data : out std_logic_vector(7 downto 0);
               valid : out std_logic );
    end component;

    signal tx_send : std_logic := '0';
    signal tx_data : std_logic_vector(7 downto 0) := (others=>'0');
    signal tx_busy : std_logic;
    signal rx_data : std_logic_vector(7 downto 0);
    signal rx_valid: std_logic;

    type frame_st is (PARADO, B0, B1, B2, B3);
    signal fst : frame_st := PARADO;
    signal trig_d : std_logic := '0';
    signal start_frame : std_logic := '0';

    signal st_byte : std_logic_vector(7 downto 0);
    signal zn_byte : std_logic_vector(7 downto 0);
    signal ck_byte : std_logic_vector(7 downto 0);

    signal estado_d : std_logic_vector(2 downto 0) := "000";  -- estado anterior (deteccao de mudanca)
    signal wd_cont : integer range 0 to 600 := 0;  -- contagem em "ticks de 1 Hz"*?
    signal ack_ok  : std_logic := '0';
    constant WD_S  : integer := WD_MS / 1000;
begin
    st_byte <= "00000" & estado_cod;
    zn_byte <= "000" & zonas_violadas;
    ck_byte <= x"AA" xor st_byte xor zn_byte;

    U_TX : uart_tx generic map ( DIV => CLK_HZ/9600 )
        port map ( clk=>clk, rst=>rst, send=>tx_send, data=>tx_data,
                   busy=>tx_busy, tx=>tx );
    U_RX : uart_rx generic map ( DIV => CLK_HZ/9600 )
        port map ( clk=>clk, rst=>rst, rx=>rx, data=>rx_data, valid=>rx_valid );

    -- gera start_frame: (a) em qualquer MUDANCA de estado, (b) na borda do
    -- disparo e (c) num heartbeat de 1 Hz SEMPRE (para o site refletir
    -- armado/desarmado/entrada, nao so o disparo).
    process(clk, rst)
    begin
        if rst = '1' then
            trig_d <= '0'; estado_d <= "000"; start_frame <= '0';
        elsif rising_edge(clk) then
            start_frame <= '0';
            trig_d   <= trigger;
            estado_d <= estado_cod;
            if estado_cod /= estado_d then
                start_frame <= '1';                      -- mudou de estado
            elsif (trigger = '1' and trig_d = '0') then
                start_frame <= '1';                      -- borda do disparo
            elsif tick_1hz = '1' then
                start_frame <= '1';                      -- heartbeat 1 Hz sempre
            end if;
        end if;
    end process;

    -- maquina de envio do frame de 4 bytes
    process(clk, rst)
    begin
        if rst = '1' then
            fst <= PARADO; tx_send <= '0';
        elsif rising_edge(clk) then
            tx_send <= '0';
            case fst is
                when PARADO =>
                    if start_frame = '1' and tx_busy = '0' then
                        tx_data <= x"AA"; tx_send <= '1'; fst <= B0;
                    end if;
                when B0 =>
                    if tx_busy = '0' and tx_send = '0' then
                        tx_data <= st_byte; tx_send <= '1'; fst <= B1;
                    end if;
                when B1 =>
                    if tx_busy = '0' and tx_send = '0' then
                        tx_data <= zn_byte; tx_send <= '1'; fst <= B2;
                    end if;
                when B2 =>
                    if tx_busy = '0' and tx_send = '0' then
                        tx_data <= ck_byte; tx_send <= '1'; fst <= B3;
                    end if;
                when B3 =>
                    if tx_busy = '0' and tx_send = '0' then
                        fst <= PARADO;
                    end if;
            end case;
        end if;
    end process;

    -- watchdog: espera ACK 0x55 durante DISPARANDO
    process(clk, rst)
    begin
        if rst = '1' then
            wd_cont <= 0; ack_ok <= '0'; esp_reset <= '0';
        elsif rising_edge(clk) then
            esp_reset <= '0';
            if trigger = '0' then
                wd_cont <= 0; ack_ok <= '0';
            else
                if rx_valid = '1' and rx_data = x"55" then
                    ack_ok <= '1';
                end if;
                if tick_1hz = '1' then
                    if ack_ok = '0' then
                        if wd_cont = WD_S then
                            esp_reset <= '1';            -- timeout: reseta ESP32
                            wd_cont   <= 0;
                        else
                            wd_cont <= wd_cont + 1;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- decodifica comandos do APP recebidos do ESP32
    process(clk, rst)
    begin
        if rst = '1' then
            app_toggle <= '0'; app_desarma <= '0';
            app_bypass_v <= '0'; app_bypass_z <= (others=>'0');
        elsif rising_edge(clk) then
            app_toggle <= '0'; app_desarma <= '0'; app_bypass_v <= '0';
            if rx_valid = '1' then
                case rx_data is
                    when x"41" => app_toggle  <= '1';   -- 'A'
                    when x"44" => app_desarma <= '1';   -- 'D'
                    when x"61" => app_bypass_v <= '1'; app_bypass_z <= "000";
                    when x"62" => app_bypass_v <= '1'; app_bypass_z <= "001";
                    when x"63" => app_bypass_v <= '1'; app_bypass_z <= "010";
                    when x"64" => app_bypass_v <= '1'; app_bypass_z <= "011";
                    when x"65" => app_bypass_v <= '1'; app_bypass_z <= "100";
                    when others => null;
                end case;
            end if;
        end if;
    end process;
end rtl;