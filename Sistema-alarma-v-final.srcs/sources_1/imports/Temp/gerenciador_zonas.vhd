--------------------------------------------------------------------------------
-- gerenciador_zonas.vhd  -  Monitora 5 zonas (R05) com UM sensor por zona
--
-- ATUALIZADO: cada zona possui apenas 1 sensor (antes eram 2 com fusao).
--   sensores(i) = '1' indica deteccao na zona i (sinal ja condicionado).
--
-- Mapeamento de zonas (1 sensor cada):
--   Z1 = reed switch                 (sensores(0))
--   Z2 = reed switch                 (sensores(1))
--   Z3 = sensor de obstaculo a laser (sensores(2))
--   Z4 = proximidade a laser VL53L0X (sensores(3))  -- linha digital 'detectado'
--   Z5 = proximidade ultrassonica    (sensores(4))  -- HC-SR04 (modulo sensor_hcsr04)
--
-- ANTI-FALSO-POSITIVO (PDF: "Falso-positivos devem ser evitados"):
--   como agora ha um unico sensor por zona, a robustez vem de CONFIRMACAO
--   TEMPORAL: a deteccao precisa permanecer ativa por CONFIRMA_TICKS pulsos
--   de 'tick_10ms' consecutivos antes de latchar a violacao. Glitches curtos
--   sao descartados.
--
-- MASCARA: mascara_ativa(i)='0' inibe (bypass) a zona i sem afetar as demais.
-- Saidas: zonas_violadas (latch, 1 bit/zona) e alguma_violacao.
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity gerenciador_zonas is
    generic (
        CONFIRMA_TICKS : integer := 5       -- ~50 ms estaveis (tick_10ms ~100 Hz)
    );
    port (
        clk            : in  std_logic;
        rst            : in  std_logic;
        tick_10ms      : in  std_logic;                    -- enable ~100 Hz
        armado         : in  std_logic;                    -- so monitora se armado
        limpar_latch   : in  std_logic;                    -- limpa ao desarmar
        sensores       : in  std_logic_vector(4 downto 0); -- 1 sensor por zona ('1'=deteccao)
        mascara_ativa  : in  std_logic_vector(4 downto 0); -- 1=zona ativa, 0=bypass
        zonas_violadas : out std_logic_vector(4 downto 0); -- latch das violadas
        alguma_violacao: out std_logic
    );
end gerenciador_zonas;

architecture rtl of gerenciador_zonas is
    type cont_array is array (0 to 4) of integer range 0 to CONFIRMA_TICKS;
    signal cont  : cont_array := (others => 0);
    signal latch : std_logic_vector(4 downto 0) := (others => '0');
begin
    process(clk, rst)
    begin
        if rst = '1' then
            latch <= (others => '0');
            cont  <= (others => 0);
        elsif rising_edge(clk) then
            if limpar_latch = '1' then
                latch <= (others => '0');
                cont  <= (others => 0);
            elsif armado = '1' then
                -- conta tempo de deteccao estavel a cada tick (~10 ms)
                if tick_10ms = '1' then
                    for i in 0 to 4 loop
                        if mascara_ativa(i) = '1' then
                            if sensores(i) = '1' then
                                if cont(i) < CONFIRMA_TICKS then
                                    cont(i) <= cont(i) + 1;
                                end if;
                                -- confirmou tempo minimo -> latcha violacao
                                if cont(i) = CONFIRMA_TICKS - 1 then
                                    latch(i) <= '1';
                                end if;
                            else
                                cont(i) <= 0;              -- deteccao caiu: reinicia
                            end if;
                        else
                            cont(i) <= 0;                  -- zona inibida (bypass)
                        end if;
                    end loop;
                end if;
            end if;
        end if;
    end process;

    zonas_violadas  <= latch;
    alguma_violacao <= '1' when (latch /= "00000") else '0';
end rtl;