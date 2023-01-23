--
-- Written by Ryan Kim, Digilent Inc.
-- Modified by Michael Mattioli
-- Last edit by: Amar Kasibovic (AK)
--
-- Description: This visualizes a set of 128 values ranging in 32 different magnitudes in the form of an
--             histogram. 
--
-- Amar Kasibovic edit:
--        The code by Michael Mattioli generated an hardware which was optimized for text visualization.
--        I needed to plot a histogram, so I had to do edit the functionalities of the previous version.
--        Removed parts: char visualization optimization, ASCII ROM library for conversion of ascii codes 
--                       to pixel-to-visualize layout, hello world and alphabet visualization.
--        Added parts: visualization of the input set of 128 values.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity oled_plot is
    port (  clk         : in std_logic; -- System clock
            BTNC        : in std_logic; -- Global synchronous reset
            en          : in std_logic; -- Block enable pin
            sdout       : out std_logic; -- SPI data out
            oled_sclk   : out std_logic; -- SPI clock
            oled_dc     : out std_logic; -- Data/Command controller
            fin         : out std_logic; -- Finish flag for block
            memAddr     : in std_logic_vector(6 downto 0);
            memDataIn   : in std_logic_vector(4 downto 0);
            memWE       : in std_logic);
end oled_plot;

architecture behavioral of oled_plot is

    -- SPI controller
    component spi_ctrl
        port (  clk         : in std_logic;
                BTNC        : in std_logic;
                en          : in std_logic;
                sdata       : in std_logic_vector (7 downto 0);
                sdout       : out std_logic;
                oled_sclk   : out std_logic;
                fin         : out std_logic);
    end component;

    -- delay controller
    component delay
        port (  clk         : in std_logic;
                BTNC        : in std_logic;
                delay_ms    : in std_logic_vector (11 downto 0);
                delay_en    : in std_logic;
                delay_fin   : out std_logic);
    end component;

    -- AK: Vertical line decoder.
    component OLED_vertical_line_decoder is
        port ( valueInDecoder : in std_logic_vector(4 downto 0);
               currentPageDecoder : in std_logic_vector(1 downto 0);
               valueOutDecoder : out std_logic_vector(7 downto 0)
             );
    end component;
    
    -- AK: simple dual port memory, for storing and reading values to plot.
    component memory_OLED_design is
        port (
            BRAM_PORTB_addr : in STD_LOGIC_VECTOR ( 6 downto 0 );
            BRAM_PORTB_clk : in STD_LOGIC;
            BRAM_PORTB_dout : out STD_LOGIC_VECTOR ( 4 downto 0 );
            BRAM_PORTB_en : in STD_LOGIC;
            BRAM_PORTA_addr : in STD_LOGIC_VECTOR ( 6 downto 0 );
            BRAM_PORTA_clk : in STD_LOGIC;
            BRAM_PORTA_din : in STD_LOGIC_VECTOR ( 4 downto 0 );
            BRAM_PORTA_en : in STD_LOGIC;
            BRAM_PORTA_we : in STD_LOGIC_VECTOR ( 0 to 0 )
        );
    end component memory_OLED_design;
    
    signal BRAM_PORTB_addr : STD_LOGIC_VECTOR ( 6 downto 0 );
    signal BRAM_PORTB_dout : STD_LOGIC_VECTOR ( 4 downto 0 );
    signal BRAM_PORTA_addr : STD_LOGIC_VECTOR ( 6 downto 0 );
    signal BRAM_PORTA_din : STD_LOGIC_VECTOR ( 4 downto 0 );
    
    -- States for state machine
    type states is (Idle,
                    ClearDC,
                    SetPage,
                    PageNum,
                    LeftColumn1,
                    LeftColumn2,
                    SetDC,
                    Wait1,
                    Done,
                    Transition1,
                    Transition2,
                    Transition3,
                    Transition4,
                    Transition5,
                    ProvaVisualizzazioneValori,
                    UpdateScreen);                                            
                                                   
    -- Current overall state of the state machine
    signal current_state : states := Idle;

    -- State to go to after the SPI transmission is finished
    signal after_state : states;

    -- State to go to after the set page sequence
    signal after_page_state : states;

    -- State to go to after the UpdateScreen is finished
    signal after_update_state : states;

    -- Contains the value to be outputted to oled_dc
    signal temp_dc : std_logic := '0';

    -- Used in the Delay controller block
    signal temp_delay_ms : std_logic_vector (11 downto 0); -- Amount of ms to delay
    signal temp_delay_en : std_logic := '0'; -- Enable signal for the Delay block
    signal temp_delay_fin : std_logic; -- Finish signal for the Delay block

    -- Used in the SPI controller block
    signal temp_spi_en : std_logic := '0'; -- Enable signal for the SPI block
    signal temp_sdata : std_logic_vector (7 downto 0) := (others => '0'); -- Data to be sent out on SPI
    signal temp_spi_fin : std_logic; -- Finish signal for the SPI block

    -- AK: Used for the vertical line decoder and the FSM 
    signal temp_dout : std_logic_vector (7 downto 0); -- Contains byte outputted from memory
    signal temp_page : unsigned (1 downto 0) := (others => '0'); -- Current page
    signal temp_index : unsigned(6 downto 0) := "0000000";
    signal temp_valueInDecoder : std_logic_vector(4 downto 0) := (others => '0');
    
   

