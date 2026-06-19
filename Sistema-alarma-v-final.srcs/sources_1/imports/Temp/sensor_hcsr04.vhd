--------------------------------------------------------------------------------
-- sensor_hcsr04.vhd  -  Condicionamento do sensor de ultrassom HC-SR04
-- Gera pulso de trigger (10 us) a cada ~60 ms, mede a largura do echo e
-- ativa 'detectado' quando a distancia medida e menor que LIMIAR_CM.
--   distancia[cm] = tempo_echo[us] / 58   (eco ida+volta)
--   t_echo[us]    = ciclos_de_echo / 100  (clk = 100 MHz -> 100 ciclos/us)
-- Limiar em ciclos = LIMIAR_CM * 58 * 100
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sensor_hcsr04 is
    generic (
        CLK_HZ    : integer := 100_000_000;
        LIMIAR_CM : integer := 25;          -- detecta objeto a menos de 25 cm
        PERIODO_MS: integer := 60           -- periodo entre disparos
    );
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        echo       : in  std_logic;
        trig       : out std_logic;
        detectado  : out std_logic          -- nivel: '1' enquanto objeto < limiar
    );
end sensor_hcsr04;

architecture rtl of sensor_hcsr04 is
    constant TRIG_CICLOS  : integer := CLK_HZ / 100_000;          -- 10 us
    constant PER_CICLOS   : integer := (CLK_HZ / 1000) * PERIODO_MS;
    constant LIMIAR_CICLOS: integer := LIMIAR_CM * 58 * (CLK_HZ / 1_000_000);

    type estado_t is (DISPARA, ESPERA_ECHO, MEDE, INTERVALO);
    signal estado     : estado_t := DISPARA;
    signal cont_per   : integer range 0 to PER_CICLOS := 0;
    signal cont_trig  : integer range 0 to TRIG_CICLOS := 0;
    signal cont_echo  : integer range 0 to 50_000_000 := 0;
    signal det_reg    : std_logic := '0';
begin
    process(clk, rst)
    begin
        if rst = '1' then
            estado    <= DISPARA;
            cont_per  <= 0; cont_trig <= 0; cont_echo <= 0;
            det_reg   <= '0'; trig <= '0';
        elsif rising_edge(clk) then
            case estado is
                when DISPARA =>
                    trig <= '1';
                    if cont_trig = TRIG_CICLOS - 1 then
                        cont_trig <= 0; trig <= '0';
                        estado <= ESPERA_ECHO;
                    else
                        cont_trig <= cont_trig + 1;
                    end if;

                when ESPERA_ECHO =>
                    if echo = '1' then
                        cont_echo <= 0;
                        estado <= MEDE;
                    end if;

                when MEDE =>
                    if echo = '1' then
                        cont_echo <= cont_echo + 1;
                    else
                        -- fim do echo: avalia distancia
                        if cont_echo < LIMIAR_CICLOS then
                            det_reg <= '1';
                        else
                            det_reg <= '0';
                        end if;
                        estado <= INTERVALO;
                    end if;

                when INTERVALO =>
                    if cont_per = PER_CICLOS - 1 then
                        cont_per <= 0;
                        estado   <= DISPARA;
                    else
                        cont_per <= cont_per + 1;
                    end if;
            end case;
        end if;
    end process;

    detectado <= det_reg;
end rtl;
