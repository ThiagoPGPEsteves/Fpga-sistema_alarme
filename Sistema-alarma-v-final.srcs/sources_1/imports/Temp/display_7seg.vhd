--------------------------------------------------------------------------------
-- display_7seg.vhd  -  Driver multiplexado dos 4 digitos da Basys 3 (R06)
-- Basys 3: segmentos (seg) e anodos (an) sao ATIVOS EM NIVEL BAIXO.
-- Layout: dig3 = letra de estado (A/d/U), dig2 = zona violada (1..5 ou 0),
--         dig1 = dezena da contagem, dig0 = unidade da contagem.
-- estado_cod: 000=d, 001/010/011=A, 100=U  (vide fsm_central).
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity display_7seg is
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        mux_tick     : in  std_logic;                 -- ~1 kHz para multiplexar
        estado_cod   : in  std_logic_vector(2 downto 0);
        zona         : in  unsigned(3 downto 0);       -- 0..5
        segundos     : in  unsigned(6 downto 0);       -- 0..120
        seg          : out std_logic_vector(6 downto 0); -- a..g (ativo baixo)
        an           : out std_logic_vector(3 downto 0)  -- anodos (ativo baixo)
    );
end display_7seg;

architecture rtl of display_7seg is
    signal sel  : unsigned(1 downto 0) := (others => '0');
    signal dezena, unidade : integer range 0 to 9;
    signal val_atual : integer range 0 to 15;

    -- Vetor seg eh (6 downto 0) e o XDC liga seg(0)=a .. seg(6)=g.
    -- Logo cada literal eh interpretado como "g f e d c b a", ativo baixo (0=aceso).
    function dig7(v : integer) return std_logic_vector is
    begin
        case v is                  --  g f e d c b a
            when 0 => return "1000000";
            when 1 => return "1111001";
            when 2 => return "0100100";
            when 3 => return "0110000";
            when 4 => return "0011001";
            when 5 => return "0010010";
            when 6 => return "0000010";
            when 7 => return "1111000";
            when 8 => return "0000000";
            when 9 => return "0010000";
            when 10 => return "0001000"; -- 'A'
            when 11 => return "0100001"; -- 'd'
            when 12 => return "1000001"; -- 'U'
            when others => return "1111111"; -- apagado
        end case;
    end function;
begin
    -- separa contagem em dezena/unidade (0..120 -> mostra ate 2 digitos baixos)
    dezena  <= (to_integer(segundos) / 10) mod 10;
    unidade <= to_integer(segundos) mod 10;

    process(clk, rst)
    begin
        if rst = '1' then
            sel <= (others => '0');
        elsif rising_edge(clk) then
            if mux_tick = '1' then
                sel <= sel + 1;
            end if;
        end if;
    end process;

    process(sel, estado_cod, zona, dezena, unidade)
        variable letra : integer;
    begin
        -- mapeia estado_cod para letra
        case estado_cod is
            when "000" => letra := 11;   -- d
            when "100" => letra := 12;   -- U
            when others => letra := 10;  -- A
        end case;

        case sel is
            when "00" => an <= "1110"; val_atual <= unidade;
            when "01" => an <= "1101"; val_atual <= dezena;
            when "10" => an <= "1011"; val_atual <= to_integer(zona);
            when others => an <= "0111"; val_atual <= letra;
        end case;
    end process;

    seg <= dig7(val_atual);
end rtl;
