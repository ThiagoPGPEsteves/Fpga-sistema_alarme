--------------------------------------------------------------------------------
-- keypad_4x4.vhd  -  Varredura de teclado matricial 4x4 (R17)
-- [CORRIGIDO + REMAPEADO para a fiacao fisica real desta maquete]
--
-- A logica de varredura ja estava correta; o teclado responde. Porem as linhas
-- e colunas estao conectadas em ordem trocada/invertida em relacao ao mapa
-- padrao, entao a tabela mapa() abaixo foi ajustada para casar com a fiacao
-- atual (verificado tecla a tecla pelos LEDs). Assim NAO e preciso refazer
-- a fiacao. Valores de saida: 0..9, A=10, B=11, C=12, D=13, *=14, #=15.
--
-- (Se um dia voce refizer a fiacao na ordem padrao do XDC, basta restaurar a
--  tabela mapa() original.)
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity keypad_4x4 is
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        scan_tick : in  std_logic;                  -- ~1 kHz
        linhas    : in  std_logic_vector(3 downto 0); -- rows (ativo baixo)
        colunas   : out std_logic_vector(3 downto 0); -- cols (ativo baixo)
        key_val   : out unsigned(3 downto 0);
        key_valid : out std_logic
    );
end keypad_4x4;

architecture rtl of keypad_4x4 is
    signal col_idx    : integer range 0 to 3 := 0;
    signal col_sig    : std_logic_vector(3 downto 0) := "1110"; -- col0 ativa
    signal val_reg    : unsigned(3 downto 0) := (others => '0');

    signal viu        : std_logic := '0';
    signal key_down   : std_logic := '0';
    signal key_down_d : std_logic := '0';

    -- Tabela ajustada a fiacao real (verificada pelos LEDs).
    function mapa(col : integer; lin : integer) return integer is
    begin
        case col is
            when 0 =>
                case lin is when 0=>return 13; when 1=>return 15; when 2=>return 0;  when others=>return 14; end case;
            when 1 =>
                case lin is when 0=>return 12; when 1=>return 9;  when 2=>return 8;  when others=>return 7;  end case;
            when 2 =>
                case lin is when 0=>return 11; when 1=>return 6;  when 2=>return 5;  when others=>return 4;  end case;
            when others => -- col 3
                case lin is when 0=>return 10; when 1=>return 3;  when 2=>return 2;  when others=>return 1;  end case;
        end case;
    end function;
begin
    process(clk, rst)
        variable lin_idx  : integer range 0 to 3;
        variable achou    : boolean;
        variable prox_col : integer range 0 to 3;
    begin
        if rst = '1' then
            col_idx <= 0; col_sig <= "1110";
            val_reg <= (others=>'0');
            viu <= '0'; key_down <= '0'; key_down_d <= '0';
            key_valid <= '0';
        elsif rising_edge(clk) then
            key_valid <= '0';

            if scan_tick = '1' then
                -- 1) le as linhas da coluna energizada
                achou := false; lin_idx := 0;
                for i in 0 to 3 loop
                    if linhas(i) = '0' then
                        lin_idx := i;
                        achou   := true;
                    end if;
                end loop;

                if achou then
                    val_reg <= to_unsigned(mapa(col_idx, lin_idx), 4);
                end if;

                -- 2) proxima coluna
                if col_idx = 3 then prox_col := 0; else prox_col := col_idx + 1; end if;

                -- 3) consolida key_down ao fechar o ciclo (cobre a coluna 4 via 'achou')
                if prox_col = 0 then
                    if achou then key_down <= '1'; else key_down <= viu; end if;
                    viu <= '0';
                else
                    if achou then viu <= '1'; end if;
                end if;

                col_idx <= prox_col;
                case prox_col is
                    when 0      => col_sig <= "1110";
                    when 1      => col_sig <= "1101";
                    when 2      => col_sig <= "1011";
                    when others => col_sig <= "0111";
                end case;
            end if;

            -- 4) pulso unico na borda de nova tecla
            key_down_d <= key_down;
            if key_down = '1' and key_down_d = '0' then
                key_valid <= '1';
            end if;
        end if;
    end process;

    colunas <= col_sig;
    key_val <= val_reg;
end rtl;