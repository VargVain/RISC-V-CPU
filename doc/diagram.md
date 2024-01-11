## Diagram

```mermaid
graph TB

mem[<br/> &nbsp &nbsp &nbsp &nbsp Memory &nbsp &nbsp &nbsp &nbsp  <br /><br/>]
ic(Instruction Cache)
ins(Instruction Unit)
rs(Reservation Station)
alu(ALU)
rob(Reorder Buffer)
rf(Register File)
lsb(Load Store Buffer)

mem-->ic
ic-->ins
ins-->rs
ins-->rob
ins-->rf
rs-->alu
alu-->rob
alu-->rs
rob-->rs
rob-->lsb
lsb-->rob
lsb-->rs
rob-->rf
rf-->ins
mem-->lsb
```

#### Instruction Unit

The instruction unit is responsible for organizing instructions to be fetched from memory. It fetches the instruction at current PC and then issues it to the execution unit.

#### Reservation unit

The reservation unit records instructions as well as the operands of each instruction. It checks if the operands are available and if execution unit is free before starting execution.

#### RS/ALU

The reservation station checks if instructions are ready to calculate. The arithmetic logic unit (ALU) calculates based on the incoming operands and operation codes.

#### Reorder Buffer

The reorder buffer records the order of instructions and guarantees to commit them in sequence by continuously checking if the first instruction is ready to commit.

#### Load Store Buffer

The load store buffer commits changes to data cache and reports to reservation station.

#### Instruction Cache

Use instruction cache to accelerate instruction fetching.
