--
-- Written by Ryan Kim, Digilent Inc.
-- Modified by Michael Mattioli
-- Last edit: Kasibovic Amar
--
-- Description: Top level controller that controls the OLED display.
--              It initializes the OLED display through an initializaion process (oled_init component does this),
--              and then it plots the data stored in the memory inside oled_plot.
--              This is done using a FSM.
--
-- Amar Kasibovic edit:
--      Added interface to memory inside oled_plot using signals memAddr, memDataIn, memWE.
--      Changed some variables names.
--  

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity oled_ctrl is
    port (  clk         : in std_logic;
            BTNC        : in std_logic;
            oled_sdin   : out std_logic;
            oled_sclk   : out std_logic;
            oled_dc     : out std_logic;
            oled_res    : out std_logic;
            oled_vbat   : out std_logic;
            oled_vdd    : out std_logic;
            memAddr     : in std_logic_vector(6 downto 0);
            memDataIn   : in std_logic_vector(4 downto 0);
            memWE       : in std_logic);
end oled_ctrl;

architecture behavioral of oled_ctrl is

    component oled_init is
        port (  clk         : in std_logic;
                BTNC        : in std_logic;
                en          : in std_logic;
                sdout       : out std_logic;
                oled_sclk   : out std_logic;
                oled_dc     : out std_logic;
                oled_res    : out std_logic;
                oled_vbat   : out std_logic;
                oled_vdd    : out std_logic;
                fin         : out std_logic);
    end component;

    component oled_plot is
        port (  clk         : in std_logic;
                BTNC        : in std_logic;
                en          : in std_logic;
                sdout       : out std_logic;
                oled_sclk   : out std_logic;
                oled_dc     : out std_logic;
                fin         : out std_logic;
                memAddr     : in std_logic_vector(6 downto 0);
                memDataIn   : in std_logic_vector(4 downto 0);
                memWE       : in std_logic);
    end component;

    type states is (Idle, OledInitialize, OledPlot, Done);
    signal current_state : states := Idle;

    signal init_en          : std_logic := '0';
    signal init_done        : std_logic;
    signal init_sdata       : std_logic;
    signal init_spi_clk     : std_logic;
    signal init_dc          : std_logic;

    signal plot_en       : std_logic := '0';
    signal plot_sdata    : std_logic;
    signal plot_spi_clk  : std_logic;
    signal plot_dc       : std_logic;
    signal plot_done     : std_logic;
    
    
begin

    Initialize: oled_init port map (clk         => clk,
                                    BTNC        => BTNC,
                                    en          => init_en,
                                    sdout       => init_sdata,
                                    oled_sclk   => init_spi_clk,
                                    oled_dc     => init_dc,
                                    oled_res    => oled_res,
                                    oled_vbat   => oled_vbat,
                                    oled_vdd    => oled_vdd,
                                    fin         => init_done);

    Visualize: oled_plot port map ( clk         => clk,
                                  BTNC        => BTNC,
                                  en          => plot_en,
                                  sdout       => plot_sdata,
                                  oled_sclk   => plot_spi_clk,
                                  oled_dc     => plot_dc,
                                  fin         => plot_done,
                                  memAddr     => memAddr, 
                                  memDataIn   => memDataIn,
                                  memWE       => memWE);

    
    -- MUXes to indicate which outputs are routed out depending on which block is enabled
    oled_sdin <= init_sdata when current_state = OledInitialize else plot_sdata;
    oled_sclk <= init_spi_clk when current_state = OledInitialize else plot_spi_clk;
    oled_dc <= init_dc when current_state = OledInitialize else plot_dc;
    -- End output MUXes

    -- MUXes that enable blocks when in the proper states
    init_en <= '1' when current_state = OledInitialize else '0';
    plot_en <= '1' when current_state = OledPlot else '0';
    -- End enable MUXes

    process (clk)
    begin
        if rising_edge(clk) then
            if BTNC = '1' then
                current_state <= Idle;
            else
                case current_state is
                    when Idle =>
                        current_state <= OledInitialize;
                    -- Go through the initialization sequence
                    when OledInitialize =>
                        if init_done = '1' then
                            current_state <= OledPlot;
                        end if;
                    -- Do example and do nothing when finished
                    when OledPlot =>
                        if plot_done = '1' then
                            current_state <= Done;
                        end if;
                    -- Do nthing
                    when Done =>
                        current_state <= Done;
                    when others =>
                        current_state <= Idle;
                end case;
            end if;
        end if;
    end process;

end behavioral;
