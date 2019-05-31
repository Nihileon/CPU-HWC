library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity HWC is
    port(
        -- SWA, SWB, SWC, W(1)\2\3(time)
        SW, W : in std_logic_vector(3 downto 1);
        -- IR: 7~4 high 4bits of an instruction
        IR : in std_logic_vector(7 downto 4);

        C, Z, T3, CLR : in std_logic;
        -- S : 3~0 for ALU, SEL:3~0
        S, SEL: out std_logic_vector(3 downto 0);
        --ALU
        M, CIN, ABUS, LDC, LDZ : out std_logic;
        -- RAM
        MBUS, MEMW : out std_logic;
        -- AR
        LAR, ARINC : out std_logic;
        -- PC
        PCADD, LPC, PCINC : out std_logic;
        -- sequence generator
        STOP, SHORT, LONG : out std_logic;
        -- register, IR, selector, data switcher, SST0
        DRW, LIR, SELCTL, SBUS : out std_logic
    );
end HWC;

architecture rtl of HWC is
    -- write/read register, fetch instruction,
    signal  REG_W, REG_R, FETCH_INS, MEM_W, MEM_R : std_logic;
    signal  ST0 : std_logic;
    signal  ADD, SUB, AND_I, INC, LD, ST, JC, JZ, JMP, STP, OUT_I : std_logic;
        -- 流水中增加 NOP信号
    signal  NOP : std_logic;
    -- what we add in it
    signal  XOR_I, OR_I, NAND_I, DEC, CMP : std_logic;

begin
    REG_W <= '1' when SW = "100" else '0';
    REG_R <= '1' when SW = "011" else '0';
    FETCH_INS <= '1' when SW = "000" else '0';
    MEM_R <= '1' when SW = "010" else '0';
    MEM_W <= '1' when SW = "001" else '0';

    ADD   <= '1' when IR = "0001" else '0';
    SUB   <= '1' when IR = "0010" else '0';
    AND_I <= '1' when IR = "0011" else '0';
    INC   <= '1' when IR = "0100" else '0';
    LD    <= '1' when IR = "0101" else '0';
    ST    <= '1' when IR = "0110" else '0';
    JC    <= '1' when IR = "0111" else '0';
    JZ    <= '1' when IR = "1000" else '0';
    JMP   <= '1' when IR = "1001" else '0';
    STP   <= '1' when IR = "1110" else '0';
    NOP   <= '1' when IR = "0000" else '0';
	OUT_I <= '1' when IR = "1010" else '0';
	-- OR_I  <= '1' when IR = "1011" else '0';
	-- INC   <= '1' when IR = "1011" else '0';
	NAND_I<= '1' when IR = "1100" else '0';
	DEC   <= '1' when IR = "1101" else '0';
	-- CMP   <= '1' when IR = "1111" else '0';
-- 此处把process 删除是因为还不需要用到指令
	process(clr,W)
	begin
		if(clr = '0')then
			ST0<='0';
		elsif(falling_edge(T3))then
			if((REG_W = '1' and W(2)='1')
                or ((MEM_R='1' or MEM_W='1') and W(1)='1' and (ST0 = '0'))) then
					ST0 <= not ST0;
			end if;
        end if;
	end process;
