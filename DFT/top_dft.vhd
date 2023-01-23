--
-- Written by : Amar Kasibovic
--
-- Description: This block contains an instantiation of the DFT Xilinx IP block, and it creates a more simple interface to it.
--    Some characteristics are:
--    The input data is given in 18 bit precision, and is only real: there is no imaginary input data.
--    The DFT operation is done only in the forward direction.
--    The output given is only in magnitude (phase is not considered), and is a 5 bit value, since not more bits are needed.
--    The magnitude output is calculated using the DFT output (i.e. numbers given in real and immaginary part) -> used magnitude_calculator block.
--    The transform is done using 1536 input 18 bit samples.
--    The output are 1536 values, but, since there is low space for representation on the OLED display, only the first 768 values are considered
--        (this is because the magnitude is periodical in a sampled signal due to the Nyquist sampling theorem). Of this 768 values, only the
--        biggest one every 6 ones was considered, making a total of 768/6 = 128 values, which are easyly plottable on the 32x128 pixel OLED.
--
    

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity top_dft is
    port (
        clk_100 : in std_logic;
        FD_IN : in std_logic;
        RFFD : out std_logic;
        SCLR : in std_logic;
        MAGNITUDE_VALID : out std_logic;
        MAGNITUDE : out std_logic_vector(4 downto 0);
        XN_RE : in std_logic_vector ( 17 downto 0 )
    );   
end top_dft;

architecture Behavioral of top_dft is

    -- This is the DFT Xilinx IP block.
    component dft_block_design is
        port (
            BLK_EXP : out std_logic_vector ( 3 downto 0 );
            CLK : in std_logic;
            CE : in std_logic;
            DATA_VALID : out std_logic;
            FD_IN : in std_logic;
            FD_OUT : out std_logic;
            FWD_INV : in std_logic;
            RFFD : out std_logic;
            SCLR : in std_logic;
            SIZE : in std_logic_vector ( 5 downto 0 );
            XK_IM : out std_logic_vector ( 17 downto 0 );
            XK_RE : out std_logic_vector ( 17 downto 0 );
            XN_IM : in std_logic_vector ( 17 downto 0 );
            XN_RE : in std_logic_vector ( 17 downto 0 )
        );
    end component;
    
    signal xk_im_temp, xk_re_temp : signed(17 downto 0);
    signal fd_out_dft : std_logic;
    signal data_valid_dft : std_logic;
    signal ce_temp : std_logic;
    signal useless_blk_exp : std_logic_vector(3 downto 0);
    signal magnitude_temp : std_logic_vector(4 downto 0);
    
    -- This combinatorial part is needed for calculating the magnitude using the real and imaginary DFT outputs. (Latency ~30 ns)
    component magnitude_calculator is
        port ( real_in : in signed(17 downto 0);                
               imag_in : in signed(17 downto 0);         
               magn_out : out std_logic_vector (4 downto 0)
        );
    end component;
    
    -- This is module 6 counter.
    component counter is
        port( count_enable : in std_logic;
              clk_100 : in std_logic;
              reset_count : in std_logic;
              terminal_count : out std_logic;
              counter_value : out unsigned(3 downto 0));
    end component;
    
    signal count_enable : std_logic;
    signal reset_count : std_logic;
    signal terminal_count : std_logic;
    signal magnitudes_counter : unsigned(3 downto 0) := "0000";
    
    
    signal highest_magnitude_temp : unsigned(4 downto 0) := "00000";
    
    -- FSM states.
    type states is (Idle, 
                    LockDelay1,
                    LockDelay2,
                    LockDelay3,
                    ResetHighest,
                    ReadData);
    signal current_state, next_state : states;
  
begin

    -- Instantiation of the DFT Xilinx IP block.
    dft_block_design_i: component dft_block_design
        port map (
            BLK_EXP(3 downto 0) => useless_blk_exp,                 -- AK: Assigned all zeros because we will look at the mantyssa only
            CLK => clk_100,
            CE => CE_temp,
            DATA_VALID => data_valid_dft,
            FD_IN => FD_IN,
            FD_OUT => fd_out_dft,
            FWD_INV => '1',                                -- AK: Assigned '1' because we will operate only forward transform
            RFFD => RFFD,
            SCLR => SCLR,
            SIZE(5 downto 0) => "100011",                  -- AK: The size of a data frame will be always 1536 samples
            std_logic_vector(XK_IM) => xk_im_temp,
            std_logic_vector(XK_RE) => xk_re_temp,
            XN_IM => "000000000000000000",                 -- AK: Our input signal is real, so we don't need the imaginary part
            XN_RE => XN_RE
        );
    
    -- Instantiation of the magnitude calculator block.
    magnCalc: component magnitude_calculator
        port map (
            real_in => xk_re_temp,
            imag_in => xk_im_temp,
            magn_out => magnitude_temp
        ); 
    
    -- Instantiation of the counter block.
    ctr: component counter
        port map (
            clk_100 => clk_100,
            count_enable => count_enable,
            reset_count => reset_count,
            terminal_count => terminal_count,
            counter_value => magnitudes_counter
        );
       
    magnitude <= std_logic_vector(highest_magnitude_temp);
     
    stato_presente: process(clk_100) is
    begin
        if rising_edge(clk_100) then   
            current_state <= next_state;
        end if;
    end process;
    
    stato_futuro: process(current_state, fd_out_dft, data_valid_dft) is
    begin
        next_state <= Idle;
        case current_state is
            when Idle =>
                if (fd_out_dft = '1') then
                    next_state <= LockDelay1;
                end if;
            when LockDelay1 =>
                next_state <= LockDelay2;
            when LockDelay2 =>
                next_state <= LockDelay3;
            when LockDelay3 =>
                next_state <= ReadData;
            when ReadData =>  
                if (terminal_count = '1') then
                    if (data_valid_dft = '1') then
                        next_state <= ResetHighest;
                    end if;
                else
                    next_state <= LockDelay1;
                end if;
            when ResetHighest =>
                next_state <= LockDelay1;
        end case;
    end process;
    
    uscite: process(current_state) is
    begin
        magnitude_valid <= '0';
        reset_count <= '0';
        count_enable <= '0';
        case (current_state) is
            when Idle =>
                ce_temp <= '1';
            when LockDelay1 =>      -- Delay needed for the calculations that the magnitude calculator has to perform.
                ce_temp <= '0';
            when LockDelay2 =>
                ce_temp <= '0';
            when LockDelay3 =>
                ce_temp <= '0';
                if (unsigned(magnitude_temp) > highest_magnitude_temp) then
                    highest_magnitude_temp <= unsigned(magnitude_temp);
                end if;
            when ReadData =>
                ce_temp <= '1';
                if (terminal_count = '1') then
                    magnitude_valid <= '1';
                    reset_count <= '1';
                else
                    count_enable <= '1';
                end if;
            when ResetHighest =>
                ce_temp <= '0';
                highest_magnitude_temp <= "00000";
        end case;
    end process;
                                   
    
end Behavioral;