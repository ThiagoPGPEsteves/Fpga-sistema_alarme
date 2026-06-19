--------------------------------------------------------------------------------
-- temporizador.vhd  -  Retardo programavel 0..120 s (R03)
-- 'carrega' captura 'segundos_set' (0..120). Em 'roda'=1 conta para baixo a 1 Hz.
-- 'zerado'=1 quando chega a zero. 'segundos_atual' expoe a contagem (p/ display).
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity temporizador is
    port (
        clk            : in  std_logic;
        rst            : in  std_logic;
        tick_1hz       : in  std_logic;                  -- enable de 1 Hz
        carrega        : in  std_logic;                  -- pulso: carrega segundos_set
        roda           : in  std_logic;                  -- 1 = conta regressivo
        segundos_set   : in  unsigned(6 downto 0);       -- 0..120
        segundos_atual : out unsigned(6 downto 0);
        zerado         : out std_logic
    );
end temporizador;

architecture rtl of temporizador is
    signal cont : unsigned(6 downto 0) := (others => '0');
begin
    process(clk, rst)
    begin
        if rst = '1' then
            cont <= (others => '0');
        elsif rising_edge(clk) then
            if carrega = '1' then
                if segundos_set > to_unsigned(120, 7) then
                    cont <= to_unsigned(120, 7);
                else
                    cont <= segundos_set;
                end if;
            elsif roda = '1' and tick_1hz = '1' then
                if cont > 0 then
                    cont <= cont - 1;
                end if;
            end if;
        end if;
    end process;

    segundos_atual <= cont;
    zerado <= '1' when cont = 0 else '0';
end rtl;
