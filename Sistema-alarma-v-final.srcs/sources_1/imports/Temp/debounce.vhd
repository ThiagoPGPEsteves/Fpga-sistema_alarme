--------------------------------------------------------------------------------
-- debounce.vhd  -  Anti-repique + saida estavel + pulso de borda de subida
-- Amostra a entrada a cada 'sample_tick' (ex.: ~1 kHz) e exige N amostras
-- iguais para mudar a saida. Tambem gera 'rise' (1 ciclo) na borda de subida.
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity debounce is
    generic (
        STABLE_COUNT : integer := 8        -- amostras estaveis necessarias
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        sample_tick : in  std_logic;       -- enable de amostragem (ex.: 1 kHz)
        noisy_in    : in  std_logic;
        clean_out   : out std_logic;       -- nivel estavel
        rise        : out std_logic        -- pulso 1 ciclo na borda de subida
    );
end debounce;

architecture rtl of debounce is
    signal cont   : unsigned(7 downto 0) := (others => '0');
    signal state  : std_logic := '0';
    signal state_d: std_logic := '0';
begin
    process(clk, rst)
    begin
        if rst = '1' then
            cont    <= (others => '0');
            state   <= '0';
            state_d <= '0';
            rise    <= '0';
        elsif rising_edge(clk) then
            rise <= '0';
            if sample_tick = '1' then
                if noisy_in /= state then
                    if cont = to_unsigned(STABLE_COUNT - 1, cont'length) then
                        state <= noisy_in;
                        cont  <= (others => '0');
                    else
                        cont <= cont + 1;
                    end if;
                else
                    cont <= (others => '0');
                end if;
            end if;
            -- deteccao de borda (a cada clock, sobre o nivel estavel)
            state_d <= state;
            if (state = '1') and (state_d = '0') then
                rise <= '1';
            end if;
        end if;
    end process;

    clean_out <= state;
end rtl;
