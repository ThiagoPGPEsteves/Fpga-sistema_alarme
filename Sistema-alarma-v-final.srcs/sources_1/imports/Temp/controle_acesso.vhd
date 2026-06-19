--------------------------------------------------------------------------------
-- controle_acesso.vhd  -  Interpreta o keypad (R17)
-- Operacao:
--   * Digite o PIN de 4 digitos (default 1-2-3-4), depois:
--       'A' -> ARMAR    (gera cmd_toggle, leva DESARMADO->SAIDA)
--       'D' -> DESARMAR (gera cmd_desarma, prioritario)
--   * 'B' seguido de digito 1..5 -> alterna BYPASS da zona (sem PIN, edicao local;
--     pode-se exigir PIN tambem - ver generic EXIGE_PIN_BYPASS)
--   * '*' limpa o buffer.
-- Saidas (pulsos de 1 ciclo): cmd_toggle, cmd_desarma, bypass_valid + bypass_zona.
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity controle_acesso is
    generic (
        PIN0 : integer := 1;
        PIN1 : integer := 2;
        PIN2 : integer := 3;
        PIN3 : integer := 4
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        key_valid   : in  std_logic;
        key_val     : in  unsigned(3 downto 0);
        cmd_toggle  : out std_logic;                 -- armar
        cmd_desarma : out std_logic;                 -- desarmar
        bypass_valid: out std_logic;                 -- alterna zona
        bypass_zona : out unsigned(2 downto 0);       -- 0..4
        fsm_armado  : in  std_logic;
        autenticado : out std_logic
        -- adicionar porta:
        
    );
end controle_acesso;

architecture rtl of controle_acesso is
    type buf_t is array (0 to 3) of integer range 0 to 9;
    signal buf       : buf_t := (others => 0);
    signal n_dig     : integer range 0 to 4 := 0;
    signal auth      : std_logic := '0';
    signal espera_z  : std_logic := '0';   -- aguardando digito da zona apos 'B'
    signal armado_d  : std_logic := '0';   

    function pin_ok(b : buf_t) return boolean is
    begin
        return (b(0)=PIN0 and b(1)=PIN1 and b(2)=PIN2 and b(3)=PIN3);
    end function;
begin
    process(clk, rst)
        variable k : integer;
    begin
        if rst = '1' then
            buf <= (others=>0); n_dig <= 0; auth <= '0'; espera_z <= '0'; armado_d <= '0';
            cmd_toggle <= '0'; cmd_desarma <= '0';
            bypass_valid <= '0'; bypass_zona <= (others=>'0');
        elsif rising_edge(clk) then
            cmd_toggle   <= '0';
                    cmd_desarma  <= '0';
                    bypass_valid <= '0';
                    armado_d     <= fsm_armado;
        
                    if fsm_armado /= armado_d then
                        buf <= (others=>0); n_dig <= 0; auth <= '0'; espera_z <= '0';
            end if;
            
            if key_valid = '1' then
                k := to_integer(key_val);

                if espera_z = '1' then
                    -- proximo digito apos 'B' = numero da zona (1..5)
                    if k >= 1 and k <= 5 then
                        bypass_zona  <= to_unsigned(k - 1, 3);
                        bypass_valid <= '1';
                    end if;
                    espera_z <= '0';

                elsif k <= 9 then
                    -- digito: empurra no buffer (mantem ultimos 4)
                    buf(0) <= buf(1); buf(1) <= buf(2); buf(2) <= buf(3); buf(3) <= k;
                    if n_dig < 4 then n_dig <= n_dig + 1; end if;

                elsif k = 14 then          -- '*' limpa
                    buf <= (others=>0); n_dig <= 0; auth <= '0';

                elsif k = 11 then          -- 'B' inicia bypass
                    espera_z <= '1';

                elsif k = 10 then          -- 'A' armar
                    if n_dig = 4 and pin_ok(buf) then
                        cmd_toggle <= '1';
                        auth <= '1';
                        buf <= (others=>0); n_dig <= 0;
                    end if;

                elsif k = 13 then          -- 'D' desarmar
                    if n_dig = 4 and pin_ok(buf) then
                    cmd_desarma <= '1';
                    auth <= '1';
                    buf <= (others=>0); n_dig <= 0;  -- ? limpa buffer
                    end if;
                end if;
            end if;
        end if;
    end process;

    autenticado <= auth;
end rtl;