-- 已注释的是由于指令需要用到而放在下方
    SEL(3)  <= (REG_W and (W(1) or W(2)) and ST0)
                or (REG_R and W(2));
    SEL(2)  <= (REG_W and W(2));
    SEL(1)  <= (REG_W and ((W(1) and (not ST0)) or (W(2) and ST0)))
                or (REG_R and W(2));
    SEL(0)  <= (REG_W and W(1))
                or (REG_R and (W(1) or W(2)));
    SBUS    <= (MEM_R and W(1) and (not ST0))
                or (MEM_W and W(1))
                or (REG_W and (W(1) or W(2)))
                or (NOP and W(1) and FETCH_INS); -- #####pc
    -- DRW    <= (REG_W and (W(1) or W(2)));
    -- STOP   <= ((REG_W or REG_R) and (W(1) or W(2)))
    --          or ((MEM_R or MEM_W) and W(1));
    SELCTL  <= ((REG_W or REG_R) and (W(1) or W(2)))
                or ((MEM_R or MEM_W) and W(1));
    -- LAR    <= ((MEM_R or MEM_W) and W(1) and (not ST0));
    -- SHORT   <= ((MEM_R or MEM_W) and W(1));
    -- MBUS   <= (MEM_R and W(1) and ST0);
    ARINC   <= ((MEM_W or MEM_R) and W(1) and ST0);

    --\TODO : yzq: ADD SUB AND_I INC LD

    PCINC   <= (W(1)  and (ADD or SUB or AND_I  or XOR_I or OR_I or NAND_I or DEC or CMP or OUT_I) and FETCH_INS)
                or (W(2) and (ST or JC or JZ or JMP or LD or NOP or INC) and FETCH_INS)
                or (W(1) and (((not C) and JC) or ((not Z) and JZ)) and FETCH_INS); -- AND_I or INC or [move NOP to W(2)]) and FETCH_INS)
    LIR     <= (W(1)  and (ADD or SUB or AND_I or XOR_I or OR_I or NAND_I or DEC or CMP or OUT_I) and FETCH_INS)
                or (W(2) and (ST or JC or JZ or JMP or LD or NOP or INC) and FETCH_INS)
                or (W(1) and (((not C) and JC) or ((not Z) and JZ)) and FETCH_INS);  -- AND_I or INC or [move NOP to W(2)]) and FETCH_INS)
    M       <= ((W(1) or W(2)) and ST and FETCH_INS)
                or (W(1) and (JMP or AND_I or LD or XOR_I or OR_I or NAND_I or OUT_I) and FETCH_INS);
    CIN     <= (W(1) and ADD and FETCH_INS)
				or (W(1) and DEC and FETCH_INS); -- add DEC
    S(3)      <= ((W(1) or W(2)) and ST and FETCH_INS)
                or (W(1) and (JMP or ADD or AND_I or LD or OR_I or DEC or OUT_I) and FETCH_INS); -- add or, dec
    S(2)      <= (W(1) and (ST or JMP or SUB) and FETCH_INS)
				or (W(1) and (XOR_I or OR_I or NAND_I or DEC or CMP) and FETCH_INS); --add xor, or, nand, dec, cmp
    S(1)    <= ((W(1) or W(2)) and ST and FETCH_INS)
                or (W(1) and (JMP or SUB or AND_I or LD) and FETCH_INS)
				or (W(1) and (XOR_I or OR_I or DEC or CMP or OUT_I) and FETCH_INS); --add xor or dec cmp
                -- or (ST0);  --debug
    S(0)    <= (W(1) and (ST or JMP or ADD or AND_I or DEC) and FETCH_INS);-- add dec
    ABUS    <= ((W(1) or W(2)) and ST and FETCH_INS)
                or (W(1) and (JMP or ADD or SUB or AND_I or INC or LD) and FETCH_INS)
				or (W(1) and (XOR_I or OR_I or NAND_I or DEC or OUT_I) and FETCH_INS); --add xor or nand dec
    MBUS    <= (MEM_R and W(1) and ST0)
                or (W(2) and LD and FETCH_INS);
    DRW     <= (REG_W and (W(1) or W(2)))
                or (W(1) and (ADD or SUB or AND_I or INC) and FETCH_INS)
                or (W(2) and LD and FETCH_INS)
				or (W(1) and (XOR_I or OR_I or NAND_I or DEC) and FETCH_INS); --add xor or nand dec
    LDZ     <= (W(1) and (ADD or SUB or AND_I or INC) and FETCH_INS)
				or (W(1) and (XOR_I or OR_I or NAND_I or DEC or CMP) and FETCH_INS); --add xor, or, nand, dec, cmp
    LDC     <= (W(1) and (ADD or SUB or INC) and FETCH_INS)
				or (W(1) and (DEC or CMP) and FETCH_INS); -- add dec cmp
    LPC     <= (W(1) and JMP and FETCH_INS)
				or (W(1) and NOP and FETCH_INS);-- ####PC
    LAR     <= ((MEM_R or MEM_W) and W(1) and (not ST0))
                or (W(1) and (ST or LD) and FETCH_INS);
    LONG    <= '0';
    PCADD   <= (W(1) and C and JC and FETCH_INS)
                or (W(1) and Z and JZ and FETCH_INS);
    MEMW    <= (W(1) and MEM_W and ST0)
                or (W(2) and ST and FETCH_INS);
    STOP    <= ((REG_W or REG_R) and (W(1) or W(2)))
                or ((MEM_R or MEM_W) and W(1))
                or (W(1) and STP and FETCH_INS)
                or (W(1) and NOP and FETCH_INS); --#####PC
    SHORT   <= ((MEM_R or MEM_W) and W(1        ))
                or (W(1) and (((not C) and JC) or ((not Z) and JZ)) and FETCH_INS)
                or (W(1)  and (ADD or SUB or AND_I) and FETCH_INS)
				or (W(1) and (XOR_I or OR_I or NAND_I or DEC or CMP or OUT_I) and FETCH_INS); --add xor, or, nand, dec, cmp
				--or INC or [delete NOP]) and FETCH

end architecture rtl;