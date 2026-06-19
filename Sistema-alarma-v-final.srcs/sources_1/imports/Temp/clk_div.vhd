--------------------------------------------------------------------------------
-- clk_div.vhd  -  Gerador de pulso de enable (1 ciclo) a partir do clock de 100 MHz
-- Projeto: Alarme Perimetrico FPGA - Mackenzie / Sistemas Embarcados
-- Gera um pulso 'tick' de 1 periodo de clk a cada DIV_FACTOR ciclos.
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity clk_div is
    generic (
        DIV_FACTOR : integer := 100_000_000  -- 100 MHz / DIV_FACTOR = freq do tick
    );
    port (
        clk   : in  std_logic;
        rst   : in  std_logic;
        tick  : out std_logic            -- pulso de 1 ciclo
    );
end clk_div;

architecture rtl of clk_div is
    signal cont : unsigned(31 downto 0) := (others => '0');
begin
    process(clk, rst)
    begin
        if rst = '1' then
            cont <= (others => '0');
            tick <= '0';
        elsif rising_edge(clk) then
            if cont = to_unsigned(DIV_FACTOR - 1, cont'length) then
                cont <= (others => '0');
                tick <= '1';
            else
                cont <= cont + 1;
                tick <= '0';
            end if;
        end if;
    end process;
end rtl;
