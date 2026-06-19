--------------------------------------------------------------------------------
-- fsm_central.vhd  -  Unidade de Controle da central (R02) - MEF de Moore
-- "Receita de bolo": 3 processos -> registro de estado, proximo estado, saidas.
--
-- Estados:
--   E_DESARMADO  : display 'd'
--   E_SAIDA      : retardo de saida apos armar (display 'A' piscando)
--   E_ARMADO     : display 'A', monitora zonas
--   E_ENTRADA    : zona violada -> conta tempo programado (0..120 s), display 'A'+contagem
--   E_DISPARANDO : tempo zerou sem desarme -> sirene + contramedidas + ESP32 (display 'U')
--
-- Entradas de comando (pulsos de 1 ciclo):
--   arma_desarma : toggle (botao secreto OU keypad OU app/ESP32)
--   desarma_cmd  : desarme explicito (keypad/app) - prioritario
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fsm_central is
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        tick_1hz        : in  std_logic;

        arma_desarma    : in  std_logic;   -- pulso toggle
        desarma_cmd     : in  std_logic;   -- pulso desarme explicito
        alguma_violacao : in  std_logic;   -- de gerenciador_zonas
        tempo_zerado    : in  std_logic;   -- de temporizador

        -- controle do temporizador
        timer_carrega   : out std_logic;
        timer_roda      : out std_logic;
        -- controle das zonas
        zonas_limpar    : out std_logic;
        -- atuadores / status
        armado          : out std_logic;   -- 1 em E_SAIDA/E_ARMADO/E_ENTRADA/E_DISPARANDO
        sirene          : out std_logic;
        contramedidas   : out std_logic;
        esp32_trigger   : out std_logic;   -- 1 em E_DISPARANDO (manda alerta)
        estado_cod      : out std_logic_vector(2 downto 0) -- p/ display e UART
    );
end fsm_central;

architecture rtl of fsm_central is
    type estado_t is (E_DESARMADO, E_SAIDA, E_ARMADO, E_ENTRADA, E_DISPARANDO);
    signal estado, prox : estado_t := E_DESARMADO;

    constant SAIDA_SEG : integer := 10;            -- retardo de saida (s)
    signal cont_saida  : integer range 0 to 63 := 0;
begin
    --------------------------------------------------------------------
    -- 1) Registro de estado
    --------------------------------------------------------------------
    process(clk, rst)
    begin
        if rst = '1' then
            estado <= E_DESARMADO;
            cont_saida <= 0;
        elsif rising_edge(clk) then
            estado <= prox;
            if estado = E_SAIDA then
                if tick_1hz = '1' and cont_saida < SAIDA_SEG then
                    cont_saida <= cont_saida + 1;
                end if;
            else
                cont_saida <= 0;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- 2) Logica de proximo estado
    --------------------------------------------------------------------
    process(estado, arma_desarma, desarma_cmd, alguma_violacao,
            tempo_zerado, cont_saida, tick_1hz)
    begin
        prox <= estado;
        case estado is
            when E_DESARMADO =>
                if arma_desarma = '1' then
                    prox <= E_SAIDA;
                end if;

            when E_SAIDA =>
                if desarma_cmd = '1' or arma_desarma = '1' then
                    prox <= E_DESARMADO;
                elsif (cont_saida >= SAIDA_SEG) and (tick_1hz = '1') then
                    prox <= E_ARMADO;
                end if;

            when E_ARMADO =>
                if desarma_cmd = '1' or arma_desarma = '1' then
                    prox <= E_DESARMADO;
                elsif alguma_violacao = '1' then
                    prox <= E_ENTRADA;
                end if;

            when E_ENTRADA =>
                if desarma_cmd = '1' or arma_desarma = '1' then
                    prox <= E_DESARMADO;     -- desarme dentro do retardo
                elsif tempo_zerado = '1' then
                    prox <= E_DISPARANDO;
                end if;

            when E_DISPARANDO =>
                if desarma_cmd = '1' or arma_desarma = '1' then
                    prox <= E_DESARMADO;     -- so o usuario valido cancela
                end if;
        end case;
    end process;

    --------------------------------------------------------------------
    -- 3) Logica de saidas (Moore)
    --------------------------------------------------------------------
    process(estado)
    begin
        -- default
        armado        <= '0';
        sirene        <= '0';
        contramedidas <= '0';
        esp32_trigger <= '0';
        timer_carrega <= '0';
        timer_roda    <= '0';
        zonas_limpar  <= '0';

        case estado is
            when E_DESARMADO =>
                zonas_limpar <= '1';       -- limpa latch das zonas
                estado_cod   <= "000";     -- 'd'
            when E_SAIDA =>
                armado     <= '1';
                estado_cod <= "001";       -- 'A' (piscando no display)
            when E_ARMADO =>
                armado        <= '1';
                timer_carrega <= '1';      -- mantem timer pronto c/ valor do usuario
                estado_cod    <= "010";    -- 'A'
            when E_ENTRADA =>
                armado     <= '1';
                timer_roda <= '1';         -- conta regressivo
                estado_cod <= "011";       -- 'A' + contagem
            when E_DISPARANDO =>
                armado        <= '1';
                sirene        <= '1';
                contramedidas <= '1';
                esp32_trigger <= '1';
                estado_cod    <= "100";    -- 'U' (~v)
        end case;
    end process;

end rtl;
