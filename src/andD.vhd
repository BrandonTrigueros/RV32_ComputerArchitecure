LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY andD IS
    PORT (
        A : IN std_logic;
        B : IN std_logic;
        F : OUT std_logic
    );
END ENTITY andD;

ARCHITECTURE Behavioral OF andD IS
    BEGIN
        F <= (A AND B);
    END Behavioral;