--
-- Written by Kasibovic Amar.
--
-- Description: Using the 5 bits input value, it outputs the "column" of pixels.
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity decoder_3_8 is
    port ( valueIn3Bit : in std_logic_vector(2 downto 0);
           valueOut8Bit : out std_logic_vector(7 downto 0)
         );
end decoder_3_8;

architecture Behavioral of decoder_3_8 is

begin
    with valueIn3Bit select
    valueOut8Bit <= "10000000" when "000",
                    "11000000" when "001",
                    "11100000" when "010",
                    "11110000" when "011",
                    "11111000" when "100",
                    "11111100" when "101",
                    "11111110" when "110",
                    "11111111" when "111",
                    "XXXXXXXX" when others;
end Behavioral;