begin

    oled_dc <= temp_dc;

    -- "Example" finish flag only high when in done state
    fin <= '1' when current_state = Done else '0';              -- AK: never goes high since state Done is never reached

    -- Instantiate SPI controller
    spi_comp: spi_ctrl port map (   clk => clk,
                                    BTNC => BTNC,
                                    en => temp_spi_en,
                                    sdata => temp_sdata,
                                    sdout => sdout,
                                    oled_sclk => oled_sclk,
                                    fin => temp_spi_fin);

    -- Instantiate delay
    delay_comp: delay port map (clk => clk,
                                BTNC => BTNC,
                                delay_ms => temp_delay_ms,
                                delay_en => temp_delay_en,
                                delay_fin => temp_delay_fin);
                  
    -- AK: Instantiate vertical line decoder              
    verticalLineDecoder : OLED_vertical_line_decoder  port map ( valueInDecoder => temp_valueInDecoder,
                                                                 currentPageDecoder => std_logic_vector(temp_page),
                                                                 valueOutDecoder => temp_dout);
    
    -- AK: Instantiate the memory in which are stored the values to plot.
    memory_OLED_design_i: component memory_OLED_design
        port map (
            BRAM_PORTA_addr(6 downto 0) => memAddr,
            BRAM_PORTA_clk => clk,
            BRAM_PORTA_din(4 downto 0) => std_logic_vector(memDataIn),
            BRAM_PORTA_en => '1',
            BRAM_PORTA_we(0) => memWe,
            BRAM_PORTB_addr(6 downto 0) => std_logic_vector(temp_index),
            BRAM_PORTB_clk => clk,
            BRAM_PORTB_dout(4 downto 0) => BRAM_PORTB_dout(4 downto 0),
            BRAM_PORTB_en => '1'
    );
    
             
                                                                 
    -- Process which updates the output value of the decoder when the input is changed.                                                            
    updateTemp_valueInDecoder_amar : process (BRAM_PORTB_dout) is
    begin
        temp_valueInDecoder <= BRAM_PORTB_dout;
    end process;
    
    
    -- Process for the FSM which handles the data plotting.
    FSM: process (clk)
    begin
        if rising_edge(clk) then
            case current_state is
                -- Idle until en pulled high than intialize Page to 0 and go to state alphabet afterwards
                when Idle =>
                    if en = '1' then
                        current_state <= ClearDC;
                        after_page_state <= ProvaVisualizzazioneValori; --Alphabet;
                    end if;
                
                when ProvaVisualizzazioneValori =>
                    current_state <= UpdateScreen;
                    after_update_state <= Wait1;
                    
                when Wait1 =>
                    temp_delay_ms <= "000000100000"; -- 32 ms delay 
                    after_state <= ProvaVisualizzazioneValori; --UpdateMemory; --
                    current_state <= Transition3;
              
                -- Do nothing until en is deassertted and then current_state is Idle
                when Done            =>
                    if en = '0' then
                        current_state <= Idle;
                    end if;

                -- UpdateScreen State
                when UpdateScreen =>
                    temp_sdata <= temp_dout;
                    if temp_index = 127 then
                        temp_index <= "0000000";
                        temp_page <= temp_page +1;
                        if std_logic_vector(temp_page) = "11" then
                            after_state <= after_update_state;
                        else
                            after_state <= ClearDC;
                        end if;
                    else
                        temp_index <= temp_index +1;
                        after_state <= UpdateScreen;
                    end if;
                    current_state <= Transition1; 
                    
                
                -- Update Page states
                -- 1. Sets oled_dc to command mode
                -- 2. Sends the SetPage Command
                -- 3. Sends the Page to be set to
                -- 4. Sets the start pixel to the left column
                -- 5. Sets oled_dc to data mode
                when ClearDC =>
                    temp_dc <= '0';                 -- AK: a command will be sent using SPI (dc = '0' -> command)
                    current_state <= SetPage;
                when SetPage =>
                    temp_sdata <= "00100010";      -- AK: command that means: set page adressing mode
                    after_state <= PageNum;
                    current_state <= Transition1;
                when PageNum =>
                    temp_sdata <= "000000" & std_logic_vector(temp_page);   -- AK: command that means: Set Lower Column Start Address for Page Addressing Mode 
                    after_state <= LeftColumn1;
                    current_state <= Transition1;
                when LeftColumn1 =>
                    temp_sdata <= "00000000";                   
                    after_state <= LeftColumn2;
                    current_state <= Transition1;
                when LeftColumn2 =>
                    temp_sdata <= "00010000";
                    after_state <= SetDC;
                    current_state <= Transition1;
                when SetDC =>
                    temp_dc <= '1';                            -- AK: this command means that data is going to be sent (dc = '1' -> data)
                    current_state <= after_page_state;
                -- End update Page states


                -- SPI transitions
                -- 1. Set en to 1
                -- 2. Waits for spi_ctrl to finish
                -- 3. Goes to clear state (Transition5)
                when Transition1 =>
                    temp_spi_en <= '1';
                    current_state <= Transition2;
                when Transition2 =>
                    if temp_spi_fin = '1' then
                        current_state <= Transition5;
                    end if;
                -- End SPI transitions

                -- Delay transitions
                -- 1. Set delay_en to 1
                -- 2. Waits for delay to finish
                -- 3. Goes to Clear state (Transition5)
                when Transition3 =>
                    temp_delay_en <= '1';
                    current_state <= Transition4;
                when Transition4 =>
                    if temp_delay_fin = '1' then
                        current_state <= Transition5;
                    end if;
                -- End Delay transitions

                -- Clear transition
                -- 1. Sets both delay_en and en to 0
                -- 2. Go to after state
                when Transition5 =>
                    temp_spi_en <= '0';
                    temp_delay_en <= '0';
                    current_state <= after_state;
                -- End Clear transition

                when others =>
                    current_state <= Idle;
            end case;
        end if;
    end process;

end behavioral;
