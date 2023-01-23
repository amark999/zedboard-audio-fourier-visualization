--
-- Written by Kasibovic Amar.
--
-- Description: Using the 5 bits input data and the 2 bits page, takes out the 8 bits that will be sent to the display using SPI.
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity OLED_vertical_line_decoder is
    port ( valueInDecoder : in std_logic_vector(4 downto 0);
           currentPageDecoder : in std_logic_vector(1 downto 0);
           valueOutDecoder : out std_logic_vector(7 downto 0)
         );
end OLED_vertical_line_decoder;


architecture Behavioral of OLED_vertical_line_decoder is
    component decoder_3_8 is
        port ( valueIn3Bit : in std_logic_vector(2 downto 0);
               valueOut8Bit : out std_logic_vector(7 downto 0)
             );
    end component;
    signal decoded38Out : std_logic_vector(7 downto 0);
    
begin
    dec_3_8 : decoder_3_8 port map( valueIn3Bit  => valueInDecoder(2 downto 0),
                                    valueOut8Bit => decoded38Out);
    
    with (not(currentPageDecoder) & valueInDecoder(4 downto 3)) select
        valueOutDecoder <= decoded38Out when "0000" | "0101" | "1010" | "1111",
                           "11111111"   when "0001" | "0010" | "0011" | "0110" | "0111" | "1011",
                           "00000000"   when "0100" | "1000" | "1001" | "1100" | "1101" | "1110",
                           "XXXXXXXX"   when others;
          
end Behavioral;
