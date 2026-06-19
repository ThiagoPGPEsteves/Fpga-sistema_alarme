--------------------------------------------------------------------------------
-- controle_contramedidas.vhd  -  2 contramedidas dissuasivas (R07)
--   1) ESTROBOSCOPIO: gera onda quadrada de ~FREQ_ESTROBO Hz quando habilitado.
--      A saida 'estrobo' controla o RESET/ENABLE do 555 (ou a porta do TIP31)
--      que aciona o LED de potencia 10W/12V (NAO um LED simples - vide slide 9/10).
--   2) GERADOR DE FUMACA: 'bomba' liga a bomba de diafragma (atomizador) que
--      pulveriza APENAS AGUA no prototipo (sem agente irritante - slide 11).
-- Ambas atuam apenas com 'enable'=1 (estado DISPARANDO).
-- Saidas via opto-acoplador / MOSFET para a parte de potencia (12V isolada).
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity controle_contramedidas is
    generic (
        CLK_HZ       : integer := 100_000_000;
        FREQ_ESTROBO : integer := 15            -- Hz (faixa util: alguns Hz a ~30/40)
    );
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        enable   : in  std_logic;               -- 1 = contramedidas ativas
        estrobo  : out std_logic;               -- -> 555/gate do LED 10W
        bomba    : out std_logic                -- -> rele/MOSFET da bomba (agua)
    );
end controle_contramedidas;

architecture rtl of controle_contramedidas is
    constant METADE : integer := CLK_HZ / (2 * FREQ_ESTROBO);
    signal cont : integer range 0 to METADE := 0;
    signal sq   : std_logic := '0';
begin
    process(clk, rst)
    begin
        if rst = '1' then
            cont <= 0; sq <= '0';
        elsif rising_edge(clk) then
            if enable = '1' then
                if cont = METADE - 1 then
                    cont <= 0; sq <= not sq;
                else
                    cont <= cont + 1;
                end if;
            else
                cont <= 0; sq <= '0';
            end if;
        end if;
    end process;

    estrobo <= sq      when enable = '1' else '0';
    bomba   <= enable;                 -- bomba liga continuamente durante o disparo
end rtl;
